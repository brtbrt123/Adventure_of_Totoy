"""Mock-up pictures for the owner: chapter 1 build step 3, the redesigned Mossbound Colossus (docs/PLAN_colossus_step3.md).
Nothing here is game art or game rules. The boss is a STAND-IN cut from the approved concept picture and the attack sizes are
PROPOSED numbers, drawn by the game's own renderer and warning code.

  python tools/art/make_colossus_step3_preview.py mocks    # stand-in boss at three sizes, shots.json, the escape check
  & "C:\\Tools\\Godot\\Godot_v4.7.2-stable_win64_console.exe" --path . --resolution 1152x648 --script res://presentation/review/colossus_step3/capture_mockup.gd
  python tools/art/make_colossus_step3_preview.py sheets   # labelled sheets from those captures

Writes docs/previews/colossus_step3/ (the captures themselves go to user://colossus_step3/).
"""
from __future__ import annotations

import json
import math
import os
import sys
from collections import deque
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "docs" / "previews" / "colossus_step3"
CONCEPT = ROOT / "art" / "reference" / "rootcrown_v1" / "colossus_concept_1.png"
CAPTURES = Path(os.environ.get("APPDATA", "")) / "Godot" / "app_userdata" / "Adventure of Totoy" / "colossus_step3"

SIZES = (102, 116, 130)  # visible height in px (the hero is 34)
CHOSEN = 116
BOSS = (512, 378)  # feet, tests/core/test_rootcrown.gd BOSS_START
BODY_RADIUS = 46.0
HERO_RADIUS = 6.0
HERO_SPEED = 1.0  # px per tick (Tuning.PLAYER_SPEED)
DASH_GAIN = 24.0  # a dash covers 30 px in 6 ticks: 24 more than walking them
PHASE_FACTOR = 0.85  # windup factor in the later phases (Tuning.BOSS_PHASE2_WINDUP_FACTOR)

# Proposed numbers (ticks are 1/60 s). They would live in core/tuning.gd once the owner approves the plan.
NUMBERS = {
    "slam": {"windup": 60, "damage": 30, "radius": 44},
    "sweep": {"windup": 60, "damage": 20, "radius": 112, "half_angle": 50},
    "shards": {"windup": 48, "damage": 15, "length": 240, "width": 16, "spread": 22},
    "stomp": {"windup": 60, "damage": 25, "inner": 76, "outer": 150},
    "combo": {"windup": 54, "damage": 25, "radius": 40, "offset": 56, "gap": 26, "blows": 3},
    "charge": {"windup": 60, "damage": 28, "length": 260, "width": 88},
    "snare": {"windup": 48, "damage": 18, "length": 240, "width": 28, "second_after": 30},
    "boulder": {"windup": 54, "damage": 24, "radius": 40, "ring_inner": 40, "ring_outer": 72, "ring_after": 40, "ring_damage": 12},
    "grab": {"windup": 44, "damage": 26, "length": 220, "width": 20},
    "briar": {"windup": 210, "damage": 8, "every": 30, "lasts": 600, "safe_radius": 170, "centre": [512, 410]},
    "flare": {"waves": [[52, 88, 50], [112, 148, 68], [172, 208, 86]], "wave_damage": 18, "gold_after": 140, "gold_radius": 120, "gold_damage": 35},
}


def palette() -> list[tuple[int, int, int]]:
    data = json.loads((ROOT / "art" / "palette.json").read_text(encoding="utf-8"))
    reserved = set(data["reserved"])
    return [tuple(int(c["hex"][i:i + 2], 16) for i in (1, 3, 5)) for c in data["colors"] if c["symbol"] not in reserved]


