#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
索尼 A6600 网络摄像头控制台（本地 WebUI）
数据链：gphoto2 (PTP 取景) → ffmpeg (硬件 H.264) → UDP mpegts → OBS 媒体源 → OBS 虚拟摄像头

用法：双击 camera-console.command，浏览器会打开 http://127.0.0.1:8765
"""

import json
import os
import re
import shutil
import signal
import subprocess
import threading
import time
from http.server import ThreadingHTTPServer, BaseHTTPRequestHandler
from urllib.parse import parse_qs, urlparse

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_DIR = os.path.dirname(BASE_DIR)
CONFIG_DIR = os.path.expanduser("~/.sony-webcam")
CONFIG_PATH = os.path.join(CONFIG_DIR, "config.json")
LOG_PATH = "/tmp/sony-webcam.log"
PROG_PATH = "/tmp/sony-webcam-progress.txt"
LOCK_DIR = "/tmp/sony-webcam.lock"
HTTP_PORT = 8765

ENV = dict(os.environ)
ENV["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:" + ENV.get("PATH", "")
# App 内打包模式：若上一级目录有打包的 gphoto2/ffmpeg（App Resources/bin），优先使用
_APP_BIN = os.path.join(os.path.dirname(BASE_DIR), "bin")
_APP_LIB = os.path.join(os.path.dirname(BASE_DIR), "lib")
if os.path.isfile(os.path.join(_APP_BIN, "gphoto2")):
    ENV["PATH"] = _APP_BIN + ":" + ENV["PATH"]
    ENV["CAMLIBS"] = os.path.join(_APP_LIB, "libgphoto2/2.5.34")
    ENV["IOLIBS"] = os.path.join(_APP_LIB, "libgphoto2_port/0.12.2")

DEFAULT_CONFIG = {
    "bitrate": 6,            # Mbps
    "fps": 30,               # 输出帧率
    "gop_seconds": 1,        # 关键帧间隔（秒）
    "bframes": False,        # B 帧（关闭以降低延迟）
    "realtime": True,        # 编码器实时模式
    "muxdelay": 0.0,         # mpegts 复用延迟（秒）
    "port": 1234,            # UDP 端口
    "obs_buffering_mb": 0,   # OBS 媒体源网络缓冲（MB）
    "watchdog": True,        # 画面停滞自动重启
    "watchdog_timeout": 15,  # 停滞判定秒数
}

_lock = threading.RLock()
_state = {
    "proc": None,
    "started_at": None,
    "last_restart": None,
    "restarts": 0,
    "obs_applied_at": None,
}


# ---------------- 配置 ----------------
def load_config():
    cfg = dict(DEFAULT_CONFIG)
    try:
        with open(CONFIG_PATH, "r", encoding="utf-8") as f:
            cfg.update(json.load(f))
    except Exception:
        pass
    return cfg


def save_config(cfg):
    os.makedirs(CONFIG_DIR, exist_ok=True)
    with open(CONFIG_PATH, "w", encoding="utf-8") as f:
        json.dump(cfg, f, ensure_ascii=False, indent=2)


# ---------------- 进程管理 ----------------
def _kill_existing():
    """清理可能残留的推流进程"""
    subprocess.run(["pkill", "-f", "gphoto2 --capture-movie"],
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    proc = _state.get("proc")
    if proc and proc.poll() is None:
        try:
            os.killpg(os.getpgid(proc.pid), signal.SIGTERM)
        except Exception:
            pass
        try:
            proc.wait(timeout=3)
        except Exception:
            try:
                os.killpg(os.getpgid(proc.pid), signal.SIGKILL)
            except Exception:
                pass
    _state["proc"] = None
    _state["started_at"] = None
    shutil.rmtree(LOCK_DIR, ignore_errors=True)


def build_cmd(cfg):
    gop = max(1, int(cfg["fps"] * cfg["gop_seconds"]))
    br = cfg["bitrate"]
    vport = int(cfg["port"]) + 1

    def enc_opts():
        o = ["-c:v", "h264_videotoolbox",
             "-b:v", f"{br}M", "-maxrate", f"{br}M", "-bufsize", f"{max(1, br // 2)}M",
             "-g", str(gop)]
        if not cfg["bframes"]:
            o += ["-bf", "0"]
        if cfg["realtime"]:
            o += ["-realtime", "1"]
        o += ["-pix_fmt", "yuv420p", "-r", str(cfg["fps"]),
              "-muxdelay", str(cfg["muxdelay"]), "-muxpreload", str(cfg["muxdelay"])]
        return o

    parts = [
        "gphoto2 --capture-movie --stdout 2>/dev/null",
        "|",
        "ffmpeg -hide_banner -loglevel warning -nostats",
        "-progress", PROG_PATH,
        "-fflags", "nobuffer", "-flags", "low_delay",
        "-f", "mjpeg", "-i", "-",
        "-map", "0:v",
    ]
    parts += enc_opts()
    parts += ["-f", "mpegts", f"'udp://127.0.0.1:{cfg['port']}?pkt_size=1316'"]
    # 第二路输出（浏览器直播页）：独立编码器实例，VideoToolbox 双实例开销可忽略
    parts += enc_opts()
    parts += ["-f", "mpegts", f"'udp://127.0.0.1:{vport}?pkt_size=1316'"]
    return " ".join(parts)


def start_pipeline(cfg, reason="手动启动"):
    with _lock:
        proc = _state.get("proc")
        if proc and proc.poll() is None:
            return False, "推流已在运行中"
        # 控制台手动启动 = 恢复自动启动授权
        try:
            os.remove("/tmp/sony-webcam-manual-stop")
        except OSError:
            pass
        _kill_existing()
        os.makedirs(CONFIG_DIR, exist_ok=True)
        os.makedirs(LOCK_DIR, exist_ok=True)
        with open(os.path.join(LOCK_DIR, "pid"), "w") as f:
            f.write(str(os.getpid()))
        try:
            os.remove(PROG_PATH)
        except OSError:
            pass
        log = open(LOG_PATH, "a", encoding="utf-8", buffering=1)
        log.write(f"\n=== {time.strftime('%Y-%m-%d %H:%M:%S')} 启动推流（{reason}）===\n")
        log.write(f"$ {build_cmd(cfg)}\n")
        log.flush()
        p = subprocess.Popen(
            ["/bin/zsh", "-c", build_cmd(cfg)],
            stdout=log, stderr=log, stdin=subprocess.DEVNULL,
            preexec_fn=os.setsid, env=ENV,
        )
        _state["proc"] = p
        _state["started_at"] = time.time()
        return True, f"已启动（PID {p.pid}）"


def stop_pipeline(reason="手动停止"):
    with _lock:
        proc = _state.get("proc")
        was_running = bool(proc and proc.poll() is None)
        _kill_existing()
        # 手动停止 = 暂停守护进程的自动启动
        open("/tmp/sony-webcam-manual-stop", "w").close()
        with open(LOG_PATH, "a", encoding="utf-8") as log:
            log.write(f"=== {time.strftime('%Y-%m-%d %H:%M:%S')} 停止推流（{reason}）===\n")
        return was_running, "已停止" if was_running else "推流未运行"


def restart_pipeline(cfg, reason="重启"):
    stop_pipeline(reason)
    time.sleep(0.5)
    return start_pipeline(cfg, reason)


# ---------------- 状态采集 ----------------
def parse_progress():
    data = {}
    try:
        with open(PROG_PATH, "r", encoding="utf-8", errors="ignore") as f:
            for line in f:
                if "=" in line:
                    k, v = line.strip().split("=", 1)
                    data[k] = v
        data["_age"] = round(time.time() - os.path.getmtime(PROG_PATH), 1)
    except Exception:
        data["_age"] = None
    return data


_cam_cache = {"ts": 0, "ok": False}


def camera_ok(force=False):
    now = time.time()
    if not force and now - _cam_cache["ts"] < 15:
        return _cam_cache["ok"]
    try:
        out = subprocess.run(["gphoto2", "--auto-detect"], capture_output=True,
                             text=True, timeout=10, env=ENV).stdout
        ok = "Sony" in out
    except Exception:
        ok = False
    _cam_cache.update(ts=now, ok=ok)
    return ok


def log_tail(lines=80):
    try:
        with open(LOG_PATH, "r", encoding="utf-8", errors="ignore") as f:
            return "".join(f.readlines()[-lines:])
    except Exception:
        return ""


def obs_scene_path():
    scenes = os.path.expanduser("~/Library/Application Support/obs-studio/basic/scenes")
    try:
        cands = [os.path.join(scenes, f) for f in os.listdir(scenes) if f.endswith(".json")]
        return max(cands, key=os.path.getmtime) if cands else None
    except Exception:
        return None


def apply_obs_buffering(mb, port):
    path = obs_scene_path()
    if not path:
        return False, "找不到 OBS 场景文件"
    try:
        with open(path, "r", encoding="utf-8") as f:
            d = json.load(f)
        n = 0
        for s in d.get("sources", []):
            if s.get("id") == "ffmpeg_source":
                st = s.setdefault("settings", {})
                st["input"] = f"udp://127.0.0.1:{port}"
                st["input_format"] = "mpegts"
                st["buffering_mb"] = mb
                st.setdefault("is_local_file", False)
                st.setdefault("restart_on_activate", True)
                n += 1
        with open(path, "w", encoding="utf-8") as f:
            json.dump(d, f, ensure_ascii=False, indent=4)
        _state["obs_applied_at"] = time.time()
        return True, f"已写入 OBS 媒体源配置（{n} 个源），重启 OBS 后生效"
    except Exception as e:
        return False, f"写入失败：{e}"


def restart_obs():
    subprocess.run(["pkill", "-x", "OBS"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    time.sleep(2)
    r = subprocess.run(["open", "-a", "OBS"], capture_output=True, text=True)
    return r.returncode == 0, "OBS 已重启" if r.returncode == 0 else f"启动 OBS 失败：{r.stderr}"


# ---------------- 浏览器直播（免 OBS） ----------------
VIEWER_HTML = """<!DOCTYPE html>
<html lang="zh"><head><meta charset="utf-8">
<title>A6600 直播画面</title>
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
  body{margin:0;background:#111;color:#eee;font-family:-apple-system,sans-serif;
       display:flex;flex-direction:column;align-items:center;min-height:100vh}
  h1{font-size:16px;font-weight:600;margin:14px 0 4px}
  p{font-size:12px;color:#999;margin:4px 0 10px;text-align:center;padding:0 16px}
  img{width:100%;max-width:1280px;background:#000;aspect-ratio:16/9;object-fit:contain}
  #tip{color:#f66}
</style></head><body>
<h1>📷 A6600 直播画面（浏览器直连，无需 OBS）</h1>
<p>会议软件里选择「共享屏幕/窗口」时，共享本浏览器窗口即可。<br>
按 M 键静音黑屏，避免投屏时露出私人窗口。</p>
<img id="cam" src="/stream.mjpeg" alt="等待画面">
<p id="tip"></p>
<script>
const img=document.getElementById("cam"),tip=document.getElementById("tip");
img.onerror=()=>{tip.textContent="❌ 没有画面：请确认推流已启动（插上相机或从菜单栏启动）";
 setTimeout(()=>{img.src="/stream.mjpeg?"+Date.now();tip.textContent=""},3000);};
window.addEventListener("keydown",e=>{
 if(e.key==="m"||e.key==="M"){img.style.display=img.style.display==="none"?"block":"none";}});
</script>
</body></html>"""


# ---------------- 看门狗 ----------------
def watchdog_loop():
    while True:
        time.sleep(5)
        with _lock:
            cfg = load_config()
            if not cfg.get("watchdog", True):
                continue
            proc = _state.get("proc")
            if not proc or proc.poll() is not None:
                continue
            prog = parse_progress()
            age = prog.get("_age")
            if age is not None and age > cfg.get("watchdog_timeout", 15):
                _state["restarts"] += 1
                _state["last_restart"] = time.time()
                with open(LOG_PATH, "a", encoding="utf-8") as log:
                    log.write(f"=== 看门狗：画面停滞 {age}s，自动重启（第 {_state['restarts']} 次）===\n")
                stop_pipeline("看门狗")
                time.sleep(0.5)
                start_pipeline(cfg, "看门狗重启")


# ---------------- HTTP ----------------
class Handler(BaseHTTPRequestHandler):
    server_version = "SonyCamConsole/1.0"

    def log_message(self, fmt, *args):
        pass

    def _send(self, code, body, ctype="application/json; charset=utf-8"):
        raw = body.encode("utf-8") if isinstance(body, str) else body
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(raw)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(raw)

    def _json(self, obj, code=200):
        self._send(code, json.dumps(obj, ensure_ascii=False))

    def _serve_mjpeg(self, viewer_port):
        """把 UDP 1235 上的 mjpeg-in-mpegts 转成 HTTP multipart 流给浏览器"""
        try:
            ffmpeg = shutil.which("ffmpeg", path=ENV["PATH"]) or "ffmpeg"
            proc = subprocess.Popen(
                [ffmpeg, "-hide_banner", "-loglevel", "error", "-nostdin",
                 "-fflags", "nobuffer", "-flags", "low_delay",
                 "-f", "mpegts", "-i", f"udp://127.0.0.1:{viewer_port}?timeout=5000000",
                 "-c:v", "mjpeg", "-q:v", "4", "-f", "mpjpeg",
                 "-boundary_tag", "sonycam", "-"],
                stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, env=ENV)
        except Exception as e:
            self._send(500, f"ffmpeg 启动失败: {e}", "text/plain; charset=utf-8")
            return
        self.send_response(200)
        self.send_header("Content-Type", "multipart/x-mixed-replace; boundary=sonycam")
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        try:
            while True:
                chunk = proc.stdout.read(8192)
                if not chunk:
                    break
                self.wfile.write(chunk)
        except Exception:
            pass  # 客户端断开
        finally:
            proc.kill()
            proc.wait()

    def do_GET(self):
        u = urlparse(self.path)
        if u.path in ("/", "/index.html"):
            p = os.path.join(BASE_DIR, "index.html")
            try:
                with open(p, "rb") as f:
                    self._send(200, f.read(), "text/html; charset=utf-8")
            except Exception as e:
                self._send(500, f"index.html 缺失: {e}", "text/plain; charset=utf-8")
            return
        if u.path == "/api/status":
            with _lock:
                proc = _state.get("proc")
                running = bool(proc and proc.poll() is None)
                prog = parse_progress()
                cfg = load_config()
                self._json({
                    "running": running,
                    "pid": proc.pid if running else None,
                    "uptime": int(time.time() - _state["started_at"]) if running and _state["started_at"] else 0,
                    "restarts": _state["restarts"],
                    "progress": prog,
                    "camera": camera_ok(),
                    "config": cfg,
                    "log": log_tail(40),
                })
            return
        if u.path == "/api/log":
            n = int(parse_qs(u.query).get("lines", ["120"])[0])
            self._send(200, log_tail(n), "text/plain; charset=utf-8")
            return
        if u.path == "/viewer":
            self._send(200, VIEWER_HTML, "text/html; charset=utf-8")
            return
        if u.path == "/stream.mjpeg":
            self._serve_mjpeg(int(parse_qs(u.query).get("port", [str(int(DEFAULT_CONFIG["port"]) + 1)])[0]))
            return
        self._json({"error": "not found"}, 404)

    def do_POST(self):
        u = urlparse(self.path)
        length = int(self.headers.get("Content-Length") or 0)
        body = {}
        if length:
            try:
                body = json.loads(self.rfile.read(length).decode("utf-8"))
            except Exception:
                body = {}

        if u.path == "/api/start":
            cfg = load_config()
            ok, msg = start_pipeline(cfg, "控制台启动")
            self._json({"ok": ok, "msg": msg})
            return
        if u.path == "/api/stop":
            ok, msg = stop_pipeline("控制台停止")
            self._json({"ok": True, "msg": msg})
            return
        if u.path == "/api/restart":
            cfg = load_config()
            ok, msg = restart_pipeline(cfg, "控制台重启")
            self._json({"ok": ok, "msg": msg})
            return
        if u.path == "/api/config":
            cfg = load_config()
            for k, v in body.items():
                if k in DEFAULT_CONFIG:
                    cfg[k] = v
            # 基本校验
            cfg["bitrate"] = max(1, min(20, int(cfg["bitrate"])))
            cfg["fps"] = 30 if int(cfg["fps"]) >= 30 else 25
            cfg["gop_seconds"] = max(0.2, min(10, float(cfg["gop_seconds"])))
            cfg["port"] = int(cfg["port"])
            cfg["obs_buffering_mb"] = max(0, min(20, int(cfg["obs_buffering_mb"])))
            cfg["watchdog_timeout"] = max(5, min(120, int(cfg["watchdog_timeout"])))
            save_config(cfg)
            restarted = False
            if body.get("apply_now"):
                with _lock:
                    proc = _state.get("proc")
                    if proc and proc.poll() is None:
                        restart_pipeline(cfg, "应用新参数")
                        restarted = True
            self._json({"ok": True, "msg": "设置已保存" + ("并重启推流" if restarted else ""),
                        "config": cfg, "restarted": restarted})
            return
        if u.path == "/api/obs/apply":
            cfg = load_config()
            ok, msg = apply_obs_buffering(cfg["obs_buffering_mb"], cfg["port"])
            self._json({"ok": ok, "msg": msg})
            return
        if u.path == "/api/obs/restart":
            ok, msg = restart_obs()
            self._json({"ok": ok, "msg": msg})
            return
        self._json({"error": "not found"}, 404)


def main():
    threading.Thread(target=watchdog_loop, daemon=True).start()
    srv = ThreadingHTTPServer(("127.0.0.1", HTTP_PORT), Handler)
    url = f"http://127.0.0.1:{HTTP_PORT}"

    def _bye(signum=None, frame=None):
        stop_pipeline("控制台退出")
        os._exit(0)

    signal.signal(signal.SIGTERM, _bye)
    signal.signal(signal.SIGINT, _bye)

    print(f"[camera-console] 控制台已启动：{url}")
    print("[camera-console] 关闭此窗口即退出控制台（推流会一并停止）")
    threading.Timer(1.0, lambda: subprocess.run(["open", url])).start()
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        _bye()


if __name__ == "__main__":
    main()
