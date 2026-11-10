# Third-Party Notices（第三方组件声明）

本文档适用于 **A6600摄像头.app**（下称「本应用」）及其发布包
（`A6600-camera-macOS-arm64.dmg`）。版本：**v1.0.0**。

---

## 一、本应用的分发构成

本应用自身的代码（`app/main.swift`、`webui/`、`*.sh`、`*.command`、构建脚本）
以 **MIT** 协议授权，见项目根目录 `LICENSE`。

为做到「任意 Mac 免安装即开即用」，本应用在 `Contents/Resources/bin` 与
`Contents/Resources/lib` 内**随包分发了以下第三方组件的预编译二进制**。
这些二进制均来自 [Homebrew](https://brew.sh) 官方 formula 的 arm64 构建，
本应用对其**未作任何源码级修改**，仅执行了：

1. 用 `install_name_tool` 将动态库加载路径由 `/opt/homebrew/...` 重写为 `@rpath/...`（路径重定位）；
2. 以 ad-hoc 方式重新签名（`codesign --force --sign -`）。

本应用与这些组件之间是**独立程序间的进程协作关系**：应用通过子进程
（`stdin`/`stdout` 管道）调用 `gphoto2` 与 `ffmpeg` 两个可执行文件，不将 GPL
代码静态或动态链接进本应用自身的二进制。按 FSF GPL FAQ 的界定，这属于
**arm's-length / mere aggregation（独立聚合）**，本应用自身的 MIT 授权不受影响。

> 注意：上述定性针对本应用自身的代码。随包分发的第三方二进制**仍是各自的
> 独立作品**，其分发须遵守各自许可证——本文件与 `LICENSES/` 目录即为履行
> 这些义务而设。

---

## 二、随包分发的组件清单（按许可证分组）

下表列出**全部** 46 个动态库文件（含同库的版本别名）、2 个可执行文件、
21 个相机驱动（camlibs）与 I/O 驱动（iolibs）所对应的上游组件、精确版本、
用途与官方源码地址。所有许可证**全文**见 `LICENSES/` 目录
（根目录按 SPDX 标识命名，`components/` 为各组件原始文件）。

### 2.1 GPL-3.0-or-later

| 组件 | 分发版本 | 包内文件 | 用途 | 官方源码 |
|---|---|---|---|---|
| FFmpeg | 9.0.2（Homebrew `ffmpeg 9.0.2_1`，GPL 构建） | `bin/ffmpeg`、`libavcodec/libavformat/libavfilter/libavdevice/libavutil/libswscale/libswresample` 共 14 个 dylib（含版本别名） | MJPEG→H.264 硬编码转码、mpegts 复用、浏览器直播转封装 | https://ffmpeg.org/download.html ／ https://git.ffmpeg.org/ffmpeg.git |
| GNU Readline | 8.3.6 | `libreadline.8.dylib`、`libreadline.8.3.dylib` | gphoto2 命令行交互（间接依赖） | https://git.savannah.gnu.org/cgit/readline.git |
| x264 | r3222 | `libx264.165.dylib` | H.264 软件编码（备选编码器） | https://code.videolan.org/videolan/x264 |
| x265 | 4.3 | `libx265.217.dylib` | HEVC 编码（备选编码器） | https://bitbucket.org/multicoreware/x265_git |

### 2.2 GPL-2.0-or-later

| 组件 | 分发版本 | 包内文件 | 用途 | 官方源码 |
|---|---|---|---|---|
| gphoto2 (CLI) | 2.5.32 | `bin/gphoto2` | 通过 PTP 协议获取相机实时取景流 | https://github.com/gphoto/gphoto2 |

### 2.3 LGPL-2.1（LGPL-2.1-or-later，mpg123 为 LGPL-2.1-only）

| 组件 | 分发版本 | 包内文件 | 用途 | 官方源码 |
|---|---|---|---|---|
| libgphoto2 | 2.5.34 | `libgphoto2.6.dylib`；`lib/libgphoto2/2.5.34/` 下 21 个相机驱动 `*.so` | 相机后端控制库与各厂商驱动（含 `ptp2.so`，A6600 实际使用） | https://github.com/gphoto/libgphoto2 |
| libgphoto2_port | 0.12.2 | `libgphoto2_port.12.dylib`；`lib/libgphoto2_port/0.12.2/` 下 I/O 驱动 `*.so`（含 `usb1`/`disk`） | 传输层（USB / 磁盘 I/O） | https://github.com/gphoto/libgphoto2 |
| libusb | 1.0.30 | `libusb-1.0.0.dylib` | PTP 的 USB 用户态传输实现 | https://github.com/libusb/libusb |
| libexif | 0.6.26 | `libexif.12.dylib` | EXIF 元数据处理 | https://github.com/libexif/libexif |
| libintl（GNU gettext） | gettext 1.0 | `libintl.8.dylib` | 国际化消息目录 | https://git.savannah.gnu.org/cgit/gettext.git |
| libltdl（GNU libtool） | 2.6.2 | `libltdl.7.dylib` | 动态模块加载器（camlibs/iolibs 的 `dlopen` 宿主） | https://git.savannah.gnu.org/cgit/libtool.git |
| libmpg123 | 1.33.7（LGPL-2.1-**only**） | `libmpg123.0.dylib` | MPEG 音频解码（lame 的间接依赖） | https://www.mpg123.de/download.shtml |

### 2.4 LGPL-2.0（GNU Library GPL v2）

| 组件 | 分发版本 | 包内文件 | 用途 | 官方源码 |
|---|---|---|---|---|
| LAME (libmp3lame) | 4.0 | `libmp3lame.0.dylib` | MP3 编码（FFmpeg 可选编码器） | https://lame.sourceforge.io/ |

### 2.5 Apache-2.0

| 组件 | 分发版本 | 包内文件 | 用途 | 官方源码 |
|---|---|---|---|---|
| OpenSSL | 4.1.0 | `libssl.4.dylib`、`libcrypto.4.dylib` | FFmpeg 的 TLS/加密原语 | https://github.com/openssl/openssl |

> Apache-2.0 §4(d)：本应用随包提供 `LICENSES/Apache-2.0.txt` 全文及
> `LICENSES/components/openssl@4__LICENSE.txt`（含 OpenSSL 项目版权声明与 NOTICE 内容）。

### 2.6 MIT

| 组件 | 分发版本 | 包内文件 | 用途 | 官方源码 |
|---|---|---|---|---|
| popt | 1.19 | `libpopt.0.dylib` | gphoto2 的命令行选项解析 | https://github.com/rpm-software-management/popt |

### 2.7 BSD-2-Clause / BSD-3-Clause / BSD-2-Clause-Patent

| 组件 | 分发版本 | 许可 | 包内文件 | 用途 | 官方源码 |
|---|---|---|---|---|---|
| dav1d | 1.5.4 | BSD-2-Clause | `libdav1d.7.dylib` | AV1 解码 | https://code.videolan.org/videolan/dav1d |
| libavif | 1.4.2 | BSD-2-Clause | `libavif.16.dylib` | AVIF 图像编解码 | https://github.com/AOMediaCodec/libavif |
| opus | 1.6.1 | BSD-3-Clause | `libopus.0.dylib` | Opus 音频编解码 | https://gitlab.xiph.org/xiph/opus |
| libvpx | 1.17.0 | BSD-3-Clause | `libvpx.12.dylib` | VP8/VP9 编解码 | https://chromium.googlesource.com/webm/libvpx |
| libwebp | 1.6.0 | BSD-3-Clause | `libwebp.7.dylib`、`libsharpyuv.0.dylib` | WebP 图像编解码 | https://chromium.googlesource.com/webm/libwebp |
| SVT-AV1 | 4.3.0 | BSD-3-Clause | `libSvtAv1Enc.4.dylib`、`libSvtAv1Enc.4.3.0.dylib` | AV1 编码 | https://gitlab.com/AOMediaCodec/SVT-AV1 |
| libvmaf | 3.2.1 | BSD-2-Clause-Patent | `libvmaf.3.dylib` | 视频质量评估（FFmpeg 滤镜依赖） | https://github.com/Netflix/vmaf |

### 2.8 IJG / libpng / FTL / libtiff / GD / Fontconfig / 0BSD

| 组件 | 分发版本 | 许可 | 包内文件 | 用途 | 官方源码 |
|---|---|---|---|---|---|
| libjpeg-turbo | 3.2.1 | IJG **AND** Zlib **AND** BSD-3-Clause | `libjpeg.8.dylib`、`libjpeg.8.3.2.dylib` | JPEG 编解码（MJPEG 取景流解码） | https://github.com/libjpeg-turbo/libjpeg-turbo |
| libpng | 1.6.59 | libpng-2.0 | `libpng16.16.dylib` | PNG 编解码 | https://github.com/pnggroup/libpng |
| FreeType | 2.15.0 | FTL（FreeType License） | `libfreetype.6.dylib` | 字体栅格化（gd 依赖） | https://gitlab.freedesktop.org/freetype/freetype |
| libtiff | 4.7.2 | libtiff（MIT 风格） | `libtiff.6.dylib` | TIFF 编解码 | https://gitlab.com/libtiff/libtiff |
| libgd | 2.3.3 | GD | `libgd.3.dylib` | camlibs 生成缩略图（经 `dlopen` 加载） | https://github.com/libgd/libgd |
| fontconfig | 2.18.3 | HPND-sell-variant AND Unicode-3.0 AND MIT-Modern-Variant AND MIT AND public-domain | `libfontconfig.1.dylib` | 字体发现与配置 | https://gitlab.freedesktop.org/fontconfig/fontconfig |
| liblzma (xz) | 5.8.4 | **0BSD**（liblzma 本体）；xz 工具链另有 GPL-2.0-or-later | `liblzma.5.dylib` | LZMA 解压（TIFF/FFmpeg 依赖） | https://tukaani.org/xz/ ／ https://github.com/tukaani-project/xz |

> `liblzma` 采用 0BSD（公共领域等效），无署名义务；本应用仍一并提供其全文。

### 2.9 未随包分发、需用户自行安装

| 组件 | 许可 | 说明 |
|---|---|---|
| OBS Studio（可选） | GPL-2.0-or-later | 若需向腾讯会议 / Zoom 等提供「系统摄像头」，由用户自行安装并配置媒体源。本应用不捆绑、不分发 OBS。 |

---

## 三、许可证全文的位置

| 位置 | 内容 |
|---|---|
| `LICENSES/`（App 内为 `Contents/Resources/LICENSES/`） | 全部许可证标准全文，按 SPDX 标识命名 |
| `LICENSES/components/` | 各组件自身附带的原始许可与版权文件（含具体版权人署名） |
| `LICENSES/README.md` | 许可证与组件的对照索引 |

分发的 DMG / App 包内**实际包含**上述完整文本（共 49 个文件，约 676KB），
并非仅提供外部链接。

---

## 四、对应源码的获取（GPL-2.0 §3 / GPL-3.0 §6）

本应用分发的二进制与上游发布版本**完全对应**（未修改源码，仅重定位加载路径
与 ad-hoc 重签名）。因此上表中的官方源码地址即为对应的完整源码。

**书面承诺（GPL-2.0 §3(b) / GPL-3.0 §6(d)）**：

> 自 v1.0.0 发布之日起 **三年内**，任何第三方均可通过本项目仓库的 Issue
> （https://github.com/pittyuppie/a6600-webcam/issues ）提出请求，免费获得上表
> 所列 GPL/LGPL 组件的**完整对应源码**（以 `.tar.gz` 归档提供下载，仅可能收取
> 实际传输介质成本，通常为零）。本承诺不可撤销，随本版本分发持续有效。

FFmpeg 的构建配置可通过 Homebrew 官方仓库复现：
`brew cat ffmpeg`（对应 formula 版本 `9.0.2_1`）即可获得完整 `configure` 参数，
`brew install --build-from-source ffmpeg` 可重建等价二进制。

---

## 五、LGPL 组件的可替换性说明（LGPL-2.1 §6 / LGPL-2.0 §6）

本应用以**独立动态库（dylib）**形式分发 LGPL 组件，未将其静态链接进任何自有
二进制，因此用户可以自行替换这些库：

1. 用自行编译（或从其他来源获得）的 `libgphoto2.6.dylib`、`libusb-1.0.0.dylib`
   等**替换** `A6600摄像头.app/Contents/Resources/lib/` 下的同名文件；
2. 替换后重新签名，使 App 仍可通过 Gatekeeper／自身完整性校验：

```bash
codesign --force --deep --sign - "/Applications/A6600摄像头.app"
```

3. App 的推流脚本通过 `CAMLIBS` / `IOLIBS` 环境变量与 `@rpath` 定位这些库，
   不做版本校验或哈希锁定，替换后即刻生效。

> 说明：本应用以 ad-hoc 签名发布（非 Apple Developer ID + 公证）。ad-hoc 签名
> 在替换内嵌库后需重新执行上面的 `codesign` 命令，这是 macOS 代码签名的机制
> 要求，不影响用户替换 LGPL 库的权利。

---

## 六、对本应用自身代码的说明

- 本应用自身源码以 **MIT** 授权（见 `LICENSE`），著作权人：chentao。
- 本应用不含 Sony 的代码、SDK 或商标素材；应用图标为原创设计，未使用 Sony 标识。
- 本应用不包含、不调用索尼 Imaging Edge Webcam 的任何组件。

---

## 七、商标说明

Sony、Alpha、ILCE 是索尼集团公司（Sony Group Corporation）的商标或注册商标。
Apple、macOS、Mac 是 Apple Inc. 的商标。OBS、OBS Studio 是 OBS Project 的商标。
其他名称可能是其各自所有者的商标。

本项目为**非官方**的第三方工具，与索尼公司、Apple Inc.、OBS Project
**无任何隶属、赞助或背书关系**，仅供个人设备的功能扩展与互操作性使用。

---

## 八、免责声明

本应用按「现状」提供，不附带任何明示或默示担保。使用本应用可能影响相机的
正常连接状态（例如在「影像模式」下推流可能导致相机向储存卡写入并中断），
使用者应自行评估风险。详见项目 README 的「使用须知」。

---

*本文档最后更新：随 v1.0.0 发布。若后续版本变更捆绑的组件或其版本，
本文档与 `LICENSES/` 将同步更新（由 `app/build-licenses.sh` 重新生成）。*