def cut_golem() -> Image.Image:
    """The golem of the concept picture without its flat background (flood fill from the border, then the enclosed gaps)."""
    image = Image.open(CONCEPT).convert("RGB").crop((440, 10, 1345, 745))
    width, height = image.size
    pixels = image.load()
    back = pixels[3, 3]

    def near(p: tuple[int, int, int], tolerance: int) -> bool:
        return max(abs(p[i] - back[i]) for i in range(3)) <= tolerance

    outside = bytearray(width * height)

    def flood(seeds: list[tuple[int, int]], tolerance: int) -> list[tuple[int, int]]:
        queue = deque(seeds)
        found: list[tuple[int, int]] = []
        seen = set(seeds)
        while queue:
            x, y = queue.popleft()
            if not near(pixels[x, y], tolerance):
                continue
            found.append((x, y))
            for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if 0 <= nx < width and 0 <= ny < height and (nx, ny) not in seen and not outside[ny * width + nx]:
                    seen.add((nx, ny))
                    queue.append((nx, ny))
        return found

    border = [(x, y) for x in range(width) for y in (0, height - 1)] + [(x, y) for y in range(height) for x in (0, width - 1)]
    for x, y in flood(border, 10):
        outside[y * width + x] = 1
    done: set[tuple[int, int]] = set()
    for y in range(0, height, 2):
        for x in range(0, width, 2):
            if outside[y * width + x] or (x, y) in done or not near(pixels[x, y], 5):
                continue
            region = flood([(x, y)], 7)
            done.update(region)
            if len(region) > 150:  # a gap between the roots or under an arm
                for gx, gy in region:
                    outside[gy * width + gx] = 1
    alpha = Image.frombytes("L", image.size, bytes(0 if o else 255 for o in outside))
    cut = image.convert("RGBA")
    cut.putalpha(alpha)
    return cut.crop(alpha.getbbox())


def stand_in(cut: Image.Image, height: int) -> Image.Image:
    """Scaled to `height` px, snapped to Totoy 36 without gold and red, hard alpha."""
    width = round(cut.width * height / cut.height)
    small = cut.convert("RGBa").resize((width, height), Image.Resampling.BOX).convert("RGBA")
    colours = palette()
    out = Image.new("RGBA", small.size, (0, 0, 0, 0))
    source, target = small.load(), out.load()
    for y in range(height):
        for x in range(width):
            r, g, b, a = source[x, y]
            if a >= 128:
                best = min(colours, key=lambda c: 2 * (c[0] - r) ** 2 + 4 * (c[1] - g) ** 2 + 3 * (c[2] - b) ** 2)
                target[x, y] = (*best, 255)
    return out


# ---- shots ------------------------------------------------------------------------------------------------------------------

def at(dx: float, dy: float) -> list[float]:
    return [BOSS[0] + dx, BOSS[1] + dy]


def aim(from_: list[float], to: list[float]) -> list[float]:
    dx, dy = to[0] - from_[0], to[1] - from_[1]
    length = math.hypot(dx, dy) or 1.0
    return [dx / length, dy / length]


def turn(v: list[float], degrees: float) -> list[float]:
    a = math.radians(degrees)
    return [v[0] * math.cos(a) - v[1] * math.sin(a), v[0] * math.sin(a) + v[1] * math.cos(a)]


def tell(kind: str, shape: str, centre: list[float], direction: list[float] | None = None, **extra: float) -> dict:
    return {"kind": kind, "shape": shape, "center": centre, "direction": direction or [1, 0], **extra}


