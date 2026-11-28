"""Review material for build step 4b (every body frame of the Colossus, docs/PLAN_colossus_step4.md): two sheets of all frames and
one GIF per attack and state at its real timing (core/tuning.gd COLOSSUS_ATTACKS; 60 ticks a second).

Reads the frames written by `python tools/art/rig_colossus.py --frames` (art/reference/colossus_body_v1/frames/). Like 4a these
are PREVIEWS composited by Python on the Rootcrown ground painting with Totoy's idle frames (art/build/sprites/): not the game
renderer (no night light, props, shadows, warnings or attack effects; the Boulder Toss shows its stone, held at the fists'
attachment points). Nothing is wired into the game. Also checks every frame against the art rules (Totoy 36 without gold or red,
hard alpha, sizes in multiples of 8) and fails if one breaks them.

    python tools/art/rig_colossus.py --frames
    python tools/art/make_colossus_4b_review.py
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
import make_colossus_4a_review as base  # noqa: E402  (ground, hero, font, the GIF writer)

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "art" / "reference" / "colossus_body_v1" / "frames"
OUT = ROOT / "presentation" / "review" / "colossus_4b"
META = json.loads((SRC / "frames.json").read_text(encoding="utf-8"))
FRAMES = META["frames"]
VIEW_W, VIEW_H = 272, 200  # the GIFs' window round the boss, drawn 2x
FEET_Y = 152  # its feet this far below the window's top: room for fists raised overhead
SCALE = 2
HERO_DX = -112  # Totoy stands this far left of its feet, a little lower
PHASE = 0.85  # COLOSSUS_PHASE2_WINDUP_FACTOR: the Combo (phase 2) and the Song Flare (phase 3) wind up faster


def f(name: str) -> str:
    return f"colossus_{name.rsplit('_', 1)[0]}_right_{name.rsplit('_', 1)[1]}"


def idle(ticks: int) -> list[tuple]:
    out = []
    names = ["idle_1", "idle_2", "idle_3", "idle_4"]
    k = 0
    while ticks > 0:
        step = min(12, ticks)
        out.append((names[k % 4], step))
        ticks -= step
        k += 1
    return out


def tremble(name: str, ticks: int) -> list[tuple]:
    """A held windup that shakes on its last 12 ticks (as the game does in its last fifth)."""
    still = max(0, ticks - 12)
    out = [(name, still)] if still else []
    out += [(name, 2, {"shake": 1 if k % 2 else -1}) for k in range(min(12, ticks) // 2)]
    return out


def combo() -> list[tuple]:
    w = round(54 * PHASE)
    out = [("slam_windup_1", w // 4), ("slam_windup_2", w // 4)] + tremble("slam_windup_3", w - 2 * (w // 4))
    for blow in range(3):
        out += [("slam_strike_1", 2), ("slam_strike_2", 10 if blow < 2 else 12, {"shake": 2})]
        if blow < 2:
            out += [("slam_windup_2", 6), ("slam_windup_3", 8)]
    return out + [("slam_recover_1", 16)] + idle(14)


def flare() -> list[tuple]:
    w = round(50 * PHASE)
    out = [("shards_windup_1", 14), ("shards_windup_2", w - 14)]
    for wave in range(3):  # the three rings (the game draws them; here the body bursts on each)
        out += [("shards_strike_1", 6, {"shake": 1})]
        if wave < 2:
            out += [("shards_windup_2", 12)]
    out += [("roar_1", 140 - 50 - 42), ("roar_2", 8, {"shake": 2})]  # the gold blow at 140
    return out + [("shards_recover_1", 22)] + idle(22)


SEQUENCES: dict[str, tuple[str, list[tuple]]] = {
    "idle": ("Idle (it breathes; the song glows)", idle(96)),
    "walk": ("Walk (it knuckle-walks; it moves slowly toward Totoy)", [(f"walk_{k % 6 + 1}", 8, {"move": 4}) for k in range(12)]),
    "slam": ("Gold Slam (windup 60, the blow, recover 26)",
             [("slam_windup_1", 15), ("slam_windup_2", 15)] + tremble("slam_windup_3", 30)
             + [("slam_strike_1", 2), ("slam_strike_2", 12, {"shake": 2}), ("slam_recover_1", 14)] + idle(12)),
    "combo": ("Gold Combo (phase 2: three blows 26 ticks apart)", combo()),
    "sweep": ("Gold Sweep (windup 60, the swing, recover 24)",
              [("sweep_windup_1", 25)] + tremble("sweep_windup_2", 35) + [("sweep_strike_1", 2), ("sweep_strike_2", 10, {"shake": 1}),
                                                                        ("sweep_recover_1", 12)] + idle(12)),
    "shards": ("Red Shards (windup 48, the burst, recover 22)",
               [("shards_windup_1", 18)] + tremble("shards_windup_2", 30) + [("shards_strike_1", 14, {"shake": 1}), ("shards_recover_1", 12)] + idle(10)),
    "stomp": ("Red Stomp (windup 60, the stomp, recover 28)",
              [("stomp_windup_1", 25)] + tremble("stomp_windup_2", 35) + [("stomp_strike_1", 12, {"shake": 2}), ("stomp_recover_1", 14)] + idle(14)),
    "charge": ("Red Charge (windup 60, 260 px in 14 ticks: the camera follows it, recover 34)",
               [("charge_windup_1", 25)] + tremble("charge_windup_2", 35)
               + [(f"charge_run_{k % 2 + 1}", 2, {"scroll": -37}) for k in range(7)] + [("charge_recover_1", 18)] + idle(16)),
    "snare": ("Root Snare (windup 48, a fist into the ground; the second lane 30 later)",
              tremble("snare_windup_1", 48) + [("snare_strike_1", 8, {"shake": 1}), ("snare_windup_2", 24), ("snare_strike_2", 10, {"shake": 1}),
                                               ("slam_recover_1", 14)] + idle(12)),
    "boulder": ("Boulder Toss (windup 54: it tears up a stone and throws it at Totoy)",
                [("boulder_windup_1", 20, {"stone": "rip"})] + [(n, t, {**extra, "stone": "held"}) for n, t, *rest in tremble("boulder_windup_2", 34)
                                                                for extra in [rest[0] if rest else {}]]
                + [("boulder_strike_1", 2, {"stone": "fly", "flight": k}) for k in range(5)] + [("slam_recover_1", 15)] + idle(15)),
    "grab": ("Heartroot Grab (windup 44, the lunge; the root-arm is an effect, recover 32)",
             [("grab_windup_1", 18)] + tremble("grab_windup_2", 26) + [("grab_strike_1", 12), ("grab_recover_1", 16)] + idle(16)),
    "flare": ("Song Flare (phase 3: three rings, then the gold blow at 140)", flare()),
    "broken": ("Posture broken (90 ticks, the counter window: the song flickers)",
               [(f"broken_{k % 2 + 1}", 8) for k in range(11)] + [("slam_recover_1", 12)] + idle(12)),
    "stagger": ("Stagger (Reaper's Coil stun, 45 ticks)", [(f"stagger_{k % 2 + 1}", 4) for k in range(11)] + idle(12)),
    "roar": ("Roar (a new phase; the Briar Ring rises meanwhile, 48 ticks)", [(f"roar_{k % 2 + 1}", 6, {"shake": 1}) for k in range(8)] + idle(12)),
    "death": ("Death (40 ticks: it breaks apart into stone and moss; the last frame held here)",
              [(f"death_{k + 1}", 5, {"shake": 1} if k < 3 else {}) for k in range(8)] + [("death_8", 40)]),
}


def appear_sequence() -> list[tuple]:
    ticks = META["appear_ticks"] + [150]
    out: list[tuple] = [("sleep_1", 30), ("sleep_2", 30)]
    for k in range(len(ticks) - 1):
        out.append((f"appear_{k + 1}", ticks[k + 1] - ticks[k], {"shake": 1} if 14 <= ticks[k] < 76 else {}))
    return out + idle(48)


SEQUENCES["appear"] = ("The appearing (asleep, then 2.5 s; it cannot be hurt yet)", appear_sequence())


class Stage:
    def __init__(self) -> None:
        self.ground = Image.open(base.GROUND).convert("RGBA")
        self.images = {n: Image.open(SRC / f"{n}.png").convert("RGBA") for n in FRAMES}
        self.stone = base.sprite("fx_colossus_stone_spin_1")

    def draw(self, name: str, tick: int, extra: dict, scroll: float, move: float, label: str) -> Image.Image:
        """One picture: the view round the boss's start, slid by `scroll` (the camera following the charge); the boss `move` px
        left of its start (walking toward Totoy)."""
        left = round(base.BOSS[0] - VIEW_W / 2 + scroll)
        top = base.BOSS[1] - FEET_Y
        view = self.ground.crop((left, top, left + VIEW_W, top + VIEW_H)).copy()
        hero, hero_at = base.sprite("hero2_idle_right_%d" % (tick // 12 % 4 + 1))
        view.alpha_composite(hero, (round(VIEW_W / 2 + HERO_DX - scroll) - hero_at[0], FEET_Y + 26 - hero_at[1]))
        frame = FRAMES[f(name)]
        shake = int(extra.get("shake", 0)) * (1 if tick // 2 % 2 else -1)
        at = (round(VIEW_W / 2 - move) - frame["ax"] + shake, FEET_Y - frame["ay"])
        view.alpha_composite(self.images[f(name)], at)
        stone = extra.get("stone")
        if stone in ("held", "fly"):
            fl, fr = frame["attach"]["fist_l"], frame["attach"]["fist_r"]
            hand = ((fl[0] + fr[0]) / 2.0 + VIEW_W // 2 + shake, (fl[1] + fr[1]) / 2.0 + FEET_Y - 10)
            img, img_at = self.stone
            if stone == "fly":  # thrown at where Totoy stands (the game draws the real flight and its shadow)
                k = (int(extra["flight"]) + 1) / 6.0
                target = (VIEW_W / 2 + HERO_DX + 8, FEET_Y + 20)
                hand = (hand[0] + (target[0] - hand[0]) * k, hand[1] + (target[1] - hand[1]) * k - 40 * k * (1 - k) * 4)
            view.alpha_composite(img, (round(hand[0]) - img_at[0], round(hand[1]) - img_at[1]))
        big = view.resize((VIEW_W * SCALE, VIEW_H * SCALE), Image.Resampling.NEAREST).convert("RGB")
        d = ImageDraw.Draw(big)
        d.rectangle((0, 0, big.width, 22), fill=(12, 12, 16))
        d.text((6, 3), label, fill=(240, 236, 214), font=base.font(13))
        d.rectangle((0, big.height - 20, big.width, big.height), fill=(12, 12, 16))
        d.text((6, big.height - 18), f"PREVIEW (Python)  {f(name)}", fill=(190, 186, 170), font=base.font(12))
        return big


def write_gif(stage: Stage, key: str, title: str, steps: list[tuple]) -> None:
    frames: list[tuple[Image.Image, int]] = []
    tick = 0
    scroll = 0.0
    move = 0.0
    for step in steps:
        name, ticks = step[0], int(step[1])
        extra = step[2] if len(step) > 2 else {}
        if ticks <= 0:
            continue
        for part in range(0, ticks, 2 if extra.get("shake") else ticks):
            span = min(ticks - part, 2 if extra.get("shake") else ticks)
            frames.append((stage.draw(name, tick + part, extra, scroll, move, title), span))
        tick += ticks
        scroll += float(extra.get("scroll", 0))  # px per step: the camera follows the charge, the ground slides under it
        move += float(extra.get("move", 0))  # px per step toward Totoy
    base.OUT = OUT
    base.gif(f"colossus_4b_{key}.gif", frames)


SHEETS = [
    ("colossus_4b_frames_fight.png", "Step 4b: every body frame of the fight",
     ["idle", "walk", "slam_windup", "slam_strike", "slam_recover", "sweep_windup", "sweep_strike", "sweep_recover", "shards_windup",
      "shards_strike", "shards_recover", "stomp_windup", "stomp_strike", "stomp_recover", "charge_windup", "charge_run",
      "charge_recover", "snare_windup", "snare_strike", "boulder_windup", "boulder_strike", "grab_windup", "grab_strike",
      "grab_recover", "broken", "stagger", "roar"]),
    ("colossus_4b_frames_appear_death.png", "Step 4b: asleep, the appearing and the death", ["sleep", "appear", "death"]),
]


def write_sheet(stage: Stage, file: str, title: str, sets: list[str]) -> None:
    names = [n for s in sets for n in FRAMES if n.startswith(f"colossus_{s}_right_")]
    cols = 7
    cw, ch = 240 * SCALE, 158 * SCALE
    head = 70
    rows = -(-len(names) // cols)
    out = Image.new("RGB", (cols * cw, head + rows * ch), (18, 18, 24))
    d = ImageDraw.Draw(out)
    d.text((12, 8), title + f" ({len(names)} frames)", fill=(240, 236, 214), font=base.font(26))
    d.text((12, 42), "PREVIEW composited by Python on the Rootcrown ground painting, 2x (not the game renderer). Rigged from the "
           "approved concept by tools/art/rig_colossus.py. Not wired yet.", fill=(190, 186, 170), font=base.font(15))
    for i, name in enumerate(names):
        x0, y0 = (i % cols) * cw, head + (i // cols) * ch
        tile = stage.ground.crop((base.BOSS[0] - 120, base.BOSS[1] - 136, base.BOSS[0] + 120, base.BOSS[1] + 22)).copy()
        fr = FRAMES[name]
        tile.alpha_composite(stage.images[name], (120 - fr["ax"], 136 - fr["ay"]))
        big = tile.resize((tile.width * SCALE, tile.height * SCALE), Image.Resampling.NEAREST).convert("RGB")
        out.paste(big, (x0, y0))
        d.rectangle((x0, y0, x0 + cw - 1, y0 + ch - 1), outline=(18, 18, 24), width=3)
        d.rectangle((x0 + 3, y0 + 3, x0 + cw - 4, y0 + 40), fill=(12, 12, 16))
        d.text((x0 + 8, y0 + 5), name.replace("colossus_", "").replace("_right", ""), fill=(240, 236, 214), font=base.font(14))
        d.text((x0 + 8, y0 + 22), fr["note"][:58], fill=(190, 186, 170), font=base.font(12))
    out.save(OUT / file)
    print(file, out.size)


def check_rules() -> None:
    """Every frame: Totoy 36 colours only, no gold or red, hard alpha, width and height in multiples of 8 (CLAUDE.md, art rules)."""
    data = json.loads((ROOT / "art" / "palette.json").read_text(encoding="utf-8"))
    allowed = {tuple(int(c["hex"][i:i + 2], 16) for i in (1, 3, 5)) for c in data["colors"] if c["symbol"] not in data["reserved"]}
    for name in FRAMES:
        image = Image.open(SRC / f"{name}.png").convert("RGBA")
        assert image.width % 8 == 0 and image.height % 8 == 0 and image.width <= 256 and image.height <= 256, (name, image.size)
        for _, (r, g, b, a) in image.getcolors(maxcolors=1 << 20):
            assert a in (0, 255), (name, "soft alpha", a)
            assert a == 0 or (r, g, b) in allowed, (name, "colour", (r, g, b))
    print(f"rules: {len(FRAMES)} frames pass (Totoy 36 without gold and red, hard alpha, multiples of 8)")


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    check_rules()
    stage = Stage()
    for file, title, sets in SHEETS:
        write_sheet(stage, file, title, sets)
    for key, (title, steps) in SEQUENCES.items():
        write_gif(stage, key, title, steps)
    return 0


if __name__ == "__main__":
    sys.exit(main())
