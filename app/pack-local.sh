#!/bin/bash
# 仅本地打包 zip + DMG（不上传任何地方），用于人工审核后再发布
set -e
WS="$(cd "$(dirname "$0")/.." && pwd)"
APP="$WS/app/A6600摄像头.app"

cd "$WS/app"
rm -f "A6600摄像头-macOS-arm64.zip" "A6600摄像头-macOS-arm64.dmg"
ditto -c -k --keepParent "$APP" "A6600摄像头-macOS-arm64.zip"

STAGE=/tmp/a6600-dmg-staging
rm -rf "$STAGE" && mkdir "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "A6600 摄像头" -srcfolder "$STAGE" -ov -format UDZO \
  -o "$WS/app/A6600摄像头-macOS-arm64.dmg" > /dev/null 2>&1
rm -rf "$STAGE"

hdiutil verify "$WS/app/A6600摄像头-macOS-arm64.dmg" 2>&1 | tail -1
du -sh "A6600摄像头-macOS-arm64.zip" "A6600摄像头-macOS-arm64.dmg"
