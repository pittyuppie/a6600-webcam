# Third-Party Notices（第三方组件声明）

本项目（A6600摄像头.app）是一个「编排器」：通过独立子进程（subprocess / pipe）
调用外部命令行工具，属于 GPL FAQ 所述的 arm's-length / mere aggregation
（独立聚合）关系，本项目自身源码不受上述协议传染性约束。

**自 v1.1 起，App 内捆绑了以下组件的预编译二进制**（Contents/Resources/bin 与
Contents/Resources/lib），以实现免安装、即开即用：

| 组件 | 分发版本 | 用途 | 协议 | 官方源码 |
|---|---|---|---|---|
| gphoto2 (CLI) | 2.5.32 | 通过 PTP 协议获取相机实时取景流 | GPL-2.0-or-later | https://github.com/gphoto/gphoto2 |
| libgphoto2 | 2.5.34 | gphoto2 的后端相机控制库 | LGPL-2.1-or-later | https://github.com/gphoto/libgphoto2 |
| FFmpeg | 9.0.2 (Homebrew 构建) | MJPEG → H.264 硬件转码（h264_videotoolbox）与 mpegts 推流 | GPL-3.0-or-later | https://ffmpeg.org/download |
| libusb | 1.0.x | libgphoto2 的 USB 传输层 | LGPL-2.1-or-later | https://github.com/libusb/libusb |
| 其余 dylib | 见 App 内 Resources/lib | openssl/x264/x265/libjpeg 等构建依赖 | 各自开源协议 | https://github.com/Homebrew/homebrew-core 对应 formula |
| OBS Studio（可选，用户自装） | — | 接收 UDP 流并对外提供虚拟摄像头 | GPL-2.0-or-later | https://github.com/obsproject/obs-studio |

## 分发义务履行说明

本分发包构成对 GPL 组件的「二进制分发」，依据 GPL-2.0 §3 / GPL-3.0 §6 / LGPL-2.1 §4
履行以下义务：

1. **附带许可证文本**：本文件随 App 分发（Resources/THIRD-PARTY-NOTICES.md），
   各组件完整许可证文本可在上表「官方源码」链接的仓库 LICENSE/COPYING 文件中获取；
2. **对应源码**：上表已指明各组件官方源码获取途径；FFmpeg 为 Homebrew
   formula `ffmpeg@9.0.2_1` 构建，构建配置可通过 Homebrew 官方仓库查询复现；
3. **保留版权声明**：各二进制内的版权信息未作移除或修改，仅做了动态库路径
   重定位（install_name_tool）与本机 ad-hoc 签名，不改变源码或功能。

本项目自身的源码（app/main.swift、webui/、*.sh、*.command）始终以
MIT 协议授权，见 LICENSE 文件。

## 商标说明

Sony、Alpha、macOS、OBS 分别是其各自所有者的商标。本项目与 Sony 公司
无任何隶属或合作关系，仅供个人设备的功能扩展使用。
