"""Generate ClaudeUsage app icon at 1024x1024.

Design: warm sunset-gradient squircle with a clean white 'C' shape
(270 deg arc opening right, rounded caps).
"""
from PIL import Image, ImageDraw, ImageFilter
import math
import sys

OUT = sys.argv[1] if len(sys.argv) > 1 else "icon_1024.png"

SIZE = 1024
PAD = 60
SQ = SIZE - 2 * PAD
RADIUS = int(SQ * 0.224)

img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))

# Vertical gradient (warm peach -> deep terracotta)
top = (242, 174, 132)
bot = (180, 80, 50)
strip = Image.new("RGB", (1, SQ))
for y in range(SQ):
    t = y / SQ
    strip.putpixel((0, y), tuple(int(top[i] * (1 - t) + bot[i] * t) for i in range(3)))
grad = strip.resize((SQ, SQ))

# Squircle mask
mask = Image.new("L", (SQ, SQ), 0)
ImageDraw.Draw(mask).rounded_rectangle([(0, 0), (SQ, SQ)], radius=RADIUS, fill=255)
img.paste(grad, (PAD, PAD), mask)

# Soft top highlight
hl = Image.new("RGBA", (SQ, SQ), (0, 0, 0, 0))
ImageDraw.Draw(hl).rounded_rectangle(
    [(0, 0), (SQ, int(SQ * 0.42))], radius=RADIUS, fill=(255, 255, 255, 50)
)
hl_blur = hl.filter(ImageFilter.GaussianBlur(radius=35))
hl_masked = Image.composite(hl_blur, Image.new("RGBA", (SQ, SQ), (0, 0, 0, 0)), mask)
img.alpha_composite(hl_masked, (PAD, PAD))

# Inner top-edge sheen
sheen = Image.new("RGBA", (SQ, SQ), (0, 0, 0, 0))
ImageDraw.Draw(sheen).rounded_rectangle(
    [(0, 0), (SQ, int(SQ * 0.08))], radius=RADIUS, fill=(255, 255, 255, 70)
)
sheen_blur = sheen.filter(ImageFilter.GaussianBlur(radius=15))
sheen_masked = Image.composite(sheen_blur, Image.new("RGBA", (SQ, SQ), (0, 0, 0, 0)), mask)
img.alpha_composite(sheen_masked, (PAD, PAD))

# White C-shape
draw = ImageDraw.Draw(img)
cx, cy = SIZE // 2, SIZE // 2
R = int(SIZE * 0.255)
W = int(SIZE * 0.082)

draw.arc(
    [(cx - R, cy - R), (cx + R, cy + R)],
    start=45, end=315,
    fill=(255, 255, 255, 255),
    width=W,
)

for theta in (45, 315):
    rad = math.radians(theta)
    px = cx + R * math.cos(rad)
    py = cy + R * math.sin(rad)
    cap_r = W // 2
    draw.ellipse(
        [(px - cap_r, py - cap_r), (px + cap_r, py + cap_r)],
        fill=(255, 255, 255, 255),
    )

img.save(OUT)
print(f"Saved {OUT} ({img.size[0]}x{img.size[1]})")
