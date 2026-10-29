"""Native-pixel, review-only weapon paths fitted to the game's existing poses.

python art/reference/weapon_paths_review_v1/build_review.py
Reads the installed sprite atlas and editable weapon geometry; changes no runtime asset.
"""
from __future__ import annotations

import json
import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / "tools/art"))
import import_dagger_sprites as D
import import_chain_scythe_sprites as S
import make_chain_scythe_art as C
import make_hero_lean_sheet as L

PAL = json.loads((ROOT / "art/palette.json").read_text())
P = {c["symbol"]: tuple(bytes.fromhex(c["hex"].lstrip("#"))) + (255,) for c in PAL["colors"]}
ATLAS = Image.open(ROOT / "art/build/sprites.png").convert("RGBA")
FRAMES = json.loads((ROOT / "art/build/sprites.json").read_text())["frames"]
SCYTHE = json.loads((ROOT / "art/build/chain_scythe_sprites_manifest.json").read_text())["sprites"]
SIZE = (128, 96)
ANCHOR = (48, 78)
SCALE = 4
MS = 80
WEAPONS = {
    "katana": {"prefix": "hero2", "name": "Black Katana", "swings": 3, "ramp": ["k", "v", "j", "p"], "width": 2.0},
    "daggers": {"prefix": "totoy_dagger", "name": "Dual Daggers", "swings": 4, "ramp": ["l", "n", "o", "p"], "width": 1.4},
    "scythe": {"prefix": "totoy_scythe", "name": "Chain Scythe", "swings": 3, "ramp": ["k", "t", "u", "p"], "width": 3.2},
}


def sprite(name: str) -> Image.Image:
    f = FRAMES[name]
    img = ATLAS.crop((f["x"], f["y"], f["x"] + f["w"], f["y"] + f["h"]))
    out = Image.new("RGBA", SIZE)
    out.alpha_composite(img, (ANCHOR[0] - int(f["ax"]), ANCHOR[1] - int(f["ay"])))
    return out


def katana_geometry(name: str) -> list[dict]:
    rows = [r.strip() for r in (ROOT / "art/src" / f"{name}.txt").read_text().splitlines() if r.strip() and not r.startswith("#")]
    grid = [list(r) for r in rows]
    mask = L.katana_mask(grid)
    grip = L.find_grip(grid, mask)
    assert grip is not None, name
    blade = [(x, y) for x, y in mask if grid[y][x] in L.KATANA]
    tip = max(blade, key=lambda p: math.dist(grip, p))
    f = FRAMES[name]
    return [{"grip": [grip[0] - f["ax"], grip[1] - f["ay"]], "tip": [tip[0] - f["ax"], tip[1] - f["ay"]], "lead": True}]


def geometry(weapon: str, swing: int, n: int) -> list[dict]:
    name = f'{WEAPONS[weapon]["prefix"]}_attack{swing}_right_{n}'
    if weapon == "katana":
        return katana_geometry(name)
    if weapon == "scythe":
        hands = SCYTHE[f"totoy_scythe_attack{swing}_right"]["hands"][n - 1]
        spec = S.HERO[(f"attack{swing}", n)]["scythe"]
        pommel, head = C.scythe_geometry(spec, hands)
        length = math.dist(pommel, head)
        unit = ((head[0] - pommel[0]) / length, (head[1] - pommel[1]) / length)
        blade = C.blade_pixels(head, unit, spec["side"], spec["blade"], 80, 1.25)
        tip = max((p for p, c in blade.items() if c == C.BLADE_TIP), key=lambda p: math.dist(head, p))
        return [{"grip": hands[spec["grip"][0]], "tip": list(tip), "lead": True}]
    source = f"hero2_attack{min(swing, 3)}_right_{n}"
    # The dagger finisher has its own lean, using the same source as its existing importer.
    for state, src, frame_n, phase in D.frame_names():
        if state == f"attack{swing}" and frame_n == n:
            source = src
            break
    lf = D.lean_body(f"attack{swing}", source, n)
    key = source if swing < 4 else f"swing4:{n}"
    hands = D.lean_hands(key, lf)
    result = []
    for x, y, angle, layer, lead in hands:
        grip = [x - lf.anchor[0], y - lf.anchor[1]]
        radius = 7 if n in (3, 4) and lead else 6
        radians = math.radians(angle)
        result.append({"grip": grip, "tip": [grip[0] + math.cos(radians) * radius, grip[1] + math.sin(radians) * radius], "lead": bool(lead)})
    return result


