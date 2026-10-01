#!/usr/bin/env python3
"""make_app_icon.py — Render the original placeholder app icon (1024x1024 PNG).

Original artwork: four macro-color arcs (blue calories / coral protein /
yellow fat / green carbs) forming a ring on the warm near-black surface
from MFColor. Nothing is copied from MacroFactor's brand assets.
Replace with final art before TestFlight (see app/Resources/Assets.xcassets
README).
"""
from PIL import Image, ImageDraw

SIZE = 1024
BG = (0x1A, 0x1B, 0x1E)          # MFColor.background (dark)
MACROS = [
    (0x4A, 0x8D, 0xFF),          # calories blue
    (0xEE, 0x7A, 0x52),          # protein coral
    (0xF2, 0xBE, 0x3A),          # fat yellow
    (0x3F, 0xB9, 0x7F),          # carbs green
]

img = Image.new("RGB", (SIZE, SIZE), BG)
d = ImageDraw.Draw(img)
cx = cy = SIZE // 2
radius = 330
width = 110
gap = 14  # degrees between arcs

for i, color in enumerate(MACROS):
    start = -90 + i * 90 + gap / 2
    end = -90 + (i + 1) * 90 - gap / 2
    d.arc(
        [cx - radius, cy - radius, cx + radius, cy + radius],
        start=start, end=end, fill=color, width=width,
    )

# Center dot in the calories blue.
dot_r = 56
d.ellipse([cx - dot_r, cy - dot_r, cx + dot_r, cy + dot_r],
          fill=MACROS[0])

img.save("app/Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png")
print("wrote icon-1024.png")