def attack_shots() -> list[dict]:
    n = NUMBERS
    boss = list(BOSS)
    muzzle = at(0, -48)
    shots: list[dict] = []

    def add(name: str, hero: list[float], tells: list[dict], whole_map: bool = False) -> None:
        shots.append({"name": "attack_" + name, "size": CHOSEN, "hero": hero, "camera": "frame", "outline": True,
                      "telegraphs": tells, "whole_map": whole_map})

    hero = at(96, 44)
    add("slam", hero, [tell("gold", "circle", hero, size=n["slam"]["radius"])])
    hero = at(62, 56)
    add("sweep", hero, [tell("gold", "cone", boss, aim(boss, hero), size=n["sweep"]["radius"],
                             half_angle=math.radians(n["sweep"]["half_angle"]))])
    hero = at(132, 52)
    forward = aim(muzzle, hero)
    add("shards", hero, [tell("red", "line", muzzle, turn(forward, d), size=n["shards"]["length"], width=n["shards"]["width"])
                         for d in (-n["shards"]["spread"], 0, n["shards"]["spread"])])
    hero = at(96, 40)
    add("stomp", hero, [tell("red", "ring", boss, aim(boss, hero), size=n["stomp"]["outer"], inner_size=n["stomp"]["inner"])])
    hero = at(66, 40)
    forward = aim(boss, hero)
    add("combo", hero, [tell("gold", "circle", [hero[0] + forward[0] * n["combo"]["offset"] * i,
                                                 hero[1] + forward[1] * n["combo"]["offset"] * i], size=n["combo"]["radius"])
                        for i in range(n["combo"]["blows"])])
    hero = at(150, 56)
    add("charge", hero, [tell("red", "line", boss, aim(boss, hero), size=n["charge"]["length"], width=n["charge"]["width"])])
    hero = at(122, 66)
    add("snare", hero, [tell("red", "line", boss, aim(boss, hero), size=n["snare"]["length"], width=n["snare"]["width"]),
                        tell("red", "line", boss, aim(boss, at(150, -6)), size=n["snare"]["length"], width=n["snare"]["width"])])
    hero = at(136, 42)
    add("boulder", hero, [tell("red", "circle", hero, size=n["boulder"]["radius"]),
                          tell("red", "ring", hero, aim(boss, hero), size=n["boulder"]["ring_outer"], inner_size=n["boulder"]["ring_inner"])])
    hero = at(146, 34)
    add("grab", hero, [tell("gold", "line", boss, aim(boss, hero), size=n["grab"]["length"], width=n["grab"]["width"])])
    centre = n["briar"]["centre"]
    add("briar", at(230, 90), [tell("red", "ring", centre, [0, 1], size=620, inner_size=n["briar"]["safe_radius"])], True)
    hero = at(100, 56)
    add("flare_waves", hero, [tell("red", "ring", boss, aim(boss, hero), size=outer, inner_size=inner)
                              for inner, outer, _ in n["flare"]["waves"]])
    hero = at(86, 48)
    add("flare_gold", hero, [tell("gold", "circle", boss, size=n["flare"]["gold_radius"])])
    return shots


def view_shots() -> list[dict]:
    shots: list[dict] = []

    def add(name: str, size: int, hero: list[float], camera: str, outline: bool = True) -> None:
        shots.append({"name": name, "size": size, "hero": hero, "camera": camera, "outline": outline,
                      "telegraphs": [], "whole_map": False})

    for size in SIZES:
        add(f"size_{size}", size, at(104, 36), "frame")
    for name, hero in (("below", at(24, 70)), ("beside", at(190, 24)), ("corner", at(-170, 62))):
        for camera in ("follow", "frame"):
            add(f"camera_{name}_{camera}", CHOSEN, hero, camera)
    add("behind_hidden", CHOSEN, at(14, -34), "frame", False)
    add("behind_outline", CHOSEN, at(14, -34), "frame", True)
    return shots


# ---- the escape check ---------------------------------------------------------------------------------------------------------

def escape_rows() -> list[tuple[str, float, int]]:
    """Per red or gold hit: the longest way out of its warning (px) against the warning's ticks. The worst hero spot is taken."""
    n, body, hero = NUMBERS, BODY_RADIUS + HERO_RADIUS, HERO_RADIUS
    sweep = n["sweep"]
    half = math.radians(sweep["half_angle"])
    sweep_way = max(min(d * math.sin(half) + hero, sweep["radius"] + hero - d) for d in
                    [body + 0.5 * i for i in range(int((sweep["radius"] + hero - body) * 2) + 1)])
    stomp = n["stomp"]
    inside, outside = stomp["inner"] - hero, stomp["outer"] + hero
    stomp_way = max(min(d - inside, outside - d) for d in [inside + 0.5 * i for i in range(int((outside - inside) * 2) + 1)])
    shards = n["shards"]
    shard_way = 0.0
    for d in range(int(body), shards["length"]):  # beside the middle lane, past the outer one
        outer = d * math.sin(math.radians(shards["spread"]))
        gap = outer - shards["width"] - 2 * hero
        shard_way = max(shard_way, shards["width"] / 2 + hero if gap > 0 else outer + shards["width"] / 2 + hero)
    centre = n["briar"]["centre"]
    corner = max(math.hypot(x - centre[0], y - centre[1]) for x in (200, 824) for y in (238, 582))
    return [
        ("slam", n["slam"]["radius"] + hero, n["slam"]["windup"]),
        ("sweep", sweep_way, sweep["windup"]),
        ("shards", shard_way, shards["windup"]),
        ("stomp", stomp_way, stomp["windup"]),
        ("combo (first blow)", n["combo"]["radius"] + hero, n["combo"]["windup"]),
        ("charge", n["charge"]["width"] / 2 + hero, n["charge"]["windup"]),
        ("snare", n["snare"]["width"] / 2 + hero, n["snare"]["windup"]),
        ("boulder", n["boulder"]["radius"] + hero, n["boulder"]["windup"]),
        ("grab", n["grab"]["width"] / 2 + hero, n["grab"]["windup"]),
        ("briar ring", corner - n["briar"]["safe_radius"], n["briar"]["windup"]),
    ]


