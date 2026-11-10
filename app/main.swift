import AppKit

// A6600 即插即连摄像头 App（菜单栏常驻）
// App 运行中：相机插入 USB 自动开始推流，拔出自动停止
// 退出 App：停止推流，且不再有任何自动行为

// 资源定位：优先使用 App 内打包资源（自包含，任意 Mac 即开即用）。
// 开发调试（裸 SonyCam 二进制运行）时回退：环境变量 SONYCAM_WORKSPACE > 当前目录。
let resPath: String = {
    let r = Bundle.main.resourcePath ?? ""
    if FileManager.default.fileExists(atPath: r + "/scripts/sony-webcam.sh") { return r }
    if let env = ProcessInfo.processInfo.environment["SONYCAM_WORKSPACE"],
       FileManager.default.fileExists(atPath: env + "/sony-webcam.sh") { return env }
    return FileManager.default.currentDirectoryPath
}()
let SCRIPT = resPath + "/scripts/sony-webcam.sh"
let WEBUI_SERVER = resPath + "/webui/server.py"

// 单引号转义，便于把含空格/中文的路径安全拼进 shell 命令
func shellQuote(_ s: String) -> String {
    return "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
}
let FLAG = "/tmp/sony-webcam-manual-stop"
let LOCK = "/tmp/sony-webcam.lock"
let LOG = "/tmp/sony-webcam.log"
let LA_AGENT = NSHomeDirectory() + "/Library/LaunchAgents/com.chentao.sony-webcam-watcher.plist"
let WATCHER_LABEL = "com.chentao.sony-webcam-watcher"

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    var pipeline: Process?
    var consoleProc: Process?
    var cameraPresent = false
    var lastStartAttempt: Date?
    var timer: Timer?
    var statusMenuItem: NSMenuItem!
    var autoMenuItem: NSMenuItem!
    var startItem: NSMenuItem!
    var stopItem: NSMenuItem!
    var agentNoteItem: NSMenuItem!

    var autoEnabled: Bool { !FileManager.default.fileExists(atPath: FLAG) }
    var streamRunning: Bool { pipeline?.isRunning ?? false }

    func applicationDidFinishLaunching(_ n: Notification) {
        takeOverLaunchAgent()
        buildMenu()
        applyIcon()
        timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in self?.tick() }
        tick()
    }

    // 接管（停用）之前安装的 launchd 守护，避免双重自动启动
    func takeOverLaunchAgent() {
        let uid = getuid()
        runShell("launchctl bootout gui/\(uid)/\(WATCHER_LABEL) 2>/dev/null; rm -f '\(LA_AGENT)'; true")
    }

    func buildMenu() {
        let m = NSMenu()
        statusMenuItem = NSMenuItem(title: "状态检查中…", action: nil, keyEquivalent: "")
        m.addItem(statusMenuItem)
        m.addItem(NSMenuItem.separator())

        autoMenuItem = NSMenuItem(title: "自动连接：开", action: #selector(toggleAuto(_:)), keyEquivalent: "a")
        autoMenuItem.target = self
        m.addItem(autoMenuItem)

        startItem = NSMenuItem(title: "立即启动推流", action: #selector(startNow(_:)), keyEquivalent: "s")
        startItem.target = self
        m.addItem(startItem)

        stopItem = NSMenuItem(title: "停止推流（暂停自动连接）", action: #selector(stopNow(_:)), keyEquivalent: "x")
        stopItem.target = self
        m.addItem(stopItem)

        m.addItem(NSMenuItem.separator())
        let viewer = NSMenuItem(title: "浏览器直播画面（免 OBS，共享窗口用）", action: #selector(openViewer(_:)), keyEquivalent: "v")
        viewer.target = self
        m.addItem(viewer)
        let console = NSMenuItem(title: "打开 WebUI 参数控制台", action: #selector(openConsole(_:)), keyEquivalent: "c")
        console.target = self
        m.addItem(console)
        let licenses = NSMenuItem(title: "开源许可与第三方组件声明", action: #selector(openLicenses(_:)), keyEquivalent: "l")
        licenses.target = self
        m.addItem(licenses)

        agentNoteItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        agentNoteItem.isHidden = true
        m.addItem(agentNoteItem)

        m.addItem(NSMenuItem.separator())
        let quit = NSMenuItem(title: "退出 App（同时停止推流）", action: #selector(quitApp(_:)), keyEquivalent: "q")
        quit.target = self
        m.addItem(quit)

        m.delegate = self
        m.autoenablesItems = false
        statusItem.menu = m
    }

    func menuWillOpen(_ menu: NSMenu) { refreshMenu() }

    func refreshMenu() {
        statusMenuItem.title = statusText()
        autoMenuItem.title = autoEnabled
            ? "自动连接：开（插上相机即推流）"
            : "自动连接：关（已暂停）"
        startItem.isEnabled = !streamRunning
        stopItem.isEnabled = streamRunning
    }

    func statusText() -> String {
        if streamRunning { return cameraPresent ? "🟢 推流中 · 相机已连接" : "🟡 推流中 · 相机已断开，即将停止" }
        if !autoEnabled { return "⏸ 已暂停自动连接" }
        if cameraPresent { return "🟡 相机已连接，正在启动…" }
        return "⚪️ 待机 · 等待相机插入"
    }

    func applyIcon() {
        statusItem.button?.title = streamRunning ? "📹" : "📷"
    }

    // MARK: - 主循环（每 3 秒）
    func tick() {
        cameraPresent = checkCamera()
        if cameraPresent && autoEnabled && !streamRunning {
            // 失败重试冷却 12 秒，避免相机未进入 PC 遥控时疯狂拉起
            if let t = lastStartAttempt, Date().timeIntervalSince(t) < 12 {
                // 等待冷却
            } else {
                startPipeline()
            }
        }
        // 相机拔出后脚本会自己退出，这里只负责图标与菜单刷新
        applyIcon()
        if statusItem.menu?.supermenu != nil { refreshMenu() }
    }

    // MARK: - 相机检测
    func checkCamera() -> Bool {
        guard let p = runCapture("/usr/sbin/ioreg", ["-p", "IOUSB", "-w", "0"]) else { return false }
        return p.contains("ILCE-6600")
    }

    func runCapture(_ path: String, _ args: [String]) -> String? {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = FileHandle.nullDevice
        do { try p.run() } catch { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    func runShell(_ cmd: String) -> String? {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/zsh")
        p.arguments = ["-c", cmd]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = FileHandle.nullDevice
        do { try p.run() } catch { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return String(data: data, encoding: .utf8)
    }

    // MARK: - 推流管理
    func appendLog(_ s: String) {
        let fm = FileManager.default
        if !fm.fileExists(atPath: LOG) { fm.createFile(atPath: LOG, contents: nil) }
        if let h = FileHandle(forWritingAtPath: LOG) {
            h.seekToEndOfFile()
            h.write(s.data(using: .utf8)!)
            try? h.close()
        }
    }

    func startPipeline() {
        lastStartAttempt = Date()
        runShell("pkill -f 'gphoto2 --capture-movie' 2>/dev/null; true")
        let fm = FileManager.default
        try? fm.removeItem(atPath: LOCK)
        try? fm.removeItem(atPath: FLAG)

        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/zsh")
        p.arguments = [SCRIPT]
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        p.environment = env
        if !fm.fileExists(atPath: LOG) { fm.createFile(atPath: LOG, contents: nil) }
        if let h = FileHandle(forWritingAtPath: LOG) { h.seekToEndOfFile(); p.standardOutput = h; p.standardError = h }
        do { try p.run() } catch {
            appendLog("[app] 启动失败: \(error)\n")
            return
        }
        pipeline = p
        appendLog("[app] \(Date()) 自动启动推流 (PID \(p.processIdentifier))\n")
        applyIcon()
    }

    func stopPipeline() {
        if let p = pipeline, p.isRunning {
            p.terminate()
        }
        pipeline = nil
        // 兜底清理子进程（gphoto2/ffmpeg）
        DispatchQueue.global().async { [weak self] in
            let k = Process()
            k.executableURL = URL(fileURLWithPath: "/bin/zsh")
            k.arguments = ["-c", "pkill -f 'gphoto2 --capture-movie' 2>/dev/null; pkill -f 'sony-webcam.sh' 2>/dev/null; true"]
            try? k.run()
            k.waitUntilExit()
            DispatchQueue.main.async { self?.applyIcon() }
        }
        applyIcon()
    }

    // MARK: - 菜单动作
    @objc func toggleAuto(_ s: Any?) {
        let fm = FileManager.default
        if autoEnabled {
            fm.createFile(atPath: FLAG, contents: nil)
        } else {
            try? fm.removeItem(atPath: FLAG)
        }
        refreshMenu()
    }

    @objc func startNow(_ s: Any?) {
        try? FileManager.default.removeItem(atPath: FLAG)
        startPipeline()
        refreshMenu()
    }

    @objc func stopNow(_ s: Any?) {
        FileManager.default.createFile(atPath: FLAG, contents: nil)
        stopPipeline()
        refreshMenu()
    }

    // 确保控制台服务在运行，返回是否成功
    @discardableResult
    func ensureConsole() -> Bool {
        let consoleRunning = consoleProc?.isRunning ?? false
        if !consoleRunning {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            p.arguments = ["python3", WEBUI_SERVER]
            var env = ProcessInfo.processInfo.environment
            env["PATH"] = "/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
            p.environment = env
            do { try p.run() } catch { return false }
            consoleProc = p
            Thread.sleep(forTimeInterval: 0.5)   // 等 HTTP 服务就绪
        }
        return consoleProc?.isRunning ?? false
    }

    @objc func openViewer(_ s: Any?) {
        if ensureConsole() {
            runShell("open 'http://127.0.0.1:8765/viewer'")
        }
    }

    @objc func openConsole(_ s: Any?) {
        ensureConsole()
        runShell("open http://127.0.0.1:8765")
    }

    @objc func openLicenses(_ s: Any?) {
        // 打开随包分发的许可证目录：优先 README 索引，其次目录本身
        let dir = resPath + "/LICENSES"
        let idx = dir + "/README.md"
        let notice = resPath + "/THIRD-PARTY-NOTICES.md"
        if FileManager.default.fileExists(atPath: idx) {
            runShell("open " + shellQuote(idx))
        } else if FileManager.default.fileExists(atPath: dir) {
            runShell("open " + shellQuote(dir))
        } else {
            runShell("open " + shellQuote(notice))
        }
    }

    @objc func quitApp(_ s: Any?) {
        stopPipeline()
        if let c = consoleProc, c.isRunning { c.terminate() }
        NSApp.terminate(nil)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)   // 菜单栏应用，不占 Dock
app.run()
