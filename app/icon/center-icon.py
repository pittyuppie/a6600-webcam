#!/usr/bin/env python3
"""App 图标精确居中：检测主体边界框 → 以中心裁剪 → 1024 输出"""
from PIL import Image, ImageFilter

SRC = "/Users/chentao/WorkBuddy/2026-11-10-00-13-05/app/icon/macOS_app_icon__a_generic_blac_2026-11-10T09-27-29.png"
OUT = "/Users/chentao/WorkBuddy/2026-11-10-00-13-05/app/icon/AppIcon-1024.png"

img = Image.open(SRC).convert("RGB")
w, h = img.size

# 1) 先把右下角水印区域用同行左侧背景色逐行填充（水印约在 x>820, y>930）
px = img.load()
for y in range(925, h):
    ref = px[808, y]
    for x in range(815, w):
        px[x, y] = ref
# 对接缝处做轻微模糊过渡
seam = img.crop((760, 900, w, h)).filter(ImageFilter.GaussianBlur(3))
img.paste(seam, (760, 900))

# 2) 以四角背景色为基准，找主体边界框
corner = img.getpixel((8, 8))
small = img.resize((128, 128))
sp = small.load()
thresh = 18
xs, ys = [], []
for j in range(128):
    for i in range(128):
        r, g, b = sp[i, j]
        cr, cg, cb = corner
        if abs(r - cr) + abs(g - cg) + abs(b - cb) > thresh * 3:
            xs.append(i); ys.append(j)
x0, x1 = min(xs) * w / 128, max(xs) * w / 128
y0, y1 = min(ys) * h / 128, max(ys) * h / 128
print(f"主体边界框: x {x0:.0f}~{x1:.0f}, y {y0:.0f}~{y1:.0f} (尺寸 {x1-x0:.0f}x{y1-y0:.0f})")

# 3) 以主体中心裁正方形（留 4% 边距）
cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
side = max(x1 - x0, y1 - y0) * 1.04
left = cx - side / 2
top = cy - side / 2
# 边界 clamp
left = max(0, min(left, w - side))
top = max(0, min(top, h - side))
print(f"裁剪: 中心 ({cx:.0f},{cy:.0f}), 边长 {side:.0f}, 起点 ({left:.0f},{top:.0f})")

crop = img.crop((int(left), int(top), int(left + side), int(top + side)))
crop = crop.resize((1024, 1024), Image.LANCZOS)
crop.save(OUT)
print("已输出:", OUT)
