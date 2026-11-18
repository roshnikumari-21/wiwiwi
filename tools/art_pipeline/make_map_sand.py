"""World 5 level map: the owners' "Desert Sunset Oasis Level Map" fitted to the map size every world
uses (1672 x 941): its thin dark frame trimmed off, then scaled. Prints the centres of the 11 round
pads painted along its path (flat pale stepping stones), left to right, for level_map.gd.
Run:  python tools/art_pipeline/make_map_sand.py
"""
import numpy as np
from PIL import Image
from scipy import ndimage

from pipeline import ART, RAW

SIZE = (1672, 941)


def trim_frame(img: Image.Image) -> Image.Image:
    """Cut off a dark border: rows / columns from each edge that are mostly very dark."""
    a = np.asarray(img).astype(float).mean(axis=2)
    dark = a < 70
    def edge(lines):
        n = 0
        for line in lines:
            if line.mean() < 0.5:
                break
            n += 1
        return n
    top = edge(dark)
    bottom = edge(dark[::-1])
    left = edge(dark.T)
    right = edge(dark.T[::-1])
    pad = 2   # and a hair more, for the frame's soft inner edge
    return img.crop((left + pad, top + pad, img.width - right - pad, img.height - bottom - pad))


def pads(img: Image.Image) -> list[tuple[int, int]]:
    """Centres of the flat pale stepping stones: big blobs of pale beige, wider than tall."""
    a = np.asarray(img).astype(int)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    pale = (r > 246) & (np.abs(g - 216) < 8) & (np.abs(b - 149) < 10)   # the pads' flat pale gold
    pale = ndimage.binary_opening(pale, iterations=2)
    labels, n = ndimage.label(pale)
    found = []
    for i, box in enumerate(ndimage.find_objects(labels), start=1):
        h, w = box[0].stop - box[0].start, box[1].stop - box[1].start
        area = (labels[box] == i).sum()
        if 50 < w < 160 and 25 < h < 90 and w > h * 1.3 and area > 0.6 * w * h * 0.75:
            cy, cx = ndimage.center_of_mass(labels == i)
            found.append((round(cx), round(cy)))
    return sorted(found)


def main():
    img = Image.open(RAW / "Desert Sunset Oasis Level Map.png").convert("RGB")
    img = trim_frame(img).resize(SIZE, Image.LANCZOS)
    path = ART / "backgrounds" / "map" / "map_w5.png"
    img.save(path, optimize=True)
    print("  map_w5.png:", img.width, "x", img.height)
    for p in pads(img):
        print("  pad", p)


if __name__ == "__main__":
    main()
