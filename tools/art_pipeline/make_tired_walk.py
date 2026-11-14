"""Tired walk frames: the six walking drawings (cat_A3..A8) wearing the sleepy face of cat_S0, so the
tired cat really walks (same legs, same bounce) and only her expression changes (owners, 14 Nov 2026:
"cut the face and paste the exact sleepy tired face on the walking cat").

Feature by feature, so no patch edges show:
  1. the walking face's eyes and open mouth are painted out with the face colour (inpainting),
  2. the sleepy near eye, far eye and little frown are cut out of cat_S0 (just their drawn lines,
     filled, softly edged) and put where the walking face's eyes and mouth were.
Writes assets/art/characters/cat/cat_T3.png .. cat_T8.png.
Run:  python tools/art_pipeline/make_tired_walk.py
"""
from pathlib import Path

import cv2
import numpy as np
from PIL import Image
from scipy import ndimage

CAT = Path(__file__).resolve().parents[2] / "assets" / "art" / "characters" / "cat"
WALK = ["A3", "A4", "A5", "A6", "A7", "A8"]
SLEEPY = "S0"
# cat_S0.png features (measured): a box around each, and a point inside its drawn lines
S_NEAR_EYE = ((204, 157, 244, 188), (224, 174))
S_FAR_EYE = ((263, 151, 289, 178), (276, 165))
S_FROWN = ((249, 175, 270, 189), (259, 182))
# where the frown goes on a walking face: relative to its far eye (as in cat_S0)
FROWN_FROM_FAR_EYE = (S_FROWN[1][0] - S_FAR_EYE[1][0], S_FROWN[1][1] - S_FAR_EYE[1][1])


def lum(a):
    return a[..., 0] * 0.3 + a[..., 1] * 0.59 + a[..., 2] * 0.11


def walking_features(a):
    """The walking face's eyes (biggest dark blobs, near one first) and its open mouth, as masks."""
    dark = (lum(a) < 70) & (a[..., 3] > 200)
    dark[:, :190] = False
    dark[190:, :] = False
    lab, n = ndimage.label(dark)
    sizes = ndimage.sum(dark, lab, range(1, n + 1))
    order = np.argsort(sizes)[::-1][:2] + 1
    eyes = sorted([lab == i for i in order], key=lambda m: ndimage.center_of_mass(m)[1])   # near (left) first
    centres = [tuple(round(v) for v in ndimage.center_of_mass(m))[::-1] for m in eyes]
    # each eye with its brown rim: grow into the darker pixels around it
    rims = []
    for m in eyes:
        grown = ndimage.binary_dilation(m, iterations=6) & (lum(a) < 200)
        rims.append(ndimage.binary_dilation(grown, iterations=2))
    # the open mouth: reddish / dark pixels below the eyes, between them and a bit to the right
    nx = (centres[0][0] + centres[1][0]) // 2 + 8
    ny = max(centres[0][1], centres[1][1]) + 8
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    box = np.zeros(dark.shape, bool)
    box[ny:ny + 26, nx - 22:nx + 18] = True
    mouthy = box & (((r - g) > 60) | (lum(a) < 150)) & (a[..., 3] > 200)
    mouth = ndimage.binary_dilation(mouthy, iterations=2) & box
    # never touch the face's outline (dark pixels near the see-through edge): it stays as drawn
    near_edge = ndimage.binary_dilation(a[..., 3] < 128, iterations=9)
    return centres, (rims[0] | rims[1] | mouth) & ~near_edge


def sleepy_feature(s, box_and_seed):
    """One sleepy feature: its drawn pixels connected to the seed point, holes filled, softly edged."""
    (x0, y0, x1, y1), (sx, sy) = box_and_seed
    sub = s[y0:y1, x0:x1]
    ink = (lum(sub) < 185) & (sub[..., 3] > 200)
    lab, _ = ndimage.label(ink)
    keep = lab == lab[sy - y0, sx - x0]
    keep = ndimage.binary_fill_holes(ndimage.binary_dilation(keep, iterations=1))
    alpha = ndimage.gaussian_filter(keep.astype(float), 0.6)
    return sub, alpha, (sx - x0, sy - y0)


def place(out, sub, alpha, anchor, at):
    x0, y0 = at[0] - anchor[0], at[1] - anchor[1]
    h, w = alpha.shape
    region = out[y0:y0 + h, x0:x0 + w, :3].astype(float)
    a = alpha[..., None]
    out[y0:y0 + h, x0:x0 + w, :3] = (region * (1 - a) + sub[..., :3] * a).round().astype(np.uint8)


def main():
    s = np.array(Image.open(CAT / f"cat_{SLEEPY}.png").convert("RGBA"))
    near = sleepy_feature(s, S_NEAR_EYE)
    far = sleepy_feature(s, S_FAR_EYE)
    frown = sleepy_feature(s, S_FROWN)
    for name in WALK:
        a = np.array(Image.open(CAT / f"cat_{name}.png").convert("RGBA"))
        (near_c, far_c), erase = walking_features(a)
        rgb = cv2.inpaint(np.ascontiguousarray(a[..., :3]), erase.astype(np.uint8) * 255, 6, cv2.INPAINT_TELEA)
        out = a.copy()
        out[..., :3] = rgb
        place(out, *near, (near_c[0], near_c[1] + 2))
        place(out, *far, (far_c[0] + 1, far_c[1] + 2))
        place(out, *frown, (far_c[0] + FROWN_FROM_FAR_EYE[0], far_c[1] + FROWN_FROM_FAR_EYE[1] + 2))
        Image.fromarray(out).save(CAT / f"cat_T{name[1:]}.png")
        print(name, "eyes", near_c, far_c)


if __name__ == "__main__":
    main()
