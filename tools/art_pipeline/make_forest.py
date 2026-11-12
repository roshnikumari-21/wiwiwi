"""Build the World 3 "Whispering Forest" kit from the owners' concept art, at in-game pixel size.

Ground (assets/art/tiles/forest, same pieces as the meadow and town kits):
  top    - moss, clover and flowers + the first earth, repeats left-right along the strip's surface
  fill   - forest earth that repeats in every direction (darkening evened out, top and bottom
           cross-faded so it stacks without a seam)
  caps   - left/right ends with moss hanging over the edge
  thin   - left / middle / right of the rope-tied wooden walkway (one-way platforms)
  branch - the mossy branch, a one-way ledge up in the trees (used by the level builder)
  decos  - fern, flowers, brown mushrooms, mossy rock, berry bush, dandelion, leaf pile
           (+ the signpost, kept for level starts, not scattered)
Objects (assets/art/objects): log raft (the forest's moving platform), bump crate (full / used),
hedgehog (walk A / B, angry + its "!" burst), pinecone (hanging, falling, landed).
Background (assets/art/backgrounds/forest):
  far    - sunbeams, canopy and hazy trees (top fades into the plain sky colour)
  mid    - big mossy trees, white gaps cut away, a light haze so they stay behind the play,
           grass colour continued below, darkening

Run:  python tools/art_pipeline/make_forest.py   (prints the numbers the game uses)
"""
import numpy as np
from PIL import Image

from make_background import crossfade_wrap
from make_ground import fade, grass_bottom, scaled, solid_top
from make_town import even_rows, save
from pipeline import ART, RAW, cut, find_sprites, load, remove_background, to_image

TILES = ART / "tiles" / "forest"
OBJECTS = ART / "objects"
ENEMIES = ART / "enemies" / "hedgehog"
BACK = ART / "backgrounds" / "forest"

GROUND_SCALE = 0.22     # top tile art -> game px (moss band ~28 px, earth below)
TOP_CROP_BOTTOM = 600   # keep the moss and the first earth
FADE_ROWS = 30          # game px: the top tile's bottom melts into the earth fill behind it
FILL_ROWS = (420, 1254) # earth rows used for the fill (raw)
FILL_WRAP = 80          # raw px cross-faded top <-> bottom so the fill stacks
FILL_SHADE = 0.9        # the earth a little darker than the moss top, so the cat stands out
CAP_KEEP = 45           # game px of cap earth kept below its moss before fading (the fill continues)
CAP_INNER_FADE = 24
THIN_SCALE = 0.28       # walkway ~46 px tall
BRANCH_SCALE = 0.3      # mossy branch ~400 px long
PLANK_WIDTH = 290       # game px of logs (like the meadow and town planks; collision 270)
CRATE_SIZE = 110        # game px: a bump crate is a bit smaller than a ground step
HOG_SCALE = 0.22        # hedgehog ~120 px wide, about a slime's size
CONE_SCALE = 0.17       # pinecone ~55 px wide
DECO_SCALE = 0.3
FAR_SCALE = 1.45
MID_SCALE = 1.0       # the trees are drawn big: at 1.3 a trunk filled half the screen
MID_HAZE = (np.array([206.0, 226.0, 196.0]), 0.22)   # colour and strength mixed into the trees layer
BELOW_ROWS = 700


def measure_logs(piece):
    """Left/right x of the logs (a row below the moss) and the walkable top row."""
    top = solid_top(piece)
    row = np.flatnonzero(piece[top + 60, :, 3] > 128)
    return top, row[0], row[-1]


