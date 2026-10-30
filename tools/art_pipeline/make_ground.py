"""Build the World 1 ground kit from the concept tiles, already at in-game pixel size.

Ground strips (see plan.md §3) are drawn from:
  top    - grass + dirt band that repeats left-right along the strip's surface
  fill   - dirt that repeats in every direction below it (deep ground, walls)
  caps   - left/right ends with grass curling over the edge
  thin   - left / middle / right of the thin one-way floating platforms
  decos  - flowers, tufts and a rock scattered on top
  water  - wavy surface strip (repeats sideways) + underwater body, for pits

Run:  python tools/art_pipeline/make_ground.py   (prints the numbers ground_block.gd uses)
"""
import numpy as np
from PIL import Image

from pipeline import ART, RAW, cut, find_sprites, load, remove_background, to_image

OUT = ART / "tiles" / "meadow"

# One scale for the whole ground so stones and grass match: top tile art -> game pixels.
GROUND_SCALE = 0.2
# The end-cap sheet is drawn smaller: its grass band is 204 px vs 351 px in the top tile.
CAP_SCALE = GROUND_SCALE * 351 / 204
FILL_SCALE = 0.32       # the dirt texture's stones are drawn smaller; this matches the top tile's stones
THIN_SCALE = 0.42       # thin platforms: grass band ~45 px, a little lighter than the ground
DECO_SCALE = 0.22       # flowers ~58 px tall next to a ~150 px cat
WATER_SURFACE_SCALE = 0.37   # waves ~55 px tall
WATER_BODY_SCALE = 0.75
WATER_BODY_EXTRA = 500       # game px of deep-water colour added below the bubbles
WATER_SURFACE_KEEP = 44      # game px of the strip kept: below this its segments have notches
WATER_BODY_SKIP = 85         # game px of the body's own light top bands skipped: from here its blue
                             # matches the strip's bottom, so the two meet without a line

TOP_SURFACE = 295       # first fully solid grass row in the top tile (the cat walks here)
TOP_CROP_BOTTOM = 1236  # rows below are a soft, half-transparent fringe
FADE_ROWS = 40          # fade the top tile's bottom (game px) into the dirt fill behind it
CAP_DIRT_KEEP = 45      # game px of cap dirt kept below its grass before fading (hides its rounded bottom)
CAP_INNER_FADE = 30     # game px: the cap's inner edge melts into the top tile beneath it


def scaled(img: Image.Image, s: float) -> Image.Image:
    return img.resize((max(1, round(img.width * s)), max(1, round(img.height * s))), Image.LANCZOS)


def fade(img: Image.Image, rows=None, cols=None, from_left=True) -> Image.Image:
    """Fade alpha to 0 over `rows` (from that row down) or over the inner `cols` columns."""
    a = np.asarray(img).copy()
    if rows:
        start, n = rows
        ramp = np.clip(1.0 - (np.arange(a.shape[0]) - start) / n, 0.0, 1.0)[:, None]
        a[..., 3] = (a[..., 3] * ramp).astype(np.uint8)
    if cols:
        x = np.arange(a.shape[1]) if from_left else np.arange(a.shape[1])[::-1]
        ramp = np.clip((a.shape[1] - 1 - x) / cols, 0.0, 1.0)[None, :]
        a[..., 3] = (a[..., 3] * ramp).astype(np.uint8)
    return Image.fromarray(a)


def solid_top(piece: np.ndarray) -> int:
    """First row where the middle 60 % of the piece is solid: the walkable grass line."""
    w = piece.shape[1]
    inner = piece[:, int(w * 0.2):int(w * 0.8), 3] > 128
    return int(np.flatnonzero(inner.mean(axis=1) >= 0.97)[0])


