"""Before/after GIF of the Colossus's Gold Sweep (the owner's "Yes, rework it", 2026-11-28; docs/PLAN_colossus_step4.md): the swing in
the game now (art/build/sprites) next to the reworked one (tools/art/rig_colossus.py --set sweep --to sweep_v2), at the real timing
(core/tuning.gd: windup 60, active 5, recover 24 ticks), then once more slowed down 4 times. A PREVIEW composited by Python on the
Rootcrown ground painting with Totoy for scale (not the game renderer).

    python tools/art/rig_colossus.py --set sweep --to sweep_v2
    python tools/art/make_colossus_sweep_review.py
    python tools/art/make_colossus_sweep_review.py --game   # the GIF from presentation/review/colossus_sweep/capture_sweep.gd
"""
from __future__ import annotations

import json
import os
import sys
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
import make_colossus_4a_review as base  # noqa: E402  (ground, hero, font)

ROOT = Path(__file__).resolve().parents[2]
NEW = ROOT / "art" / "reference" / "colossus_body_v1" / "sweep_v2"
OUT = ROOT / "presentation" / "review" / "colossus_sweep"
OLD_FRAMES = json.loads((ROOT / "art" / "build" / "sprites.json").read_text(encoding="utf-8"))["frames"]
NEW_FRAMES = json.loads((NEW / "frames.json").read_text(encoding="utf-8"))["frames"]
VIEW_W, VIEW_H, FEET_Y, SCALE = 260, 190, 150, 2
WINDUP, RECOVER, LEAD = 60, 24, 20  # ticks; LEAD: standing before the attack


