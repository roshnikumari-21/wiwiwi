"""Turn the owner's ElevenLabs files (assets/raw_audio_idea, not in Git) into game-ready OGG files.

For every sound: trim silence at both ends, even out the loudness to its target, short fades so
nothing clicks. Sound effects become mono (smaller, and position doesn't matter in this game).
Music loops are made seamless: the last LOOP_XFADE seconds are crossfaded into the start, so the
track restarts with no gap or jump. Output: assets/audio/music/*.ogg, assets/audio/sfx/*.ogg.

Needs ffmpeg on PATH (installed with winget: Gyan.FFmpeg).
Run:  python tools/audio_pipeline/make_audio.py            (all sounds)
      python tools/audio_pipeline/make_audio.py mus_world2 (only the named ones)
"""
import shutil
import sys
import subprocess
import tempfile
from pathlib import Path

import numpy as np
import soundfile as sf

ROOT = Path(__file__).resolve().parents[2]
RAW = ROOT / "assets" / "raw_audio_idea"
OUT = ROOT / "assets" / "audio"
RATE = 44100
LOOP_XFADE = 2.0   # seconds

# game name: (raw file name starts with, kind, target loudness in LUFS-ish dB)
# Frequent small sounds are quieter than rare special moments, so the mix never gets tiring.
SOUNDS = {
    "mus_home": ("Mus_Home", "loop", -20.0),
    "mus_world1": ("Mus_World_1", "loop", -20.0),
    "mus_world2": ("Sunset_Stroll", "loop", -20.0),
    "mus_world3": ("Sunlit_Woodland_Stroll", "loop", -20.0),
    "mus_world4": ("Snowy_Cabin_Steps", "loop", -20.0),
    "mus_level_complete": ("Level_Complete", "jingle", -17.0),
    "mus_try_again": ("Short_soft", "jingle", -19.0),
    "sfx_coin": ("Bright_cute_coin", "sfx", -21.0),
    "sfx_jump": ("Soft_light_cartoon_j", "sfx", -26.0),
    "sfx_land": ("Soft_cushioned_thud", "sfx", -25.0),
    "sfx_stomp": ("Squishy_cartoon_slim", "sfx", -19.0),
    "sfx_boing": ("Springy_cartoon_boin", "sfx", -19.0),
    "sfx_hurt": ("Short_cute_sad_kitte", "sfx", -18.0),
    "sfx_splash": ("Small_cartoon_water", "sfx", -19.0),
    "sfx_checkpoint": ("Cheerful_little_flag", "sfx", -18.0),
    "sfx_yarn": ("A_short_magical_trea", "sfx", -16.0),
    "sfx_star": ("A_short,_bright_cart", "sfx", -19.0),
    "sfx_button": ("A_soft,_very_short_w", "sfx", -23.0),
    "sfx_meow_happy": ("A_single_happy,_cute", "sfx", -18.0),
    "sfx_purr": ("A_gentle,_continuous", "loop_sfx", -24.0),
    "sfx_confetti": ("A_cute,_cheerful_par", "sfx", -21.0),
}


def ffmpeg() -> str:
    exe = shutil.which("ffmpeg")
    if not exe:
        raise SystemExit("ffmpeg not found on PATH")
    return exe


def decode(path: Path) -> np.ndarray:
    with tempfile.TemporaryDirectory() as tmp:
        wav = Path(tmp) / "a.wav"
        subprocess.run([ffmpeg(), "-v", "error", "-y", "-i", str(path), "-ar", str(RATE), str(wav)], check=True)
        audio, _ = sf.read(wav, always_2d=True)
    return audio


def encode(audio: np.ndarray, path: Path, quality: int):
    with tempfile.TemporaryDirectory() as tmp:
        wav = Path(tmp) / "a.wav"
        sf.write(wav, audio, RATE, subtype="FLOAT")
        subprocess.run([ffmpeg(), "-v", "error", "-y", "-i", str(wav), "-c:a", "libvorbis", "-q:a", str(quality), str(path)], check=True)


def loudness(audio: np.ndarray) -> float:
    """Loudness of the loud parts (simple gated RMS in dB), so pauses don't count."""
    mono = audio.mean(axis=1)
    block = RATE // 20
    rms = np.array([np.sqrt(np.mean(mono[i:i + block] ** 2)) for i in range(0, len(mono) - block, block)])
    loud = rms[rms > rms.max() * 0.1] if rms.max() > 0 else rms
    return 20 * np.log10(np.sqrt(np.mean(loud ** 2)) + 1e-9)


def trim(audio: np.ndarray, threshold_db=-45.0, keep=0.01) -> np.ndarray:
    level = np.abs(audio).max(axis=1)
    on = np.flatnonzero(level > 10 ** (threshold_db / 20) * np.abs(audio).max())
    a, b = max(on[0] - int(keep * RATE), 0), min(on[-1] + int(keep * RATE * 4), len(audio))
    return audio[a:b]


def fade(audio: np.ndarray, start=0.004, end=0.03) -> np.ndarray:
    audio = audio.copy()
    n1, n2 = int(start * RATE), int(end * RATE)
    audio[:n1] *= np.linspace(0.0, 1.0, n1)[:, None]
    audio[-n2:] *= np.linspace(1.0, 0.0, n2)[:, None]
    return audio


def make_loop(audio: np.ndarray, seconds: float) -> np.ndarray:
    """Crossfade the end into the start; the result restarts seamlessly when played on loop."""
    n = int(seconds * RATE)
    t = np.linspace(0.0, 1.0, n)[:, None]
    out = audio[n:].copy()
    out[-n:] = audio[-n:] * np.cos(t * np.pi / 2) + audio[:n] * np.sin(t * np.pi / 2)   # equal power
    return out


def main():
    (OUT / "music").mkdir(parents=True, exist_ok=True)
    (OUT / "sfx").mkdir(parents=True, exist_ok=True)
    raw_files = sorted(RAW.glob("*.mp3")) + sorted(RAW.glob("*.wav"))
    only = sys.argv[1:]
    for name, (prefix, kind, target) in SOUNDS.items():
        if only and name not in only:
            continue
        matches = [f for f in raw_files if f.name.startswith(prefix)]
        if not matches:
            print(f"  MISSING {name} (no file starting with '{prefix}')")
            continue
        audio = decode(matches[0])
        if kind in ("sfx", "loop_sfx"):
            audio = audio.mean(axis=1, keepdims=True)   # mono
        if kind == "loop":
            audio = make_loop(audio, LOOP_XFADE)
        elif kind == "loop_sfx":
            audio = make_loop(trim(audio), 0.4)
        else:
            audio = fade(trim(audio))
        audio = audio * 10 ** ((target - loudness(audio)) / 20)
        peak = np.abs(audio).max()
        if peak > 0.89:   # keep 1 dB of headroom
            audio *= 0.89 / peak
        folder = "music" if name.startswith("mus_") else "sfx"
        path = OUT / folder / f"{name}.ogg"
        encode(audio, path, 3 if kind == "loop" else 4)
        print(f"  {name:20s} {len(audio) / RATE:6.2f}s  {path.stat().st_size / 1024:6.0f} KB  <- {matches[0].name}")


if __name__ == "__main__":
    main()
