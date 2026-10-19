"""Grade the owner's menu painting to the game's dusk mood.

Reads art/reference/menu_background_source.jpg (the owner's painted ruins-and-world-tree scene, supplied by the
human on 2026-10-19), crops it to 16:9, and writes presentation/menu/menu_background.jpg (1920x1080):
cooler and darker, shadows toward violet, the bright sky and sun rays toward pale moonlight, a vignette, a darker
top for the title and a soft blurred, darkened area behind the menu lettering.

Run from the project root:  python tools/art/grade_menu_background.py [--preview]
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageEnhance, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "art" / "reference" / "menu_background_source.jpg"
OUT = ROOT / "presentation" / "menu" / "menu_background.jpg"
W, H = 1920, 1080
INK = (28, 24, 36)  # the palette's ink


def curve(gamma: float, gain: float):
    return lambda v: int(min(255, 255 * gain * (v / 255.0) ** gamma))


def grade(src: Image.Image) -> Image.Image:
    w, h = src.size
    target_w = round(h * 16 / 9)
    left = (w - target_w) // 2
    img = src.crop((left, 0, left + target_w, h)).resize((W, H), Image.LANCZOS).convert("RGB")
    # cooler, darker: a per-channel curve (the red drops most, the blue keeps its strength)
    r, g, b = img.split()
    img = Image.merge("RGB", (r.point(curve(1.25, 0.82)), g.point(curve(1.18, 0.84)), b.point(curve(1.0, 0.96))))
    img = ImageEnhance.Color(img).enhance(0.9)
    img = ImageEnhance.Contrast(img).enhance(1.12)
    lum = img.convert("L")
    # shadows lean violet
    shadow_mask = lum.point(lambda v: int(255 * ((1 - v / 255.0) ** 1.6) * 0.5))
    img = Image.composite(Image.new("RGB", img.size, (40, 24, 82)), img, shadow_mask)
    # the bright sky and sun rays become pale moonlight
    glow_mask = lum.point(lambda v: int(max(0, v - 120) / 135.0 * 255 * 0.55))
    img = Image.composite(Image.new("RGB", img.size, (176, 200, 255)), img, glow_mask)
    # twilight gradient over the sky, strongest at the top
    sky = Image.linear_gradient("L").resize(img.size).rotate(180).point(lambda v: int((v / 255.0) ** 1.4 * 255 * 0.55))
    img = Image.composite(Image.new("RGB", img.size, (28, 22, 66)), img, sky)
    # vignette
    vig = Image.radial_gradient("L").resize(img.size).point(lambda v: int(max(0, v - 90) * 1.25 * 0.85))
    img = Image.composite(Image.new("RGB", img.size, INK), img, vig)
    # a calmer, darker area behind the menu (centre) so the lettering reads over the busy painting
    band = Image.new("L", img.size, 0)
    ImageDraw.Draw(band).rounded_rectangle((470, 400, 1450, 900), radius=120, fill=205)
    band = band.filter(ImageFilter.GaussianBlur(70))
    calm = ImageChops.multiply(img.filter(ImageFilter.GaussianBlur(14)), Image.new("RGB", img.size, (96, 92, 128)))
    return Image.composite(calm, img, band)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--preview", action="store_true")
    args = parser.parse_args()
    if not SOURCE.exists():
        print("missing", SOURCE)
        return 1
    out = grade(Image.open(SOURCE).convert("RGB"))
    OUT.parent.mkdir(parents=True, exist_ok=True)
    out.save(OUT, quality=90, optimize=True)
    if args.preview:
        out.resize((960, 540), Image.LANCZOS).save(OUT.with_name("menu_background_graded_preview.png"))
    print("wrote", OUT, out.size, OUT.stat().st_size, "bytes")
    return 0


if __name__ == "__main__":
    sys.exit(main())
