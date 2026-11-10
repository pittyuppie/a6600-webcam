# A6600 摄像头 for macOS

把索尼 A6600（ILCE-6600）变成 macOS 上即插即用的直播/会议摄像头。

一个菜单栏小工具：**插上相机自动开始推流、拔出自动停止、退出 App 一切归零**。
内置 gphoto2 与 FFmpeg 全部依赖，**目标电脑无需安装 Homebrew**，拖进应用程序文件夹就能用。

> 为什么需要它：索尼官方的 Imaging Edge Webcam 在 macOS 26/27 上存在兼容性问题
> （相机一直停留在「正在连接...」），本项目用 gphoto2 的 PTP 取景完全绕开了它。

## 功能

- 📷 **即插即连**：菜单栏常驻，A6600 插上 USB 自动推流，拔出自动停止
- 🎛 **WebUI 参数控制台**：码率 / 帧率 / 关键帧 / B 帧 / UDP 端口 / 看门狗，实时 FPS 曲线，三档预设
- 🖥 **两种观看方式**：
  - **OBS 虚拟摄像头**（推荐）——会议软件里直接选择「OBS Virtual Camera」
  - **浏览器直播页**——免安装 OBS，浏览器打开画面，会议软件共享窗口即可（按 M 可瞬间黑屏）
- 🛡 **卡顿看门狗**：画面停滞自动重启取景管道
- 📦 **完全自包含**：gphoto2 2.5.32 + FFmpeg 9.0.2（VideoToolbox 硬编码）+ 全部依赖库打包在 App 内

## 安装

1. 从 [Releases](../../releases) 下载 `A6600摄像头-macOS-arm64.dmg`
2. 双击打开，把 **A6600摄像头.app** 拖入右侧的 **Applications**
3. 首次打开：因为未做公证（notarization），macOS 会拦截一次——
   在「应用程序」里 **右键 App → 打开 → 打开**，之后再打开就不会再拦
4. 菜单栏出现 📷 图标即安装成功

> 仅支持 Apple Silicon（M 系列）Mac。

## 相机设置（重要）

| 设置项 | 位置 | 要求 |
|---|---|---|
| PC 遥控 | 网络 → PC 遥控功能 → PC 遥控 | **开** |
| USB 连接模式 | 设置 → USB | USB 流式传输 / PC 遥控 |
| 波轮档位 | 机身波轮 | **P / S / M / A / Auto 任一拍照档** |

⚠️ **波轮请勿停在影像模式（电影档）**：影像模式下相机会把 PC 遥控取景当作真实录制
写入储存卡，推流重启时会反复打断写入，导致相机卡在「正在写入储存卡，请稍等」、
画面停滞。拍照档则是纯取景流、不落卡，完全稳定。

## 使用方式

### 方式 A：OBS 虚拟摄像头（推荐）

