"""Build the World 5 "Sunny Dunes" kit from the owners' concept art, at in-game pixel size.

Ground (assets/art/tiles/sand, same pieces as the other kits) + the quicksand kit (quick_top, quick_fill):
  top    - the sand layer + the first stones, repeats left-right
  fill   - sandstone rocks that repeat in every direction (cross-faded top <-> bottom)
  caps   - left/right ends with sand rounding over the edge
  thin   - left / middle / right of the sandstone ledge (one-way platforms)
  ledge_wood - the palm-wood plank tied with rope (used by the level builder)
  decos  - cactus, flowers, rock, jar, lantern, palm sprout, aloe (scattered); the signpost kept apart
Objects (assets/art/objects): flying carpet, clay pot (full / used), coconut (hanging / falling / landed),
cactus spikes (short / long). enemies/mole: tunnelling mound, popping up, looking around (2), squashed
(one canvas, the mound's bottom on its bottom edge).
Background (assets/art/backgrounds/sand): far dunes + sky; tall palms and cacti, sand below.

Run:  python tools/art_pipeline/make_sand.py   (prints the numbers the game uses)
"""
import numpy as np
from PIL import Image
from scipy import ndimage

from make_background import crossfade_wrap
from make_ground import fade, scaled, solid_top
from make_snow import cut_above_outline
from make_town import even_rows, save
from pipeline import ART, RAW, cut, find_sprites, load, remove_background, to_image

TILES = ART / "tiles" / "sand"
OBJECTS = ART / "objects"
ENEMIES = ART / "enemies" / "mole"
BACK = ART / "backgrounds" / "sand"

GROUND_SCALE = 0.22
TOP_CROP_BOTTOM = 620     # the sand layer and the first stones (raw)
FILL_ROWS = (470, 1254)   # stones only
FILL_WRAP = 80
QUICK_FILL_ROWS = (560, 1254)
QUICK_WRAP = 260          # quicksand swirls: a wide cross-fade so no line shows where it repeats
FADE_ROWS = 30
CAP_KEEP = 45
CAP_INNER_FADE = 24
THIN_SCALE = 0.33         # sandstone ledge ~48 px tall
LEDGE_WOOD_SCALE = 0.3
PLANK_WIDTH = 290         # the carpet's flat top, like the other moving platforms
BOX_SIZE = 110            # clay pot body width
MOLE_SCALE = 0.48         # the mole sitting up ~95 px wide, about a slime
COCONUT_SIZE = 62         # the coconut's width in game (the pinecone is ~54-61)
SPIKES_SHORT_HEIGHT = 314  # same raw heights as the meadow spikes (spikes.gd draws them at 0.26)
SPIKES_LONG_HEIGHT = 327
DECO_SCALE = 0.3
FAR_SCALE = 1.45
MID_SCALE = 1.0
MID_HAZE = (np.array([250.0, 236.0, 214.0]), 0.2)   # a little warm haze so the palms sit back
BELOW_ROWS = 700


def sand_bottom(piece: np.ndarray) -> int:
    """Row where the golden sand turns into the redder sandstone below it: the first row (below the
    sand's top outline) where a good share of the middle of the picture is stone-coloured. By colour
    (the sand's shading is as dark as the stones) and row by row (its pebbles don't count)."""
    # sand is yellow (green almost as strong as red), the sandstone a redder orange
    warmth = piece[..., 1] / np.maximum(piece[..., 0], 1.0)
    x0, x1 = int(piece.shape[1] * 0.15), int(piece.shape[1] * 0.85)
    solid = piece[:, x0:x1, 3] > 128
    dark = solid & (warmth[:, x0:x1] < 0.62)
    top = int(np.flatnonzero(solid.any(axis=1))[0])
    share = dark.sum(axis=1) / np.maximum(solid.sum(axis=1), 1)
    stony = share[top + 40:] > 0.6
    run = np.convolve(stony.astype(int), np.ones(12, int), "valid")   # stone-coloured for 12 rows running
    return top + 40 + int(np.flatnonzero(run == 12)[0])


