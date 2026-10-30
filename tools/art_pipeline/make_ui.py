"""Cut menu UI pieces (buttons, icons, panels) from the UI concept sheets, by grid cells.

Each cell is cropped from the background-removed sheet and trimmed to its art, so a cell's stray
sparkles never become separate pieces. Output: assets/art/ui/menu/.
Run:  python tools/art_pipeline/make_ui.py
"""
import numpy as np
from PIL import Image
from scipy import ndimage

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


def save_cell(img, box, name, holes=False, single=False):
    x0, y0, x1, y1 = box
    piece = img[y0:y1, x0:x1].copy()
    if holes:   # clear grey checkerboard trapped inside an outline (e.g. the empty star)
        rgb = piece[..., :3]
        grey = (rgb.max(axis=2) - rgb.min(axis=2) <= 6) & (rgb.max(axis=2) >= 100) & (rgb.max(axis=2) <= 225)
        labels, n = ndimage.label(grey)
        sizes = ndimage.sum(grey, labels, range(1, n + 1))
        piece[np.isin(labels, np.flatnonzero(sizes > 2000) + 1), 3] = 0
    # single: keep only the biggest piece of art (drops slivers of the neighbouring cell).
    # Not for icons made of separate parts (pause bars, sound waves).
    labels, n = ndimage.label(piece[..., 3] > 20)
    if single and n > 1:
        sizes = ndimage.sum(np.ones_like(labels), labels, range(1, n + 1))
        piece[(labels > 0) & (labels != np.argmax(sizes) + 1), 3] = 0
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

    # This sheet has a painted grey checkerboard (105..215 bright), darker than the usual backgrounds.
    nodes = remove_background(load("Cartoon Level Buttons and Stars.png"), neutral_min=100)
    for box, name in zip([(110, 100, 750, 620), (725, 100, 1360, 640), (1340, 190, 1715, 550), (1715, 190, 2090, 550)],
                         ["level_open", "level_locked", "level_star_full", "level_star_empty"]):
        save_cell(nodes, box, name, holes=True, single=True)

    icons = remove_background(load("Cute Cartoon Game UI Icon Sheet.png"))
    for r, c, box in cells([20, 300, 590, 875, 1170, 1460, 1765], [45, 320, 570, 845]):
        save_cell(icons, box, f"icon_{ICONS[r][c]}")
    # The logo is already transparent (its preview's dark glow is colour data hidden under alpha 0):
    # trim it, clear that hidden colour, and shrink it to a size the home page can use.
    logo = load("Kawaii Cat Wiwiwi Garden Logo.png")
    logo[logo[..., 3] < 8] = 0
    solid = np.argwhere(logo[..., 3] > 8)
    (t, l), (b, r) = solid.min(axis=0), solid.max(axis=0) + 1
    image = to_image(logo[t:b, l:r])
    image = image.resize((900, round(image.height * 900 / image.width)), Image.LANCZOS)
    image.save(OUT / "logo.png", optimize=True)
    print("  cut", len(list(OUT.glob("*.png"))), "pieces")


if __name__ == "__main__":
    main()
