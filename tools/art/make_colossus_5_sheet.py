"""The sheet for the owner from presentation/review/colossus_5/capture_5.gd (build step 5, docs/PLAN_colossus_step5.md): the real fight
in Rootcrown at night with the PROPOSED effects of the six attacks kept from the arena drawn over it (a mock: nothing is wired).

    & "C:\\Tools\\Godot\\Godot_v4.7.2-stable_win64_console.exe" --path . --resolution 1152x648 --script res://presentation/review/colossus_5/capture_5.gd
    python tools/art/make_colossus_5_sheet.py
    (with `-- --gifs` on the capture:) python tools/art/make_colossus_5_sheet.py --gifs   # one GIF per attack
"""
from __future__ import annotations

import json
import shutil
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, str(Path(__file__).resolve().parent))
import make_colossus_3a_sheets as base  # noqa: E402

base.OUT = base.ROOT / "presentation" / "review" / "colossus_5"
base.CAPTURES = base.CAPTURES.parent / "colossus_5"

CELLS = [
    ("5_01_slam_flash", "Gold Slam: the floor cracks", "PROPOSED (mock): PixelFX ground-slam, stone with the song's blue, on the real circle."),
    ("5_02_slam_rocks", "...rocks erupt, first dust", "PROPOSED (mock): 1 s, then gone (its later dust column is cut)."),
    ("5_03_combo", "Gold Combo: the same on each blow", "PROPOSED (mock): one ground-slam per real circle as it strikes."),
    ("5_04_stomp", "Red Stomp: shards across its ring", "PROPOSED (mock): the approved stone shards round the middle of the real ring."),
    ("5_05_shards", "Red Shards: shards race along the lanes", "PROPOSED (mock): the approved stone shards along the three real lanes."),
    ("5_06_sweep", "Gold Sweep: dust along its arc", "PROPOSED (mock): PixelFX blunt-hit as pale dust across the real cone, in swing order."),
    ("5_07_charge_running", "Red Charge: a dust trail...", "PROPOSED (mock): that pale dust where its feet pass along the real lane."),
    ("5_08_charge_trail", "...along the whole lane", "PROPOSED (mock)."),
]


GIFS = [("gold_slam", "Gold Slam"), ("gold_combo", "Gold Combo"), ("red_stomp", "Red Stomp"), ("red_shards", "Red Shards"),
        ("red_charge", "Red Charge")]
TICK_MS = 1000.0 / 60.0


def font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    for name in ("segoeui.ttf", "arial.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            continue
    return ImageFont.load_default()


def gifs() -> int:
    """One GIF per attack from the capture's --gifs pictures (every 2 ticks): the real speed, then the blow slowed down 3 times. The
    window is 3x the view: shrunk to the view's own pixels and drawn 2x."""
    for attack, title in GIFS:
        folder = base.CAPTURES / f"gif_{attack}"
        meta = json.loads((folder / "meta.json").read_text(encoding="utf-8"))
        shots = sorted(folder.glob("seq_*.png"))
        pictures = []
        for shot in shots:
            image = Image.open(shot).convert("RGB")
            view = image.resize((image.width // 3, image.height // 3), Image.Resampling.NEAREST)
            pictures.append(view.resize((view.width * 2, view.height * 2), Image.Resampling.NEAREST))

        def labelled(image: Image.Image, label: str) -> Image.Image:
            out = image.copy()
            d = ImageDraw.Draw(out)
            d.rectangle((0, out.height - 22, out.width, out.height), fill=(12, 12, 16))
            d.text((8, out.height - 20), f"{title}  {label}   REAL game; MOCK: the proposed effect (not wired)", fill=(240, 236, 214), font=font(14))
            return out

        frames = [(labelled(p, "real speed"), 2) for p in pictures]
        start = max(0, int(meta["first_blow"]) - 6)
        frames += [(labelled(p, "slowed x3"), 6) for p in pictures[start:start + 30]]
        images = [f[0].quantize(colors=255, method=Image.Quantize.MEDIANCUT) for f in frames]
        durations = [max(20, round(f[1] * TICK_MS / 10.0) * 10) for f in frames]
        name = f"colossus_5_{attack}.gif"
        images[0].save(base.OUT / name, save_all=True, append_images=images[1:], duration=durations, loop=0, disposal=1)
        print(f"{name}: {len(images)} frames, {sum(durations) / 1000:.1f} s")
    return 0


def main() -> int:
    if "--gifs" in sys.argv:
        base.OUT.mkdir(parents=True, exist_ok=True)
        return gifs()
    base.OUT.mkdir(parents=True, exist_ok=True)
    for name, _, _ in CELLS:
        shutil.copyfile(base.CAPTURES / f"{name}.png", base.OUT / f"{name}.png")
    base.sheet("colossus_5_effects.png", "Step 5: effects for the six attacks kept from the arena",
               "Real captures of the fight; the effects are a MOCK drawn over them (not wired). PixelFX in Totoy 36 with hard alpha.", 4, CELLS)
    return 0


if __name__ == "__main__":
    sys.exit(main())
