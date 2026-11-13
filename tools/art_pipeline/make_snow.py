"""Build the World 4 "Frosty Peaks" kit from the owners' concept art, at in-game pixel size.

Ground (assets/art/tiles/snow, same pieces as the other kits) + the slippery-ice kit (ice_top, ice_fill):
  top    - the snow layer + the first stones, repeats left-right
  fill   - frosty boulders that repeat in every direction (cross-faded top <-> bottom)
  caps   - left/right ends with snow curling over the edge
  thin   - left / middle / right of the icy stone ledge (one-way platforms)
  ledge_wood - the snowy wooden shelf with icicles (used by the level builder)
  decos  - snowman, sapling, snowy rock, lantern, berry bush, snowballs (scattered);
           icicles (hung under ledges) and the signpost are kept apart
The ground tiles' snow / ice touches the picture's edges, where white snow meets the white background:
the background is cut column by column above the dark outline instead (no bites out of the snow).
Objects (assets/art/objects): ice floe, gift box (full / used); enemies/penguin: waddle A / B, slide,
squashed (one canvas, feet on its bottom edge).
Background (assets/art/backgrounds/snow): far mountains + sky; tall snowy pines, snow below.

Run:  python tools/art_pipeline/make_snow.py   (prints the numbers the game uses)
"""
import numpy as np
from PIL import Image

from make_background import crossfade_wrap
from make_ground import fade, scaled, solid_top
from make_town import even_rows, save
from pipeline import ART, RAW, cut, find_sprites, load, remove_background, to_image

TILES = ART / "tiles" / "snow"
OBJECTS = ART / "objects"
ENEMIES = ART / "enemies" / "penguin"
BACK = ART / "backgrounds" / "snow"

GROUND_SCALE = 0.22
TOP_CROP_BOTTOM = 620     # the snow layer and the first boulders (raw)
FILL_ROWS = (470, 1254)   # boulders only
FILL_WRAP = 80
FADE_ROWS = 30
CAP_KEEP = 45
CAP_INNER_FADE = 24
THIN_SCALE = 0.33         # icy stone ledge ~48 px tall
LEDGE_WOOD_SCALE = 0.3
PLANK_WIDTH = 290
BOX_SIZE = 110            # gift box body width (the bow sticks up above it)
PENGUIN_SCALE = 0.25      # waddling penguin ~100 px wide, about a slime
DECO_SCALE = 0.3
FAR_SCALE = 1.45
MID_SCALE = 1.0
MID_HAZE = (np.array([226.0, 236.0, 248.0]), 0.18)
BELOW_ROWS = 700


def cut_above_outline(raw: np.ndarray, start: int, stop: int) -> tuple[np.ndarray, int]:
    """Make everything above the top outline transparent, column by column. The outline is the
    first clearly darker pixel from the top (a dark blue line above the white snow / glossy ice).
    Returns the cut picture and the median outline row (the walkable surface)."""
    out = raw.copy()
    lum = raw[..., :3].mean(axis=2)
    rows = []
    for x in range(raw.shape[1]):
        dark = np.flatnonzero(lum[start:stop, x] < 170)
        y = start + (dark[0] if len(dark) else stop - start)
        rows.append(y)
        out[:y, x, 3] = 0
        if y > 0:
            out[y - 1, x, 3] *= 0.5   # soften the edge a touch
    return out, int(np.median(rows))


def ground_kit(raw_name: str, prefix: str, numbers: dict, outline_from: int, fill_rows=FILL_ROWS, wrap=FILL_WRAP):
    raw = np.asarray(Image.open(RAW / raw_name).convert("RGBA")).astype(np.float32)
    strip, surface = cut_above_outline(raw[:TOP_CROP_BOTTOM], outline_from, TOP_CROP_BOTTOM)
    top = np.asarray(scaled(to_image(strip), GROUND_SCALE)).copy()
    top[-FADE_ROWS:, :, 3] = (top[-FADE_ROWS:, :, 3] * np.linspace(1.0, 0.0, FADE_ROWS)[:, None]).astype(np.uint8)
    numbers[f"{prefix}top"] = save(top, TILES / f"{prefix}top.png")
    numbers[f"{prefix}TOP_SURFACE"] = round(surface * GROUND_SCALE)
    fill = even_rows(raw[fill_rows[0]:fill_rows[1]].copy())
    fill = crossfade_wrap(fill.transpose(1, 0, 2), wrap).transpose(1, 0, 2)
    numbers[f"{prefix}fill"] = save(scaled(to_image(fill), GROUND_SCALE), TILES / f"{prefix}fill.png")
    return surface