def key_out(img: np.ndarray, tol=46.0, hole_min_area=2500) -> np.ndarray:
    """Remove a flat coloured background (the palms' plain sky-blue): pixels close to the corner
    colour that touch the border, plus enclosed patches of it bigger than hole_min_area (the sky
    between fronds). Edge pixels are softened by how close they are to the key colour."""
    out = img.copy()
    key = np.median(np.concatenate([img[:6, :6, :3].reshape(-1, 3), img[:6, -6:, :3].reshape(-1, 3)]), axis=0)
    dist = np.sqrt(((img[..., :3] - key) ** 2).sum(axis=2))
    near = dist < tol
    labels, _ = ndimage.label(near)
    border = np.unique(np.concatenate([labels[0], labels[-1], labels[:, 0], labels[:, -1]]))
    bg = np.isin(labels, border[border > 0])
    sizes = ndimage.sum(near, labels, range(1, labels.max() + 1))
    bg |= np.isin(labels, np.flatnonzero(sizes >= hole_min_area) + 1)
    out[bg, 3] = 0
    edge = ndimage.binary_dilation(bg, iterations=2) & ~bg
    out[edge, 3] = np.clip((dist[edge] - tol * 0.5) / tol, 0.0, 1.0) * 255
    return out


def ground_kit(raw_name, prefix, numbers, outline_from, fill_rows=FILL_ROWS, wrap=FILL_WRAP):
    raw = np.asarray(Image.open(RAW / raw_name).convert("RGBA")).astype(np.float32)
    strip, surface = cut_above_outline(raw[:TOP_CROP_BOTTOM], outline_from, TOP_CROP_BOTTOM)
    top = np.asarray(scaled(to_image(strip), GROUND_SCALE)).copy()
    top[-FADE_ROWS:, :, 3] = (top[-FADE_ROWS:, :, 3] * np.linspace(1.0, 0.0, FADE_ROWS)[:, None]).astype(np.uint8)
    numbers[f"{prefix}top"] = save(top, TILES / f"{prefix}top.png")
    numbers[f"{prefix}TOP_SURFACE"] = round(surface * GROUND_SCALE)
    numbers[f"{prefix}FILL_FROM"] = top.shape[0] - FADE_ROWS - round(surface * GROUND_SCALE)
    fill = even_rows(raw[fill_rows[0]:fill_rows[1]].copy())
    fill = crossfade_wrap(fill.transpose(1, 0, 2), wrap).transpose(1, 0, 2)
    numbers[f"{prefix}fill"] = save(scaled(to_image(fill), GROUND_SCALE), TILES / f"{prefix}fill.png")
    return surface, raw


def groups_by_x(found, n):
    """Cluster sprite boxes into n groups left to right (a pose and its loose sand / stars / lines)."""
    found = sorted(found, key=lambda b: (b[0] + b[2]) / 2)
    centres = [(b[0] + b[2]) / 2 for b in found]
    gaps = sorted(range(len(centres) - 1), key=lambda i: centres[i + 1] - centres[i], reverse=True)[:n - 1]
    groups, start = [], 0
    for i in sorted(gaps):
        groups.append(found[start:i + 1])
        start = i + 1
    groups.append(found[start:])
    return groups


def union(sheet, group):
    """Crop the union of a group of sprites, keeping only their own pixels."""
    x0, y0 = min(b[0] for b in group), min(b[1] for b in group)
    x1, y1 = max(b[2] for b in group), max(b[3] for b in group)
    piece = np.zeros((y1 - y0, x1 - x0, 4), np.float32)
    for b in group:
        part = cut(sheet, b)
        region = piece[b[1] - y0:b[3] - y0, b[0] - x0:b[2] - x0]
        mask = part[..., 3] > region[..., 3]
        region[mask] = part[mask]
    return piece, (x0, y0, x1, y1)


