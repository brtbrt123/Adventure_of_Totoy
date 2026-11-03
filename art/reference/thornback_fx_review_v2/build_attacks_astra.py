"""Review-only richer FX for the THREE existing Stag attacks. No summon/runtime writes.

Run from anywhere: python <path-to-this-file>. Only writes sibling attacks_astra/.
The original rig is imported read-only; the previous build_review.py is NEVER imported.
"""
from __future__ import annotations

import hashlib
import json
import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent / "attacks_astra"
sys.path.insert(0, str(ROOT / "tools" / "art"))
import make_chapter1_creatures_art as R

PALETTE = json.loads((ROOT / "art" / "palette.json").read_text())
C = {p["symbol"]: tuple(bytes.fromhex(p["hex"][1:])) + (255,) for p in PALETTE["colors"]}
ALLOWED = set(C.values())
NONWARNING = ALLOWED - {C[s] for s in PALETTE["reserved"]}
SIZE = (288, 144)
SCALE = 4
PHASES = {"slam": (54, 6, 48), "charge": (56, 36, 40), "roots": (50, 5, 40)}
NAMES = {"slam": "GOLD ANTLER SLAM", "charge": "RED CHARGE / OBSTACLE CRASH", "roots": "RED ROOT ERUPTION"}
FONT = ImageFont.load_default()
NEIGHBOURS = ((1, 0), (-1, 0), (0, 1), (0, -1))
CHECKS: dict = {"status": "PASS", "native_images_checked": 0, "gif_audits": {}, "limitations": [
    "Graphify query failed: No module named graphify; no graph updates attempted outside scoped outputs.",
    "Review choreography only; no Godot runtime/collision/lighting or play-feel validation.",
    "Owner art/motion approval and cross-review remain pending.",
    "20fps samples a 60Hz timeline every three ticks: phase transitions can display up to two ticks late.",
]}


def layer(size: tuple[int, int] = SIZE) -> Image.Image:
    return Image.new("RGBA", size)


def validate(im: Image.Image, warning: bool = False) -> None:
    values = set(im.convert("RGBA").get_flattened_data())
    assert all(p[3] in (0, 255) and (p[3] == 0 or p in (ALLOWED if warning else NONWARNING)) for p in values)
    CHECKS["native_images_checked"] += 1


def save_png(im: Image.Image, relative: str, warning: bool = False) -> None:
    validate(im, warning)
    path = OUT / relative
    path.parent.mkdir(parents=True, exist_ok=True)
    im.save(path)


def stamp(dst: Image.Image, src: Image.Image, at: tuple, anchor: tuple) -> None:
    dst.alpha_composite(src, (round(at[0] - anchor[0]), round(at[1] - anchor[1])))


def text(im: Image.Image, xy: tuple, message: str, color: str = "1") -> None:
    draw = ImageDraw.Draw(im)
    draw.fontmode = "1"  # no font antialiasing / extra palette colours
    draw.text(xy, message, font=FONT, fill=C[color])


def rig_sources() -> tuple[dict, dict]:
    """Capture final visible part ownership in memory; never alter the rig file or pose inputs."""
    masks: dict[int, set] = {}
    original = R.Pic.done

    def capture(pic: R.Pic, ink: str = "0") -> list:
        grid = original(pic, ink)
        masks[id(grid)] = {(x, y) for y in range(pic.h) for x in range(pic.w)
                           if pic.owner[y][x] >= 0 and pic.groups[pic.owner[y][x]] in ("antler", "antlerb", "shard")}
        return grid

    R.Pic.done = capture
    try:
        grids = R.stag_frames()
    finally:
        R.Pic.done = original
    used = ("idle", "slam_raise", "slam_strike", "slam_recover", "charge_tell", "charge_run", "charge_crash", "phase2_roar")
    bodies, horns = {}, {}
    for state in used:
        for index, grid in enumerate(grids[state]):
            key = f"{state}_{index + 1}"
            bodies[key] = R.to_image(grid)
            horns[key] = masks[id(grid)]
            save_png(bodies[key], f"bodies/{key}_right.png")
            mask = layer(bodies[key].size)
            for point in horns[key]:
                mask.putpixel(point, C["p"])
            save_png(mask, f"horn_masks/{key}_right.png")
    # A second uninstrumented call verifies the observer did not change any pose pixel.
    baseline = R.stag_frames()
    for state in used:
        for index, grid in enumerate(baseline[state]):
            assert bodies[f"{state}_{index + 1}"].tobytes() == R.to_image(grid).tobytes()
    CHECKS["body_pose_pixel_parity"] = {"pass": True, "poses": len(bodies), "anchor": list(R.STAG_A)}
    return bodies, horns


