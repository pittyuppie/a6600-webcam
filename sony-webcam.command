#!/bin/zsh
# 索尼 A6600 网络摄像头服务（绕过 Imaging Edge Webcam）
# 数据链：gphoto2 (PTP 取景) → ffmpeg (硬件转码 H.264) → UDP 127.0.0.1:1234 (mpegts)
# OBS「媒体源」：输入 udp://127.0.0.1:1234，输入格式 mpegts
# 停止：双击 stop-sony-webcam.command，或在本窗口按 Ctrl+C

export PATH="/opt/homebrew/bin:$PATH"
URL="udp://127.0.0.1:1234?pkt_size=1316"
LOCK="/tmp/sony-webcam.lock"
PROG="/tmp/sony-webcam-progress.txt"
STALL_LIMIT=15   # 超过这么多秒没有新帧就重启管道

# ---- 防重复实例 ----
if ! mkdir "$LOCK" 2>/dev/null; then
    pid=$(cat "$LOCK/pid" 2>/dev/null)
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
        echo "[sony-webcam] 已有实例在运行 (PID $pid)，本实例退出"
        exit 0
    fi
    rm -rf "$LOCK"
    mkdir "$LOCK"
fi
echo $$ > "$LOCK/pid"
trap 'rm -rf "$LOCK"' EXIT

echo "[sony-webcam] 检查相机..."
if ! gphoto2 --auto-detect 2>/dev/null | grep -q "Sony"; then
    echo "[sony-webcam] ❌ 未检测到索尼相机"
    echo "   请确认：USB 已连接 + 相机菜单 网络 → PC 遥控功能 → PC 遥控：开"
    sleep 5
    exit 1
fi

echo "[sony-webcam] ✅ 相机已连接"
echo "[sony-webcam] 🟢 推流已就绪：$URL（格式 mpegts）"
echo "[sony-webcam]    本窗口请保持打开，关闭窗口即停止推流"
echo "[sony-webcam]    已启用卡顿看门狗：画面停滞 ${STALL_LIMIT}s 自动重启管道"

while true; do
    rm -f "$PROG"
    # 防止 macOS 图像捕捉服务抢占相机（它会自动复活，所以每次取景前都清一次）
    killall ptpcamerad 2>/dev/null
    sleep 1
    gphoto2 --capture-movie --stdout 2>/dev/null \
    | ffmpeg -loglevel warning -nostats -progress "$PROG" \
             -fflags nobuffer -flags low_delay \
             -f mjpeg -i - \
             -c:v h264_videotoolbox -b:v 6M -maxrate 6M -bufsize 3M \
             -g 30 -bf 0 -realtime 1 -pix_fmt yuv420p -r 30 \
             -muxdelay 0 -muxpreload 0 \
             -f mpegts "$URL" &
    PIPE_PID=$!

    # 看门狗：-progress 文件不再更新 = 取景卡住
    while kill -0 $PIPE_PID 2>/dev/null; do
        sleep 5
        if [ -f "$PROG" ]; then
            age=$(( $(date +%s) - $(stat -f %m "$PROG") ))
            if [ "$age" -gt "$STALL_LIMIT" ]; then
                echo "[sony-webcam] ⚠️ 画面停滞 ${age}s，重启取景管道"
                kill $PIPE_PID 2>/dev/null
                pkill -f "gphoto2 --capture-movie" 2>/dev/null
                break
            fi
        fi
    done
    wait $PIPE_PID 2>/dev/null
    echo "[sony-webcam] 🔄 2 秒后重新开始取景（Ctrl+C 退出）"
    sleep 2
done
