"""Puts the owners' TALLER middle background pictures (painted in ChatGPT, 19 Nov 2026) in the game.

The old mid layers ended in a flat one-colour block that showed as an empty band when the camera rose for
a jump. The owners repainted each one taller, with scenery all the way down. This script fits them:
  1. the black sky (ChatGPT can't do transparency) becomes see-through, with soft edges;
  2. black side borders are trimmed;
  3. the picture is scaled and shifted so its scenery lines up with the OLD picture (found by matching),
     so it sits behind the ground exactly as before;
  4. the left and right edges are cross-faded so it repeats sideways without a seam.

Reads  assets/raw_assets_idea/<ChatGPT file name>.png  and  assets/raw_assets_idea/bg_mid_originals/<world>_bg_mid.png
Writes assets/art/backgrounds/<world>/bg_mid.png, and a check picture per world in the scratch folder given.
Run:  python tools/art_pipeline/fit_bg_mid.py [world ...]
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[2]
RAW = ROOT / "assets" / "raw_assets_idea"
SOURCES = {
    "meadow": "Hand-Painted Meadow Hillside Landscape.png",
    "town": "Cozy Terraced Hillside Town at Dusk.png",
    "forest": "Lush Hand-Painted Forest Understory.png",
    "snow": "Snowy Pine Forest with Berry Bushes.png",
    "sand": "Cartoon Desert Dunes with Cacti.png",
}
DARK = 34          # brighter than this (max channel) is scenery, not the black sky
SOFT = 95          # sky edge pixels up to this brightness fade in (soft edge, no black halo)
SEAM = 260         # px where the right edge overlaps the left one (joined along the best-matching path)


def key_out_sky(rgb: np.ndarray) -> np.ndarray:
    """Alpha: 0 for the black sky (dark pixels connected to the top edge), soft at its edges."""
    br = rgb.max(axis=2)
    dark = br < DARK
    labels, _ = ndimage.label(dark)
    top = set(np.unique(labels[0])) - {0}
    sky = np.isin(labels, list(top))
    # pockets of sky enclosed by scenery (under a tree arch, between branches): pure black blobs
    pure, n = ndimage.label(br < 26)
    sizes = ndimage.sum(np.ones_like(br), pure, range(1, n + 1))
    sky |= np.isin(pure, np.nonzero(sizes > 6)[0] + 1)
    near = ndimage.binary_dilation(sky, iterations=4)
    alpha = np.full(br.shape, 255.0)
    edge = near & ~sky
    alpha[edge] = np.clip((br[edge] - DARK) / (SOFT - DARK), 0, 1) * 255
    alpha[sky] = 0
    return alpha


def trim_sides(rgb: np.ndarray) -> tuple[int, int]:
    dark = rgb.max(axis=2) < DARK
    col = dark[rgb.shape[0] // 2:].mean(axis=0)
    left = 0
    while col[left] > 0.5:
        left += 1
    right = rgb.shape[1]
    while col[right - 1] > 0.5:
        right -= 1
    return left + 2, right - 2   # a hair more, the border's soft edge


def unblack(rgb: np.ndarray, alpha: np.ndarray) -> np.ndarray:
    """Soft sky-edge pixels were mixed with black: brighten them back to the scenery's colour."""
    a = np.clip(alpha / 255.0, 0.25, 1)[..., None]
    out = rgb.copy()
    m = alpha < 255
    out[m] = np.clip(rgb[m] / a[m], 0, 255)
    return out


def _grey(x: np.ndarray) -> np.ndarray:
    return x[..., :3].mean(axis=2) * (x[..., 3] / 255.0)


