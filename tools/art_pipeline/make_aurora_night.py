"""The aurora night's far layer (level 4-9 "Aurora Pass"): the owners' painted night version of the snow
background (ChatGPT, from bg_far.png: moon, aurora curtains behind the peaks, the lake reflecting them)
fitted to the far layer: its thin dark frame trimmed, scaled to the far layer's height, and its left and
right edges cross-faded so it repeats sideways without a seam.

Reads assets/raw_assets_idea/Moonlit Aurora Over Snowy Mountains.png
Writes assets/art/backgrounds/snow/bg_far_night.png
Run:  python tools/art_pipeline/make_aurora_night.py
"""
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "assets" / "raw_assets_idea" / "Moonlit Aurora Over Snowy Mountains.png"
OUT = ROOT / "assets" / "art" / "backgrounds" / "snow" / "bg_far_night.png"
DAY = ROOT / "assets" / "art" / "backgrounds" / "snow" / "bg_far.png"
TRIM = 6        # px of dark rounded frame on each side of the picture
BLEND = 150     # px (after scaling) over which the right edge fades into the left one


def main():
    img = Image.open(SRC).convert("RGB")
    img = img.crop((TRIM, TRIM, img.width - TRIM, img.height - TRIM))
    height = Image.open(DAY).height             # same height as the day picture: same placement
    width = round(img.width * height / img.height)
    a = np.array(img.resize((width, height), Image.LANCZOS)).astype(float)
    # seamless: the first BLEND columns fade from the picture's right end into its start, and that
    # right end is cut off, so the last column now leads straight into the first
    t = np.linspace(0.0, 1.0, BLEND)[None, :, None]
    start = a[:, :BLEND] * t + a[:, width - BLEND:] * (1.0 - t)
    out = np.concatenate([start, a[:, BLEND:width - BLEND]], axis=1)
    Image.fromarray(out.round().clip(0, 255).astype(np.uint8)).save(OUT)
    print("bg_far_night", out.shape[1], "x", out.shape[0], "seam diff", float(np.abs(out[:, 0] - out[:, -1]).sum(1).mean()))


if __name__ == "__main__":
    main()