def old(tick: int) -> tuple[str, int]:
    """The game's sweep now: windup frames over 3/4 of the warning, the falling frame 3 ticks before the blow, then the blow."""
    hit = WINDUP
    if tick < 0 or tick >= hit + 5 + RECOVER:
        return "colossus_idle_right_1", 0
    if tick < hit - 3:
        p = tick / hit
        return f"colossus_sweep_windup_right_{min(2, 1 + int(p / 0.75 * 2))}", (1 if p > 0.8 and tick // 2 % 2 else -1 if p > 0.8 else 0)
    if tick < hit:
        return "colossus_sweep_strike_right_1", 0
    if tick < hit + 5:
        return "colossus_sweep_strike_right_2", 0
    return ("colossus_sweep_recover_right_1" if tick - hit - 5 < 16 else "colossus_idle_right_1"), 0


SWING = [-4, -2, 0, 4]  # the reworked swing: each strike frame's first tick from the blow


def new(tick: int) -> tuple[str, int]:
    hit = WINDUP
    if tick < 0 or tick >= hit + 5 + RECOVER:
        return "colossus_idle_right_1", 0
    if tick < hit + SWING[0]:
        p = tick / hit
        return f"colossus_sweep_windup_right_{min(2, 1 + int(p / 0.75 * 2))}", (1 if p > 0.8 and tick // 2 % 2 else -1 if p > 0.8 else 0)
    if tick < hit + 5:
        n = max(i for i, start in enumerate(SWING) if tick >= hit + start) + 1
        return f"colossus_sweep_strike_right_{n}", 0
    r = tick - hit - 5
    return (f"colossus_sweep_recover_right_{1 + r * 2 // 16}" if r < 16 else "colossus_idle_right_1"), 0


def panel(ground: Image.Image, frame: str, shake: int, tick: int, reworked: bool) -> Image.Image:
    left, top = base.BOSS[0] - VIEW_W // 2, base.BOSS[1] - FEET_Y
    view = ground.crop((left, top, left + VIEW_W, top + VIEW_H)).copy()
    hero, hero_at = base.sprite("hero2_idle_right_%d" % (tick // 12 % 4 + 1))
    view.alpha_composite(hero, (VIEW_W // 2 - 104 - hero_at[0], FEET_Y + 18 - hero_at[1]))
    if reworked and frame in NEW_FRAMES:
        image, meta = Image.open(NEW / f"{frame}.png").convert("RGBA"), NEW_FRAMES[frame]
    else:
        image, meta = Image.open(base.SPRITES / f"{frame}.png").convert("RGBA"), OLD_FRAMES[frame]
    view.alpha_composite(image, (VIEW_W // 2 - meta["ax"] + shake, FEET_Y - meta["ay"]))
    return view.resize((VIEW_W * SCALE, VIEW_H * SCALE), Image.Resampling.NEAREST)


def picture(ground: Image.Image, tick: int, label: str) -> Image.Image:
    a, sa = old(tick)
    b, sb = new(tick)
    out = Image.new("RGB", (VIEW_W * SCALE * 2 + 8, VIEW_H * SCALE + 50), (12, 12, 16))
    out.paste(panel(ground, a, sa, tick, False).convert("RGB"), (0, 50))
    out.paste(panel(ground, b, sb, tick, True).convert("RGB"), (VIEW_W * SCALE + 8, 50))
    d = ImageDraw.Draw(out)
    d.text((8, 4), f"Gold Sweep  {label}  (PREVIEW, Python; tick {tick - WINDUP:+d} from the blow)", fill=(240, 236, 214), font=base.font(16))
    d.text((8, 27), "NOW in the game", fill=(190, 186, 170), font=base.font(14))
    d.text((VIEW_W * SCALE + 16, 27), "REWORKED: arc across the chest, body twist, smear", fill=(190, 186, 170), font=base.font(14))
    return out


CAPTURES = Path(os.environ.get("APPDATA", "")) / "Godot" / "app_userdata" / "Adventure of Totoy" / "colossus_sweep"


def game_gif() -> int:
    """The real captures (every 2 ticks) as one GIF: run A (he takes the blow), then run B (he parries), each labelled, at the real
    speed, then run A again slowed down 3 times. The window is 3x the view: shrunk to the view's own pixels, drawn 2x."""
    real = "--real" in sys.argv
    prefix = "real_" if real else ""
    note = "REAL game, wired" if real else "REAL game; MOCK: the reworked swing and the proposed dust"
    runs = [(prefix + "a", "He takes the blow"), (prefix + "b", "He parries it (gold)")]
    frames: list[tuple[Image.Image, int]] = []

    def load(folder: str, label: str, ticks: int) -> None:
        for shot in sorted((CAPTURES / folder).glob("seq_*.png")):
            image = Image.open(shot).convert("RGB")
            view = image.resize((image.width // 3, image.height // 3), Image.Resampling.NEAREST)
            big = view.resize((view.width * 2, view.height * 2), Image.Resampling.NEAREST)
            d = ImageDraw.Draw(big)
            d.rectangle((0, big.height - 22, big.width, big.height), fill=(12, 12, 16))
            d.text((8, big.height - 20), f"{label}   {note}", fill=(240, 236, 214), font=base.font(14))
            frames.append((big, ticks))

    for folder, label in runs:
        load(folder, label, 2)
    load(prefix + "a", "He takes the blow, slowed x3", 6)
    base.OUT = OUT
    base.gif("colossus_sweep_wired.gif" if real else "colossus_sweep_in_game.gif", frames)
    return 0


def main() -> int:
    if "--game" in sys.argv:
        return game_gif()
    OUT.mkdir(parents=True, exist_ok=True)
    ground = Image.open(base.GROUND).convert("RGBA")
    frames: list[tuple[Image.Image, int]] = []
    for tick in range(-LEAD, WINDUP + 5 + RECOVER + LEAD, 2):  # real speed: 2 ticks a picture
        frames.append((picture(ground, tick, "real speed"), 2))
    for tick in range(WINDUP - 12, WINDUP + 5 + RECOVER):  # the swing slowed down 4 times: every tick, 4 ticks long
        frames.append((picture(ground, tick, "slowed x4"), 8))
    base.OUT = OUT
    base.gif("colossus_sweep_before_after.gif", frames)
    strip = Image.new("RGB", (VIEW_W * SCALE * 4, VIEW_H * SCALE), (12, 12, 16))
    for i, tick in enumerate([WINDUP - 4, WINDUP - 2, WINDUP, WINDUP + 4]):
        f, s = new(tick)
        strip.paste(panel(ground, f, s, tick, True).convert("RGB"), (i * VIEW_W * SCALE, 0))
    strip.save(OUT / "colossus_sweep_swing_frames.png")
    print("colossus_sweep_swing_frames.png")
    return 0


if __name__ == "__main__":
    sys.exit(main())
