#!/usr/bin/env python3
"""Generate LockedIn's app icon — design option 1a "Ring Spark" (Widget Logo Options):
a progress ring frozen at 70% with a center dot, cream on a warm coral gradient tile.
Outputs Resources/AppIcon.icns. No emoji, no external art — legible down to 16px."""
import math
import os, subprocess, tempfile
from PIL import Image, ImageDraw

S = 1024
SUPERSAMPLE = 2            # render big, downscale for clean edges
N = S * SUPERSAMPLE

def lerp(a, b, t): return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(len(a)))

def rounded_mask(size, box, radius):
    m = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(m)
    d.rounded_rectangle(box, radius=radius, fill=255)
    return m

img = Image.new("RGBA", (N, N), (0, 0, 0, 0))

# --- tile: rounded square, coral gradient (145deg approximated vertically) ---
margin = round(N * 0.085)
tile = (margin, margin, N - margin, N - margin)
tile_w = N - 2 * margin
tile_r = round(tile_w * 0.2237)   # macOS-ish corner radius

# stops from the design: #F0906A 0% -> #D96A42 55% -> #B8512F 100%
c0, c1, c2 = (240, 144, 106), (217, 106, 66), (184, 81, 47)
grad = Image.new("RGBA", (N, N), (0, 0, 0, 0))
gd = ImageDraw.Draw(grad)
for y in range(N):
    t = y / N
    col = lerp(c0, c1, t / 0.55) if t < 0.55 else lerp(c1, c2, (t - 0.55) / 0.45)
    gd.line([(0, y), (N, y)], fill=col + (255,))
img.paste(grad, (0, 0), rounded_mask(N, tile, tile_r))

# --- the mark: ring at 70% + center dot (geometry from the 72-viewBox SVG on a 120 tile) ---
cx = cy = N / 2
R = tile_w * (26 / 120)            # ring radius
sw = tile_w * (7 / 120)            # stroke width
dot_r = tile_w * (7 / 120)         # center dot radius
cream = (255, 244, 235)

layer = Image.new("RGBA", (N, N), (0, 0, 0, 0))
ld = ImageDraw.Draw(layer)

def ring_bbox(radius):
    return (cx - radius, cy - radius, cx + radius, cy + radius)

# track: full circle, cream at 28%
ld.ellipse(ring_bbox(R + sw / 2), outline=cream + (71,), width=round(sw))

# progress: 70% sweep from 12 o'clock, clockwise, round caps
start, sweep = 270, 0.70 * 360
end = (start + sweep) % 360
ld.arc(ring_bbox(R + sw / 2), start=start, end=end, fill=cream + (255,), width=round(sw))
for ang in (start, end):   # round line caps
    px = cx + R * math.cos(math.radians(ang))
    py = cy + R * math.sin(math.radians(ang))
    ld.ellipse((px - sw / 2, py - sw / 2, px + sw / 2, py + sw / 2), fill=cream + (255,))

# center dot
ld.ellipse((cx - dot_r, cy - dot_r, cx + dot_r, cy + dot_r), fill=cream + (255,))

img = Image.alpha_composite(img, layer)

# downscale (anti-alias)
icon = img.resize((S, S), Image.Resampling.LANCZOS)

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
res_dir = os.path.join(root, "Resources")
os.makedirs(res_dir, exist_ok=True)
icon.save(os.path.join(res_dir, "icon_1024.png"))

# build .iconset and convert to .icns
with tempfile.TemporaryDirectory() as d:
    iconset = os.path.join(d, "AppIcon.iconset")
    os.makedirs(iconset)
    specs = [(16,1),(16,2),(32,1),(32,2),(128,1),(128,2),(256,1),(256,2),(512,1),(512,2)]
    for base, scale in specs:
        px = base * scale
        name = f"icon_{base}x{base}{'@2x' if scale==2 else ''}.png"
        icon.resize((px, px), Image.Resampling.LANCZOS).save(os.path.join(iconset, name))
    out = os.path.join(res_dir, "AppIcon.icns")
    subprocess.run(["iconutil", "-c", "icns", iconset, "-o", out], check=True)
    print("wrote", out)
