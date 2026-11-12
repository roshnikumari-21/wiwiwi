"""Build the World 2 "Sunset Town" kit from the owners' concept art, at in-game pixel size.

Ground (assets/art/tiles/town, same pieces as the World 1 meadow kit, see make_ground.py):
  top    - curb + cobbles + first bricks, repeats left-right along the strip's surface
  fill   - brick wall that repeats in every direction: cut exactly between two mortar lines
           (three brick rows), its darkening toward the bottom evened out, so it stacks like bricks
  caps   - left/right ends of the street
  thin   - left / middle / right of the floating wooden ledge (one-way platforms)
  decos  - lamp, planter, barrel, crates, bench, pot, bush, stone post
Background (assets/art/backgrounds/town):
  far    - sunset sky, sun, hazy hills and town (top fades into the plain sky colour)
  mid    - the row of houses, white sky cut away, their wall colour continued below, darkening

Run:  python tools/art_pipeline/make_town.py   (prints the numbers ground_block.gd uses)
"""
import numpy as np
from PIL import Image

from make_background import crossfade_wrap
from make_ground import fade, scaled, solid_top
from pipeline import ART, RAW, cut, find_sprites, load, remove_background, to_image

TILES = ART / "tiles" / "town"
OBJECTS = ART / "objects"
BACK = ART / "backgrounds" / "town"

GROUND_SCALE = 0.22     # top tile art -> game px (curb + cobble band ~57 px, like World 1's grass)
TOP_SURFACE = 246       # first solid row of the top tile (top of the curb): the cat walks here
TOP_CROP_BOTTOM = 700   # keep the curb, cobbles, lower curb and the first bricks
BRICKS_FROM = 505       # first brick row in the top tile (below the lower curb)
FADE_ROWS = 30          # game px: the top tile's bottom melts into the brick fill behind it
FILL_SHADE = 0.86       # the wall is a bit darker than the street, so the cat and coins stand out
FILL_ROWS = (624, 994)  # between two mortar lines (dark rows at 624, 734, 893, 994 in the raw tile)
# The end-cap sheet is drawn smaller: its curb-to-bricks band is 219 px vs 259 px in the top tile.
CAP_SCALE = GROUND_SCALE * 259 / 219
CAP_BRICKS_FROM = 375   # first brick row in the cap pieces (raw)
CAP_BRICK_KEEP = 40     # game px of cap bricks kept before fading (the fill continues below)
CAP_INNER_FADE = 24
THIN_SCALE = 0.75       # ledge plank ~28 px thick, whole ledge ~85 px tall
DECO_SCALE = 0.5        # lamp ~300 px, bench ~100 px tall next to a ~150 px cat
PLANK_WIDTH = 290       # game px, like the meadow plank (its collision is 270 wide)
CRUMBLE_SCALE = 0.476   # roof tile ~300 px wide, like a short ledge
CRUMBLE_ROWS = (220, 520)            # rows holding all 3 drawings incl. dust and falling bits (raw)
CRUMBLE_LEFT = (42, 762, 1476)       # left edge of each drawing's box: platforms start 6 px in
CRUMBLE_WIDTH = 642
BELOW_ROWS = 700        # wall colour continued under the houses layer (a high jump looks this far down)
FAR_SCALE = 1.45
MID_SCALE = 1.3


def even_rows(a: np.ndarray) -> np.ndarray:
    """Remove a top-to-bottom brightness trend, so a repeated tile shows no light/dark bands."""
    lum = a[..., :3].mean(axis=(1, 2))
    rows = np.arange(len(lum))
    trend = np.polyval(np.polyfit(rows, lum, 1), rows)
    out = a.copy()
    out[..., :3] *= (trend.mean() / trend)[:, None, None]
    return out


def save(a, path):
    img = a if isinstance(a, Image.Image) else Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))
    img.save(path, optimize=True)
    return img.size


