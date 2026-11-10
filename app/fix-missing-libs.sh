#!/bin/bash
# 补齐 @rpath 引用名与实际文件名不一致的库（拷贝为引用名）
set -e
# 工作区 = 本脚本（位于 app/ 下）的上级目录
APP_DIR="$(cd "$(dirname "$0")" && pwd)"
WS="$(dirname "$APP_DIR")"
RES="$WS/app/A6600摄像头.app/Contents/Resources"

# 先生成 引用名 → 真实路径 映射表（deps_list 里每个文件可能对应多个引用名）
> /tmp/libmap.txt
while IFS= read -r p; do
    b=$(basename "$p")
    echo "$p|$b" >> /tmp/libmap.txt
    # 去掉最后一段 .so.N.M / .N.M.N 版本号，得到常见短引用名
    short=$(echo "$b" | sed -E 's/(\.dylib)$//; s/(\.[0-9]+)+$//; s/$/.dylib/')
    if [ "$short" != "$b" ]; then echo "$p|$short" >> /tmp/libmap.txt; fi
    # libjpeg.8.3.2.dylib → libjpeg.8.dylib 这类
    short2=$(echo "$b" | sed -E 's/^lib([^.]+)\.[0-9]+\.[0-9]+\.[0-9]+\.dylib$/lib\1.dylib/')
    if [ "$short2" != "$b" ]; then echo "$p|$short2" >> /tmp/libmap.txt; fi
done < "$WS/app/deps_list.txt"

for pass in 1 2 3; do
  missing=0
  for f in "$RES"/bin/* "$RES"/lib/*.dylib "$RES"/lib/libgphoto2/2.5.34/*.so "$RES"/lib/libgphoto2_port/0.12.2/*.so; do
    [ -f "$f" ] || continue
    for ref in $(otool -L "$f" | awk '/@rpath\//{print $1}'); do
      name="${ref#@rpath/}"
      if [ -f "$RES/lib/$name" ]; then continue; fi
      real=$(ls /opt/homebrew/lib/"$name"* 2>/dev/null | sort -t. -k1,1 -k2,2n | head -1)
      if [ -n "$real" ]; then
        cp -L "$real" "$RES/lib/$name"
        echo "补齐: $name ← $(basename "$real")"
        missing=$((missing+1))
      else
        echo "⚠️ 映射表里找不到: $name (来自 $(basename "$f"))"
      fi
    done
  done
  [ "$missing" -eq 0 ] && { echo "第 $pass 轮：无缺失，完成"; break; }
done

# 新补的库也要改路径 + 重签名
for f in "$RES"/lib/*.dylib; do
    refs=$(otool -L "$f" 2>/dev/null | awk 'NR>1 {print $1}' | grep '^/opt/homebrew/' || true)
    while IFS= read -r ref; do
        [ -z "$ref" ] && continue
        install_name_tool -change "$ref" "@rpath/$(basename "$ref")" "$f" 2>/dev/null || true
    done <<< "$refs"
    if ! otool -l "$f" | grep -q LC_RPATH; then install_name_tool -add_rpath "@loader_path" "$f" 2>/dev/null || true; fi
    codesign --force --sign - "$f" 2>/dev/null || true
done
echo "✅ 补齐完成"
