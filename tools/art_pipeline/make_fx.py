"""Cut the one-shot effects (5 frames each) from the effects sheet by its grid.

Every frame of an effect is cut from the same-size cell, so the animation never jumps.
The sheet's red checkpoint-flag row is skipped: it doesn't match our flag (the star burst is used).
Run:  python tools/art_pipeline/make_fx.py
"""
from pipeline import ART, load, remove_background, to_image

SHEET = "Cute Chibi Game Effects Sprite Sheet.png"
OUT = ART / "fx"
COLUMNS = [100, 395, 650, 905, 1140, 1400]          # x edges of the 5 frames
ROWS = {                                             # name: (top, bottom) of each effect row
    "dust": (20, 167),
    "coin": (193, 340),
    "stars": (355, 497),
    "heart": (529, 657),
    "confetti": (857, 1004),
}


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    img = remove_background(load(SHEET))
    for name, (top, bottom) in ROWS.items():
        for i in range(5):
            frame = to_image(img[top:bottom, COLUMNS[i]:COLUMNS[i + 1]])
            frame.save(OUT / f"fx_{name}_{i}.png", optimize=True)
        print(f"  fx_{name}_0..4: {COLUMNS[1] - COLUMNS[0]}x{bottom - top} (cell)")


if __name__ == "__main__":
    main()
