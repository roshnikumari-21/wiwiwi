"""Cut single sprites (buttons, icons, props) from concept sheets.

Each recipe: sheet name -> (output folder, names in reading order; None = skip that piece).
Run:  python tools/art_pipeline/cut_pieces.py
"""
from pipeline import ART, cut, find_sprites, load, remove_background, to_image

RECIPES = {
    "Pastel Kawaii Game Control Buttons.png": (
        ART / "ui" / "touch",
        ["btn_left", "btn_right", "btn_jump", "btn_left_pressed", "btn_right_pressed", "btn_jump_pressed"],
    ),
}


def main():
    for sheet, (out_dir, names) in RECIPES.items():
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


if __name__ == "__main__":
    main()