def mix(a: float, b: float, t: float) -> float:
    return a + (b - a) * t


def swept_points(before: dict, after: dict, clockwise: bool = False) -> list[tuple[float, float]]:
    a, b = before["grip"], after["grip"]
    ta, tb = before["tip"], after["tip"]
    aa = math.atan2(ta[1] - a[1], ta[0] - a[0])
    ab = math.atan2(tb[1] - b[1], tb[0] - b[0])
    delta = (ab - aa + math.pi) % math.tau - math.pi
    if clockwise and delta < 0:
        delta += math.tau
    ra, rb = math.dist(a, ta), math.dist(b, tb)
    out = []
    for i in range(41):
        t = i / 40
        angle = aa + delta * t
        radius = mix(ra, rb, t)
        out.append((ANCHOR[0] + mix(a[0], b[0], t) + math.cos(angle) * radius,
                    ANCHOR[1] + mix(a[1], b[1], t) + math.sin(angle) * radius))
    return out


def trail(weapon: str, previous: list[dict], current: list[dict], age: int = 0, clockwise: bool = False) -> Image.Image:
    im = Image.new("RGBA", SIZE)
    d = ImageDraw.Draw(im)
    cfg = WEAPONS[weapon]
    for hand, after in enumerate(current):
        if not after["lead"]:
            continue
        pts = swept_points(previous[hand], after, clockwise)
        for i in range(1, len(pts)):
            t = i / (len(pts) - 1)
            # Taper toward the oldest part of the trace. It remains a short path close to the blade.
            radius = max(.45, cfg["width"] * (.15 + .85 * math.sin(t * math.pi / 2)))
            width = max(1, round(radius * 2 - age))
            p0 = tuple(round(v) for v in pts[i - 1])
            p1 = tuple(round(v) for v in pts[i])
            d.line((p0, p1), fill=P[cfg["ramp"][max(0, 1 - age)]], width=width)
            if age < 2 and t > .25:
                d.line((p0, p1), fill=P[cfg["ramp"][2]], width=max(1, width - 2))
            if age == 0 and t > .64:
                d.line((p0, p1), fill=P[cfg["ramp"][3]], width=1)
        if age == 0:
            # A few directional glints, rather than a detached impact burst.
            for i in (25, 32):
                x, y = (round(v) for v in pts[i])
                d.point((x + (1 if weapon == "daggers" else 2), y - 2), fill=P[cfg["ramp"][2]])
    if age:
        # Dissolve by removing whole pixels. No partially transparent trail pixels.
        px = im.load()
        for y in range(SIZE[1]):
            for x in range(SIZE[0]):
                if (x * 3 + y * 5) % (age + 2) == 0:
                    px[x, y] = (0, 0, 0, 0)
    return im


def check(im: Image.Image) -> None:
    allowed = {c for k, c in P.items() if k not in PAL["reserved"]}
    assert all(pixel[3] == 0 or pixel in allowed for pixel in im.getdata()), "palette, hard alpha or reserved colour violation"
    bounds = im.getbbox()
    if bounds:
        assert bounds[0] > 0 and bounds[1] > 0 and bounds[2] < SIZE[0] and bounds[3] < SIZE[1], "clipped effect"


def ground() -> Image.Image:
    im = Image.new("RGBA", SIZE, P["2"])
    d = ImageDraw.Draw(im)
    for y in range(SIZE[1]):
        for x in range(SIZE[0]):
            if (x * 31 + y * 53 + x * y) % 139 < 5:
                d.point((x, y), fill=P["3"])
    d.ellipse((ANCHOR[0] - 12, ANCHOR[1] - 3, ANCHOR[0] + 12, ANCHOR[1] + 2), fill=P["8"])
    return im


