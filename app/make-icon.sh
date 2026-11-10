#!/bin/bash
# 生成 App 图标：裁水印 → 多尺寸 iconset → icns
set -e
WS="/Users/chentao/WorkBuddy/2026-11-10-00-13-05"
FF="$WS/app/A6600摄像头.app/Contents/Resources/bin/ffmpeg"
ICON_DIR="$WS/app/icon"
SRC="$ICON_DIR/macOS_app_icon__a_generic_blac_2026-11-10T09-27-29.png"

# 裁掉右下角水印（取左上 900x900 区域）再放大回 1024
"$FF" -y -loglevel error -i "$SRC" -vf "crop=900:900:0:0,scale=1024:1024:flags=lanczos" "$ICON_DIR/AppIcon-1024.png"

# 生成 iconset 全尺寸
IS="$ICON_DIR/AppIcon.iconset"
rm -rf "$IS" "$ICON_DIR/AppIcon.icns"
mkdir -p "$IS"
sips -z 16 16     "$ICON_DIR/AppIcon-1024.png" --out "$IS/icon_16x16.png"     > /dev/null
sips -z 32 32     "$ICON_DIR/AppIcon-1024.png" --out "$IS/icon_16x16@2x.png"  > /dev/null
sips -z 32 32     "$ICON_DIR/AppIcon-1024.png" --out "$IS/icon_32x32.png"     > /dev/null
sips -z 64 64     "$ICON_DIR/AppIcon-1024.png" --out "$IS/icon_32x32@2x.png"  > /dev/null
sips -z 128 128   "$ICON_DIR/AppIcon-1024.png" --out "$IS/icon_128x128.png"   > /dev/null
sips -z 256 256   "$ICON_DIR/AppIcon-1024.png" --out "$IS/icon_128x128@2x.png"> /dev/null
sips -z 256 256   "$ICON_DIR/AppIcon-1024.png" --out "$IS/icon_256x256.png"   > /dev/null
sips -z 512 512   "$ICON_DIR/AppIcon-1024.png" --out "$IS/icon_256x256@2x.png"> /dev/null
sips -z 512 512   "$ICON_DIR/AppIcon-1024.png" --out "$IS/icon_512x512.png"   > /dev/null
sips -z 1024 1024 "$ICON_DIR/AppIcon-1024.png" --out "$IS/icon_512x512@2x.png"> /dev/null

iconutil -c icns "$IS" -o "$ICON_DIR/AppIcon.icns"
echo "icns 生成成功: $(du -sh "$ICON_DIR/AppIcon.icns" | cut -f1)"