def grass_bottom(piece: np.ndarray) -> int:
    """Median row where grass turns into dirt (red clearly above green)."""
    ys = []
    for x in range(0, piece.shape[1], 7):
        col = piece[:, x]
        hit = np.flatnonzero((col[:, 3] > 128) & (col[:, 0] > col[:, 1] + 25))
        if len(hit):
            ys.append(hit[0])
    return int(np.median(ys))


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    numbers = {}

    # Top tile: crop the soft fringe, scale, fade its bottom so it melts into the fill.
    top = Image.open(RAW / "Seamless Cartoon Grass and Dirt Tile.png").convert("RGBA").crop((0, 0, 1254, TOP_CROP_BOTTOM))
    top = scaled(top, GROUND_SCALE)
    a = np.asarray(top).copy()
    ramp = np.linspace(1.0, 0.0, FADE_ROWS)[:, None]
    a[-FADE_ROWS:, :, 3] = (a[-FADE_ROWS:, :, 3] * ramp).astype(np.uint8)
    Image.fromarray(a).save(OUT / "ground_top.png", optimize=True)
    numbers["TOP_SURFACE"] = round(TOP_SURFACE * GROUND_SCALE)
    numbers["TOP_SIZE"] = top.size

    fill = scaled(Image.open(RAW / "Seamless Cartoon Cobblestone Dirt Texture.png").convert("RGBA"), FILL_SCALE)
    fill.save(OUT / "ground_fill.png", optimize=True)
    numbers["FILL_SIZE"] = fill.size

    # End caps: left and right pieces, enlarged to the ground scale.
    img = remove_background(load("Cartoon Grassy Platform End Tiles.png"))
    for box, name in zip(find_sprites(img), ["ground_cap_left", "ground_cap_right"]):
        piece = cut(img, box)
        surface = solid_top(piece)
        # Where the dirt side wall is, measured half-way down the dirt (below the grass overhang).
        row = piece[int(piece.shape[0] * 0.8), :, 3] > 128
        cols = np.flatnonzero(row)
        side = cols[0] if name.endswith("left") else piece.shape[1] - 1 - cols[-1]
        out = scaled(to_image(piece), CAP_SCALE)
        # Keep the grass and a little dirt; fade the rest (its rounded, outlined bottom) and the inner edge.
        dirt_line = round(grass_bottom(piece) * CAP_SCALE)
        out = fade(out, rows=(dirt_line + CAP_DIRT_KEEP, 30), cols=CAP_INNER_FADE, from_left=name.endswith("left"))
        out.save(OUT / f"{name}.png", optimize=True)
        numbers[name] = {"size": out.size, "surface": round(surface * CAP_SCALE), "side_inset": round(side * CAP_SCALE)}

    # Thin platform pieces.
    img = remove_background(load("Cartoon Grassy Platform Tile Set.png"))
    for box, name in zip(find_sprites(img), ["thin_left", "thin_mid", "thin_right"]):
        piece = cut(img, box)
        surface = solid_top(piece)
        out = scaled(to_image(piece), THIN_SCALE)
        out.save(OUT / f"{name}.png", optimize=True)
        numbers[name] = {"size": out.size, "surface": round(surface * THIN_SCALE)}

    # Decorations.
    img = remove_background(load("Cute Cartoon Nature Game Assets.png"))
    names = ["deco_flower_white", "deco_flower_pink", "deco_flower_yellow", "deco_tuft_big", "deco_tuft_small", "deco_rock"]
    for box, name in zip(find_sprites(img, min_area=1500), names):
        out = scaled(to_image(cut(img, box)), DECO_SCALE)
        out.save(OUT / f"{name}.png", optimize=True)
        numbers[name] = out.size

    # Water: the surface strip's left and right ends are cross-faded so it repeats; the body gets
    # its deepest colour continued below so a pit of any depth stays filled.
    img = remove_background(load("Cartoon Water Wave and Underwater Tiles.png"))
    surface_box, body_box = find_sprites(img)
    surface = to_image(cut(img, surface_box))
    surface = scaled(surface, WATER_SURFACE_SCALE)
    a = np.asarray(surface).astype(np.float32)
    band = 24
    t = np.linspace(0.0, 1.0, band)[None, :, None]
    a = np.concatenate([a[:, :band] * t + a[:, -band:] * (1.0 - t), a[:, band:-band]], axis=1)
    a = a[:WATER_SURFACE_KEEP]
    Image.fromarray(np.clip(a, 0, 255).astype(np.uint8)).save(OUT / "water_surface.png", optimize=True)
    numbers["water_surface"] = (a.shape[1], a.shape[0])
    body = np.asarray(scaled(to_image(cut(img, body_box)), WATER_BODY_SCALE)).astype(np.float32)
    body = body[WATER_BODY_SKIP:-2, 3:-3]   # skip the top bands; trim the soft edge columns
    deep = np.empty((WATER_BODY_EXTRA, body.shape[1], 4), np.float32)
    deep[:] = body[-6:, :, :].reshape(-1, 4).mean(axis=0)   # one smooth deep colour, no streaks
    body = np.concatenate([body, deep], axis=0)
    Image.fromarray(np.clip(body, 0, 255).astype(np.uint8)).save(OUT / "water_body.png", optimize=True)
    numbers["water_body"] = (body.shape[1], body.shape[0])

    for k, v in numbers.items():
        print(f"  {k}: {v}")


if __name__ == "__main__":
    main()