def best_fit(old: np.ndarray, rgba: np.ndarray) -> tuple[float, int]:
    """Scale and vertical shift (px) that line the new scenery up with the old picture's scenery.
    The shift never cuts the new picture's own scenery off at the top."""
    rows = (old[..., 3] > 200).mean(axis=1)
    top = int(np.argmax(rows > 0.3))
    sd = old[..., :3].std(axis=1).mean(axis=1)
    y0 = old.shape[0] - 3
    while y0 > 0 and sd[y0] < 6:
        y0 -= 1
    k = 4                                    # compare at a quarter size: fast
    o = np.asarray(Image.fromarray(old.astype(np.uint8)).resize((old.shape[1] // k, old.shape[0] // k))).astype(np.float32)
    band = _grey(o)[top // k:y0 // k]
    base = old.shape[1] / rgba.shape[1]
    src = Image.fromarray(np.clip(rgba, 0, 255).astype(np.uint8))
    best = (None, base, 0)
    for f in np.linspace(0.8, 1.3, 26):
        scale = base * f
        w, h = round(rgba.shape[1] * scale / k), round(rgba.shape[0] * scale / k)
        g = _grey(np.asarray(src.resize((w, h))).astype(np.float32))
        first = int(np.argmax((g > 0).mean(axis=1) > 0.02))     # the new picture's top scenery row
        cols = min(g.shape[1], band.shape[1])
        for dy in range(-first, 80):
            a = top // k - dy
            b = a + band.shape[0]
            if a < 0 or b > g.shape[0]:
                continue
            diff = np.abs(g[a:b, :cols] - band[:, :cols]).mean()
            if best[0] is None or diff < best[0]:
                best = (diff, scale, dy * k)
    return best[1], best[2]


def seamless(img: np.ndarray, n: int) -> np.ndarray:
    """Makes the picture tile sideways: its last n columns overlap its first n, and they're joined along
    the path (top to bottom) where the two look most alike, so nothing shows through twice."""
    w = img.shape[1]
    a, b = img[:, w - n:], img[:, :n]             # a = what comes before the join, b = after
    cost = np.abs(a - b).sum(axis=2)
    acc = cost.copy()
    for y in range(1, acc.shape[0]):
        prev = acc[y - 1]
        left = np.concatenate([[np.inf], prev[:-1]])
        right = np.concatenate([prev[1:], [np.inf]])
        acc[y] += np.minimum(np.minimum(left, prev), right)
    cut = np.zeros(acc.shape[0], int)
    cut[-1] = int(np.argmin(acc[-1]))
    for y in range(acc.shape[0] - 2, -1, -1):
        x = cut[y + 1]
        lo, hi = max(0, x - 1), min(n, x + 2)
        cut[y] = lo + int(np.argmin(acc[y, lo:hi]))
    xs = np.arange(n)[None, :]
    mask = (xs >= cut[:, None]).astype(np.float32)          # 1 = take b
    mask = ndimage.uniform_filter(mask, size=(1, 7))          # a soft 7 px join
    out = img[:, : w - n].copy()
    out[:, :n] = a * (1 - mask[..., None]) + b * mask[..., None]
    return out


def fit(world: str, check_dir: Path | None) -> None:
    src = Image.open(RAW / SOURCES[world]).convert("RGB")
    rgb = np.asarray(src).astype(np.float32)
    left, right = trim_sides(rgb)
    rgb = rgb[:, left:right]
    alpha = key_out_sky(rgb)
    rgb = unblack(rgb, alpha)
    rgba = np.dstack([rgb, alpha])

    old = np.asarray(Image.open(RAW / "bg_mid_originals" / f"{world}_bg_mid.png").convert("RGBA")).astype(np.float32)
    scale, dy = best_fit(old, rgba)                         # same scenery size and height as the old picture
    size = (round(rgba.shape[1] * scale), round(rgba.shape[0] * scale))
    big = np.asarray(Image.fromarray(np.clip(rgba, 0, 255).astype(np.uint8)).resize(size, Image.LANCZOS)).astype(np.float32)
    # place it dy rows lower (or higher) on a canvas at least as tall as the old picture
    h = max(old.shape[0], big.shape[0] + dy)
    canvas = np.zeros((h, big.shape[1], 4), np.float32)
    if dy >= 0:
        canvas[dy:dy + big.shape[0]] = big
    else:
        canvas[: big.shape[0] + dy] = big[-dy:]
    fade = 40                                                # the picture's top edge fades in (no straight line)
    canvas[:fade, :, 3] *= np.linspace(0, 1, fade)[:, None]
    canvas = seamless(canvas, SEAM)
    # 2 see-through rows at the bottom, like the old pictures: the texture repeats, and without them its
    # bottom row bleeds into the top edge on screen as a thin line
    canvas = np.concatenate([canvas, np.zeros((2,) + canvas.shape[1:], np.float32)])
    out = Image.fromarray(np.clip(canvas, 0, 255).astype(np.uint8))
    out.save(ROOT / "assets" / "art" / "backgrounds" / world / "bg_mid.png")
    print(world, "source", src.size, "-> ", out.size, "scale", round(scale, 3), "shift", dy, "px, trimmed", left, rgb.shape[1] + left)
    if check_dir:   # old (left) vs new (right), over a sky colour
        o = Image.fromarray(old.astype(np.uint8))
        bg = Image.new("RGBA", (o.width * 2, max(o.height, out.height)), (120, 190, 250, 255))
        bg.alpha_composite(o, (0, 0))
        bg.alpha_composite(out.crop((0, 0, o.width, out.height)), (o.width, 0))
        bg.convert("RGB").resize((bg.width // 4, bg.height // 4)).save(check_dir / f"fit_{world}.png")


if __name__ == "__main__":
    args = sys.argv[1:]
    check = None
    if args and args[0].startswith("--check="):
        check = Path(args.pop(0).split("=", 1)[1])
    for world in args or list(SOURCES):
        fit(world, check)
