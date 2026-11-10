#!/usr/bin/env python3
"""第二遍：以玻璃面板为边界全出血（面板 = 图标整体，供系统遮罩裁切）"""
from PIL import Image

SRC = "/Users/chentao/WorkBuddy/2026-11-10-00-13-05/app/icon/AppIcon-1024.png"
img = Image.open(SRC).convert("RGB")
w, h = img.size

# 以画布四角（面板外深色背景）为基准，检测玻璃面板边界（阈值放宽）
corner = img.getpixel((4, 4))
small = img.resize((160, 160))
sp = small.load()
xs, ys = [], []
for j in range(160):
    for i in range(160):
        r, g, b = sp[i, j]
        cr, cg, cb = corner
        if abs(r - cr) + abs(g - cg) + abs(b - cb) > 30:
            xs.append(i); ys.append(j)
x0, x1 = min(xs) * w / 160, max(xs) * w / 160
y0, y1 = min(ys) * h / 160, max(ys) * h / 160
print(f"面板边界框: x {x0:.0f}~{x1:.0f}, y {y0:.0f}~{y1:.0f} ({x1-x0:.0f}x{y1-y0:.0f})")

cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
side = max(x1 - x0, y1 - y0) * 1.02  # 轻微出血，圆角拐角被画布裁掉
left = max(0, min(cx - side / 2, w - side))
top = max(0, min(cy - side / 2, h - side))
print(f"裁剪: 中心 ({cx:.0f},{cy:.0f}), 边长 {side:.0f}, 起点 ({left:.0f},{top:.0f})")

crop = img.crop((int(left), int(top), int(left + side), int(top + side)))
crop = crop.resize((1024, 1024), Image.LANCZOS)
crop.save(SRC)
print("已输出:", SRC)