def print_escape() -> None:
    print("escape check (walk = ticks x 1 px; a dash adds 24)")
    print(f"  {'attack':20} {'way out':>8} {'phase 1':>16} {'later (x0.85)':>16}")
    for name, way, windup in escape_rows():
        cells = []
        for factor in (1.0, 1.0 if name == "briar ring" else PHASE_FACTOR):
            ticks = round(windup * factor)
            walk = ticks * HERO_SPEED
            verdict = "walk" if walk >= way else ("dash" if walk + DASH_GAIN >= way else "NO")
            cells.append(f"{ticks:3d}t {verdict:>4}")
        print(f"  {name:20} {way:7.1f}  {cells[0]:>16} {cells[1]:>16}")
    waves = NUMBERS["flare"]["waves"]
    strips = [inner - outer - 2 * HERO_RADIUS for (_, outer, _), (inner, _, _) in zip(waves, waves[1:])]
    print("  song flare: safe strips between the rings", ", ".join(f"{s:.0f} px" for s in strips))


def make_mocks() -> None:
    (OUT / "mock").mkdir(parents=True, exist_ok=True)
    cut = cut_golem()
    for size in SIZES:
        image = stand_in(cut, size)
        image.save(OUT / "mock" / f"colossus_stand_in_{size}.png")
        print(f"stand-in {size}: {image.width}x{image.height}")
    attacks = attack_shots()
    bright = [{**shot, "name": "bright_" + shot["name"], "bright": True} for shot in attacks
              if shot["name"] in ("attack_shards", "attack_sweep")]
    spec = {"boss": list(BOSS), "body_radius": BODY_RADIUS, "shots": view_shots() + attacks + bright}
    (OUT / "shots.json").write_text(json.dumps(spec, indent=1) + "\n", encoding="utf-8")
    print(f"shots.json: {len(spec['shots'])} shots")
    print_escape()


# ---- sheets -------------------------------------------------------------------------------------------------------------------

def font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    for name in ("C:/Windows/Fonts/segoeui.ttf", "C:/Windows/Fonts/arial.ttf"):
        if Path(name).exists():
            return ImageFont.truetype(name, size)
    return ImageFont.load_default()