1. 安装 [OBS Studio](https://obsproject.com)（仅需一次）
2. OBS 里添加 **媒体源**：取消勾选「本地文件」，
   输入 `udp://127.0.0.1:1234`，输入格式 `mpegts`，网络缓冲 `0 MB`
3. 右键媒体源 → 高级属性 → 关闭「使用硬件解码（如可用）」保持默认即可
4. OBS → 启动虚拟摄像头
5. 会议软件里选择摄像头为 **OBS Virtual Camera**

App 菜单里有「一键写入 OBS 配置」的参数控制台可以帮你完成第 2 步。

### 方式 B：浏览器直播（免 OBS）

1. 菜单栏图标 → **浏览器直播画面（免 OBS，共享窗口用）**（快捷键 V）
2. 浏览器打开 `http://127.0.0.1:8765/viewer`，画面直接显示
3. 会议软件里选择「共享屏幕/窗口」→ 共享这个浏览器窗口
4. 按 **M** 键可瞬间隐藏画面（再按恢复），避免投屏露出私人窗口

### 菜单说明

| 菜单项 | 作用 |
|---|---|
| 自动连接：开/关 | 开 = 插上相机即推流；关 = 暂停自动行为 |
| 立即启动推流 | 手动启动（同时清除「手动停止」标志） |
| 停止推流 | 停止并暂停自动连接 |
| 浏览器直播画面 | 打开免 OBS 的浏览器直播页 |
| WebUI 参数控制台 | 打开参数控制台（http://127.0.0.1:8765） |
| 退出 App | 停止推流，且不再有任何自动行为 |

## 技术架构

```text
索尼 A6600 (PTP / USB)
        │  gphoto2 --capture-movie --stdout   （1024×576 @24.8fps MJPEG）
        ▼
   FFmpeg × 2 路
   ├─ h264_videotoolbox 硬编码 → mpegts → udp://127.0.0.1:1234  → OBS 媒体源 → OBS 虚拟摄像头
   └─ h264_videotoolbox 硬编码 → mpegts → udp://127.0.0.1:1235  → 浏览器直播页（ffmpeg 转 MJPEG）
```

- 画面参数：1024×576 @30fps，H.264 6Mbps（可在控制台调整）， GOP 1s，无 B 帧，实时模式
- 延迟实测：OBS 链路约 0.3~0.5s，浏览器链路相近
- 看门狗：ffmpeg `-progress` 文件停滞超过 15s 自动重启管道

## 故障排查

| 现象 | 原因 / 处理 |
|---|---|
| 相机显示「正在写入储存卡，请稍等」 | 波轮在影像模式。改用拍照档（P/S/M/Auto），等待提示消失或关机重启相机 |
| App 显示待机、不推流 | 检查 USB 线与 PC 遥控开关；相机拔插一次 |
| OBS 有源但无画面 | 确认推流已启动（菜单栏 📹 图标）；媒体源输入是否 `udp://127.0.0.1:1234` |
| 画面卡住不动 | 看门狗会自动重启；若持续，菜单里「停止推流」再「立即启动」 |
| 会议软件找不到虚拟摄像头 | 需要已安装 OBS 并「启动虚拟摄像头」；或改用浏览器直播方式 |
| 首次打开被 macOS 拦截 | 右键 App → 打开；或终端执行 `xattr -cr /Applications/A6600摄像头.app` |

## 从源码构建

```bash
# 1. 编译菜单栏 App
cd app
swiftc -O -o SonyCam main.swift
mkdir -p "A6600摄像头.app/Contents/MacOS" "A6600摄像头.app/Contents/Resources"
cp SonyCam "A6600摄像头.app/Contents/MacOS/"
cp Info.plist "A6600摄像头.app/Contents/"
cp -R ../webui "A6600摄像头.app/Contents/Resources/webui"
cp scripts/sony-webcam.sh "A6600摄像头.app/Contents/Resources/scripts/" 2>/dev/null || true

# 2. 打包 gphoto2 / ffmpeg 及全部依赖进 App（需要本机已 brew install gphoto2 ffmpeg）
bash build/bundle-deps.sh    # 收集依赖 → Resources/{bin,lib}
bash build/fix-paths.sh      # 动态库路径改写为 @rpath + ad-hoc 重签名
bash build/fix-missing-libs.sh  # 补齐引用名与文件名不一致的库

# 3. 整体签名
codesign --force --deep --sign - "A6600摄像头.app"
```

构建脚本里的工作区路径需要按你的机器调整（`bundle-deps.sh` 等开头有路径变量）。

不用 App 也可以直接命令行推流（需自行 `brew install gphoto2 ffmpeg`）：

```bash
./scripts/sony-webcam.sh    # 双击 scripts/sony-webcam.command 亦可
```

## 已知限制

- 仅 Apple Silicon（arm64）；Intel Mac 需自行交叉构建
- 未做 Apple 公证：首次打开需右键方式绕过 Gatekeeper
- 虚拟摄像头输出依赖 OBS（本项目未实现 CMIO 摄像头扩展）；纯浏览器共享则无需 OBS
- PTZ / 拍照 / 参数调整等相机控制未实现，仅做实时取景推流

## 开源协议

本项目代码以 **MIT** 协议开源，见 [LICENSE](LICENSE)。
App 内捆绑分发的 gphoto2（GPL-2.0+）、libgphoto2（LGPL-2.1+）、FFmpeg（GPL-3.0+）
等第三方组件，其协议义务履行说明见 [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md)。
本项目通过独立进程管道调用上述工具（mere aggregation），自身源码不受其传染性约束。

Sony、Alpha 是 Sony Group Corporation 的商标；本项目与 Sony 无任何隶属关系。
