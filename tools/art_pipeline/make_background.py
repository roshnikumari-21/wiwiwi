"""Build the World 1 parallax background layers, at in-game size and repeating seamlessly sideways.

  far  - sky, clouds and distant rolling hills  (edges cross-faded so it repeats)
  mid  - countryside with cottages and trees    (placed next to a mirrored copy: edges always match;
                                                  its grass continues below, darkening, so looking
                                                  down into a pit never shows empty sky)
The bushes strip ("Cartoon Bushes and Flowers Game Border") was tried as a near layer and dropped:
it looked busy in front of the countryside.
Run:  python tools/art_pipeline/make_background.py   (prints sizes and the sky colour)
"""
import numpy as np
from PIL import Image
from scipy import ndimage

from pipeline import ART, RAW

OUT = ART / "backgrounds" / "meadow"


def crossfade_wrap(a: np.ndarray, band: int) -> np.ndarray:
    """Make an image repeat left-right: blend its last `band` columns into its first ones."""
    w = a.shape[1]
    t = np.linspace(0.0, 1.0, band)[None, :, None]
    start = a[:, :band] * t + a[:, w - band:] * (1.0 - t)
    return np.concatenate([start, a[:, band:w - band]], axis=1)


def clean_specks(a: np.ndarray, min_area=400) -> np.ndarray:
    """Drop tiny stray bits around the art (the panorama's cloud edges have white specks)."""
    a = a.copy()
    a[a[..., 3] < 40, 3] = 0
    labels, n = ndimage.label(a[..., 3] > 0)
    sizes = ndimage.sum(np.ones_like(labels), labels, range(1, n + 1))
    small = np.isin(labels, np.flatnonzero(sizes < min_area) + 1)
    a[small, 3] = 0
    return a


def load(name: str, scale: float) -> np.ndarray:
    img = Image.open(RAW / name).convert("RGBA")
    img = img.resize((round(img.width * scale), round(img.height * scale)), Image.LANCZOS)
    return np.asarray(img).astype(np.float32)


def save(a: np.ndarray, name: str):
    Image.fromarray(np.clip(a, 0, 255).astype(np.uint8)).save(OUT / name, optimize=True)
    print(f"  {name}: {a.shape[1]}x{a.shape[0]}")


def main():
    OUT.mkdir(parents=True, exist_ok=True)

    far = load("Pastel Rolling Hills and Cloudy Skies.png", 1.5)
    print("  sky colour:", far[3, far.shape[1] // 2, :3].astype(int))
    far = crossfade_wrap(far, 150)
    far[:80, :, 3] *= np.linspace(0.0, 1.0, 80)[:, None]   # top edge fades into the plain sky colour
    far[-2:, :, 3] = 0   # the layer repeats, so its top edge blends with this row: keep it clear (no line in the sky)
    save(far, "bg_far.png")

    mid = load("Whimsical Pastel Countryside Panorama.png", 1.0)[260:]
    mid = clean_specks(mid)
    mid = np.concatenate([mid, mid[:, ::-1]], axis=1)
    grass = mid[-8:, :, :3].reshape(-1, 3).mean(axis=0)
    below = np.zeros((500, mid.shape[1], 4), np.float32)
    shade = np.linspace(1.0, 0.7, 500)[:, None, None]   # darker the deeper you look
    below[..., :3] = grass * shade
    below[..., 3] = 255
    mid = np.concatenate([mid, below], axis=0)
    mid[-2:, :, 3] = 0   # same reason as the far layer
    save(mid, "bg_mid.png")

if __name__ == "__main__":
    main()