def main():
    for folder in (TILES, ENEMIES, BACK):
        folder.mkdir(parents=True, exist_ok=True)
    numbers = {}

    # --- Ground -------------------------------------------------------------------------------
    raw = np.asarray(Image.open(RAW / "Mossy Meadow Underground Cross-Section.png").convert("RGBA")).astype(np.float32)
    strip = remove_background(raw[:TOP_CROP_BOTTOM].copy())
    surface, moss_end = solid_top(strip), grass_bottom(strip)
    top = np.asarray(scaled(to_image(strip), GROUND_SCALE)).copy()
    top[-FADE_ROWS:, :, 3] = (top[-FADE_ROWS:, :, 3] * np.linspace(1.0, 0.0, FADE_ROWS)[:, None]).astype(np.uint8)
    numbers["top"] = save(top, TILES / "ground_top.png")
    numbers["TOP_SURFACE"] = round(surface * GROUND_SCALE)

    fill = even_rows(raw[FILL_ROWS[0]:FILL_ROWS[1]].copy())
    fill = crossfade_wrap(fill.transpose(1, 0, 2), FILL_WRAP).transpose(1, 0, 2)
    fill[..., :3] *= FILL_SHADE
    numbers["fill"] = save(scaled(to_image(fill), GROUND_SCALE), TILES / "ground_fill.png")

    sheet = remove_background(load("Cute Forest Platform Asset Sheet.png"))
    boxes = find_sprites(sheet)
    caps = sorted([b for b in boxes if (b[3] - b[1]) > 300], key=lambda b: b[0])
    branch_box, walk_box = sorted([b for b in boxes if (b[3] - b[1]) <= 300], key=lambda b: b[1])
    # The caps are drawn bigger: scale them so their moss band matches the tile's.
    cap_scale = None
    for box, name in zip(caps, ["ground_cap_left", "ground_cap_right"]):
        piece = cut(sheet, box)
        cap_top, cap_moss = solid_top(piece), grass_bottom(piece)
        cap_scale = cap_scale or GROUND_SCALE * (moss_end - surface) / (cap_moss - cap_top)
        row = piece[int(piece.shape[0] * 0.8), :, 3] > 128
        cols = np.flatnonzero(row)
        side = cols[0] if name.endswith("left") else piece.shape[1] - 1 - cols[-1]
        out = scaled(to_image(piece), cap_scale)
        out = fade(out, rows=(round(cap_moss * cap_scale) + CAP_KEEP, 24), cols=CAP_INNER_FADE,
                   from_left=name.endswith("left"))
        numbers[name] = {"size": save(out, TILES / f"{name}.png"), "surface": round(cap_top * cap_scale),
                         "side_inset": round(side * cap_scale)}

    walk = cut(sheet, walk_box)
    w = walk.shape[1]
    parts = {"thin_left": walk[:, : int(w * 0.3)], "thin_mid": walk[:, int(w * 0.3): int(w * 0.7)],
             "thin_right": walk[:, int(w * 0.7):]}
    for name, part in parts.items():
        out = scaled(to_image(part), THIN_SCALE)
        numbers[name] = {"size": save(out, TILES / f"{name}.png"), "surface": round(solid_top(part) * THIN_SCALE)}
    branch = cut(sheet, branch_box)
    numbers["branch"] = {"size": save(scaled(to_image(branch), BRANCH_SCALE), TILES / "branch.png"),
                         "surface": round(solid_top(branch[:, int(branch.shape[1] * 0.2): int(branch.shape[1] * 0.8)]) * BRANCH_SCALE)}

    decos = remove_background(load("Chibi Forest Decoration Set.png"))
    names = ["deco_fern", "deco_flowers", "deco_mushrooms", "deco_rock",
             "deco_berries", "signpost", "deco_dandelion", "deco_leaves"]
    for box, name in zip(find_sprites(decos, min_area=1500), names):   # reading order: 2 rows of 4
        numbers[name] = save(scaled(to_image(cut(decos, box)), DECO_SCALE), TILES / f"{name}.png")

    # --- Objects ------------------------------------------------------------------------------
    art = remove_background(load("Mossy Forest Log Raft.png"))
    raft = cut(art, max(find_sprites(art), key=lambda b: (b[2] - b[0]) * (b[3] - b[1])))
    raft_top, left, right = measure_logs(raft)
    s = PLANK_WIDTH / (right - left)
    numbers["raft"] = {"size": save(scaled(to_image(raft), s), OBJECTS / "platform_moving_forest.png"),
                       "surface": round(raft_top * s), "logs_centre_x": round((left + right) / 2 * s)}

    crates = remove_background(load("Mossy Wooden Crates_ Paw-Emblazoned and Plain.png"))
    for box, name in zip(sorted(find_sprites(crates), key=lambda b: b[0]), ["crate_full", "crate_used"]):
        piece = cut(crates, box)
        s = CRATE_SIZE / piece.shape[1]
        numbers[name] = save(scaled(to_image(piece), s), OBJECTS / f"{name}.png")

    hogs = remove_background(load("Chibi Hedgehog Walking and Alert.png"))
    found = find_sprites(hogs, min_area=1500)
    bodies = sorted([b for b in found if (b[2] - b[0]) > 300], key=lambda b: b[0])
    burst = [b for b in found if (b[2] - b[0]) <= 300]
    feet = max(b[3] for b in bodies)   # the frames share one ground line
    frames = [scaled(to_image(hogs[box[1]:feet, box[0]:box[2]]), HOG_SCALE) for box in bodies]
    # One canvas size for all three, feet on its bottom edge, body centred: they swap without jumping.
    cw, ch = max(f.width for f in frames), max(f.height for f in frames)
    for frame, name in zip(frames, ["hog_walk_0", "hog_walk_1", "hog_angry"]):
        canvas = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
        canvas.paste(frame, ((cw - frame.width) // 2, ch - frame.height))
        numbers[name] = save(canvas, ENEMIES / f"{name}.png")
    if burst:   # the "!" lines are three pieces: keep them together as one picture
        x0, y0 = min(b[0] for b in burst), min(b[1] for b in burst)
        x1, y1 = max(b[2] for b in burst), max(b[3] for b in burst)
        numbers["hog_alert"] = save(scaled(to_image(hogs[y0:y1, x0:x1]), HOG_SCALE), ENEMIES / "hog_alert.png")

    cones = remove_background(load("Cute Pinecone Life Cycle Trio.png"))
    parts = find_sprites(cones, min_area=800)
    big = sorted([b for b in parts if (b[2] - b[0]) * (b[3] - b[1]) > 60000], key=lambda b: b[0])
    for box, name in zip(big, ["cone_hanging", "cone_falling", "cone_landed"]):
        numbers[name] = save(scaled(to_image(cut(cones, box)), CONE_SCALE), OBJECTS / f"{name}.png")

    # --- Background ---------------------------------------------------------------------------
    far = np.asarray(scaled(Image.open(RAW / "Dreamy Misty Forest Canopy.png").convert("RGBA"), FAR_SCALE)).astype(np.float32)
    band = far[:80, :, :3].reshape(-1, 3)
    sky = band[(band[:, 2] > band[:, 1] + 20) & (band[:, 2] > 200)].mean(axis=0)   # the blue between the leaves
    numbers["sky colour"] = [round(c / 255, 3) for c in sky]
    far = crossfade_wrap(far, 80)
    far[:80, :, 3] *= np.linspace(0.0, 1.0, 80)[:, None]   # top edge fades into the plain sky colour
    far[-2:, :, 3] = 0
    numbers["bg_far"] = save(far, BACK / "bg_far.png")

    # The gaps between the trees are closed in by the canopy, so they are cleared as enclosed holes too.
    mid = remove_background(load("Whimsical Sunlit Forest Strip.png"), hole_min_area=3000)
    mid = np.asarray(scaled(to_image(mid), MID_SCALE)).astype(np.float32)
    mid = crossfade_wrap(mid, 60)
    colour, amount = MID_HAZE
    mid[..., :3] = mid[..., :3] * (1.0 - amount) + colour * amount
    mid[:90, :, 3] *= np.linspace(0.0, 1.0, 90)[:, None]   # the cut-off canopy fades out at the top
    grass = mid[-6:, :, :3].reshape(-1, 3)
    grass = grass[mid[-6:, :, 3].reshape(-1) > 200].mean(axis=0)
    below = np.zeros((BELOW_ROWS, mid.shape[1], 4), np.float32)
    below[..., :3] = grass * np.linspace(0.85, 0.6, BELOW_ROWS)[:, None, None]   # darker the deeper you look
    below[..., 3] = 255
    mid = np.concatenate([mid, below], axis=0)
    mid[-2:, :, 3] = 0
    numbers["bg_mid"] = save(mid, BACK / "bg_mid.png")

    for k, v in numbers.items():
        print(f"  {k}: {v}")


if __name__ == "__main__":
    main()
