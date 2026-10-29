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
        ["spikes", "flag_off", "flag_on", "cat_bed", "floating_island", "signpost"],
        None,
    ),
    "Kawaii Girl and Cat Pose Sheet.png": (
        ART / "characters" / "girl",
        ["girl_idle", "girl_side", "girl_arms_open", None],   # old hug replaced by the hug sheet below
        150,
    ),
    "Chibi Girl and Cat Hug Sprite Sheet.png": (
        ART / "characters" / "girl",
        ["girl_kneel_open", "girl_hug_0", "girl_hug_1", "girl_hug_2", None],  # None = the kitten (game has her)
        150,
    ),
}

# Pieces that animate together: put on one same-size canvas so they don't jump between frames.
# "centre" = middle of the canvas (spinning coin); "feet" = bottom-centre (poses swapped on the ground);
# "match" = first piece bottom-right, the others shifted to best overlap it (AI frames are drawn
#           a few pixels apart; this stops the body jiggling between frames).
CENTRED_GROUPS = {
    ART / "objects": [(["coin_0", "coin_1", "coin_2", "coin_3", "coin_4"], "centre")],
    ART / "characters" / "girl": [
        (["girl_idle", "girl_side", "girl_arms_open"], "feet"),
        (["girl_kneel_open"], "feet"),
        (["girl_hug_0", "girl_hug_1", "girl_hug_2"], "match"),
    ],
}


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

    for out_dir, groups in CENTRED_GROUPS.items():
        for group, anchor in groups:
            ims = [Image.open(out_dir / f"{n}.png") for n in group]
            w, h = max(i.width for i in ims), max(i.height for i in ims)
            if anchor == "match":
                w, h = w + 40, h + 40   # room to shift
            ref = None
            for n, im in zip(group, ims):
                canvas = Image.new("RGBA", (w, h), (0, 0, 0, 0))
                y = (h - im.height) // 2 if anchor == "centre" else h - im.height - (20 if anchor == "match" else 0)
                x = w - im.width - 20 if anchor == "match" else (w - im.width) // 2
                if anchor == "match" and ref is not None:
                    x, y = best_offset(ref, np.asarray(im), (x, y))
                canvas.alpha_composite(im, (x, y))
                if ref is None:
                    ref = np.asarray(canvas)
                canvas.save(out_dir / f"{n}.png", optimize=True)
            print(f"  centred {group[0]}..{group[-1]} on {w}x{h}")


if __name__ == "__main__":
    main()
