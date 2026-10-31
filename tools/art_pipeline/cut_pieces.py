"""Cut single sprites (buttons, icons, props) from concept sheets.

Each recipe: sheet -> (output folder, names in reading order (None = skip), hole_min_area).
hole_min_area: also clear trapped white background patches at least this big (None = off).
Run:  python tools/art_pipeline/cut_pieces.py
"""
import numpy as np
from PIL import Image

from pipeline import ART, cut, find_sprites, load, remove_background, to_image

RECIPES = {
    "Pastel Kawaii Game Control Buttons.png": (
        ART / "ui" / "touch",
        ["btn_left", "btn_right", "btn_jump", "btn_left_pressed", "btn_right_pressed", "btn_jump_pressed"],
        None,
    ),
    "Cute Chibi Game Icon Spritesheet.png": (
        ART / "objects",
        ["coin_0", "coin_1", "coin_2", "coin_3", "coin_4",
         "milk_bowl_full", "milk_bowl_empty", "heart_full", "heart_empty", "star_full", "star_empty"],
        None,
    ),
    "Magical Golden Yarn Ball Icons.png": (ART / "objects", ["yarn", "yarn_glow"], None),
    "Cute Cat Platformer Asset Sprite Sheet.png": (
        ART / "objects",
        [None, "flag_off", "flag_on", "cat_bed", "floating_island", "signpost"],   # old spikes: replaced by the spike trap sheet
        None,
    ),
    "Cute Red Mushroom Sprite Pair.png": (ART / "objects", ["mushroom", "mushroom_squash"], None),
    "Cartoon Grass-Topped Wooden Platform.png": (ART / "objects", ["platform_moving"], None),
    "Cartoon Spike Trap Platforms.png": (ART / "objects", ["spikes_short", "spikes_long"], None),
    # World 1 slime (green row); the orange row is kept in the sheet for later.
    "Kawaii Slime Sprite Sheet.png": (
        ART / "enemies" / "slime",
        ["slime_idle", "slime_move_0", "slime_move_1", "slime_squash", None, None, None, None],
        None,
    ),
    # Girl at the level goal: wait -> crouch -> kneel reaching -> kneel arms wide, then the hug loop.
    "Chibi Girl Hugging Animation Sprites.png": (
        ART / "characters" / "girl",
        ["girl_wait", "girl_crouch", "girl_kneel_reach", "girl_kneel_open"],
        150,
    ),
    "Three-Frame Chibi Cat Hug Stickers.png": (
        ART / "characters" / "girl",
        ["girl_hug_0", "girl_hug_1", "girl_hug_2"],
        150,
    ),
}

# Pieces cut far bigger than they ever appear in the game: shrunk to this width (px) to keep the
# app small. Their scenes use a matching bigger scale (yarn_glow 0.5, platform_moving 0.5).
SHRINK = {ART / "objects": {"yarn_glow": 236, "platform_moving": 604, "yarn": 200,
                            "mushroom": 360, "mushroom_squash": 385}}   # 723:773 kept

# Pieces that animate together: put on one same-size canvas so they don't jump between frames.
# "centre" = middle of the canvas (spinning coin); "feet" = bottom-centre (poses swapped on the ground);
# "shoe" = bottom of the canvas, her right shoe on the centre line (it stays planted while she kneels);
# "shoe_match" = first piece like "shoe", the others shifted to best overlap it (AI frames are drawn
#           a few pixels apart; this stops the body jiggling between frames).
# Optional 3rd value = resize factor, to bring a sheet drawn bigger to the same size as the others.
CENTRED_GROUPS = {
    ART / "objects": [(["coin_0", "coin_1", "coin_2", "coin_3", "coin_4"], "centre"),
                      (["mushroom", "mushroom_squash"], "feet")],
    ART / "enemies" / "slime": [(["slime_idle", "slime_move_0", "slime_move_1", "slime_squash"], "feet")],
    ART / "characters" / "girl": [
        (["girl_wait", "girl_crouch", "girl_kneel_reach", "girl_kneel_open"], "shoe"),
        # The hug sheet is drawn bigger: kneeling height 664 px vs 509 px in the kneel-down sheet.
        (["girl_hug_0", "girl_hug_1", "girl_hug_2"], "shoe_match", 509 / 664),
    ],
}