def main():
    TILES.mkdir(parents=True, exist_ok=True)
    BACK.mkdir(parents=True, exist_ok=True)
    numbers = {}

    # --- Ground -------------------------------------------------------------------------------
    raw = Image.open(RAW / "Warm Cobblestone and Moss Wall Tile.png").convert("RGBA")
    street = remove_background(np.asarray(raw.crop((0, 0, raw.width, TOP_CROP_BOTTOM))).astype(np.float32))
    top = np.asarray(scaled(to_image(street), GROUND_SCALE)).copy()   # white sky between the curb stones cut away
    top[-FADE_ROWS:, :, 3] = (top[-FADE_ROWS:, :, 3] * np.linspace(1.0, 0.0, FADE_ROWS)[:, None]).astype(np.uint8)
    numbers["top"] = save(top, TILES / "ground_top.png")
    numbers["TOP_SURFACE"] = round(TOP_SURFACE * GROUND_SCALE)
    numbers["bricks_from"] = round(BRICKS_FROM * GROUND_SCALE)

    fill = np.asarray(raw.crop((0, FILL_ROWS[0], raw.width, FILL_ROWS[1]))).astype(np.float32)
    fill = even_rows(fill)
    fill[..., :3] *= FILL_SHADE
    fill_img = Image.fromarray(np.clip(fill, 0, 255).astype(np.uint8))
    numbers["fill"] = save(scaled(fill_img, GROUND_SCALE), TILES / "ground_fill.png")

    sheet = remove_background(load("Hand-Painted Garden Platform Asset Sheet.png"))
    boxes = sorted(find_sprites(sheet), key=lambda b: (b[0], b[1]))   # left cap, ledge(s), right cap
    caps = [b for b in boxes if (b[3] - b[1]) > 400]
    ledges = sorted([b for b in boxes if (b[3] - b[1]) <= 400], key=lambda b: b[1])
    for box, name in zip(sorted(caps, key=lambda b: b[0]), ["ground_cap_left", "ground_cap_right"]):
        piece = cut(sheet, box)
        surface = solid_top(piece)
        row = piece[int(piece.shape[0] * 0.8), :, 3] > 128
        cols = np.flatnonzero(row)
        side = cols[0] if name.endswith("left") else piece.shape[1] - 1 - cols[-1]
        out = scaled(to_image(piece), CAP_SCALE)
        keep = round((CAP_BRICKS_FROM - box[1]) * CAP_SCALE) + CAP_BRICK_KEEP
        out = fade(out, rows=(keep, 24), cols=CAP_INNER_FADE, from_left=name.endswith("left"))
        numbers[name] = {"size": save(out, TILES / f"{name}.png"), "surface": round(surface * CAP_SCALE),
                         "side_inset": round(side * CAP_SCALE)}

    # Thin ledge: the plain one (lower on the sheet), cut into ends + a repeating middle with one bracket.
    plain = cut(sheet, ledges[-1])
    w = plain.shape[1]
    parts = {"thin_left": plain[:, : int(w * 0.31)], "thin_mid": plain[:, int(w * 0.31): int(w * 0.69)],
             "thin_right": plain[:, int(w * 0.69):]}
    for name, part in parts.items():
        out = scaled(to_image(part), THIN_SCALE)
        numbers[name] = {"size": save(out, TILES / f"{name}.png"), "surface": round(solid_top(part) * THIN_SCALE)}
    flower = cut(sheet, ledges[0])
    numbers["ledge_flowers"] = save(scaled(to_image(flower), THIN_SCALE), TILES / "ledge_flowers.png")
    # The town's moving plank (the owners' "Charming Wooden Lantern Garden Platform"). Its lantern and
    # flower pot hang past the boards, so the boards are measured: their width sets the scale, and the
    # game centres the boards (not the whole picture) on the platform's collision.
    art = remove_background(load("Charming Wooden Lantern Garden Platform.png"))
    plank = cut(art, max(find_sprites(art), key=lambda b: (b[2] - b[0]) * (b[3] - b[1])))
    top = solid_top(plank)
    boards = np.flatnonzero(plank[top + 30, :, 3] > 128)   # a row through the boards, below the top edge
    s = PLANK_WIDTH / (boards[-1] - boards[0])
    out = scaled(to_image(plank), s)
    numbers["plank"] = {"size": save(out, OBJECTS / "platform_moving_town.png"), "surface": round(top * s),
                        "boards_centre_x": round((boards[0] + boards[-1]) / 2 * s)}

    # Crumbling roof tile: the same box cut from each of the 3 drawings, so the frames line up.
    # The breaking drawing's 4 chunks are saved one by one (exact shape, not a box, so no chunk
    # carries a bit of its neighbour), with their place in the frame, so each can drop on its own.
    roof = remove_background(load("Crumbling Terracotta Roof Platform Stages.png"))
    for i, name in enumerate(["crumble_whole", "crumble_cracked", "crumble_breaking"]):
        x0 = CRUMBLE_LEFT[i]
        frame = roof[CRUMBLE_ROWS[0]:CRUMBLE_ROWS[1], x0:x0 + CRUMBLE_WIDTH]
        out = scaled(to_image(frame), CRUMBLE_SCALE)
        if i < 2:
            numbers[name] = save(out, OBJECTS / f"{name}.png")
        if i == 0:
            numbers["crumble_surface"] = round(solid_top(frame) * CRUMBLE_SCALE)
        if i == 2:
            small = np.asarray(out).astype(np.float32)
            chunks = sorted(find_sprites(small, min_area=1500), key=lambda b: b[0])
            numbers["crumble_chunks"] = []
            for n, (x_0, y_0, x_1, y_1, label, labels) in enumerate(chunks):
                piece = small[y_0:y_1, x_0:x_1].copy()
                piece[labels[y_0:y_1, x_0:x_1] != label, 3] = 0
                save(piece, OBJECTS / f"crumble_chunk_{n}.png")
                numbers["crumble_chunks"].append((int(x_0), int(y_0)))

    decos = remove_background(load("Whimsical Garden Street Asset Collection.png"))
    names = ["deco_lamp", "deco_planter", "deco_barrel", "deco_crates", "deco_bench", "deco_pot", "deco_bush", "deco_post"]
    for box, name in zip(sorted(find_sprites(decos, min_area=1500), key=lambda b: b[0]), names):
        numbers[name] = save(scaled(to_image(cut(decos, box)), DECO_SCALE), TILES / f"{name}.png")

    # --- Background ---------------------------------------------------------------------------
    far_img = Image.open(RAW / "Twilight Storybook Village Panorama.png").convert("RGBA")
    far = np.asarray(scaled(far_img, FAR_SCALE)).astype(np.float32)
    sky = far[3, :, :3].mean(axis=0)
    numbers["sky colour"] = [round(c) / 255 for c in sky]
    far = crossfade_wrap(far, 60)
    far[:80, :, 3] *= np.linspace(0.0, 1.0, 80)[:, None]   # top edge fades into the plain sky colour
    far[-2:, :, 3] = 0   # the layer repeats: keep its last rows clear (no line in the sky)
    numbers["bg_far"] = save(far, BACK / "bg_far.png")

    mid = remove_background(load("Charming Sunset Canal Town Row.png"))
    mid = np.asarray(scaled(to_image(mid), MID_SCALE)).astype(np.float32)
    # Below the houses: their wall colour, darkening the deeper you look (like World 1's green below
    # its countryside). A canal reflecting the town was tried here and looked confusing (12 Nov 2026).
    wall = mid[-6:, :, :3].reshape(-1, 3)
    wall = wall[mid[-6:, :, 3].reshape(-1) > 200].mean(axis=0)
    below = np.zeros((BELOW_ROWS, mid.shape[1], 4), np.float32)
    below[..., :3] = wall * np.linspace(0.85, 0.6, BELOW_ROWS)[:, None, None]
    below[..., 3] = 255
    mid = np.concatenate([mid, below], axis=0)
    mid[-2:, :, 3] = 0
    numbers["bg_mid"] = save(mid, BACK / "bg_mid.png")

    for k, v in numbers.items():
        print(f"  {k}: {v}")


if __name__ == "__main__":
    main()