def horn_glow(body: Image.Image, mask: set, tick: int, power: float) -> Image.Image:
    result = layer(body.size)
    pulse = (math.sin(tick * .30) + 1) * .5
    for x, y in sorted(mask):
        edge = any((x + dx, y + dy) not in mask for dx, dy in NEIGHBOURS)
        if power > 0 and (edge or (x * 3 + y + tick // 3) % 7 < 2):
            result.putpixel((x, y), C["p" if pulse * power > .67 else "o" if pulse * power > .32 else "u"])
        # Sparse one-pixel contour, only outside the existing opaque silhouette.
        for dx, dy in NEIGHBOURS:
            xx, yy = x + dx, y + dy
            if power > .3 and 0 <= xx < body.width and 0 <= yy < body.height:
                if body.getpixel((xx, yy))[3] == 0 and (xx + yy + tick // 3) % 3 == 0:
                    result.putpixel((xx, yy), C["t"])
    assert all((x, y) in mask or body.getpixel((x, y))[3] == 0
               for y in range(body.height) for x in range(body.width) if result.getpixel((x, y))[3])
    return result


def arc(im: Image.Image, at: tuple, radius: float, color: str, tick: int, squash: float = .36) -> None:
    d = ImageDraw.Draw(im)
    for segment in range(12):
        if (segment + tick // 3) % 4 == 0:
            continue
        a = segment * math.tau / 12
        points = [(round(at[0] + math.cos(a + q * .045) * radius),
                   round(at[1] + math.sin(a + q * .045) * radius * squash)) for q in range(9)]
        d.line(points, fill=C[color])


def dust(im: Image.Image, at: tuple, age: int, seed: int, strength: float = 1) -> None:
    """Small ballistic clods plus low horizontal dust, never a filled screen cloud."""
    if not 0 <= age < 28:
        return
    d = ImageDraw.Draw(im)
    for j in range(11):
        h = R.hsh(j, seed)
        vx = ((h % 101) / 50 - 1) * strength
        vy = (.4 + (h // 101 % 100) / 100) * strength
        x = round(at[0] + vx * age)
        y = round(at[1] - vy * age + age * age * .045)
        if y > at[1] + 5:
            continue
        c = "c" if age < 10 else "b" if age < 18 else "9"
        d.line((x, y, x + (1 if age < 16 else 0), y), fill=C[c])
        if age < 14 and j % 3 == 0:
            d.point((x, y - 1), fill=C["d"])
    if age < 19:
        for side in (-1, 1):
            x = round(at[0] + side * (4 + age * .65))
            y = round(at[1] + 1 - age * .10)
            d.line((x - 3, y, x + 3, y), fill=C["b" if age < 10 else "9"])


def burst(im: Image.Image, at: tuple, age: int, seed: int) -> None:
    if not 0 <= age < 27:
        return
    d = ImageDraw.Draw(im)
    if age < 9:
        for j in range(9):
            a = (j / 8 * math.pi) + math.pi
            r1, r2 = 2 + age * .8, 9 + age * 1.1
            d.line((round(at[0] + math.cos(a) * r1), round(at[1] + math.sin(a) * r1),
                    round(at[0] + math.cos(a) * r2), round(at[1] + math.sin(a) * r2)),
                   fill=C["p" if age < 4 else "u"])
    arc(im, at, 6 + age * 1.5, "j" if age < 8 else "i" if age < 17 else "g", age)
    if age < 17:
        arc(im, at, 3 + age, "u" if age < 9 else "t", age + 3)
    dust(im, at, age, seed, 1.4)


def warning(attack: str, tick: int, windup: int) -> Image.Image:
    im = layer()
    if tick >= windup:
        return im
    d = ImageDraw.Draw(im)
    if attack == "slam":
        p = [(64, 106)] + [(round(64 + 61 * math.cos(-.8 + 1.6 * j / 30)),
                            round(106 + 36 * math.sin(-.8 + 1.6 * j / 30))) for j in range(31)] + [(64, 106)]
        d.line(p, fill=C["y"], width=3)
        d.line(p, fill=C["x"])
        x, y = 116, 107
        d.polygon(((x, y - 4), (x + 3, y), (x, y + 4), (x - 3, y)), outline=C["x"])
    elif attack == "charge":
        d.rectangle((64, 91, 228, 119), outline=C["A"], width=2)
        d.line((64, 91, 228, 91), fill=C["z"])
        d.line((64, 119, 228, 119), fill=C["z"])
        for x in (144, 172, 200):
            d.line((x - 3, 102, x, 105, x - 3, 108), fill=C["z"])
    else:
        d.ellipse((182, 88, 244, 126), outline=C["A"], width=3)
        d.ellipse((182, 88, 244, 126), outline=C["z"])
        for dx, dy in ((-33, 0), (33, 0), (0, -21), (0, 21)):
            d.line((213 + dx - 2, 107 + dy, 213 + dx + 2, 107 + dy), fill=C["z"])
    return im


def select_pose(attack: str, tick: int) -> tuple[str, str, tuple[int, int]]:
    w, s, r = PHASES[attack]
    age = tick - w
    at = (64, 106)
    if attack == "charge":
        at = (round(64 + max(0, min(s, age)) * 3.9), 106)
    if tick >= w + s + r:
        return f"idle_{tick // 12 % 4 + 1}", "RESET", at
    if tick < w:
        key, count = {"slam": ("slam_raise", 4), "charge": ("charge_tell", 5), "roots": ("phase2_roar", 6)}[attack]
        return f"{key}_{min(count - 1, tick * count // w) + 1}", "WINDUP", at
    if age < s:
        if attack == "slam":
            return f"slam_strike_{min(2, age // 2) + 1}", "STRIKE", at
        if attack == "charge":
            return f"charge_run_{age // 3 % 4 + 1}", "STRIKE", at
        return "slam_recover_1", "STRIKE", at
    key, count = ("charge_crash", 3) if attack == "charge" else ("slam_recover", 4)
    return f"{key}_{min(count - 1, (age - s) * count // r) + 1}", "RECOVERY", at


def root_effect(age: int, tick: int) -> Image.Image:
    im = layer()
    if not -15 <= age < 34:
        return im
    d = ImageDraw.Draw(im)
    # Fine branching veins terminate within the warning boundary; no connecting laser across the arena.
    for j in range(7):
        a = j * math.tau / 7 + .2
        points = [(213, 107)]
        for step in range(1, 5):
            r = step * 5
            points.append((round(213 + math.cos(a) * r), round(107 + math.sin(a) * r * .5 + (step % 2))))
        d.line(points, fill=C["8"], width=2)
        if age < 15:
            n = max(1, min(5, (age + 15) // 4))
            d.line(points[:n], fill=C["t" if (tick // 3 + j) % 3 else "u"])
    k = 0 if age < 0 else 1 if age < 1 else 2 if age < 5 else 3 if age < 10 else 4 if age < 24 else 5
    root = R.to_image(R.root_spike(k))
    # Spirit vein stays strictly on the existing root's opaque wood pixels.
    if 1 <= k <= 4:
        for y in range(root.height):
            wood = [x for x in range(9, 17) if root.getpixel((x, y)) in {C[c] for c in "89abc"}]
            if wood and y < 33:
                root.putpixel((max(wood) - (1 if len(wood) > 2 else 0), y), C["u" if y % 4 else "p"])
    stamp(im, root, (213, 107), (12, 36))
    if age >= 0:
        dust(im, (213, 108), age, 73, 1.4)
        if age < 17:
            arc(im, (213, 107), 5 + age * 1.4, "u" if age < 6 else "t", age)
        for j in range(9):
            a = (age + j * 4) % 27
            if age < 23:
                x = round(213 + math.sin(j * 2.3) * (8 + a * .3))
                y = round(100 - a * .85)
                d.point((x, y), fill=C["u" if a < 14 else "t"])
    return im


def encode(name: str, frames: list[Image.Image]) -> None:
    # Exact index mapping: all 36 Totoy colours occupy entries 0..35, even if unused.
    colors = [v for rgba in C.values() for v in rgba[:3]]
    palette = (colors + [0] * 768)[:768]
    lookup = {rgba[:3]: index for index, rgba in enumerate(C.values())}
    indexed = []
    for frame in frames:
        rgb = frame.convert("RGB")
        im = Image.new("P", rgb.size)
        im.putpalette(palette)
        im.putdata([lookup[p] for p in rgb.get_flattened_data()])
        indexed.append(im.resize((im.width * SCALE, im.height * SCALE), Image.Resampling.NEAREST))
    path = OUT / f"{name}.gif"
    indexed[0].save(path, save_all=True, append_images=indexed[1:], duration=50, loop=0, disposal=2, optimize=False)
    with Image.open(path) as gif:
        assert gif.getpalette()[:len(colors)] == colors
        durations, decoded = [], []
        for i in range(gif.n_frames):
            gif.seek(i)
            durations.append(gif.info["duration"])
            rgba = gif.convert("RGBA")
            assert set(rgba.get_flattened_data()) <= ALLOWED
            decoded.append((rgba.copy(), gif.info["duration"]))
        assert sum(durations) == len(frames) * 50
        assert all(ms % 50 == 0 for ms in durations)
        # Compare every decoded held frame to the authored timeline, catching warning palette shifts.
        cursor = 0
        for image, duration in decoded:
            for _ in range(duration // 50):
                expected = frames[cursor].resize(image.size, Image.Resampling.NEAREST)
                assert expected.tobytes() == image.tobytes(), (name, cursor)
                cursor += 1
        assert cursor == len(frames)
        CHECKS["gif_audits"][name] = {"authored_frames": len(frames), "encoded_frames": gif.n_frames,
                                     "duration_ms": sum(durations), "fps": 20, "scale": 4,
                                     "all_36_palette_entries": True, "decoded_pixel_parity": True}


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    protected = [ROOT / "tools/art/make_chapter1_creatures_art.py"]
    protected += sorted((ROOT / "art/reference/glowmoth_stag_animation_review_v1").rglob("*"))
    hashes = {str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in protected if p.is_file()}
    bodies, horns = rig_sources()
    ground = Image.open(ROOT / "presentation/forest/root_hollow_layered_ground.png").convert("RGBA").crop((160, 90, 448, 234))
    validate(ground)
    boulder = Image.open(ROOT / "art/reference/root_hollow_v1/props/root_hollow_boulder.png").convert("RGBA")
    validate(boulder)
    manifest: dict = {"review_only": True, "summoning": False, "fps": 20, "native_stage": SIZE,
                      "body_anchor": list(R.STAG_A), "facing": "right", "native_source": "Totoy36, binary alpha",
                      "layer_order": ["back", "body", "horn", "front", "warning"],
                      "stage_layers_anchor": [0, 0], "horn_layer_anchor": list(R.STAG_A), "clips": {}}
    combined, contact_rows = [], []
    for attack, (w, s, r) in PHASES.items():
        frames, records, history = [], [], []
        for frame_index, tick in enumerate(range(0, w + s + r + 30, 3)):
            key, phase, at = select_pose(attack, tick)
            body, mask = bodies[key], horns[key]
            age = tick - w
            back, front = layer(), layer()
            power = .25 + .75 * min(1, tick / w) if phase == "WINDUP" else 1 if phase == "STRIKE" else max(0, 1 - (age - s) / 24)
            glow = horn_glow(body, mask, tick, power)
            cx = sum(x for x, _ in mask) / len(mask) + at[0] - R.STAG_A[0]
            cy = sum(y for _, y in mask) / len(mask) + at[1] - R.STAG_A[1]
            d = ImageDraw.Draw(back)
            if phase in ("WINDUP", "STRIKE"):
                # Breathing wisps and sparklets cluster around the true moving horn centroid.
                for j in range(7):
                    t = (tick + j * 5) % 27
                    x = round(cx + math.sin(j * 2.4) * (7 + t * .25) - (t * .35 if attack == "charge" else 0))
                    y = round(cy - 4 - t * .45)
                    d.line((x, y, x + 1, y - (1 if t < 8 else 0)), fill=C["o" if t < 7 else "u" if t < 17 else "t"])
                if tick > w // 3:
                    for j in range(2):
                        pts = [(round(cx - 10 + q * 3), round(cy - 9 - j * 3 + math.sin(q * .7 + tick * .15 + j) * 3)) for q in range(7)]
                        d.line(pts, fill=C["t" if j else "u"])
            if phase == "STRIKE" and attack in ("charge", "slam"):
                # Motion echoes of actual antlers, never whole-body ghosts.
                for lag, (oldmask, oldat) in enumerate(reversed(history[-3:]), 1):
                    for x, y in sorted(oldmask):
                        if (x + y) % (lag + 2) == 0:
                            d.point((x + oldat[0] - 36 - lag * 2, y + oldat[1] - 62), fill=C["u" if lag == 1 else "t"])
            if attack == "slam":
                # Impact at the actual lowered horn extremity, using the existing strike pose.
                contact_mask = horns["slam_strike_2"]
                bottom = max(y for _, y in contact_mask)
                contact_xs = [x for x, y in contact_mask if y == bottom]
                impact = (round(sum(contact_xs) / len(contact_xs) + at[0] - 36), bottom + at[1] - 62)
                impact_age = age - 2  # the first pose drives down; second pose contacts the floor
                burst(back, impact, impact_age, 19)
                if 0 <= impact_age < 22:
                    rubble = R.to_image(R.slam_rubble(min(4, impact_age // 5)))
                    stamp(back, rubble, impact, (24, 22))
                if phase == "WINDUP" and tick > 18:
                    dust(back, (52, 107), (tick - 21) % 21, 4, .55)
            elif attack == "charge":
                if phase == "WINDUP" and tick > 12:
                    dust(back, (71, 107), (tick - 15) % 21, 8, .7)
                for born in range(w, w + s, 6):
                    dust(back, (round(64 + (born - w) * 3.9 - 13), 107), tick - born, born, .8)
                if 0 <= age - s < 27:
                    burst(front, (233, 95), age - s, 31)
                    stamp(front, R.to_image(R.boar_crash(min(4, (age - s) // 5))), (233, 106), (20, 30))
            else:
                front.alpha_composite(root_effect(age, tick))
                if phase == "WINDUP":
                    for foot in (52, 73):
                        dust(back, (foot, 107), tick % 25, foot, .45)
            # Front impact FX cannot obscure any opaque body pixels. Horn FX can affect horns only.
            for y in range(body.height):
                for x in range(body.width):
                    xx, yy = x + at[0] - 36, y + at[1] - 62
                    if body.getpixel((x, y))[3] and 0 <= xx < SIZE[0] and 0 <= yy < SIZE[1]:
                        front.putpixel((xx, yy), (0, 0, 0, 0))
            warn = warning(attack, tick, w)
            prefix = f"layers/{attack}/{frame_index:03d}"
            for lname, im in (("back", back), ("horn", glow), ("front", front), ("warning", warn)):
                save_png(im, f"{prefix}_{lname}.png", lname == "warning")
            scene = ground.copy()
            ImageDraw.Draw(scene).ellipse((at[0] - 21, 103, at[0] + 21, 110), fill=C["8"])
            if attack == "charge":
                stamp(scene, boulder, (258, 106), (28, 40))
            scene.alpha_composite(back)
            stamp(scene, body, at, R.STAG_A)
            stamp(scene, glow, at, R.STAG_A)
            scene.alpha_composite(front)
            scene.alpha_composite(warn)  # cues remain exact and unobscured
            ImageDraw.Draw(scene).rectangle((0, 0, 287, 27), fill=C["0"])
            text(scene, (5, 2), NAMES[attack])
            text(scene, (5, 15), f"{phase}  /  tick {tick:03d}  /  REVIEW ONLY", "i")
            # Audit every warning pixel after composition.
            assert all(scene.getpixel((x, y)) == warn.getpixel((x, y))
                       for y in range(28, SIZE[1]) for x in range(SIZE[0]) if warn.getpixel((x, y))[3])
            validate(scene, True)
            frames.append(scene)
            history.append((mask, at))
            records.append({"tick": tick, "phase": phase, "body": f"bodies/{key}_right.png", "body_at": at,
                            "horn_mask": f"horn_masks/{key}_right.png", "layers_prefix": prefix})
        encode(f"thornback_{attack}_fx_4x", frames)
        combined.extend(frames)
        picks = [max(0, w // 6), (w - 1) // 3, math.ceil((w + s // 2) / 3), math.ceil((w + s) / 3), min(len(frames) - 1, math.ceil((w + s + 18) / 3))]
        row = Image.new("RGBA", (SIZE[0] * 5, SIZE[1]))
        for col, index in enumerate(picks):
            row.paste(frames[index], (col * SIZE[0], 0))
            save_png(frames[index].resize((SIZE[0] * 4, SIZE[1] * 4), Image.Resampling.NEAREST), f"stills/{attack}_{col + 1}.png", True)
        contact_rows.append(row)
        manifest["clips"][attack] = {"phase_ticks": [w, s, r], "simulation_hz": 60, "sample_step_ticks": 3,
                                     "pause_ticks_requested": 30, "duration_ms": len(frames) * 50, "frames": records}
    encode("thornback_existing_attacks_fx_4x", combined)
    sheet = Image.new("RGBA", (SIZE[0] * 5, SIZE[1] * 3))
    for row, im in enumerate(contact_rows):
        sheet.paste(im, (0, row * SIZE[1]))
    save_png(sheet.resize((sheet.width * 2, sheet.height * 2), Image.Resampling.NEAREST), "contact_sheet.png", True)
    assert all(hashlib.sha256(Path(p).read_bytes()).hexdigest() == digest for p, digest in hashes.items())
    CHECKS["protected_reference_hashes_unchanged"] = len(hashes)
    CHECKS["horn_overlay_registered_to_visible_rig_parts"] = True
    CHECKS["warning_pixels_unobscured"] = True
    CHECKS["reserved_colors_only_in_warning_layers"] = True
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    (OUT / "validation.json").write_text(json.dumps(CHECKS, indent=2) + "\n", encoding="utf-8")
    (OUT / "README.md").write_text("""# Thornback existing attacks: richer FX / Astra sidecar

REVIEW ONLY. No summoning, runtime installation, gameplay edits or changed body poses.
Rebuild: `python art/reference/thornback_fx_review_v2/build_attacks_astra.py`.

- Gold slam: horn-bound teal/ice pulse, contour light, moving antler echoes, planted-hoof dust, short impact rays, double broken shockwave and ballistic rubble.
- Red charge: horn pulse, sparse spirit wisps and antler trails, repeated hoof dust; existing obstacle-crash ending with directional pale burst, stone chips and ground dust. Boulder/path are preview choreography.
- Red roots: existing phase2 gesture reused as an art proposal only, horn pulse, hoof tremor, local branching spirit veins, existing root silhouette with lit wood vein, erupting clods and rising motes. One target/root; no new mechanics.

Four GIFs (three isolated and one combined), native 288x144 stage enlarged exactly 4x nearest, 20fps. `contact_sheet.png` rows are slam/charge/roots; columns are mid tell / late tell / sampled mid-strike / first sampled recovery / later recovery. `stills/` has those 15 panels at4x. `layers/` contains back, horn, front and warning PNGs for EVERY frame; `bodies/` contains unchanged right-facing poses, `horn_masks/` the visible antler/shard ownership masks. Body/horn anchor is36,62; stage layers anchor0,0. All frame placements and exact source tick values live in `manifest.json`. Only hard alpha and Totoy36, including review composition. Gold/red occur only in warning layers; no blur, additive blending or semitransparency. Body pixels are protected from front FX; actual horn pixels receive glow; warning outlines are composited last and audited. Slam impact is registered to the lowest pixel of the existing second strike antler pose; the burst starts on that pose's source tick.

Source phase ticks remain slam54/6/48, charge56/36/40, roots50/5/40 at60Hz.20fps samples tick0,3,6...: boundaries not divisible by3 display up to2 ticks late, explicitly recorded rather than changing gameplay lengths. Reset pause is review spacing. Effects in recovery are cosmetic; they do not imply lingering damage.

`validation.json`: source palette/binary-alpha, exact uninstrumented-rig body parity, horn registration, reserved-colour isolation, visible warning integrity, preserved full36-entry GIF palettes, ALL decoded GIF pixels against authored frames, and total encoded durations PASS. Hashes confirm the rig and pre-existing Glowmoth/Stag review files remained unchanged. The prior build_review.py is never imported. No credits or image generation used.

Graphify query failed (No module named graphify). No runtime harness or Godot capture: integration, collision alignment, timing feel and in-engine lighting remain unverified. Owner judges aesthetics/motion; cross-review and approval are pending. Representative panels must be inspected separately with view_image after building.
""", encoding="utf-8")
    print(json.dumps({"result": "PASS", "output": str(OUT), "checks": CHECKS}, indent=2))


if __name__ == "__main__":
    main()