def screen(name: str) -> Image.Image:
    """One capture as the 384x216 screen at 2x."""
    shot = Image.open(CAPTURES / f"{name}.png").convert("RGB")
    if name.endswith("briar"):  # the whole map at 1x, fitted into the same cell
        scale = min(768 / shot.width, 432 / shot.height)
        fitted = shot.resize((round(shot.width * scale), round(shot.height * scale)), Image.Resampling.LANCZOS)
        cell = Image.new("RGB", (768, 432), (12, 12, 16))
        cell.paste(fitted, ((768 - fitted.width) // 2, (432 - fitted.height) // 2))
        return cell
    return shot.resize((384, 216), Image.Resampling.NEAREST).resize((768, 432), Image.Resampling.NEAREST)


def sheet(file: str, title: str, columns: int, cells: list[tuple[str, str, str]]) -> None:
    """cells: (capture name, heading, note)."""
    cell_w, cell_h, head, gap, top = 768, 432, 70, 12, 96
    rows = math.ceil(len(cells) / columns)
    image = Image.new("RGB", (columns * cell_w + (columns + 1) * gap, top + rows * (cell_h + head + gap) + gap), (22, 20, 28))
    draw = ImageDraw.Draw(image)
    draw.text((gap, 10), title, font=font(34), fill=(244, 236, 214))
    draw.text((gap, 56), "MOCK-UP, not gameplay: stand-in boss cut from the concept picture, proposed sizes, the game's own night "
              "light and warnings, HUD hidden.", font=font(22), fill=(167, 205, 224))
    for i, (name, heading, note) in enumerate(cells):
        x = gap + (i % columns) * (cell_w + gap)
        y = top + (i // columns) * (cell_h + head + gap)
        draw.text((x, y + 2), heading, font=font(26), fill=(244, 236, 214))
        draw.text((x, y + 38), note, font=font(21), fill=(198, 191, 170))
        image.paste(screen(name), (x, y + head))
    image.save(OUT / file)
    print("wrote", OUT / file)


def make_sheets() -> None:
    sheet("step3_size.png", "1. How big is the Colossus?  (Totoy is 34 px tall)", 3, [
        ("size_102", "A: 102 px tall (3x Totoy)", "Easiest to fit on screen."),
        ("size_116", "B: 116 px tall (3.4x), recommended", "Fits the planned 144 px frame."),
        ("size_130", "C: 130 px tall (3.8x)", "Needs a wider frame; cut off sooner."),
    ])
    cells = []
    for name, where in (("below", "Totoy below it"), ("beside", "Totoy far to the side"), ("corner", "Totoy far, low left")):
        cells.append((f"camera_{name}_follow", f"TODAY: {where}", "The camera follows Totoy only."))
        cells.append((f"camera_{name}_frame", f"PROPOSED: {where}", "The camera slides toward the boss; Totoy never nears an edge."))
    sheet("step3_camera.png", "2. The camera in the fight", 2, cells)
    sheet("step3_behind.png", "3. When Totoy walks behind it", 2, [
        ("behind_hidden", "Without a fix", "Totoy disappears behind the body."),
        ("behind_outline", "PROPOSED: Totoy outlined over the body", "A pale outline plus every other pixel of Totoy (solid or clear only)."),
    ])
    n = NUMBERS

    def note(key: str, kind: str, extra: str) -> str:
        return f"{kind}  |  warning {n[key]['windup'] / 60:.1f} s  |  damage {n[key]['damage']}  |  {extra}"

    sheet("step3_attacks_kept.png", "4. The six attacks it has today, at the new size", 3, [
        ("attack_slam", "1 Gold Slam", note("slam", "GOLD: parry", "a circle where you stand")),
        ("attack_sweep", "2 Sweep", note("sweep", "GOLD: parry", "an arm swing")),
        ("attack_shards", "3 Red Shards", note("shards", "RED: dodge", "three lanes")),
        ("attack_stomp", "4 Red Stomp", note("stomp", "RED: dodge", "hug it or get far")),
        ("attack_combo", "5 Gold Combo (phase 2+)", note("combo", "GOLD x3", "blows 0.4 s apart")),
        ("attack_charge", "6 Red Charge (phase 2+)", note("charge", "RED: dodge", "it rushes the lane")),
    ])
    flare = n["flare"]
    sheet("step3_attacks_new.png", "5. The five new attacks", 3, [
        ("attack_snare", "7 Root Snare (all phases)", note("snare", "RED", "a second line follows your dodge")),
        ("attack_boulder", "8 Boulder Toss (phase 2+)", note("boulder", "RED", f"crater, then a ring {n['boulder']['ring_after'] / 60:.1f} s later")),
        ("attack_grab", "9 Heartroot Grab (phase 2+)", note("grab", "GOLD: parry", "parry it to crack its posture")),
        ("attack_briar", "10 Briar Ring (at 60% and 25%), whole map", note("briar", "RED edge", "only the circle stays safe, 10 s")),
        ("attack_flare_waves", "11a Song Flare, waves (phase 3)",
         f"RED  |  {flare['waves'][0][2] / 60:.1f} to {flare['waves'][-1][2] / 60:.1f} s  |  stand in a gap or dash through  |  damage {flare['wave_damage']}"),
        ("attack_flare_gold", "11b Song Flare, last blow",
         f"GOLD  |  {flare['gold_after'] / 60:.1f} s after the start  |  parry it to break its posture  |  damage {flare['gold_damage']}"),
    ])
    sheet("step3_warnings.png", "6. Warnings on the night floor", 2, [
        ("attack_shards", "Today's red warning", "The night light dims it."),
        ("bright_attack_shards", "PROPOSED: glowing edge", "Same shape, drawn unlit and 2 px wide."),
        ("attack_sweep", "Today's gold warning", "The night light dims it."),
        ("bright_attack_sweep", "PROPOSED: glowing edge", "Same shape, drawn unlit and 2 px wide."),
    ])


def main() -> int:
    step = sys.argv[1] if len(sys.argv) > 1 else ""
    if step == "mocks":
        make_mocks()
    elif step == "sheets":
        make_sheets()
    else:
        print(__doc__)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
