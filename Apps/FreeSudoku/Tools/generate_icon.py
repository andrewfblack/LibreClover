#!/usr/bin/env python3
"""Generate FreeSudoku's original artwork. Dev dependency: Pillow >= 10.

Run from anywhere with python3 Apps/FreeSudoku/Tools/generate_icon.py.
All shapes are drawn here; no fonts or third-party artwork are used.
"""

from pathlib import Path
from PIL import Image, ImageDraw

SCALE = 2
image = Image.new("RGB", (1024 * SCALE, 1024 * SCALE), "#123f3c")
draw = ImageDraw.Draw(image)


def rectangle(box, radius, fill):
    draw.rounded_rectangle(tuple(int(n * SCALE) for n in box), radius=radius * SCALE, fill=fill)


def stroke(points, fill, width=22):
    scaled = [(int(x * SCALE), int(y * SCALE)) for x, y in points]
    draw.line(scaled, fill=fill, width=width * SCALE, joint="curve")
    r = width * SCALE / 2
    for x, y in scaled:
        draw.ellipse((x - r, y - r, x + r, y + r), fill=fill)


# An inset ivory puzzle with a single mint focus cell.
rectangle((142, 158, 882, 898), 80, "#092f2c")
rectangle((142, 126, 882, 866), 80, "#fbf7e9")
for row in range(3):
    for column in range(3):
        x, y = 186 + column * 222, 170 + row * 222
        rectangle((x, y, x + 208, y + 208), 24, "#e9eddf")
rectangle((408, 392, 616, 600), 24, "#94d9bd")

# Hand-drawn geometric digits 1, 2 and 3 on a diagonal.
stroke([(270, 239), (294, 216), (294, 330)], "#24594f")
stroke([(268, 330), (320, 330)], "#24594f")
stroke([(476, 447), (492, 432), (526, 432), (542, 450), (542, 470),
        (478, 534), (546, 534)], "#123f3c")
stroke([(700, 654), (751, 654), (768, 673), (751, 704),
        (768, 731), (751, 756), (700, 756)], "#24594f")
stroke([(726, 704), (751, 704)], "#24594f")

output = Path(__file__).resolve().parents[1] / "Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
output.parent.mkdir(parents=True, exist_ok=True)
image.resize((1024, 1024), Image.Resampling.LANCZOS).save(output)
print(output)