def main():
    for folder in (TILES, ENEMIES, BACK):
        folder.mkdir(parents=True, exist_ok=True)
    numbers = {}

    # --- Ground: sand and quicksand -------------------------------------------------------------
    sand_surface, sand_raw = ground_kit("Warm Desert Sandstone Tile.png", "ground_", numbers, 220)
    ground_kit("Glossy Swirling Mud Layers.png", "quick_", numbers, 220, QUICK_FILL_ROWS, QUICK_WRAP)
    sand_end = sand_bottom(cut_above_outline(sand_raw[:TOP_CROP_BOTTOM], 220, TOP_CROP_BOTTOM)[0])

    sheet = remove_background(load("Desert Sandstone Platform Asset Sheet.png"))
    boxes = find_sprites(sheet)
    caps = sorted([b for b in boxes if (b[3] - b[1]) > 400], key=lambda b: b[0])
    wood_box, stone_box = sorted([b for b in boxes if (b[3] - b[1]) <= 400], key=lambda b: b[1])
    cap_scale = None
    for box, name in zip(caps, ["ground_cap_left", "ground_cap_right"]):
        piece = cut(sheet, box)
        cap_top, cap_sand = solid_top(piece), sand_bottom(piece)
        cap_scale = cap_scale or GROUND_SCALE * (sand_end - sand_surface) / (cap_sand - cap_top)
        row = piece[int(piece.shape[0] * 0.8), :, 3] > 128
        cols = np.flatnonzero(row)
        side = cols[0] if name.endswith("left") else piece.shape[1] - 1 - cols[-1]
        out = scaled(to_image(piece), cap_scale)
        out = fade(out, rows=(round(cap_sand * cap_scale) + CAP_KEEP, 24), cols=CAP_INNER_FADE,
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

    decos = remove_background(load("Cute Desert Decor Collection.png"))
    names = ["deco_cactus", "deco_flowers", "deco_rock", "deco_jar", "deco_lantern", "signpost",
             "deco_sprout", "deco_aloe"]
    found = sorted(find_sprites(decos, min_area=1500), key=lambda b: b[0])
    for group, name in zip(groups_by_x(found, 8), names):
        piece, _ = union(decos, group)
        numbers[name] = save(scaled(to_image(piece), DECO_SCALE), TILES / f"{name}.png")

    # --- Objects ------------------------------------------------------------------------------
    art = remove_background(load("Whimsical Golden-Tasseled Magic Carpet.png"))
    carpet = cut(art, max(find_sprites(art), key=lambda b: (b[2] - b[0]) * (b[3] - b[1])))
    body_row = int(carpet.shape[0] * 0.45)   # through the carpet's body, above the tassels
    cols = np.flatnonzero(carpet[body_row, :, 3] > 128)
    s = PLANK_WIDTH / (cols[-1] - cols[0])
    mid = carpet[:, int(carpet.shape[1] * 0.3): int(carpet.shape[1] * 0.7)]
    numbers["carpet"] = {"size": save(scaled(to_image(carpet), s), OBJECTS / "platform_moving_sand.png"),
                         "surface": round(solid_top(mid) * s), "body_centre_x": round((cols[0] + cols[-1]) / 2 * s)}

    pots = remove_background(load("Vibrant and Weathered Clay Pots.png"))
    bodies = sorted(find_sprites(pots), key=lambda b: b[0])[:2]
    pieces = [cut(pots, b) for b in bodies]
    body_w = max((p[int(p.shape[0] * 0.55), :, 3] > 128).sum() for p in pieces)   # the pot's belly
    s = BOX_SIZE / body_w
    for piece, name in zip(pieces, ["pot_full", "pot_used"]):
        numbers[name] = save(scaled(to_image(piece), s), OBJECTS / f"{name}.png")

    coco = remove_background(load("Coconut Harvest Cartoon Icons.png"))
    groups = groups_by_x(find_sprites(coco, min_area=200), 3)
    falling, _ = union(coco, [max(groups[1], key=lambda b: (b[2] - b[0]) * (b[3] - b[1]))])   # just the nut
    s = COCONUT_SIZE / falling.shape[1]
    numbers["coconut_falling"] = save(scaled(to_image(falling), s), OBJECTS / "coconut_falling.png")
    hanging, _ = union(coco, groups[0])
    numbers["coconut_hanging"] = save(scaled(to_image(hanging), s), OBJECTS / "coconut_hanging.png")
    landed, _ = union(coco, groups[2])
    numbers["coconut_landed"] = save(scaled(to_image(landed), s), OBJECTS / "coconut_landed.png")

    cacti = remove_background(load("Cartoon Desert Cactus Platforms.png"))
    found = sorted(find_sprites(cacti, min_area=1500), key=lambda b: b[0])
    for group, name, height in zip(groups_by_x(found, 2), ["spikes_cactus_short", "spikes_cactus_long"],
                                   [SPIKES_SHORT_HEIGHT, SPIKES_LONG_HEIGHT]):
        piece, _ = union(cacti, group)   # as tall as the meadow spikes: just as hard to jump
        numbers[name] = save(scaled(to_image(piece), height / piece.shape[0]), OBJECTS / f"{name}.png")

    mole = remove_background(load("Cute Sand Mole Adventure Sprite Sheet.png"))
    found = find_sprites(mole, min_area=150)
    poses = groups_by_x(found, 5)
    crops = [union(mole, g) for g in poses]
    ground_line = max(box[3] for _, box in crops)
    frames = []
    for piece, (x0, y0, x1, y1) in crops:
        canvas = np.zeros((ground_line - y0, x1 - x0, 4), np.float32)
        canvas[: y1 - y0] = piece
        frames.append(scaled(to_image(canvas), MOLE_SCALE))
    cw, ch = max(f.width for f in frames), max(f.height for f in frames)
    for frame, name in zip(frames, ["mole_mound", "mole_pop", "mole_look_0", "mole_look_1", "mole_squash"]):
        canvas = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
        canvas.paste(frame, ((cw - frame.width) // 2, ch - frame.height))
        numbers[name] = save(canvas, ENEMIES / f"{name}.png")

    # --- Background ---------------------------------------------------------------------------
    far = np.asarray(scaled(Image.open(RAW / "Tranquil Desert Oasis Panorama.png").convert("RGBA"), FAR_SCALE)).astype(np.float32)
    numbers["sky colour"] = [round(c / 255, 3) for c in far[:40, :, :3].reshape(-1, 3).mean(axis=0)]
    far = crossfade_wrap(far, 80)
    far[:80, :, 3] *= np.linspace(0.0, 1.0, 80)[:, None]
    far[-2:, :, 3] = 0
    numbers["bg_far"] = save(far, BACK / "bg_far.png")

    mid = key_out(load("Cartoon Desert Oasis Panorama.png"))
    mid = np.asarray(scaled(to_image(mid), MID_SCALE)).astype(np.float32)
    mid = crossfade_wrap(mid, 90)   # also smooths the frond that was cut where the picture repeats
    colour, amount = MID_HAZE
    mid[..., :3] = mid[..., :3] * (1.0 - amount) + colour * amount
    mid[:12, :, 3] = 0
    ground = mid[-6:, :, :3].reshape(-1, 3)
    ground = ground[mid[-6:, :, 3].reshape(-1) > 200].mean(axis=0)
    below = np.zeros((BELOW_ROWS, mid.shape[1], 4), np.float32)
    below[..., :3] = ground * np.linspace(0.95, 0.75, BELOW_ROWS)[:, None, None]   # sand, a little darker deeper
    below[..., 3] = 255
    mid = np.concatenate([mid, below], axis=0)
    mid[-2:, :, 3] = 0
    numbers["bg_mid"] = save(mid, BACK / "bg_mid.png")

    for k, v in numbers.items():
        print(f"  {k}: {v}")


if __name__ == "__main__":
    main()
