#!/usr/bin/env python3
"""Generates the Homy app icon (folder + smiling cloud mascot) as PNGs.

Writes every size macOS needs into Resources/Assets.xcassets/AppIcon.appiconset
using the `.iconset` naming scheme, so build.sh can also feed the same files
to `iconutil` to produce AppIcon.icns.

The geometry mirrors MascotView.swift (both use a 1024 x 1024 design space).

Usage: python3 scripts/generate_icon.py   (requires Pillow)
"""
import json
import os

from PIL import Image, ImageDraw, ImageFilter

S = 4  # supersampling factor
BASE = 1024
W = BASE * S

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "Resources", "Assets.xcassets", "AppIcon.appiconset")


def s(v):
    return int(round(v * S))


def box(x0, y0, x1, y1):
    return [s(x0), s(y0), s(x1), s(y1)]


def hex_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def vertical_gradient(size, top, bottom):
    """RGBA image filled with a top->bottom gradient."""
    w, h = size
    mask = Image.linear_gradient("L").resize((w, h))
    a = Image.new("RGBA", (w, h), hex_rgb(top) + (255,))
    b = Image.new("RGBA", (w, h), hex_rgb(bottom) + (255,))
    return Image.composite(b, a, mask)


def paste_with_mask(canvas, fill, mask):
    canvas.alpha_composite(Image.composite(fill, Image.new("RGBA", canvas.size, (0, 0, 0, 0)), mask))


def shadow(canvas, mask, offset=(0, 18), blur=28, opacity=70, color=(20, 60, 140)):
    sh = mask.filter(ImageFilter.GaussianBlur(s(blur)))
    sh = sh.point(lambda p: p * opacity // 255)
    layer = Image.new("RGBA", canvas.size, color + (0,))
    layer.putalpha(sh)
    shifted = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    shifted.paste(layer, (s(offset[0]), s(offset[1])))
    canvas.alpha_composite(shifted)


def new_mask():
    return Image.new("L", (W, W), 0)


def draw_icon():
    canvas = Image.new("RGBA", (W, W), (0, 0, 0, 0))

    # Background squircle
    bg_mask = new_mask()
    ImageDraw.Draw(bg_mask).rounded_rectangle(box(100, 100, 924, 924), radius=s(185), fill=255)
    shadow(canvas, bg_mask, offset=(0, 10), blur=14, opacity=90, color=(30, 50, 90))
    paste_with_mask(canvas, vertical_gradient((W, W), "#F5FAFF", "#CFE3FF"), bg_mask)

    # Folder back (body + tab)
    back = new_mask()
    d = ImageDraw.Draw(back)
    d.rounded_rectangle(box(190, 330, 834, 800), radius=s(48), fill=255)
    d.rounded_rectangle(box(190, 282, 480, 380), radius=s(36), fill=255)
    d.rectangle(box(190, 330, 260, 380), fill=255)
    shadow(canvas, back, offset=(0, 14), blur=24, opacity=60)
    paste_with_mask(canvas, vertical_gradient((W, W), "#2F86F6", "#1858D0"), back)

    # Cloud
    cloud = new_mask()
    d = ImageDraw.Draw(cloud)
    for cx, cy, r in [(380, 470, 110), (520, 400, 150), (660, 470, 115), (300, 565, 85), (740, 565, 85)]:
        d.ellipse(box(cx - r, cy - r, cx + r, cy + r), fill=255)
    d.rounded_rectangle(box(300, 470, 740, 650), radius=s(70), fill=255)
    shadow(canvas, cloud, offset=(0, 10), blur=18, opacity=55)
    paste_with_mask(canvas, vertical_gradient((W, W), "#FFFFFF", "#E4EEFB"), cloud)

    # Face
    face = ImageDraw.Draw(canvas)
    navy = hex_rgb("#12306B") + (255,)
    for ex in (450, 590):
        face.ellipse(box(ex - 18, 425, ex + 18, 477), fill=navy)
        face.ellipse(box(ex - 9, 433, ex + 3, 447), fill=(255, 255, 255, 255))
    face.arc(box(482, 452, 558, 520), start=20, end=160, fill=navy, width=s(12))
    blush = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    bd = ImageDraw.Draw(blush)
    for bx in (395, 645):
        bd.ellipse(box(bx - 30, 488, bx + 30, 514), fill=(255, 120, 150, 120))
    canvas.alpha_composite(blush.filter(ImageFilter.GaussianBlur(s(4))))

    # Folder front panel
    front = new_mask()
    ImageDraw.Draw(front).rounded_rectangle(box(170, 560, 854, 822), radius=s(50), fill=255)
    shadow(canvas, front, offset=(0, -6), blur=16, opacity=50)
    paste_with_mask(canvas, vertical_gradient((W, W), "#62B4FF", "#1F6FEB"), front)

    # Gloss on the front panel
    gloss = new_mask()
    ImageDraw.Draw(gloss).rounded_rectangle(box(196, 576, 828, 640), radius=s(30), fill=110)
    gloss = gloss.filter(ImageFilter.GaussianBlur(s(6)))
    gl = Image.new("RGBA", (W, W), (255, 255, 255, 0))
    gl.putalpha(gloss)
    canvas.alpha_composite(gl)

    return canvas


SIZES = [
    ("icon_16x16.png", 16, "16x16", "1x"),
    ("icon_16x16@2x.png", 32, "16x16", "2x"),
    ("icon_32x32.png", 32, "32x32", "1x"),
    ("icon_32x32@2x.png", 64, "32x32", "2x"),
    ("icon_128x128.png", 128, "128x128", "1x"),
    ("icon_128x128@2x.png", 256, "128x128", "2x"),
    ("icon_256x256.png", 256, "256x256", "1x"),
    ("icon_256x256@2x.png", 512, "256x256", "2x"),
    ("icon_512x512.png", 512, "512x512", "1x"),
    ("icon_512x512@2x.png", 1024, "512x512", "2x"),
]


def main():
    os.makedirs(OUT, exist_ok=True)
    master = draw_icon()
    images = []
    for name, px, size, scale in SIZES:
        master.resize((px, px), Image.LANCZOS).save(os.path.join(OUT, name))
        images.append({"filename": name, "idiom": "mac", "scale": scale, "size": size})
    with open(os.path.join(OUT, "Contents.json"), "w") as f:
        json.dump({"images": images, "info": {"author": "xcode", "version": 1}}, f, indent=2)
        f.write("\n")
    print(f"Wrote {len(SIZES)} icons to {OUT}")


if __name__ == "__main__":
    main()
