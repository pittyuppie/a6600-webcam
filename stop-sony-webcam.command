#!/bin/zsh
# 停止推流并暂停自动启动（守护进程不再自动拉起，
# 直到下次双击 sony-webcam.command 或在控制台点「启动」）
touch /tmp/sony-webcam-manual-stop
pkill -f "capture-movie"
pkill -f "sony-webcam"
echo "已停止索尼相机推流（自动启动已暂停）"
echo "恢复：双击 sony-webcam.command，或重新在控制台点「启动」"
sleep 1
