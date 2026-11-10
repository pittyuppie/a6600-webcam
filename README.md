# A6600 摄像头 for macOS

**解决索尼 A6600 在 macOS 27 上 Imaging Edge Webcam 无法传输相机画面的问题。**

一个菜单栏小工具：**插上相机自动开始推流、拔出自动停止、退出 App 一切归零**。
内置 gphoto2 与 FFmpeg 全部依赖，**目标电脑无需安装 Homebrew**，拖进应用程序文件夹就能用。

## 背景：为什么 Imaging Edge Webcam 在 macOS 27 上连不上

从 macOS 26 升级到 macOS 27 后，索尼官方的 **Imaging Edge Webcam（IEW）** 无法再把 A6600 的画面
传给系统：相机会一直停留在「**正在连接...**」，IEW 输出的是没有内容的占位帧，OBS / 会议软件里看不到画面。

我们对 IEW 的相机扩展（CameraExt）做了逆向分析，定位到故障链条：

1. **IEW 的核心是一个 CMIO 相机系统扩展**（2024-02 构建，基于 macOS 14.2 SDK），
   通过 libusb 在用户态直连相机的 USB 接口，自行发起 PTP 会话取景；
2. 在 macOS 27 上，该扩展**内部 PTP 握手逻辑卡死**：相机屏幕停在「正在连接...」等待电脑侧的会话建立，
   扩展侧则一直没有发出会话请求——**逻辑卡死，而非崩溃**（系统日志无崩溃记录，libusb 用户态访问实测正常）；
3. 该系统扩展受 SIP 保护，无法卸载；索尼官方至今未发布适配 macOS 27 的版本。

**结论：这是官方软件与新系统之间的代际兼容性故障，等不来修复，只能绕开。**
本项目用 gphoto2 的 PTP 实时取景 + FFmpeg 硬编码推流，完全绕开了 IEW 的相机扩展，
并把它做成了「即插即连」的完整体验。

## 功能

- 📷 **即插即连**：菜单栏常驻，A6600 插上 USB 自动推流，拔出自动停止
- 🎛 **WebUI 参数控制台**：码率 / 帧率 / 关键帧 / B 帧 / UDP 端口 / 看门狗，实时 FPS 曲线，三档预设
- 🖥 **两种观看方式**：
  - **OBS 虚拟摄像头**（推荐）——会议软件里直接选择「OBS Virtual Camera」
  - **浏览器直播页**——免安装 OBS，浏览器打开画面，会议软件共享窗口即可（按 M 可瞬间黑屏）
- 🛡 **卡顿看门狗**：画面停滞自动重启取景管道，并已放宽重试间隔避免打断相机
- 📦 **完全自包含**：gphoto2 2.5.32 + FFmpeg 9.0.2（VideoToolbox 硬编码）+ 全部依赖库打包在 App 内

## 安装

1. 从 [Releases](../../releases) 下载 `A6600-camera-macOS-arm64.dmg`
2. 双击打开，把 **A6600摄像头.app** 拖入右侧的 **Applications**
3. 首次打开：因为未做公证（notarization），macOS 会拦截一次——
   在「应用程序」里 **右键 App → 打开 → 打开**，之后再打开就不会再拦
4. 菜单栏出现相机图标即安装成功

> 仅支持 Apple Silicon（M 系列）Mac；不需要安装 Homebrew，也不受已安装的 Homebrew 版本影响
> （App 内置了独立的一套 gphoto2 / FFmpeg，与系统里已有的互不干扰）。

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
3. OBS → 启动虚拟摄像头
4. 会议软件里选择摄像头为 **OBS Virtual Camera**

WebUI 参数控制台可以帮你核对这些 OBS 设置。

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

- 画面参数：1024×576 @30fps，H.264 6Mbps（可在控制台调整），GOP 1s，无 B 帧，实时模式
  （PTP 取景流由相机硬件固定为 1024×576@24.8fps，与相机录制规格无关）
- 延迟实测：OBS 链路约 0.3~0.5s，浏览器链路相近
- 看门狗：ffmpeg `-progress` 文件停滞超过 15s 自动重启管道
- 与 IEW 的关系：本项目不使用、不修改、不卸载 IEW 的系统扩展，两条链路完全独立

## 故障排查