def build(weapon: str) -> tuple[list[Image.Image], list[Image.Image], list[dict]]:
    cfg = WEAPONS[weapon]
    idle = sprite(f'{cfg["prefix"]}_idle_right_1')
    blank = Image.new("RGBA", SIZE)
    poses, effects, records = [idle] * 5, [blank] * 5, []
    folder = OUT / "frames" / weapon
    folder.mkdir(parents=True, exist_ok=True)
    for swing in range(1, cfg["swings"] + 1):
        anchors = [geometry(weapon, swing, n) for n in range(1, 7)]
        records.append({"swing": swing, "blade_geometry_feet_relative": anchors,
                        "sweep_direction": "clockwise_overhead" if weapon == "katana" and swing == 3 else "shortest"})
        peak = None
        early = None
        for n in range(1, 7):
            effect = blank
            if n in (3, 4):
                # The overhead finisher crosses >180 degrees between raised and low poses. The shortest
                # rotation goes backwards under the body; explicitly follow the forward/downward sword cut.
                overhead = weapon == "katana" and swing == 3 and n == 3
                effect = trail(weapon, anchors[n - 2], anchors[n - 1], clockwise=overhead)
                if n == 3:
                    early = effect.copy()
                elif early is not None:
                    # The first active segment lingers as a dimmer path behind the current blade.
                    older = early.copy()
                    px = older.load()
                    for y in range(SIZE[1]):
                        for x in range(SIZE[0]):
                            if px[x, y][3]:
                                px[x, y] = P[cfg["ramp"][1]]
                    older.alpha_composite(effect)
                    effect = older
                peak = effect if n == 4 else peak
            elif n in (5, 6) and peak is not None:
                effect = peak.copy()
                # Leave the afterimage where the blade actually passed, rather than swinging it back in recovery.
                fade = n - 4
                px = effect.load()
                for y in range(SIZE[1]):
                    for x in range(SIZE[0]):
                        if px[x, y][3]:
                            px[x, y] = (0, 0, 0, 0) if (x + y * 3) % 4 < fade else P[cfg["ramp"][max(0, 2 - fade)]]
            check(effect)
            if effect.getbbox():
                effect.save(folder / f"path_swing{swing}_{n}.png")
            poses.append(sprite(f'{cfg["prefix"]}_attack{swing}_right_{n}'))
            effects.append(effect)
        poses.extend([poses[-1]] * 2)
        effects.extend([blank] * 2)
    while len(poses) < 48:
        poses.append(idle)
        effects.append(blank)
    visuals = []
    for pose, effect in zip(poses, effects):
        preview = ground()
        preview.alpha_composite(effect)
        preview.alpha_composite(pose)  # trails behind the actor, original blade stays readable in front
        visuals.append(preview)
    sheet = Image.new("RGBA", (SIZE[0] * 4, SIZE[1] * cfg["swings"]))
    for swing in range(1, cfg["swings"] + 1):
        for col, n in enumerate(range(3, 7)):
            path = folder / f"path_swing{swing}_{n}.png"
            if path.exists():
                sheet.alpha_composite(Image.open(path), (col * SIZE[0], (swing - 1) * SIZE[1]))
    sheet.save(OUT / f"{weapon}_paths.png")
    loops = [im.resize((512, 384), Image.Resampling.NEAREST).convert("RGB") for im in visuals]
    loops[0].save(OUT / f"{weapon}_paths.gif", save_all=True, append_images=loops[1:], duration=MS, loop=0, disposal=2, optimize=False)
    return visuals, effects, records


def main() -> None:
    data = {weapon: build(weapon) for weapon in WEAPONS}
    font = ImageFont.truetype(str(ROOT / "presentation/fonts/Cinzel.ttf"), 24)
    frames = []
    for t in range(48):
        im = Image.new("RGB", (1536, 440), P["0"][:3])
        d = ImageDraw.Draw(im)
        for column, weapon in enumerate(WEAPONS):
            d.text((column * 512 + 24, 10), WEAPONS[weapon]["name"], font=font, fill=P["1"][:3])
            tile = data[weapon][0][t].resize((512, 384), Image.Resampling.NEAREST)
            im.paste(tile, (column * 512, 48))
        frames.append(im)
    frames[0].save(OUT / "weapon_paths_review.gif", save_all=True, append_images=frames[1:], duration=MS, loop=0, disposal=2, optimize=False)
    (OUT / "paths.json").write_text(json.dumps({"review_only": True, "native_cell": SIZE, "anchor": ANCHOR, "preview_ms": MS, "weapons": {weapon: data[weapon][2] for weapon in WEAPONS}}, indent=2) + "\n")
    print("REVIEW OK: all 3 weapons, 10 combo swings; blade geometry matched, FX palette/hard alpha/unclipped checks pass")


if __name__ == "__main__":
    main()
