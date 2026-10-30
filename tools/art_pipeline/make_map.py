"""World 1 level map background (stand-in): the concept map with its painted-in level buttons,
stars, kitten, back arrow and World 2 card painted out (OpenCV inpainting), so the real, live
buttons can sit on the same spots. Replace with a clean painting from the owner when it arrives.
Run:  python tools/art_pipeline/make_map.py
"""
import cv2
import numpy as np

from pipeline import ART, RAW

## Level-node centres in the map picture (1672 x 941); the map screen uses the same numbers.
NODES = [(143, 345), (316, 375), (461, 460), (680, 540), (845, 563),
         (990, 645), (1137, 675), (1290, 703), (1432, 685), (1553, 617)]


def main():
    img = cv2.imread(str(RAW / "Chibi Cat Meadow Level Map.png"), cv2.IMREAD_COLOR)
    mask = np.zeros(img.shape[:2], np.uint8)
    for i, (x, y) in enumerate(NODES):
        cv2.circle(mask, (x, y), 66 if i == 3 else 58, 255, -1)        # node 4 had a glow
        cv2.rectangle(mask, (x - 64, y + 28), (x + 64, y + 82), 255, -1)  # its stars
    cv2.rectangle(mask, (605, 380), (785, 525), 255, -1)    # the kitten on node 4
    cv2.circle(mask, (92, 78), 66, 255, -1)                 # back arrow
    cv2.rectangle(mask, (1405, 320), (1672, 488), 255, -1)  # World 2 card
    out = cv2.inpaint(img, mask, 12, cv2.INPAINT_TELEA)
    path = ART / "backgrounds" / "map" / "map_w1.png"
    path.parent.mkdir(parents=True, exist_ok=True)
    cv2.imwrite(str(path), out)
    print("  map_w1.png:", out.shape[1], "x", out.shape[0])


if __name__ == "__main__":
    main()
