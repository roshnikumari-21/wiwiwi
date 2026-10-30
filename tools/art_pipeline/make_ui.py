"""Cut menu UI pieces (buttons, icons, panels) from the UI concept sheets, by grid cells.

Each cell is cropped from the background-removed sheet and trimmed to its art, so a cell's stray
sparkles never become separate pieces. Output: assets/art/ui/menu/.
Run:  python tools/art_pipeline/make_ui.py
"""
import numpy as np

from pipeline import ART, load, remove_background, to_image

OUT = ART / "ui" / "menu"

PILL_COLOURS = ["green", "yellow", "red", "brown"]        # rows of the pill block
PILL_STATES = ["normal", "pressed", "disabled"]          # columns
ROUND_COLOURS = ["brown", "yellow", "red", "grey"]       # columns of the round block
ROUND_KINDS = ["plain", "ring", "paw"]                   # rows
ICONS = [
    ["play", "pause", "settings", "home", "replay", "next"],
    ["sound_on", "sound_off", "music_on", "music_off", "vibrate", "leaderboard"],
    ["trophy", "lock", "star", "coin", "heart", "paw"],
]


def cells(xs, ys):
    for r in range(len(ys) - 1):
        for c in range(len(xs) - 1):
            yield r, c, (xs[c], ys[r], xs[c + 1], ys[r + 1])


def save_cell(img, box, name):
    x0, y0, x1, y1 = box
    piece = img[y0:y1, x0:x1]
    solid = np.argwhere(piece[..., 3] > 20)
    (t, l), (b, r) = solid.min(axis=0), solid.max(axis=0) + 1
    to_image(piece[t:b, l:r]).save(OUT / f"{name}.png", optimize=True)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    sheet = remove_background(load("Cute Cartoon Game UI Asset Sheet.png"))
    for r, c, box in cells([30, 360, 665, 975], [25, 135, 245, 360, 480]):
        save_cell(sheet, box, f"pill_{PILL_COLOURS[r]}_{PILL_STATES[c]}")
    for r, c, box in cells([990, 1150, 1310, 1475, 1650], [45, 200, 345, 500]):
        save_cell(sheet, box, f"round_{ROUND_COLOURS[c]}_{ROUND_KINDS[r]}")
    save_cell(sheet, (35, 485, 875, 895), "panel_leafy")
    save_cell(sheet, (880, 505, 1645, 712), "sign_wood")
    save_cell(sheet, (895, 712, 1625, 895), "ribbon")

    icons = remove_background(load("Cute Cartoon Game UI Icon Sheet.png"))
    for r, c, box in cells([20, 300, 590, 875, 1170, 1460, 1765], [45, 320, 570, 845]):
        save_cell(icons, box, f"icon_{ICONS[r][c]}")
    print("  cut", len(list(OUT.glob("*.png"))), "pieces")


if __name__ == "__main__":
    main()
