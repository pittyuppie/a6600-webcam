#!/bin/bash
# 汇总随 App 分发的第三方组件的完整许可证文本到 LICENSES/ 目录。
# 用法：bash build-licenses.sh [输出目录，默认 ../LICENSES]
# 说明：所有文本均取自本机 Homebrew Cellar 中对应组件自身附带的许可文件，
#       不依赖网络下载，确保与被分发二进制版本严格对应。
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="${1:-$HERE/../LICENSES}"
CELLAR="${CELLAR:-/opt/homebrew/Cellar}"

rm -rf "$OUT"
mkdir -p "$OUT/components"

# 取组件目录（任取一个版本目录）
cell() {
    ls -d "$CELLAR/$1"/*/ 2>/dev/null | tail -1 | sed 's:/$::'
}

# 拷贝组件原始许可文件：copy_comp <组件名> <相对路径>
copy_comp() {
    local name="$1" rel="$2" dir
    dir=$(cell "$name")
    if [ -n "$dir" ] && [ -f "$dir/$rel" ]; then
        local base
        base=$(echo "$rel" | tr '/' '_')
        cp "$dir/$rel" "$OUT/components/${name}__${base}"
        echo "  ✓ components/${name}__${base}"
    else
        echo "  ! 缺失: $name/$rel"
    fi
}

echo "== 1) 标准许可证全文（按 SPDX 标识命名）=="
# name|源组件|相对路径
while IFS='|' read -r out comp rel; do
    [ -z "$out" ] && continue
    dir=$(cell "$comp")
    if [ -n "$dir" ] && [ -f "$dir/$rel" ]; then
        cp "$dir/$rel" "$OUT/$out"
        echo "  ✓ $out  ← $comp/$rel"
    else
        echo "  ! 缺失: $out ← $comp/$rel"
    fi
done <<'MAP'
GPL-2.0.txt|gphoto2|COPYING
GPL-3.0.txt|ffmpeg|COPYING.GPLv3
LGPL-2.1.txt|libgphoto2|COPYING
LGPL-2.0.txt|lame|COPYING
0BSD.txt|xz|COPYING.0BSD
Apache-2.0.txt|openssl@4|LICENSE.txt
MIT.txt|popt|COPYING
BSD-2-Clause.txt|dav1d|COPYING
BSD-3-Clause.txt|opus|COPYING
BSD-2-Clause-Patent.txt|libvmaf|LICENSE
IJG.txt|jpeg-turbo|LICENSE.md
libpng-2.0.txt|libpng|LICENSE
FTL.txt|freetype|LICENSE.TXT
libtiff.txt|libtiff|LICENSE.md
GD.txt|gd|COPYING
Fontconfig.txt|fontconfig|COPYING
MAP

echo "== 2) 各组件自身附带的许可/版权文件（components/）=="
for spec in \
    "gphoto2|COPYING" \
    "libgphoto2|COPYING" \
    "libusb|COPYING" \
    "readline|COPYING" \
    "ffmpeg|LICENSE.md" \
    "ffmpeg|COPYING.GPLv3" \
    "openssl@4|LICENSE.txt" \
    "jpeg-turbo|LICENSE.md" \
    "libexif|COPYING" \
    "gettext|COPYING" \
    "gd|COPYING" \
    "libtiff|LICENSE.md" \
    "libpng|LICENSE" \
    "fontconfig|COPYING" \
    "freetype|LICENSE.TXT" \
    "libtool|COPYING" \
    "libtool|share/libtool/COPYING.LIB" \
    "xz|COPYING" \
    "xz|COPYING.0BSD" \
    "lame|COPYING" \
    "lame|LICENSE" \
    "mpg123|COPYING" \
    "opus|COPYING" \
    "popt|COPYING" \
    "dav1d|COPYING" \
    "libavif|LICENSE" \
    "libvmaf|LICENSE" \
    "libvpx|LICENSE" \
    "webp|COPYING" \
    "x264|COPYING" \
    "x265|COPYING" \
    "svt-av1|LICENSE.md" \
; do
    copy_comp "${spec%%|*}" "${spec#*|}"
done

echo "== 3) 统计 =="
echo "  文件数: $(find "$OUT" -type f | wc -l | tr -d ' ')"
echo "  体积:   $(du -sh "$OUT" | cut -f1)"
echo "  目录:   $OUT"
