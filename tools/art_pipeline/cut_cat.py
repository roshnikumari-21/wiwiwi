"""Cut the kitten concept sheets into aligned animation frames + a Godot SpriteFrames resource.

Run:  python tools/art_pipeline/cut_cat.py
"""
import numpy as np
from PIL import Image

from pipeline import ART, ROOT, cut, find_sprites, load, remove_background, save_frames

SHEETS = {
    "A": "Chibi Kitten Animation Sprite Sheet.png",
    "L": "Chibi Kitten Landing Sequence.png",
    "S": "Sleepy Kawaii Kitten Sticker Sequence.png",
}

# animation: (frame ids, frames per second, loop)
ANIMATIONS = {
    # One still frame: the concept idle frames differ slightly, which looked like trembling.
    "idle":   (["A0"], 1.0, False),
    "walk":   (["A3", "A4", "A5", "A6", "A7", "A8"], 12.0, True),
    "jump":   (["A10"], 1.0, False),
    "fall":   (["L0", "L1"], 6.0, True),
    "land":   (["L2", "L3", "L4"], 14.0, False),
    "hurt":   (["A11", "A14"], 8.0, False),
    "cheer":  (["A12", "A13"], 5.0, True),
    "sleepy": (["S0", "S1", "S1", "S0", "S2"], 2.5, True),
}

OUT_DIR = ART / "characters" / "cat"


def ear_height(arr: np.ndarray) -> float:
    """Ear tip to feet, measured on the head side (right) so the tail doesn't count."""
    alpha = arr[..., 3] > 40
    cols = np.nonzero(alpha.any(axis=0))[0]
    right = alpha[:, cols[0] + int((cols[-1] - cols[0]) * 0.45):]
    rows = np.nonzero(right.any(axis=1))[0]
    return float(rows[-1] - rows[0])


# Sleepy frames have drooping ears, so their ear height reads short; this corrects for it.
EAR_DROOP = {"S": 1.12}


def main():
    pieces = {}
    for tag, name in SHEETS.items():
        img = remove_background(load(name))
        for i, box in enumerate(find_sprites(img)):
            pieces[f"{tag}{i}"] = cut(img, box)

    # Scale every sheet to match sheet A, comparing a standing frame from each sheet.
    reference = {"A": "A0", "L": "L4", "S": "S0"}
    base = ear_height(pieces["A0"])
    scale = {tag: base / (ear_height(pieces[ref]) * EAR_DROOP.get(tag, 1.0)) for tag, ref in reference.items()}
    print("sheet scale factors:", {k: round(v, 3) for k, v in scale.items()})

    used = sorted({f for frames, _, _ in ANIMATIONS.values() for f in frames})
    scaled = {}
    for fid in used:
        arr = pieces[fid]
        s = scale[fid[0]]
        if abs(s - 1.0) > 0.01:
            im = Image.fromarray(arr.astype(np.uint8))
            im = im.resize((round(im.width * s), round(im.height * s)), Image.LANCZOS)
            arr = np.asarray(im).astype(np.float32)
        scaled[fid] = arr

    pad = 16
    cell_w = int(max(a.shape[1] for a in scaled.values()) * 1.25) + pad
    cell_h = int(max(a.shape[0] for a in scaled.values())) + pad
    print("cell size:", cell_w, "x", cell_h)

    for old in OUT_DIR.glob("cat_*.png"):
        old.unlink()
    save_frames([(f"cat_{fid}", scaled[fid]) for fid in used], OUT_DIR, cell_w, cell_h)
    write_sprite_frames()
    print("wrote", len(used), "frames to", OUT_DIR)


def write_sprite_frames():
    """Godot SpriteFrames resource listing every animation (editable later in the editor)."""
    res_dir = "res://" + OUT_DIR.relative_to(ROOT).as_posix()
    used = sorted({f for frames, _, _ in ANIMATIONS.values() for f in frames})
    ids = {fid: f"{i + 1}_{fid}" for i, fid in enumerate(used)}
    lines = ['[gd_resource type="SpriteFrames" format=3]', ""]
    for fid in used:
        lines.append(f'[ext_resource type="Texture2D" path="{res_dir}/cat_{fid}.png" id="{ids[fid]}"]')
    lines += ["", "[resource]"]
    anims = []
    for name, (frames, fps, loop) in ANIMATIONS.items():
        fr = ", ".join('{\n"duration": 1.0,\n"texture": ExtResource("%s")\n}' % ids[f] for f in frames)
        anims.append('{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %.1f\n}'
                     % (fr, "true" if loop else "false", name, fps))
    lines.append("animations = [" + ", ".join(anims) + "]")
    (OUT_DIR / "cat_frames.tres").write_text("\n".join(lines) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
