"""Home page pieces from the owner's art (31 Oct 2026): porch background, cushion, the lying
kitten (+ a blink frame), the sign-only logo and the floral buttons.

The blink: the two kitten drawings differ slightly in pose, so swapping whole frames would make her
twitch (see plan.md: never loop separately drawn AI frames for still poses). Instead only the eyes,
nose and mouth of the eyes-closed drawing are pasted onto the open one, with soft edges.
Run:  python tools/art_pipeline/make_home.py
"""
import numpy as np
from PIL import Image

from pipeline import ART, RAW

OUT = ART / "ui" / "home"

# Pieces as (left, top, right, bottom) in their sheets.
KITTEN_OPEN = (76, 22, 965, 709)
KITTEN_CLOSED = (1177, 22, 2066, 709)       # shifted 2 px left to line up with the open one
FACE_PATCHES = [(510, 368, 92, 80), (745, 300, 82, 74), (640, 405, 76, 68)]   # eyes, nose + mouth
BUTTONS = {"play_btn": (33, 242, 697, 491), "play_btn_pressed": (720, 241, 1377, 491),
           "round_btn": (1435, 237, 1729, 505), "round_btn_pressed": (1818, 237, 2114, 505)}


def rgba(name: str) -> np.ndarray:
    return np.asarray(Image.open(RAW / name).convert("RGBA")).astype(np.float32)


def save(a: np.ndarray, name: str, width: int | None = None):
    img = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))
    if width:
        img = img.resize((width, round(img.height * width / img.width)), Image.LANCZOS)
    img.save(OUT / f"{name}.png", optimize=True)
    print(f"  {name}: {img.width}x{img.height}")


def crop(a: np.ndarray, box) -> np.ndarray:
    x0, y0, x1, y1 = box
    piece = a[y0:y1, x0:x1].copy()
    piece[piece[..., 3] < 8] = 0           # clear colour hidden under transparent pixels
    return piece


def trim(a: np.ndarray) -> np.ndarray:
    solid = np.argwhere(a[..., 3] > 8)
    (t, l), (b, r) = solid.min(axis=0), solid.max(axis=0) + 1
    return a[t:b, l:r]


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    bg = Image.open(RAW / "Sunny Countryside Veranda Retreat.png").convert("RGB")
    bg.save(OUT / "porch.png", optimize=True)
    print(f"  porch: {bg.width}x{bg.height}")

    save(trim(crop(rgba("Cute Coral Paw-Print Pet Cushion.png"), (0, 0, 1774, 887))), "cushion", 600)
    save(trim(crop(rgba("Whimsical Wiwiwi Woodland Logo.png"), (0, 0, 1774, 887))), "logo_sign", 1000)

    kittens = rgba("Matching Chibi Kittens with Bells.png")
    open_ = crop(kittens, KITTEN_OPEN)
    closed = crop(kittens, KITTEN_CLOSED)
    h, w = open_.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w]
    weight = np.zeros((h, w))
    for cx, cy, rx, ry in FACE_PATCHES:
        d = ((xx - cx) / rx) ** 2 + ((yy - cy) / ry) ** 2
        weight = np.maximum(weight, np.clip((1.2 - d) / 0.35, 0.0, 1.0))
    blink = open_ * (1 - weight[..., None]) + closed * weight[..., None]
    blink[..., 3] = open_[..., 3]
    save(open_, "kitten_lying", 440)
    save(blink, "kitten_lying_blink", 440)

    sheet = rgba("Glossy Floral Game Button Asset Sheet.png")
    for name, box in BUTTONS.items():
        save(trim(crop(sheet, box)), name, 600 if name.startswith("play") else 270)


if __name__ == "__main__":
    main()
