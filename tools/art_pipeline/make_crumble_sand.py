"""World 5's CRUMBLING SANDSTONE: the crumbling tile (World 2's roof tile, World 4's thin ice) with a desert
look, made from the sandstone ledge already cut by make_sand.py (assets/art/tiles/sand/thin_*.png) so it
matches: whole (a few hairline cracks), cracked (bold cracks, a little sand trickling), and 4 chunks.

Writes assets/art/objects/crumble_sand_whole.png, crumble_sand_cracked.png, crumble_sand_chunk_0..3.png
and prints the numbers scenes/objects/crumble_tile.gd needs (surface, chunk_at).
Run:  python tools/art_pipeline/make_crumble_sand.py
"""
import random
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
SAND = ROOT / "assets" / "art" / "tiles" / "sand"
OUT = ROOT / "assets" / "art" / "objects"
W = 306                       # same width as the other crumbling tiles
CUTS = [0, 78, 160, 232, W]   # where it splits into 4 chunks
SURFACE = 6                   # the ledge's walkable top row (make_sand.py: thin_* surface)


def body() -> Image.Image:
    """The ledge stretched to the tile's width, then WEATHERED so it never looks like the safe ledges:
    paler and greyer, as if dried out and crumbly."""
    left = Image.open(SAND / "thin_left.png").convert("RGBA")
    mid = Image.open(SAND / "thin_mid.png").convert("RGBA")
    right = Image.open(SAND / "thin_right.png").convert("RGBA")
    h = max(left.height, mid.height, right.height)
    mid = mid.resize((W - left.width - right.width, mid.height), Image.LANCZOS)   # stretched: no seam
    out = Image.new("RGBA", (W, h))
    out.alpha_composite(left, (0, 0))
    out.alpha_composite(mid, (left.width, 0))
    out.alpha_composite(right, (W - right.width, 0))
    r, g, b, a = out.split()
    grey = Image.merge("RGB", (r, g, b)).convert("L")
    pale = Image.blend(Image.merge("RGB", (r, g, b)), Image.merge("RGB", (grey, grey, grey)), 0.45)
    pale = Image.eval(pale, lambda v: min(255, int(v * 0.9 + 40)))
    pale.putalpha(a)
    return pale


def cracks(img: Image.Image, bold: bool, seed: int) -> Image.Image:
    rnd = random.Random(seed)
    d = ImageDraw.Draw(img)
    h = img.height
    for sx in ([78, 160, 232] if bold else [110, 205]):
        x, y = sx + rnd.randint(-5, 5), SURFACE + 8
        pts = [(x, y)]
        while y < h - 10:
            x += rnd.randint(-6, 6)
            y += rnd.randint(5, 8)
            pts.append((x, y))
        if bold:
            d.line(pts, fill=(92, 46, 28, 255), width=3)
            d.line([(px + 1, py) for px, py in pts], fill=(255, 214, 150, 160), width=1)
        else:   # already cracked when whole: it's old, crumbly stone
            d.line(pts, fill=(110, 70, 50, 230), width=2)
    if bold:   # a little sand trickling from the cracks
        for sx in [78, 160, 232]:
            for k in range(4):
                d.ellipse((sx - 2 + rnd.randint(-3, 3), h - 4 + k * 0, sx + 2, h), fill=(240, 196, 110, 200))
    return img


def main():
    whole = cracks(body(), False, 3)
    whole.save(OUT / "crumble_sand_whole.png")
    cracked = cracks(body(), True, 5)
    cracked.save(OUT / "crumble_sand_cracked.png")
    at = []
    for i in range(4):
        piece = cracked.crop((CUTS[i], 0, CUTS[i + 1], cracked.height))
        box = piece.getbbox()
        piece.crop(box).save(OUT / f"crumble_sand_chunk_{i}.png")
        at.append((CUTS[i] + box[0], box[1]))
    print("size", whole.size, "SURFACE", SURFACE, "CHUNK_AT", at)


if __name__ == "__main__":
    main()
