"""Review material for build step 4a (the Colossus's body, docs/PLAN_colossus_step4.md): the rigged poses of
tools/art/rig_colossus.py on a sheet, and two GIFs at game speed (60 ticks a second): the appearing (asleep, the song wakes, the fists
burst out, it pulls itself out of the ground and roars) and a Gold Slam.

They are PREVIEWS composited by Python on the Rootcrown ground painting (presentation/forest/rootcrown_layered_ground.png) with
Totoy's idle frames and the approved stone-landing dust (art/build/sprites/): not the game renderer, so no night light, no props,
no shadows. Nothing here is wired into the game.

    python tools/art/make_colossus_4a_review.py
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, str(Path(__file__).resolve().parent))
import rig_colossus as rig  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "presentation" / "review" / "colossus_4a"
GROUND = ROOT / "presentation" / "forest" / "rootcrown_layered_ground.png"
SPRITES = ROOT / "art" / "build" / "sprites"
FRAMES = json.loads((ROOT / "art" / "build" / "sprites.json").read_text(encoding="utf-8"))["frames"]
BOSS = (512, 378)  # its feet in Rootcrown (tests/core/test_rootcrown.gd BOSS_START)
HERO = (424, 414)
VIEW = (320, 222, 704, 438)  # 384x216 round it, as the fight camera frames it
SCALE = 3
TICK_MS = 1000.0 / 60.0

# The appearing, proposed: the wake grows from 90 to 150 ticks (2.5 s; it cannot be hurt meanwhile). (tick, pose) keys; the rig
# draws the in-betweens every 4 ticks. Dust bursts where each fist breaks the ground.
APPEAR_KEYS = [(0, "appear_2"), (14, "appear_2"), (24, "appear_3"), (38, "appear_3"), (48, "appear_4"), (60, "appear_4"),
               (72, "appear_5"), (88, "appear_6"), (102, "appear_7"), (114, "appear_8"), (124, "appear_9"), (134, "appear_10"),
               (150, "appear_10")]
# Where each fist breaks out: stone shards burst up (the approved fx_colossus_shard); where the fists plant: the first, dust-only
# frames of the stone landing (fx_colossus_stone_land 1..10, before its ring spreads). (tick, x from its feet, effect)
APPEAR_DUST = [(20, -44, "shard"), (22, -32, "shard"), (24, -54, "shard"), (44, 44, "shard"), (46, 32, "shard"), (48, 54, "shard"),
               (70, -60, "dust"), (70, 60, "dust")]
SHAKE_TICKS = [(18, 30), (42, 54), (66, 76)]
SLAM_KEYS = [(0, "idle_1"), (24, "slam_windup_mid"), (40, "slam_windup"), (60, "slam_windup"), (64, "slam_strike"),
             (72, "slam_strike"), (86, "slam_recover"), (98, "idle_1")]


def poses() -> dict[str, dict]:
    extra = {
        "slam_windup_mid": rig.F(body=(0, -1), arm_l=80.0, arm_r=-80.0, head=(0, -1), light="lit"),
        "slam_recover": rig.F(body=(0, 3), arm_l=-10.0, arm_r=10.0, head=(0, 2), light="lit"),
    }
    return {**rig.POSES, **extra}


def lerp(a: dict, b: dict, f: float) -> dict:
    def mix(x: object, y: object) -> object:
        if isinstance(x, tuple) and all(isinstance(v, (int, float)) for v in x + tuple(y)):
            return tuple(round(xi + (yi - xi) * f) for xi, yi in zip(x, y))
        if isinstance(x, (int, float)) and not isinstance(x, bool):
            return x + (y - x) * f if isinstance(x, float) or isinstance(y, float) else round(x + (y - x) * f)
        return x if f < 0.5 else y
    return {k: mix(a[k], b[k]) for k in a}


class Painter:
    def __init__(self) -> None:
        self.layers = rig.split(rig.cut_golem())
        self.cache: dict[str, tuple[Image.Image, tuple[int, int]]] = {}

    def body(self, pose: dict) -> tuple[Image.Image, tuple[int, int]]:
        key = json.dumps(pose, sort_keys=True, default=list)
        if key not in self.cache:
            grid, feet = rig.render(self.layers, pose)
            rows, at = rig.trim(grid, feet)
            self.cache[key] = (rig.to_image(rows), at)
        return self.cache[key]


def sprite(name: str) -> tuple[Image.Image, tuple[int, int]]:
    f = FRAMES[name]
    return Image.open(SPRITES / f"{name}.png").convert("RGBA"), (int(f["ax"]), int(f["ay"]))


def scene(painter: Painter, pose: dict, tick: int, dust: list[tuple[int, int]], shake: int, label: str) -> Image.Image:
    ground = Image.open(GROUND).convert("RGBA").crop(VIEW)
    hero, hero_at = sprite("hero2_idle_right_%d" % (tick // 12 % 4 + 1))
    ground.alpha_composite(hero, (HERO[0] - VIEW[0] - hero_at[0], HERO[1] - VIEW[1] - hero_at[1]))
    body, at = painter.body(pose)
    ground.alpha_composite(body, (BOSS[0] - VIEW[0] - at[0] + shake, BOSS[1] - VIEW[1] - at[1]))
    for start, dx, kind in dust:
        n = (tick - start) // (4 if kind == "shard" else 2) + 1
        if 1 <= n <= (11 if kind == "shard" else 10):
            fx, fx_at = sprite(("fx_colossus_shard_%d" if kind == "shard" else "fx_colossus_stone_land_%d") % n)
            ground.alpha_composite(fx, (BOSS[0] + dx - VIEW[0] - fx_at[0], BOSS[1] + 2 - VIEW[1] - fx_at[1]))
    big = ground.resize((ground.width * SCALE, ground.height * SCALE), Image.Resampling.NEAREST).convert("RGB")
    d = ImageDraw.Draw(big)
    d.rectangle((0, 0, big.width, 26), fill=(12, 12, 16))
    d.text((8, 5), label, fill=(240, 236, 214), font=font(15))
    return big


def font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    for name in ("segoeui.ttf", "arial.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            continue
    return ImageFont.load_default()


def at_tick(keys: list[tuple[int, str]], table: dict[str, dict], tick: int) -> dict:
    for (t0, a), (t1, b) in zip(keys, keys[1:]):
        if t0 <= tick < t1:
            f = (tick - t0) / float(t1 - t0)
            return lerp(table[a], table[b], round(f * 3) / 3.0)  # in-betweens at thirds: what a frame set can hold
    return table[keys[-1][1]]


def gif(name: str, frames: list[tuple[Image.Image, int]]) -> None:
    merged: list[tuple[Image.Image, int]] = []
    for image, ticks in frames:
        if merged and merged[-1][0].tobytes() == image.tobytes():
            merged[-1] = (merged[-1][0], merged[-1][1] + ticks)
        else:
            merged.append((image, ticks))
    images = [m[0].quantize(colors=255, method=Image.Quantize.MEDIANCUT) for m in merged]
    durations = [max(20, round(m[1] * TICK_MS / 10.0) * 10) for m in merged]
    images[0].save(OUT / name, save_all=True, append_images=images[1:], duration=durations, loop=0, disposal=1)
    print(f"{name}: {len(images)} frames, {sum(durations) / 1000:.1f} s")


def appear_gif(painter: Painter, table: dict[str, dict]) -> None:
    frames: list[tuple[Image.Image, int]] = []
    asleep = table["appear_1"]
    for tick in range(0, 60, 4):
        frames.append((scene(painter, asleep, tick, [], 0, "PREVIEW (Python, not the game renderer): asleep in Rootcrown"), 4))
    for tick in range(0, 150, 2):
        shake = 0
        for a, b in SHAKE_TICKS:
            if a <= tick < b:
                shake = 1 if tick // 2 % 2 else -1
        pose = at_tick(APPEAR_KEYS, table, tick)
        frames.append((scene(painter, pose, tick, APPEAR_DUST, shake, "PREVIEW: it appears (2.5 s, cannot be hurt yet)"), 2))
    for tick in range(150, 240, 4):
        pose = table["idle_1"] if tick // 30 % 2 == 0 else table["idle_2"]
        frames.append((scene(painter, pose, tick, [], 0, "PREVIEW: then the fight"), 4))
    gif("colossus_4a_appear.gif", frames)


def slam_gif(painter: Painter, table: dict[str, dict]) -> None:
    frames: list[tuple[Image.Image, int]] = []
    for tick in range(0, 110, 2):
        shake = (1 if tick // 2 % 2 else -1) if 44 <= tick < 60 or 62 <= tick < 72 else 0
        dust = [(62, -46, "dust"), (62, 46, "dust")]
        frames.append((scene(painter, at_tick(SLAM_KEYS, table, tick), tick, dust, shake, "PREVIEW: Gold Slam (windup 1 s, the blow, recover)"), 2))
    gif("colossus_4a_slam.gif", frames)


SHEET_ROWS = [
    ("Key poses", ["idle_1", "slam_windup", "slam_strike", "posture_broken", "roar"]),
    ("Appearing (1/2)", ["appear_1", "appear_2", "appear_3", "appear_4", "appear_5"]),
    ("Appearing (2/2)", ["appear_6", "appear_7", "appear_8", "appear_9", "appear_10"]),
]


def sheet(painter: Painter, table: dict[str, dict]) -> None:
    cw, ch = 240 * 3, 170 * 3
    head = 90
    out = Image.new("RGB", (cw * 5, head + len(SHEET_ROWS) * (ch + 40)), (18, 18, 24))
    d = ImageDraw.Draw(out)
    d.text((16, 10), "Step 4a: the Colossus's body, rigged from the approved concept", fill=(240, 236, 214), font=font(30))
    d.text((16, 52), "PREVIEW composited by Python on the Rootcrown ground painting, 3x (not the game renderer: no night light, props or "
           "shadows). Totoy for scale in the first cell. Nothing is wired yet.", fill=(190, 186, 170), font=font(17))
    ground = Image.open(GROUND).convert("RGBA")
    hero, hero_at = sprite("hero2_idle_right_1")
    for r, (title, names) in enumerate(SHEET_ROWS):
        y0 = head + r * (ch + 40)
        d.text((16, y0 + 4), title, fill=(240, 236, 214), font=font(22))
        for c, name in enumerate(names):
            x0 = c * cw
            tile = ground.crop((BOSS[0] - 120, BOSS[1] - 148, BOSS[0] + 120, BOSS[1] + 22)).copy()
            body, at = painter.body(table[name])
            if c == 0 and r == 0:
                tile.alpha_composite(hero, (120 - 98 - hero_at[0], 148 - hero_at[1]))
            tile.alpha_composite(body, (120 - at[0] + (12 if c == 0 and r == 0 else 0), 148 - at[1]))
            big = tile.resize((tile.width * 3, tile.height * 3), Image.Resampling.NEAREST).convert("RGB")
            out.paste(big, (x0, y0 + 36))
            d.rectangle((x0, y0 + 36, x0 + cw - 1, y0 + 36 + ch - 1), outline=(18, 18, 24), width=4)
            d.rectangle((x0 + 4, y0 + 40, x0 + cw - 5, y0 + 66), fill=(12, 12, 16))
            d.text((x0 + 10, y0 + 43), f"{name}: {table[name]['note']}", fill=(240, 236, 214), font=font(16))
    out.save(OUT / "colossus_4a_poses.png")
    print("colossus_4a_poses.png", out.size)


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    painter = Painter()
    table = poses()
    sheet(painter, table)
    appear_gif(painter, table)
    slam_gif(painter, table)
    return 0


if __name__ == "__main__":
    sys.exit(main())
