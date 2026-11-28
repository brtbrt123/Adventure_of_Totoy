"""The GIF for the owner from presentation/review/hit_feedback/capture_hits.gd (the TikTok reference, 2026-11-28;
docs/PLAN_hit_feedback.md): the same real fight as the game is NOW, then with the PROPOSED damage numbers, hit counter, bar drain and
the redesigned mob bar and level badge, then the first kills slowed down 3 times. The window is 3x the view: shrunk to the view's own pixels, drawn 2x.

    python tools/art/make_hit_feedback_gif.py
"""
from __future__ import annotations

import os
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
CAPTURES = Path(os.environ.get("APPDATA", "")) / "Godot" / "app_userdata" / "Adventure of Totoy" / "hit_feedback"
OUT = ROOT / "presentation" / "review" / "hit_feedback"
TICK_MS = 1000.0 / 60.0
NOW_PICTURES = 60  # the first 2 s of the fight as it is now
NEW_PICTURES = 150  # the proposed version, 5 s
SLOW = (12, 42)  # the pictures of the first kills, slowed down


def font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    for name in ("segoeui.ttf", "arial.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            continue
    return ImageFont.load_default()


def load(folder: str, picks: range, label: str) -> list[Image.Image]:
    out = []
    for i in picks:
        path = CAPTURES / folder / ("seq_%04d.png" % i)
        if not path.exists():
            break
        image = Image.open(path).convert("RGB")
        view = image.resize((image.width // 3, image.height // 3), Image.Resampling.NEAREST)
        big = view.resize((view.width * 2, view.height * 2), Image.Resampling.NEAREST)
        d = ImageDraw.Draw(big)
        d.rectangle((0, big.height - 22, big.width, big.height), fill=(12, 12, 16))
        d.text((8, big.height - 20), label, fill=(240, 236, 214), font=font(14))
        out.append(big)
    return out


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    frames: list[tuple[Image.Image, int]] = []
    frames += [(f, 2) for f in load("before", range(NOW_PICTURES), "NOW: the game as it is (REAL)")]
    frames += [(f, 2) for f in load("after", range(NEW_PICTURES), "PROPOSED: numbers, hit counter, new mob bar and level (REAL game, not wired yet)")]
    frames += [(f, 6) for f in load("after", range(*SLOW), "PROPOSED, slowed x3")]
    images = [f[0].quantize(colors=96, method=Image.Quantize.MEDIANCUT) for f in frames]
    durations = [max(20, round(f[1] * TICK_MS / 10.0) * 10) for f in frames]
    images[0].save(OUT / "hit_feedback_before_after.gif", save_all=True, append_images=images[1:], duration=durations, loop=0)
    size = (OUT / "hit_feedback_before_after.gif").stat().st_size
    print(f"hit_feedback_before_after.gif: {len(images)} frames, {sum(durations) / 1000:.1f} s, {size / 1e6:.1f} MB")
    return 0


if __name__ == "__main__":
    sys.exit(main())
