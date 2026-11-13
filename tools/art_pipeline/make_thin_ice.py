"""World 4's THIN ICE: a crumbling tile made from the ice ground's own art (assets/art/tiles/snow/ice_top.png),
so it matches the ice stretches. It's a bare slab of clear ice with no snow on top (snow-covered floes are
the safe moving ones), faint hairline cracks when whole, and bold cracks when it's about to break.

Writes assets/art/objects/thin_ice_whole.png, thin_ice_cracked.png and thin_ice_chunk_0..3.png, and prints
the numbers scenes/objects/crumble_tile.gd needs (SURFACE, CHUNK_AT).
Run:  python tools/art_pipeline/make_thin_ice.py
"""
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "assets" / "art" / "tiles" / "snow" / "ice_top.png"
OUT = ROOT / "assets" / "art" / "objects"

W, H = 306, 70          # frame (same width as the roof tile)
TOP = 14                # the walkable top row inside the frame
SLAB = 34               # slab thickness at its middle
CUTS = [0, 78, 160, 232, W]   # where the slab splits into 4 chunks


def slab_mask():
    """A rounded slab whose underside is a little jagged, like a broken-off sheet of ice."""
    rnd = random.Random(7)
    m = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(m)
    pts = [(10, TOP + 2), (16, TOP), (W - 16, TOP), (W - 10, TOP + 2), (W - 3, TOP + 12)]
    x = W - 3
    while x > 3:   # the jagged bottom, right to left
        depth = SLAB - 6 * abs(x - W / 2) / (W / 2) + rnd.uniform(-4, 4)
        pts.append((x, TOP + depth))
        x -= rnd.randint(14, 26)
    pts += [(3, TOP + 12)]
    d.polygon(pts, fill=255)
    return m.filter(ImageFilter.GaussianBlur(0.8))


def body():
    src = Image.open(SRC).convert("RGBA")
    band = src.crop((0, 84, src.width, 136))   # the ice starts at row 84
    band = band.crop((0, 0, band.width, 52))
    tile = Image.new("RGBA", (W + band.width, 52))
    tile.paste(band, (0, 0))
    tile.paste(band, (band.width, 0))
    ice = Image.new("RGBA", (W, H))
    ice.paste(tile.crop((0, 0, W, 52)), (0, TOP - 2))
    # paler and a little see-through: it's THIN ice
    r, g, b, a = ice.split()
    r = r.point(lambda v: int(v * 0.75 + 255 * 0.25))
    g = g.point(lambda v: int(v * 0.8 + 255 * 0.2))
    ice = Image.merge("RGBA", (r, g, b, a))
    m = slab_mask()
    out = Image.new("RGBA", (W, H))
    out.paste(ice, (0, 0), m.point(lambda v: int(v * 0.92)))
    d = ImageDraw.Draw(out)
    # a dark-blue outline so it reads against the sky and the water
    edge = m.filter(ImageFilter.MaxFilter(3))
    ring = Image.new("RGBA", (W, H), (40, 80, 140, 255))
    shell = Image.new("RGBA", (W, H))
    shell.paste(ring, (0, 0), edge)
    shell.alpha_composite(out)
    d = ImageDraw.Draw(shell)
    d.line([(18, TOP + 2), (W - 18, TOP + 2)], fill=(255, 255, 255, 220), width=2)   # frosty top shine
    return shell, m


def cracks(img, bold, seed):
    rnd = random.Random(seed)
    d = ImageDraw.Draw(img)
    starts = [70, 150, 235] if bold else [95, 205]
    for sx in starts:
        x, y = sx + rnd.randint(-8, 8), TOP + 1
        pts = [(x, y)]
        while y < TOP + SLAB - 4:
            x += rnd.randint(-10, 10)
            y += rnd.randint(5, 9)
            pts.append((x, y))
        if bold:
            d.line(pts, fill=(30, 60, 110, 255), width=3)
            d.line(pts, fill=(255, 255, 255, 230), width=1)
            bx, by = pts[1]   # a side branch
            d.line([(bx, by), (bx + rnd.choice([-1, 1]) * 18, by + 10)], fill=(30, 60, 110, 255), width=2)
        else:
            d.line(pts[:3], fill=(255, 255, 255, 150), width=1)
    return img


def main():
    whole, m = body()
    cracks(whole, False, 3)
    whole.save(OUT / "thin_ice_whole.png")
    cracked, _ = body()
    cracks(cracked, True, 5)
    cracked.save(OUT / "thin_ice_cracked.png")
    at = []
    for i in range(4):
        piece = cracked.crop((CUTS[i], 0, CUTS[i + 1], H))
        box = piece.getbbox()
        piece = piece.crop(box)
        piece.save(OUT / f"thin_ice_chunk_{i}.png")
        at.append((CUTS[i] + box[0], box[1]))
    print("SURFACE", TOP, "WIDTH", W, "CHUNK_AT", at)


if __name__ == "__main__":
    main()
