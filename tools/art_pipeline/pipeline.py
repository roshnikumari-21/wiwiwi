"""Reusable helpers: turn concept-art sheets into clean, transparent game sprites."""
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[2]
RAW = ROOT / "assets" / "raw_assets_idea"
ART = ROOT / "assets" / "art"


def load(name: str) -> np.ndarray:
    """Load a concept sheet as float RGBA (0..255)."""
    return np.asarray(Image.open(RAW / name).convert("RGBA")).astype(np.float32)


def remove_background(img: np.ndarray, neutral_min=200, neutral_sat=14, shadow=True) -> np.ndarray:
    """Make the background transparent.

    Background = near-grey/white pixels (and soft beige drop shadows) that are connected to the
    image border. Anything enclosed by an outline (like the cat's cream fur) is never touched.
    Pixels that already have real transparency stay transparent.
    """
    rgb = img[..., :3]
    mx, mn = rgb.max(axis=2), rgb.min(axis=2)
    sat, val = mx - mn, mx
    candidate = (sat <= neutral_sat) & (val >= neutral_min)
    if shadow:
        # Soft warm drop shadows: very light, slightly beige.
        candidate |= (val >= 215) & (sat <= 60) & (rgb[..., 0] >= rgb[..., 2])
    candidate |= img[..., 3] < 8

    labels, _ = ndimage.label(candidate)
    border = np.unique(np.concatenate([labels[0], labels[-1], labels[:, 0], labels[:, -1]]))
    background = np.isin(labels, border[border > 0])

    out = img.copy()
    out[background, 3] = 0

    # Soften the edge: pixels touching the background are partly white; un-blend them.
    ring = ndimage.binary_dilation(background, iterations=2) & ~background
    lum = rgb[ring].mean(axis=1)
    a = np.clip((252.0 - lum) / (252.0 - 110.0), 0.0, 1.0)
    keep = a > 0.04
    a_safe = np.maximum(a, 0.04)[:, None]
    unblended = np.clip((rgb[ring] - 252.0 * (1.0 - a_safe)) / a_safe, 0, 255)
    out_ring = out[ring]
    out_ring[:, :3] = np.where(keep[:, None], unblended, out_ring[:, :3])
    out_ring[:, 3] = np.where(keep, np.minimum(out_ring[:, 3], a * 255.0), 0)
    out[ring] = out_ring
    return out


def find_sprites(img: np.ndarray, min_area=3000):
    """Return bounding boxes (x0, y0, x1, y1) of separate sprites, sorted in reading order."""
    solid = img[..., 3] > 40
    labels, n = ndimage.label(solid, structure=np.ones((3, 3)))
    boxes = []
    for i, sl in enumerate(ndimage.find_objects(labels), start=1):
        if sl is None:
            continue
        area = int((labels[sl] == i).sum())
        if area >= min_area:
            boxes.append((sl[1].start, sl[0].start, sl[1].stop, sl[0].stop, i, labels))
    # Reading order: group into rows by vertical centre, then left to right.
    boxes.sort(key=lambda b: (b[1] + b[3]) / 2)
    rows, current = [], []
    for b in boxes:
        cy = (b[1] + b[3]) / 2
        if current and cy - (current[-1][1] + current[-1][3]) / 2 > 80:
            rows.append(current)
            current = []
        current.append(b)
    if current:
        rows.append(current)
    ordered = []
    for row in rows:
        ordered += sorted(row, key=lambda b: b[0])
    return ordered


def cut(img: np.ndarray, box) -> np.ndarray:
    """Crop one sprite, keeping only its own pixels (drops nearby sparkles/marks)."""
    x0, y0, x1, y1, idx, labels = box
    piece = img[y0:y1, x0:x1].copy()
    mine = ndimage.binary_dilation(labels[y0:y1, x0:x1] == idx, iterations=3)
    piece[~mine, 3] = 0
    return piece


def to_image(arr: np.ndarray) -> Image.Image:
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGBA")


def body_anchor_x(arr: np.ndarray) -> float:
    """Horizontal centre of the lower body (legs), so tails don't shift the alignment."""
    alpha = arr[..., 3] > 40
    h = alpha.shape[0]
    lower = alpha[int(h * 0.6):]
    cols = np.nonzero(lower.any(axis=0))[0]
    if len(cols) == 0:
        cols = np.nonzero(alpha.any(axis=0))[0]
    return float((cols[0] + cols[-1]) / 2)


def save_frames(frames, out_dir: Path, cell_w: int, cell_h: int, pad_bottom=6):
    """Place each frame on a same-size canvas: feet on the bottom line, body centred."""
    out_dir.mkdir(parents=True, exist_ok=True)
    paths = []
    for name, arr in frames:
        img = to_image(arr)
        canvas = Image.new("RGBA", (cell_w, cell_h), (0, 0, 0, 0))
        x = int(round(cell_w / 2 - body_anchor_x(arr)))
        y = cell_h - pad_bottom - img.height
        canvas.alpha_composite(img, (max(x, 0), max(y, 0)))
        path = out_dir / f"{name}.png"
        canvas.save(path, optimize=True)
        paths.append(path)
    return paths