def snow_bottom(piece: np.ndarray) -> int:
    """Median row where the bright snow turns into the darker stones below it."""
    lum = piece[..., :3].mean(axis=2)
    ys = []
    for x in range(int(piece.shape[1] * 0.2), int(piece.shape[1] * 0.8), 7):
        col = np.flatnonzero((piece[:, x, 3] > 128) & (lum[:, x] < 150))
        top = np.flatnonzero(piece[:, x, 3] > 128)
        if len(col) and len(top):
            after = col[col > top[0] + 20]   # skip the dark outline on the snow's top
            if len(after):
                ys.append(after[0])
    return int(np.median(ys))


def main():
    for folder in (TILES, ENEMIES, BACK):
        folder.mkdir(parents=True, exist_ok=True)
    numbers = {}

    # --- Ground: snow and ice ------------------------------------------------------------------
    snow_surface = ground_kit("Cartoon Snow-Capped Boulder Wall.png", "ground_", numbers, 200)
    # Ice: its fill from deeper down, cross-faded over a wide band (its cracks showed a line at each repeat).
    ground_kit("Glowing Blue Ice Platform.png", "ice_", numbers, 300, (560, 1254), 260)
    snow_raw = np.asarray(Image.open(RAW / "Cartoon Snow-Capped Boulder Wall.png").convert("RGBA")).astype(np.float32)
    snow_end = snow_bottom(cut_above_outline(snow_raw[:TOP_CROP_BOTTOM], 200, TOP_CROP_BOTTOM)[0])

    sheet = remove_background(load("Cartoon Snowy Cliff Platform Set.png"))
    boxes = find_sprites(sheet)
    caps = sorted([b for b in boxes if (b[3] - b[1]) > 400], key=lambda b: b[0])
    wood_box, stone_box = sorted([b for b in boxes if (b[3] - b[1]) <= 400], key=lambda b: b[1])
    cap_scale = None
    for box, name in zip(caps, ["ground_cap_left", "ground_cap_right"]):
        piece = cut(sheet, box)
        cap_top, cap_snow = solid_top(piece), snow_bottom(piece)
        cap_scale = cap_scale or GROUND_SCALE * (snow_end - snow_surface) / (cap_snow - cap_top)
        row = piece[int(piece.shape[0] * 0.8), :, 3] > 128
        cols = np.flatnonzero(row)
        side = cols[0] if name.endswith("left") else piece.shape[1] - 1 - cols[-1]
        out = scaled(to_image(piece), cap_scale)
        out = fade(out, rows=(round(cap_snow * cap_scale) + CAP_KEEP, 24), cols=CAP_INNER_FADE,
                   from_left=name.endswith("left"))
        numbers[name] = {"size": save(out, TILES / f"{name}.png"), "surface": round(cap_top * cap_scale),
                         "side_inset": round(side * cap_scale)}

    stone = cut(sheet, stone_box)
    w = stone.shape[1]
    parts = {"thin_left": stone[:, : int(w * 0.3)], "thin_mid": stone[:, int(w * 0.3): int(w * 0.7)],
             "thin_right": stone[:, int(w * 0.7):]}
    for name, part in parts.items():
        out = scaled(to_image(part), THIN_SCALE)
        numbers[name] = {"size": save(out, TILES / f"{name}.png"), "surface": round(solid_top(part) * THIN_SCALE)}
    wood = cut(sheet, wood_box)
    numbers["ledge_wood"] = {"size": save(scaled(to_image(wood), LEDGE_WOOD_SCALE), TILES / "ledge_wood.png"),
                             "surface": round(solid_top(wood) * LEDGE_WOOD_SCALE)}

    decos = remove_background(load("Cute Winter Game Asset Collection.png"))
    names = ["deco_snowman", "deco_sapling", "deco_rock", "deco_lantern",
             "icicles", "signpost", "deco_berries", "deco_snowballs"]
    for box, name in zip(find_sprites(decos, min_area=1500), names):   # reading order: 2 rows of 4
        numbers[name] = save(scaled(to_image(cut(decos, box)), DECO_SCALE), TILES / f"{name}.png")

    # --- Objects ------------------------------------------------------------------------------
    art = remove_background(load("Chibi Ice Platform with Snowy Flag.png"))
    floe = cut(art, max(find_sprites(art), key=lambda b: (b[2] - b[0]) * (b[3] - b[1])))
    slab_row = int(floe.shape[0] * 0.72)   # through the ice slab, below the flag and the snow
    cols = np.flatnonzero(floe[slab_row, :, 3] > 128)
    s = PLANK_WIDTH / (cols[-1] - cols[0])
    mid = floe[:, int(floe.shape[1] * 0.3): int(floe.shape[1] * 0.6)]
    numbers["floe"] = {"size": save(scaled(to_image(floe), s), OBJECTS / "platform_moving_snow.png"),
                       "surface": round(solid_top(mid) * s), "slab_centre_x": round((cols[0] + cols[-1]) / 2 * s)}

    gifts = remove_background(load("Snowy Gift Boxes_ Full and Used.png"))
    bodies = sorted(find_sprites(gifts), key=lambda b: b[0])
    pieces = [cut(gifts, b) for b in bodies]
    body_w = max((p[-40, :, 3] > 128).sum() for p in pieces)   # the box's own width, near its bottom
    s = BOX_SIZE / body_w
    for piece, name in zip(pieces, ["gift_full", "gift_used"]):
        numbers[name] = save(scaled(to_image(piece), s), OBJECTS / f"{name}.png")

    peng = remove_background(load("Chibi Penguin Action Pose Parade.png"))
    found = find_sprites(peng, min_area=800)
    bodies = sorted([b for b in found if (b[2] - b[0]) > 300], key=lambda b: b[0])
    feet = max(b[3] for b in bodies)
    frames = [scaled(to_image(peng[b[1]:feet, b[0]:b[2]]), PENGUIN_SCALE) for b in bodies]
    cw, ch = max(f.width for f in frames), max(f.height for f in frames)
    for frame, name in zip(frames, ["peng_walk_0", "peng_walk_1", "peng_slide", "peng_squash"]):
        canvas = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
        canvas.paste(frame, ((cw - frame.width) // 2, ch - frame.height))
        numbers[name] = save(canvas, ENEMIES / f"{name}.png")
    puffs = [b for b in found if (b[2] - b[0]) <= 300 and b[0] < bodies[2][0]]   # speed lines + snow puffs
    if puffs:
        x0, y0 = min(b[0] for b in puffs), min(b[1] for b in puffs)
        x1, y1 = max(b[2] for b in puffs), max(b[3] for b in puffs)
        numbers["peng_trail"] = save(scaled(to_image(peng[y0:y1, x0:x1]), PENGUIN_SCALE), ENEMIES / "peng_trail.png")

    # --- Background ---------------------------------------------------------------------------
    far = np.asarray(scaled(Image.open(RAW / "Pastel Snowy Mountain Valley.png").convert("RGBA"), FAR_SCALE)).astype(np.float32)
    numbers["sky colour"] = [round(c / 255, 3) for c in far[:40, :, :3].reshape(-1, 3).mean(axis=0)]
    far = crossfade_wrap(far, 80)
    far[:80, :, 3] *= np.linspace(0.0, 1.0, 80)[:, None]
    far[-2:, :, 3] = 0
    numbers["bg_far"] = save(far, BACK / "bg_far.png")

    mid = remove_background(load("Snowy Pine Forest Panorama.png"), hole_min_area=3000)
    mid = np.asarray(scaled(to_image(mid), MID_SCALE)).astype(np.float32)
    mid = crossfade_wrap(mid, 60)
    colour, amount = MID_HAZE
    mid[..., :3] = mid[..., :3] * (1.0 - amount) + colour * amount
    mid[:12, :, 3] = 0
    ground = mid[-6:, :, :3].reshape(-1, 3)
    ground = ground[mid[-6:, :, 3].reshape(-1) > 200].mean(axis=0)
    below = np.zeros((BELOW_ROWS, mid.shape[1], 4), np.float32)
    below[..., :3] = ground * np.linspace(0.92, 0.7, BELOW_ROWS)[:, None, None]   # snow, a little darker deeper
    below[..., 3] = 255
    mid = np.concatenate([mid, below], axis=0)
    mid[-2:, :, 3] = 0
    numbers["bg_mid"] = save(mid, BACK / "bg_mid.png")

    for k, v in numbers.items():
        print(f"  {k}: {v}")


if __name__ == "__main__":
    main()
