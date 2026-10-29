"""Cut the kitten concept sheets into aligned animation frames + a Godot SpriteFrames resource.

Run:  python tools/art_pipeline/cut_cat.py
"""
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

from pipeline import ART, ROOT, cut, find_sprites, load, remove_background, save_frames

SHEETS = {
    "A": "Chibi Kitten Animation Sprite Sheet.png",
    "L": "Chibi Kitten Landing Sequence.png",
    "S": "Sleepy Kawaii Kitten Sticker Sequence.png",
    "I": "Chibi Cat Idle Animation Frames.png",
}

# animation: (frames, frames per second, loop). A frame is an id, or (id, duration in frame-units).
ANIMATIONS = {
    # Still pose with a blink every few seconds (sometimes a double blink). Breathing is done in code.
    "idle":   ([("I0", 28), ("I0b", 1.2), ("I0", 18), ("I0b", 1.2), ("I0", 1.2), ("I0b", 1.2)], 8.0, True),
    "walk":   (["A3", "A4", "A5", "A6", "A7", "A8"], 12.0, True),
    "jump":   (["A10"], 1.0, False),
    # Only for drops without a jump (walking off a ledge). One steady frame: L1's folded legs
    # looked wrong in mid-air; folding happens only on touchdown ("land").
    "fall":   (["L0"], 1.0, False),
    "land":   (["L2", "L3", "L4"], 14.0, False),
    "hurt":   (["A11", "A14"], 8.0, False),
    "cheer":  (["A12", "A13"], 5.0, True),
    "sleepy": (["S0", "S1", "S1", "S0", "S2"], 2.5, True),
}

# A standing frame from each sheet, used to match the sheets' sizes.
SIZE_REFERENCE = {"A": "A0", "L": "L4", "S": "S0", "I": "I0"}
# Sleepy frames have drooping ears, so their ear height reads short; this corrects for it.
EAR_DROOP = {"S": 1.12}

OUT_DIR = ART / "characters" / "cat"


def frame_id(entry):
    return entry[0] if isinstance(entry, tuple) else entry


def frame_duration(entry):
    return entry[1] if isinstance(entry, tuple) else 1.0


def ear_height(arr: np.ndarray) -> float:
    """Ear tip to feet, measured on the head side (right) so the tail doesn't count."""
    alpha = arr[..., 3] > 40
    cols = np.nonzero(alpha.any(axis=0))[0]
    right = alpha[:, cols[0] + int((cols[-1] - cols[0]) * 0.45):]
    rows = np.nonzero(right.any(axis=1))[0]
    return float(rows[-1] - rows[0])


def make_blink(base: np.ndarray, eyes_closed: np.ndarray) -> np.ndarray:
    """Copy only the closed eyes onto the base frame, so a blink changes nothing else (no wobble)."""
    H, W = base.shape[:2]

    def placed(arr, dx, dy):
        out = np.zeros((H, W, 4), np.float32)
        h, w = arr.shape[:2]
        ys, xs, ye, xe = max(dy, 0), max(dx, 0), min(H, dy + h), min(W, dx + w)
        out[ys:ye, xs:xe] = arr[ys - dy:ye - dy, xs - dx:xe - dx]
        return out

    head = (slice(0, int(H * 0.6)), slice(int(W * 0.4), W))
    best = None
    for dy in range(-12, 13):
        for dx in range(-12, 13):
            b = placed(eyes_closed, dx, dy)
            both = (base[head][..., 3] > 200) & (b[head][..., 3] > 200)
            err = np.abs(base[head][..., :3] - b[head][..., :3]).sum(axis=2)[both].mean()
            if best is None or err < best[0]:
                best = (err, dx, dy)
    aligned = placed(eyes_closed, best[1], best[2])

    face = np.zeros((H, W), bool)
    face[int(H * 0.30): int(H * 0.62), int(W * 0.55):] = True  # eye band: no ears, no mouth
    diff = np.abs(base[..., :3] - aligned[..., :3]).sum(axis=2)
    diff[(base[..., 3] < 200) | (aligned[..., 3] < 200)] = 0
    mask = ndimage.binary_opening(diff > 120, iterations=2) & face
    lab, n = ndimage.label(ndimage.binary_dilation(mask, iterations=6))
    sizes = ndimage.sum(np.ones_like(lab), lab, range(1, n + 1))
    eyes = np.isin(lab, np.argsort(sizes)[::-1][:2] + 1)
    patch = ndimage.binary_dilation(eyes, iterations=8) & ndimage.binary_dilation(face, iterations=4)
    soft = ndimage.gaussian_filter(patch.astype(np.float32), 3)[..., None]

    out = base.copy()
    out[..., :3] = base[..., :3] * (1 - soft) + aligned[..., :3] * soft
    return out


def main():
    pieces = {}
    for tag, name in SHEETS.items():
        img = remove_background(load(name))
        for i, box in enumerate(find_sprites(img)):
            pieces[f"{tag}{i}"] = cut(img, box)
    pieces["I0b"] = make_blink(pieces["I0"], pieces["I2"])

    base = ear_height(pieces["A0"])
    scale = {tag: base / (ear_height(pieces[ref]) * EAR_DROOP.get(tag, 1.0)) for tag, ref in SIZE_REFERENCE.items()}
    print("sheet scale factors:", {k: round(v, 3) for k, v in scale.items()})

    used = sorted({frame_id(f) for frames, _, _ in ANIMATIONS.values() for f in frames})
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

    # Remove only frames that are no longer used (keeps Godot's .import files, and their IDs, stable).
    wanted = {f"cat_{fid}.png" for fid in used}
    for old in OUT_DIR.glob("cat_*.png"):
        if old.name not in wanted:
            old.unlink()
            Path(str(old) + ".import").unlink(missing_ok=True)
    save_frames([(f"cat_{fid}", scaled[fid]) for fid in used], OUT_DIR, cell_w, cell_h)
    write_sprite_frames(used)
    print("wrote", len(used), "frames to", OUT_DIR)


def write_sprite_frames(used):
    """Godot SpriteFrames resource listing every animation (editable later in the editor)."""
    res_dir = "res://" + OUT_DIR.relative_to(ROOT).as_posix()
    ids = {fid: f"{i + 1}_{fid}" for i, fid in enumerate(used)}
    lines = ['[gd_resource type="SpriteFrames" format=3]', ""]
    for fid in used:
        lines.append(f'[ext_resource type="Texture2D" path="{res_dir}/cat_{fid}.png" id="{ids[fid]}"]')
    lines += ["", "[resource]"]
    anims = []
    for name, (frames, fps, loop) in ANIMATIONS.items():
        fr = ", ".join('{\n"duration": %.2f,\n"texture": ExtResource("%s")\n}' % (frame_duration(f), ids[frame_id(f)])
                       for f in frames)
        anims.append('{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %.1f\n}'
                     % (fr, "true" if loop else "false", name, fps))
    lines.append("animations = [" + ", ".join(anims) + "]")
    (OUT_DIR / "cat_frames.tres").write_text("\n".join(lines) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
