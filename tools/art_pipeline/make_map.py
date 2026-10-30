"""World 1 level map background: the owner's clean map painting (no buttons on it), copied in.
The level buttons sit on the round pads along its path; their centres are SPOTS in level_map.gd.
Run:  python tools/art_pipeline/make_map.py
"""
from PIL import Image

from pipeline import ART, RAW


def main():
    img = Image.open(RAW / "Whimsical Countryside Adventure Map.png").convert("RGB")
    path = ART / "backgrounds" / "map" / "map_w1.png"
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, optimize=True)
    print("  map_w1.png:", img.width, "x", img.height)


if __name__ == "__main__":
    main()
