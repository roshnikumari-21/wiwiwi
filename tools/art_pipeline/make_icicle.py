"""World 4's FALLING ICICLE (the pinecone hazard with look = "icicle"), cut from the icicle art that already
hangs under the snowy ledges (assets/art/tiles/snow/icicles.png), so it matches:

  icicle_hanging.png  the biggest icicle with its own lump of snow, enlarged (it's the dangerous one)
  icicle_falling.png  the same icicle without the snow, point down
  icicle_landed.png   a few shards scattered on the ground

Run:  python tools/art_pipeline/make_icicle.py
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "assets" / "art" / "tiles" / "snow" / "icicles.png"
OUT = ROOT / "assets" / "art" / "objects"
SCALE = 1.7
BIG = (33, 0, 68, 70)        # the big middle icicle with the snow above it (x0, y0, x1, y1 in icicles.png)
SNOW_ROWS = 24               # rows of snow on top of it
ROOT_HALF = 14               # half the icicle's width where it meets the snow


def only_big_icicle(src):
    """The big icicle alone: below the snow, inside a wedge from its tip up to its root (its
    neighbours touch it only near the snow, outside the wedge)."""
    a = src.split()[3].load()
    w, h = src.size
    cols = [x for x in range(BIG[0], BIG[2]) if any(a[x, y] > 128 for y in range(h - 12, h))]
    cx = (min(cols) + max(cols)) / 2                 # the tip's column
    tip = max(y for y in range(h) if a[round(cx), y] > 128)
    out = Image.new("RGBA", src.size)
    px, opx = src.load(), out.load()
    for y in range(SNOW_ROWS, tip + 1):
        half = 2.5 + (tip - y) * ROOT_HALF / (tip - SNOW_ROWS)
        for x in range(w):
            if abs(x - cx) <= half:
                opx[x, y] = px[x, y]
    return out.crop(out.getbbox())


def snow_lump(width):
    """A rounded lump of snow (cut from the snow cap of the icicle art) for the top of the hanging icicle."""
    src = Image.open(SRC).convert("RGBA")
    cap = src.crop((BIG[0] - 4, 2, BIG[2] + 4, SNOW_ROWS + 2)).resize((width, SNOW_ROWS + 4), Image.LANCZOS)
    m = Image.new("L", cap.size, 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, cap.width - 1, cap.height - 1), radius=cap.height // 2, fill=255)
    out = Image.new("RGBA", cap.size)
    out.paste(cap, (0, 0), Image.composite(cap.split()[3], m, m).filter(ImageFilter.GaussianBlur(0.5)))
    return out


def main():
    src = Image.open(SRC).convert("RGBA")
    ice = only_big_icicle(src)
    falling = ice.resize((round(ice.width * SCALE), round(ice.height * SCALE)), Image.LANCZOS)
    falling.save(OUT / "icicle_falling.png")
    lump = snow_lump(falling.width + 14)
    hanging = Image.new("RGBA", (lump.width, lump.height - 8 + falling.height))
    hanging.alpha_composite(falling, (7, lump.height - 8))
    hanging.alpha_composite(lump, (0, 0))
    hanging.save(OUT / "icicle_hanging.png")
    # shards: the icicle cut in three, lying down and spread out
    landed = Image.new("RGBA", (96, 34))
    h = falling.height
    for i, (x, y, angle) in enumerate([(4, 10, 80), (36, 14, -100), (66, 8, 70)]):
        piece = falling.crop((0, i * h // 3, falling.width, (i + 1) * h // 3))
        piece = piece.resize((piece.width * 2 // 3, piece.height * 2 // 3), Image.LANCZOS).rotate(angle, expand=True)
        landed.alpha_composite(piece, (x, max(0, min(y, landed.height - piece.height))))
    landed.crop(landed.getbbox()).save(OUT / "icicle_landed.png")
    for n in ["icicle_hanging", "icicle_falling", "icicle_landed"]:
        print(n, Image.open(OUT / f"{n}.png").size)


if __name__ == "__main__":
    main()