| 现象 | 原因 / 处理 |
|---|---|
| 相机显示「正在写入储存卡，请稍等」 | 波轮在影像模式。改用拍照档（P/S/M/Auto），等待提示消失或关机重启相机 |
| 相机屏幕停在「正在连接...」 | 这是 IEW 相机扩展占用了相机 USB 接口。删除/退出 IEW 后拔插一次 USB 线 |
| App 显示待机、不推流 | 检查 USB 线与 PC 遥控开关；相机拔插一次 |
| OBS 有源但无画面 | 确认推流已启动（菜单栏图标）；媒体源输入是否 `udp://127.0.0.1:1234`、格式 `mpegts` |
| 画面卡住不动 | 看门狗会自动重启；若持续，菜单里「停止推流」再「立即启动」 |
| 会议软件找不到虚拟摄像头 | 需要已安装 OBS 并「启动虚拟摄像头」；或改用浏览器直播方式 |
| 首次打开被 macOS 拦截 | 右键 App → 打开；或终端执行 `xattr -cr /Applications/A6600摄像头.app` |

## 从源码构建

```bash
# 0. 准备：本机需已 brew install gphoto2 ffmpeg（打包时从 Homebrew 收集依赖）

# 1. 编译菜单栏 App 并搭好目录
cd app
mkdir -p "A6600摄像头.app/Contents/MacOS" "A6600摄像头.app/Contents/Resources/scripts"
swiftc -O -o "A6600摄像头.app/Contents/MacOS/SonyCam" main.swift
cp Info.plist "A6600摄像头.app/Contents/"
cp ../sony-webcam.sh "A6600摄像头.app/Contents/Resources/scripts/"
cp -R ../webui "A6600摄像头.app/Contents/Resources/webui"
cp icon/AppIcon.icns "A6600摄像头.app/Contents/Resources/"   # 应用图标（可用 make-icon.sh 重新生成）

# 2. 打包 gphoto2 / ffmpeg 及全部依赖进 App（脚本自动以自身位置推导工作区）
bash bundle-deps.sh         # 递归收集依赖 → Resources/{bin,lib} + camlibs/iolibs
bash fix-paths.sh           # 动态库路径改写为 @rpath + 逐文件 ad-hoc 重签名
bash fix-missing-libs.sh    # 补齐引用名与实际文件名版本不一致、dlopen 隐式加载的库

# 3. 整体签名
codesign --force --deep --sign - "A6600摄像头.app"
```

不打 App 也可以直接命令行推流（需自行 `brew install gphoto2 ffmpeg`）：

```bash
./sony-webcam.sh            # 双击 sony-webcam.command 亦可
```

## 已知限制

- 仅 Apple Silicon（arm64）；Intel Mac 需自行交叉构建
- 未做 Apple 公证：首次打开需右键方式绕过 Gatekeeper
- 虚拟摄像头输出依赖 OBS（本项目未实现 CMIO 摄像头扩展）；纯浏览器共享则无需 OBS
- PTZ / 拍照 / 参数调整等相机控制未实现，仅做实时取景推流
- macOS 后续版本（28+）如果修复了 IEW，官方软件恢复后可与其并存使用

## 开源协议

本项目**自身代码**以 **MIT** 协议开源，见 [LICENSE](LICENSE)。

为做到「免安装即开即用」，App 内（`Contents/Resources/bin`、`Contents/Resources/lib`）
**捆绑分发了** gphoto2、FFmpeg 及其全部动态库依赖（共 46 个 dylib、21 个相机驱动），
涉及 GPL-2.0+ / GPL-3.0+ / LGPL-2.1 / LGPL-2.0 / Apache-2.0 / MIT / BSD 系 /
IJG / libpng / FTL / libtiff / GD / Fontconfig / 0BSD 等多种许可证。

合规情况：

- **全部许可证全文随包附带**：见 [`LICENSES/`](LICENSES/)（App 内为
  `Contents/Resources/LICENSES/`，49 个文件），并非只给外链
- **完整组件清单**（版本、用途、上游源码地址）与 **GPL-2.0 §3(b) 书面承诺**
  （三年内可索取对应源码）：见 [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md)
- **LGPL 可替换性**：各 LGPL 库以独立 dylib 形式分发，可按需替换后重签名，
  操作说明见上述文档第五节
- 应用通过独立子进程管道调用 `gphoto2`/`ffmpeg`（mere aggregation），
  自身 MIT 代码不受其传染性约束

在 App 菜单栏中点击 **「开源许可与第三方组件声明」**（快捷键 L）可直接查看这些文件。

Sony、Alpha 是 Sony Group Corporation 的商标；本项目与 Sony 无任何隶属关系。