def shoe_x(im: Image.Image) -> int:
    """x of the right-most solid pixel near the bottom: the front shoe."""
    a = np.asarray(im)[..., 3]
    rows = a[int(a.shape[0] * 0.88):] > 128
    return int(np.flatnonzero(rows.any(axis=0)).max())


def best_offset(ref: np.ndarray, im: np.ndarray, start, search=30):
    """Shift (x, y) that makes `im` overlap `ref` best, judged on the lower-right body
    (dress, legs): the cat's head and tail are the parts meant to move."""
    h, w = ref.shape[:2]
    region = (slice(h // 2, h), slice(w * 2 // 5, w))
    target = ref[region].astype(np.float32)
    best, best_err = start, None
    for dy in range(-search, search + 1, 2):
        for dx in range(-search, search + 1, 2):
            x, y = start[0] + dx, start[1] + dy
            canvas = Image.new("RGBA", (w, h), (0, 0, 0, 0))
            canvas.alpha_composite(Image.fromarray(im), (max(x, 0), max(y, 0)))
            err = np.abs(np.asarray(canvas)[region].astype(np.float32) - target).mean()
            if best_err is None or err < best_err:
                best, best_err = (x, y), err
    return best


def main():
    for sheet, (out_dir, names, hole_min_area) in RECIPES.items():
        img = remove_background(load(sheet), hole_min_area=hole_min_area)
        boxes = find_sprites(img)
        if len(boxes) != len(names):
            raise SystemExit(f"{sheet}: found {len(boxes)} pieces, recipe lists {len(names)}")
        out_dir.mkdir(parents=True, exist_ok=True)
        for box, name in zip(boxes, names):
            if name:
                piece = to_image(cut(img, box))
                piece.save(out_dir / f"{name}.png", optimize=True)
                print(f"  {name}: {piece.width}x{piece.height}")

    for out_dir, pieces in SHRINK.items():
        for name, width in pieces.items():
            im = Image.open(out_dir / f"{name}.png")
            im = im.resize((width, round(im.height * width / im.width)), Image.LANCZOS)
            im.save(out_dir / f"{name}.png", optimize=True)
            print(f"  shrunk {name} to {im.width}x{im.height}")

    for out_dir, groups in CENTRED_GROUPS.items():
        for group, anchor, *resize in groups:
            ims = [Image.open(out_dir / f"{n}.png") for n in group]
            if resize:
                ims = [i.resize((round(i.width * resize[0]), round(i.height * resize[0])), Image.LANCZOS) for i in ims]
            if anchor.startswith("shoe"):
                shoes = [shoe_x(i) for i in ims]
                half = max(max(s, i.width - s) for s, i in zip(shoes, ims)) + 20
                w, h = 2 * half, max(i.height for i in ims) + 20
            else:
                w, h = max(i.width for i in ims), max(i.height for i in ims)
            ref = None
            for k, (n, im) in enumerate(zip(group, ims)):
                canvas = Image.new("RGBA", (w, h), (0, 0, 0, 0))
                if anchor == "centre":
                    x, y = (w - im.width) // 2, (h - im.height) // 2
                elif anchor == "feet":
                    x, y = (w - im.width) // 2, h - im.height
                else:  # shoe / shoe_match
                    x, y = w // 2 - shoes[k], h - im.height - 10
                    if anchor == "shoe_match" and ref is not None:
                        x, y = best_offset(ref, np.asarray(im), (x, y), search=16)
                canvas.alpha_composite(im, (x, y))
                if ref is None:
                    ref = np.asarray(canvas)
                canvas.save(out_dir / f"{n}.png", optimize=True)
            print(f"  aligned {group[0]}..{group[-1]} ({anchor}) on {w}x{h}")

if __name__ == "__main__":
    main()
