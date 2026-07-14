#!/usr/bin/env python3
"""Generate LockedIn's app icon from code — the signature split bar (solid = you,
hatched = agent) on a graphite tile. Outputs Resources/AppIcon.icns.
No emoji, no external art — premium and legible down to 16px."""
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
draw = ImageDraw.Draw(img)

# --- tile: rounded square with the macOS content margin ---
margin = round(N * 0.085)
tile = (margin, margin, N - margin, N - margin)
tile_r = round((N - 2 * margin) * 0.2237)   # macOS-ish corner radius

# gentle graphite gradient — light at top, never near-black at the bottom
top, bot = (62, 42, 110), (26, 17, 52)
grad = Image.new("RGBA", (N, N), (0, 0, 0, 0))
gd = ImageDraw.Draw(grad)
for y in range(N):
    gd.line([(0, y), (N, y)], fill=lerp(top, bot, y / N) + (255,))
tile_mask = rounded_mask(N, tile, tile_r)
img.paste(grad, (0, 0), tile_mask)

# --- signature split bar (optically centred, sits a touch below middle) ---
bar_h = round(N * 0.135)
cy = round(N * 0.55)
bx0 = round(N * 0.225)
bx1 = round(N * 0.775)
bar_box = (bx0, cy - bar_h // 2, bx1, cy + bar_h // 2)
bar_r = bar_h // 2
split = bx0 + round((bx1 - bx0) * 0.42)   # 42% you, 58% agent

# whole bar mask (rounded ends)
bar_mask = rounded_mask(N, bar_box, bar_r)

# human portion: solid white
human = Image.new("RGBA", (N, N), (0, 0, 0, 0))
ImageDraw.Draw(human).rectangle((bx0, bar_box[1], split, bar_box[3]), fill=(255, 211, 74, 255))
# agent portion: mid-grey base + diagonal hatch, clipped to the agent rectangle only
agent = Image.new("RGBA", (N, N), (0, 0, 0, 0))
ad = ImageDraw.Draw(agent)
ad.rectangle((split, bar_box[1], bx1, bar_box[3]), fill=(126, 116, 160, 255))
step = round(N * 0.022)
lw = max(2, round(N * 0.006))
for x in range(split - bar_h, bx1 + bar_h, step):
    ad.line([(x, bar_box[3] + bar_h), (x + bar_h, bar_box[1] - bar_h)],
            fill=(168, 158, 200, 255), width=lw)
agent_rect = Image.new("L", (N, N), 0)
ImageDraw.Draw(agent_rect).rectangle((split, bar_box[1], bx1, bar_box[3]), fill=255)
agent = Image.composite(agent, Image.new("RGBA", (N, N), (0, 0, 0, 0)), agent_rect)

bar = Image.alpha_composite(human, agent)
# thin gap between segments for a crisp split
gap = max(3, round(N * 0.006))
ImageDraw.Draw(bar).rectangle((split - gap, bar_box[1], split + gap, bar_box[3]), fill=(26, 17, 52, 255))
img.paste(bar, (0, 0), Image.composite(bar_mask, Image.new("L", (N, N), 0), bar_mask))

# --- a row of three small "project" ticks above the bar (it's a tracker) ---
tick_h = round(N * 0.028)
tick_y = cy - bar_h // 2 - round(N * 0.10)
widths = [0.34, 0.22, 0.13]
shade = [(255, 211, 74), (170, 160, 205), (120, 110, 155)]
tx = bx0
for w, c in zip(widths, shade):
    tw = round((bx1 - bx0) * w)
    tm = rounded_mask(N, (tx, tick_y, tx + tw, tick_y + tick_h), tick_h // 2)
    img.paste(Image.new("RGBA", (N, N), c + (255,)), (0, 0), tm)
    tx += tw + round(N * 0.025)

# downscale (anti-alias)
icon = img.resize((S, S), Image.Resampling.LANCZOS)

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
res_dir = os.path.join(root, "Resources")
os.makedirs(res_dir, exist_ok=True)
png1024 = os.path.join(res_dir, "icon_1024.png")
icon.save(png1024)

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
