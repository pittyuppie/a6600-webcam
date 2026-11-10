# LICENSES 目录说明

本目录包含 `A6600摄像头.app` 随附分发的**全部第三方组件的完整许可证文本**，
用于履行 GPL-2.0 §3、GPL-3.0 §6、LGPL-2.1 §4/§6、Apache-2.0 §4(d) 等条款规定的
「随二进制附带许可证副本」义务。

- 根目录下的文件按 **SPDX 许可证标识**命名，是该许可证的标准全文；
- `components/` 子目录下是**各组件自身附带的原始许可/版权文件**（含组件的具体版权人
  与附加声明），命名格式为 `<组件名>__<原文件名>`。

所有文本均取自与所分发二进制**完全对应的版本**（Homebrew Cellar 中该版本安装包内
自带的许可文件），未经任何修改。由 `app/build-licenses.sh` 自动汇总生成。

## 许可证 → 组件对照

| 许可证（本目录文件） | 适用组件 |
|---|---|
| `GPL-2.0.txt` | gphoto2 |
| `GPL-3.0.txt` | FFmpeg（Homebrew 构建，启用 GPL 组件）、GNU Readline、x264、x265 |
| `LGPL-2.1.txt` | libgphoto2 及全部相机驱动（camlibs）、libgphoto2_port 及全部 I/O 驱动（iolibs）、libusb、libexif、libintl（gettext）、libltdl（libtool）、libmpg123 |
| `LGPL-2.0.txt` | libmp3lame |
| `Apache-2.0.txt` | OpenSSL（libssl / libcrypto） |
| `MIT.txt` | popt |
| `BSD-2-Clause.txt` | dav1d、libavif |
| `BSD-3-Clause.txt` | opus、libvpx、libwebp / libsharpyuv、SVT-AV1 |
| `BSD-2-Clause-Patent.txt` | libvmaf |
| `IJG.txt` | libjpeg-turbo（IJG + Zlib + BSD-3-Clause 三重许可，全文见文件） |
| `libpng-2.0.txt` | libpng16 |
| `FTL.txt` | FreeType |
| `libtiff.txt` | libtiff |
| `GD.txt` | libgd |
| `Fontconfig.txt` | fontconfig（HPND-sell-variant 等多项许可，全文见文件） |
| `0BSD.txt` | liblzma（xz） |

> 说明：`gettext` 与 `libtool` 的完整许可文件同时含 GPL 与 LGPL 部分，
> 见 `components/gettext__COPYING`、`components/libtool__COPYING` 与
> `components/libtool__share_libtool_COPYING.LIB`。本项目仅以动态链接方式使用其中的
> LGPL 运行库（libintl、libltdl）。

## 源码获取

各组件的官方源码地址见项目根目录 `THIRD-PARTY-NOTICES.md`。本项目对所分发二进制
**未作任何源码级修改**，仅执行了以下打包处理：

1. 用 `install_name_tool` 将动态库加载路径由 `/opt/homebrew/...` 重写为 `@rpath/...`；
2. 以 ad-hoc 方式重新签名（`codesign --force --sign -`）。

因此上游官方源码即为对应的完整源码。若任一上游地址日后不可访问，可依据
`THIRD-PARTY-NOTICES.md` 中的书面承诺条款，通过项目 Issue 索取对应源码副本。
