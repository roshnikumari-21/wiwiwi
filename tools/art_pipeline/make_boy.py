"""The boy owner (owners, 20 Nov 2026): the same poses as the girl at the level goal, cut from the two
ChatGPT sheets in assets/raw_assets_idea/ and lined up exactly like the girl's (tools/art_pipeline/cut_pieces.py):

  "Chibi Boy in Blue Dungarees.png"               -> boy_wait, boy_crouch, boy_kneel_reach, boy_kneel_open
  "Chibi Boy and Kitten Cuddle Sprite Sheet.png"  -> boy_hug_0, boy_hug_1, boy_hug_2  (with the ginger kitten)

The hug sheet came with a fake checkerboard painted in (no real transparency): it's light and grey, so the
normal background removal takes it as background like plain white.
Sizes: the boy is scaled to the girl's height (girl_wait), and his hug frames to his own kneeling height,
so he stands exactly where she does. Frames are put on one canvas with his front shoe on the centre line
(it stays planted while he kneels), and the hug frames shifted to overlap the first (no jiggle).

Writes assets/art/characters/boy/*.png and prints the kitten's box in the hug art (for HUG_REGION).
Run:  python tools/art_pipeline/make_boy.py
"""
import numpy as np
from PIL import Image

from cut_pieces import best_offset, shoe_x
from pipeline import ART, cut, find_sprites, load, remove_background, to_image

OUT = ART / "characters" / "boy"
GIRL = ART / "characters" / "girl"
POSES = ["boy_wait", "boy_crouch", "boy_kneel_reach", "boy_kneel_open"]
HUGS = ["boy_hug_0", "boy_hug_1", "boy_hug_2"]


def pieces(sheet: str, names: list[str]) -> list[Image.Image]:
    img = remove_background(load(sheet), hole_min_area=150)
    boxes = find_sprites(img)
    if len(boxes) != len(names):
        raise SystemExit(f"{sheet}: found {len(boxes)} pieces, expected {len(names)}")
    return [to_image(cut(img, b)) for b in boxes]


def content_height(im: Image.Image) -> int:
    box = im.getchannel("A").point(lambda a: 255 if a > 128 else 0).getbbox()
    return box[3] - box[1]


def scaled(ims, factor):
    return [i.resize((round(i.width * factor), round(i.height * factor)), Image.LANCZOS) for i in ims]


def place(ims, names, match: bool):
    """One canvas for the group, his front shoe on the centre line; `match` = shift to overlap the first."""
    shoes = [shoe_x(i) for i in ims]
    half = max(max(s, i.width - s) for s, i in zip(shoes, ims)) + 20
    w, h = 2 * half, max(i.height for i in ims) + 20
    ref = None
    for k, (n, im) in enumerate(zip(names, ims)):
        canvas = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        x, y = w // 2 - shoes[k], h - im.height - 10
        if match and ref is not None:
            x, y = best_offset(ref, np.asarray(im), (x, y), search=16)
        canvas.alpha_composite(im, (x, y))
        if ref is None:
            ref = np.asarray(canvas)
        canvas.save(OUT / f"{n}.png", optimize=True)
    print(f"  {names[0]}..{names[-1]} on {w}x{h}")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    poses = pieces("Chibi Boy in Blue Dungarees.png", POSES)
    hugs = pieces("Chibi Boy and Kitten Cuddle Sprite Sheet.png", HUGS)
    # as tall as the girl standing
    poses = scaled(poses, content_height(Image.open(GIRL / "girl_wait.png")) / content_height(poses[0]))
    # the hug frames at his own kneeling height (kneeling, arms wide = the pose just before the hug)
    hugs = scaled(hugs, content_height(poses[3]) / content_height(hugs[0]))
    place(poses, POSES, match=False)
    place(hugs, HUGS, match=True)
    # where the kitten is in the hug art: orange fur
    a = np.asarray(Image.open(OUT / "boy_hug_0.png").convert("RGBA")).astype(int)
    r, g, b, al = a[..., 0], a[..., 1], a[..., 2], a[..., 3]
    orange = (al > 200) & (r > 200) & (g > 110) & (g < 190) & (b < 110)
    ys, xs = np.nonzero(orange)
    print("  kitten (orange) box in boy_hug_0:", xs.min(), ys.min(), xs.max(), ys.max(), " canvas", a.shape[1], a.shape[0])


if __name__ == "__main__":
    main()
