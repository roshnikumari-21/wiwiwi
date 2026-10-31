"""App icons and the loading (boot) screen.

Icon = "Cheerful Ginger Kitten Garden Icon" (full-square art, no text: Play's icon rules say no
text, and it stays readable at launcher size). Android adaptive icons only show the middle 66 %
of a 432 px layer (inside a circle/squircle mask), so the art is placed at that size in the middle,
over a blurred, enlarged copy that fills the edges (only seen in launcher animations).
Loading screen = the "wiwiwi" cat logo on a soft sky-to-meadow background.

Run:  python tools/art_pipeline/make_icons.py
Outputs: assets/icons/*.png (in the game), store_assets/icon_512.png (Play Store listing, not in the game).
"""
from PIL import Image, ImageDraw, ImageFilter

from pipeline import RAW, ROOT

ICONS = ROOT / "assets" / "icons"
STORE = ROOT / "store_assets"
ICON_ART = "Cheerful Ginger Kitten Garden Icon.png"
LOGO = "Kawaii Cat Wiwiwi Garden Logo.png"
SKY = (102, 196, 254)
MEADOW = (226, 244, 196)


def main():
    ICONS.mkdir(parents=True, exist_ok=True)
    STORE.mkdir(parents=True, exist_ok=True)
    (STORE / ".gdignore").touch()
    art = Image.open(RAW / ICON_ART).convert("RGB")

    # Classic launcher icon (old Android) + the project icon + Play Store listing icon.
    art.resize((192, 192), Image.LANCZOS).save(ICONS / "icon_192.png", optimize=True)
    art.resize((256, 256), Image.LANCZOS).save(ICONS / "icon_256.png", optimize=True)
    art.resize((512, 512), Image.LANCZOS).save(STORE / "icon_512.png", optimize=True)

    # Adaptive icon: background = the art enlarged + blurred (edges), foreground = the art at the
    # visible 66 % (288 px) plus a small margin, so the face and ears survive any mask shape.
    background = art.resize((432, 432), Image.LANCZOS).filter(ImageFilter.GaussianBlur(10))
    background.save(ICONS / "icon_adaptive_bg.png", optimize=True)
    size = 300
    fg = Image.new("RGBA", (432, 432), (0, 0, 0, 0))
    inner = art.resize((size, size), Image.LANCZOS).convert("RGBA")
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size - 1, size - 1), radius=40, fill=255)
    inner.putalpha(mask)
    fg.alpha_composite(inner, ((432 - size) // 2, (432 - size) // 2))
    fg.save(ICONS / "icon_adaptive_fg.png", optimize=True)

    # Loading screen: 1920x1080, sky fading to meadow, the cat logo in the middle.
    w, h = 1920, 1080
    splash = Image.new("RGB", (w, h), SKY)
    draw = ImageDraw.Draw(splash)
    for y in range(h):
        t = max(0.0, (y - h * 0.45) / (h * 0.55))
        draw.line([(0, y), (w, y)], fill=tuple(int(SKY[i] + (MEADOW[i] - SKY[i]) * t) for i in range(3)))
    logo = Image.open(RAW / LOGO).convert("RGBA")
    box = logo.getbbox()
    logo = logo.crop(box)
    logo_w = 760
    logo = logo.resize((logo_w, round(logo.height * logo_w / logo.width)), Image.LANCZOS)
    splash.paste(logo, ((w - logo.width) // 2, (h - logo.height) // 2 - 30), logo)
    splash.save(ICONS / "splash.png", optimize=True)
    print("  icons + splash written to", ICONS, "and", STORE / "icon_512.png")


if __name__ == "__main__":
    main()
