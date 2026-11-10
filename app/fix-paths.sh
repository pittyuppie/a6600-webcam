#!/bin/bash
# 重写 App 内二进制/动态库的加载路径：/opt/homebrew/... → @rpath，并添加 rpath
# 最后对每个 Mach-O 重新 ad-hoc 签名（Apple Silicon 上签名无效会直接被杀进程）
set -e

# 工作区 = 本脚本（位于 app/ 下）的上级目录
APP_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE="$(dirname "$APP_DIR")"
RES="$WORKSPACE/app/A6600摄像头.app/Contents/Resources"

fix_refs() {
    # 把文件里所有 /opt/homebrew 引用改写为 @rpath/<basename>
    local file="$1"
    local refs
    refs=$(otool -L "$file" | awk 'NR>1 {print $1}' | grep '^/opt/homebrew/' || true)
    while IFS= read -r ref; do
        [ -z "$ref" ] && continue
        install_name_tool -change "$ref" "@rpath/$(basename "$ref")" "$file"
    done <<< "$refs"
}

# ---- 1. lib/ 下的 dylib：id 改为 @rpath/xxx，引用改写，rpath=@loader_path ----
for f in "$RES"/lib/*.dylib; do
    fix_refs "$f"
    install_name_tool -id "@rpath/$(basename "$f")" "$f"
    install_name_tool -add_rpath "@loader_path" "$f" 2>/dev/null || true
done

# ---- 2. camlibs (.so)：引用改写，rpath=@loader_path/../.. (即 lib/) ----
for f in "$RES"/lib/libgphoto2/2.5.34/*.so "$RES"/lib/libgphoto2_port/0.12.2/*.so; do
    [ -f "$f" ] || continue
    fix_refs "$f"
    install_name_tool -add_rpath "@loader_path/../.." "$f" 2>/dev/null || true
done

# ---- 3. bin/ 下两个可执行文件：引用改写，rpath=@executable_path/../lib ----
for f in "$RES"/bin/gphoto2 "$RES"/bin/ffmpeg; do
    fix_refs "$f"
    install_name_tool -add_rpath "@executable_path/../lib" "$f" 2>/dev/null || true
done

# ---- 4. 全部重新 ad-hoc 签名 ----
find "$RES/bin" "$RES/lib" -type f -exec codesign --force --sign - {} \;

echo "=== 验证：bin/gphoto2 残留的 homebrew 引用（应为空）==="
otool -L "$RES/bin/gphoto2" | grep '/opt/homebrew' || echo "✅ 无残留"
echo "=== 验证：签名 ==="
codesign -dv "$RES/bin/gphoto2" 2>&1 | head -2
