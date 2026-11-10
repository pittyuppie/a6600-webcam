#!/bin/bash
# 递归收集 gphoto2 + ffmpeg 的全部 homebrew 依赖，复制进 App，并重写加载路径
set -e

# 工作区 = 本脚本（位于 app/ 下）的上级目录
APP_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE="$(dirname "$APP_DIR")"
APP="$WORKSPACE/app/A6600摄像头.app"
RES="$APP/Contents/Resources"
LIST="$WORKSPACE/app/deps_list.txt"

# ---------- 1. 递归收集依赖 ----------
: > /tmp/collect_seen.txt
collect() {
    local bin="$1"
    local lines
    lines=$(otool -L "$bin" 2>/dev/null | grep -o '/opt/homebrew/[^ (]*\.dylib')
    while IFS= read -r lib; do
        [ -z "$lib" ] && continue
        local real
        real=$(readlink -f "$lib")
        if ! grep -qxF "$real" /tmp/collect_seen.txt; then
            echo "$real" >> /tmp/collect_seen.txt
            collect "$real"
        fi
    done <<< "$lines"
}
collect /opt/homebrew/bin/ffmpeg
collect /opt/homebrew/bin/gphoto2
sort -u /tmp/collect_seen.txt > "$LIST"
echo "依赖库总数: $(wc -l < "$LIST" | tr -d ' ')"

# ---------- 2. 清空并复制 ----------
rm -rf "$RES/lib" "$RES/bin"
mkdir -p "$RES/bin" "$RES/lib/libgphoto2" "$RES/lib/libgphoto2_port"
cp -L /opt/homebrew/bin/gphoto2 "$RES/bin/gphoto2"
cp -L /opt/homebrew/bin/ffmpeg "$RES/bin/ffmpeg"
n=0
while IFS= read -r f; do
    cp -L "$f" "$RES/lib/$(basename "$f")" && n=$((n+1))
done < "$LIST"
echo "已复制依赖库: $n 个"
cp -R /opt/homebrew/lib/libgphoto2/2.5.34 "$RES/lib/libgphoto2/"
cp -R /opt/homebrew/lib/libgphoto2_port/0.12.2 "$RES/lib/libgphoto2_port/"
echo "camlibs: $(find "$RES/lib/libgphoto2" -name '*.so' | wc -l | tr -d ' ') 个"
du -sh "$RES/lib" "$RES/bin"
