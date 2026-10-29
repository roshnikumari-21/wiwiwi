"""Cut single sprites (buttons, icons, props) from concept sheets.

Each recipe: sheet -> (output folder, names in reading order (None = skip), centre_in_cell).
centre_in_cell=True puts every piece on one same-size canvas, centred (for spin animations like the coin).
Run:  python tools/art_pipeline/cut_pieces.py
"""
from PIL import Image

from pipeline import ART, cut, find_sprites, load, remove_background, to_image

RECIPES = {
    "Pastel Kawaii Game Control Buttons.png": (
        ART / "ui" / "touch",
        ["btn_left", "btn_right", "btn_jump", "btn_left_pressed", "btn_right_pressed", "btn_jump_pressed"],
        False,
    ),
    "Cute Chibi Game Icon Spritesheet.png": (
        ART / "objects",
        ["coin_0", "coin_1", "coin_2", "coin_3", "coin_4",
         "milk_bowl_full", "milk_bowl_empty", "heart_full", "heart_empty", "star_full", "star_empty"],
        False,
    ),
    "Magical Golden Yarn Ball Icons.png": (ART / "objects", ["yarn", "yarn_glow"], False),
    "Cute Cat Platformer Asset Sprite Sheet.png": (
        ART / "objects",
        ["spikes", "flag_off", "flag_on", "cat_bed", "floating_island", "signpost"],
        False,
    ),
}

# Pieces that animate together: centred on one canvas so they don't jump between frames.
CENTRED_GROUPS = {ART / "objects": [["coin_0", "coin_1", "coin_2", "coin_3", "coin_4"]]}


def main():
    for sheet, (out_dir, names, _) in RECIPES.items():
        img = remove_background(load(sheet))
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
        for group in groups:
            ims = [Image.open(out_dir / f"{n}.png") for n in group]
            w, h = max(i.width for i in ims), max(i.height for i in ims)
            for n, im in zip(group, ims):
                canvas = Image.new("RGBA", (w, h), (0, 0, 0, 0))
                canvas.alpha_composite(im, ((w - im.width) // 2, (h - im.height) // 2))
                canvas.save(out_dir / f"{n}.png", optimize=True)
            print(f"  centred {group[0]}..{group[-1]} on {w}x{h}")


if __name__ == "__main__":
    main()
