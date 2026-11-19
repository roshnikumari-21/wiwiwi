"""Fills the FLAT block under each world's middle background layer (bg_mid.png) with more scenery.

The painted mid layers (hills, trees, dunes...) end in a plain single-colour block that the ground
normally hides. The background moves up and down more slowly than the ground (that is the depth effect),
so when the camera rises for a jump the ground slides down past the scenery and that flat block showed
as an empty band (owners, 19 Nov 2026). Here the dense undergrowth just above the block is copied
downwards, each copy a little darker (deeper in the shade), so a jump only ever shows more scenery.

Overwrites assets/art/backgrounds/<world>/bg_mid.png (the originals are in Git). Safe to re-run: a picture
with no flat block left is skipped.
Run:  python tools/art_pipeline/extend_bg_mid.py
"""
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
WORLDS = ["meadow", "town", "forest", "snow", "sand"]
FLAT_SD = 6.0      # a row whose colours vary less than this is "flat"
BAND_MAX = 240     # how much undergrowth (px above the flat block) to copy downwards
BLEND = 40         # px over which each copy fades into the one above (no hard seam)
SHADE = 0.86       # each copy down is this much darker


def flat_start(a: np.ndarray) -> int:
    sd = a[:, :, :3].std(axis=1).mean(axis=1)
    y = a.shape[0] - 3
    while y > 0 and sd[y] < FLAT_SD:
        y -= 1
    return y + 1


def band_rows(a: np.ndarray, y0: int) -> int:
    """How many mostly opaque rows sit right above the flat block (up to BAND_MAX)."""
    k = 0
    while k < BAND_MAX and y0 - k - 1 >= 0 and (a[y0 - k - 1, :, 3] > 240).mean() > 0.6:
        k += 1
    return k


def extend(world: str) -> None:
    path = ROOT / "assets" / "art" / "backgrounds" / world / "bg_mid.png"
    a = np.asarray(Image.open(path).convert("RGBA")).astype(np.float32)
    h, w = a.shape[:2]
    y0 = flat_start(a)
    if h - y0 < 20:
        print(world, "no flat block, skipped")
        return
    k = band_rows(a, y0)
    if k < BLEND * 2:
        print(world, "undergrowth band too thin:", k)
        return
    band = a[y0 - k:y0].copy()
    fill = a[y0 + 2, :, :3].mean(axis=0)              # see-through bits of the band show the block's colour
    alpha = band[:, :, 3:4] / 255.0
    band[:, :, :3] = band[:, :, :3] * alpha + fill * (1 - alpha)
    out = a.copy()
    y = y0 - BLEND           # each copy overlaps the rows above by BLEND, fading in
    n = 1
    while y < h:
        piece = band.copy()
        piece = np.roll(piece, (n * w) // 3, axis=1)   # shifted sideways: no stacked look (it tiles anyway)
        if n % 2:
            piece = piece[:, ::-1]
        piece[:, :, :3] *= SHADE ** n
        rows = min(k, h - y)
        fade = np.ones((rows, 1, 1), np.float32)
        ramp = min(BLEND, rows)
        fade[:ramp, 0, 0] = np.linspace(0.0, 1.0, ramp)
        cur = out[y:y + rows]
        out[y:y + rows, :, :3] = cur[:, :, :3] * (1 - fade) + piece[:rows, :, :3] * fade
        out[y:y + rows, :, 3] = 255
        y += k - BLEND
        n += 1
    Image.fromarray(np.clip(out, 0, 255).astype(np.uint8)).save(path)
    print(world, "filled rows", y0, "to", h, "with a", k, "px band")


if __name__ == "__main__":
    for world in WORLDS:
        extend(world)
