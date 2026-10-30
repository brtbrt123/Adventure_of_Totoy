"""Review choreography only. Extends existing pixel rigs; never edits runtime art or rules."""
from __future__ import annotations
import hashlib
import importlib.util
import json
import math
import sys
from pathlib import Path
from PIL import Image, ImageDraw

sys.dont_write_bytecode = True
OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]
spec = importlib.util.spec_from_file_location("astra_fx", OUT.parent / "thornback_fx_review_v2/build_attacks_astra.py")
A = importlib.util.module_from_spec(spec)
spec.loader.exec_module(A)
A.OUT = OUT / "sources"
R, C = A.R, A.C
SIZE = (384, 216)
SITES = [(83, 58), (178, 61), (270, 57), (338, 82), (58, 164), (143, 169), (241, 172), (328, 178)]
PROTECTED = OUT.parent / "glowmoth_stag_animation_review_v1"

def hashes() -> dict:
    return {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in PROTECTED.glob("glowmoth_*.gif")}

def blank() -> Image.Image:
    return Image.new("RGBA", SIZE)

def cue_sector(im: Image.Image, at: tuple, radius: float, color: str) -> None:
    points = [(round(at[0] + math.cos(-.95 + i * 1.9 / 70) * radius),
               round(at[1] + math.sin(-.95 + i * 1.9 / 70) * radius)) for i in range(71)]
    d = ImageDraw.Draw(im)
    d.line(points, fill=C[color], width=2)
    for end in (points[0], points[-1]):
        d.line((at, end), fill=C[color])

def encode(name: str, frames: list) -> None:
    pal = Image.new("P", (1, 1))
    colors = [p for color in C.values() for p in color[:3]]
    pal.putpalette(colors + [0] * (768 - len(colors)))
    output = []
    for im in frames:
        A.validate(im, True)
        scaled = im.convert("RGB").resize((1152, 648), Image.Resampling.NEAREST)
        p = scaled.quantize(palette=pal, dither=Image.Dither.NONE)
        assert p.convert("RGB").tobytes() == scaled.tobytes()
        output.append(p)
    output[0].save(OUT / f"{name}.gif", save_all=True, append_images=output[1:],
                   duration=50, loop=0, optimize=False, disposal=2)
    with Image.open(OUT / f"{name}.gif") as gif:
        duration = 0
        for i in range(gif.n_frames):
            gif.seek(i)
            duration += gif.info["duration"]
        assert duration == len(frames) * 50

def main() -> None:
    before = hashes()
    bodies, horns = A.rig_sources()
    ground = Image.open(ROOT / "presentation/forest/root_hollow_layered_ground.png").convert("RGBA").crop((120, 65, 504, 281))
    A.validate(ground)
    clips, stills = {}, []
    timings = {"slam": (54, 6, 48), "charge": (56, 24, 40), "eruption": (50, 5, 40)}
    titles = {"slam": "SLAM / 2.5x REACH / 125 PIXELS", "charge": "CHARGE / PROPOSED 1.5x SPEED", "eruption": "ROOT ERUPTION / EIGHT WARNED SITES"}
    hero_grid, hero_anchor = R.hero_and_golem()[0]
    hero = R.to_image(hero_grid)
    for attack, (w, s, recovery) in timings.items():
        frames = []
        for tick in range(0, w + s + recovery + 30, 3):
            age = tick - w
            phase = "WINDUP" if age < 0 else "STRIKE" if age < s else "RECOVERY"
            at = (76, 108)
            if attack == "charge":
                at = (round(76 + max(0, min(age, s)) * 6.6), 108)
            state = {"slam": "slam_raise", "charge": "charge_tell", "eruption": "phase2_roar"}[attack]
            if age < 0:
                count = {"slam": 4, "charge": 5, "eruption": 6}[attack]
                index = min(count - 1, tick * count // w) + 1
            elif age < s:
                state = {"slam": "slam_strike", "charge": "charge_run", "eruption": "slam_recover"}[attack]
                index = 1 + (min(2, age // 2) if attack == "slam" else age // 3 % 4)
            else:
                state = "charge_crash" if attack == "charge" and age - s < 15 else "slam_recover"
                count = 3 if state == "charge_crash" else 4
                index = min(count - 1, (age - s) // 5) + 1
            key = f"{state}_{index}"
            scene, front, warn = ground.copy(), blank(), blank()
            d = ImageDraw.Draw(warn)
            if age < 0:
                if attack == "slam":
                    cue_sector(warn, at, 125, "y")
                elif attack == "charge":
                    d.rectangle((76, 93, 235, 123), outline=C["A"], width=2)
                    for x in range(95, 230, 27):
                        d.line([(x, 101), (x + 7, 108), (x, 115)], fill=C["z"], width=2)
                else:
                    for x, y in SITES:
                        d.ellipse((x - 34, y - 34, x + 34, y + 34), outline=C["A"], width=2)
                        d.line((x - 3, y, x + 3, y), fill=C["z"])
            if attack == "slam" and 0 <= age < 28:
                cue_sector(front, at, min(125, (age + 3) * 125 / 6), "p" if age < 6 else "t")
                for j in range(9):
                    a = -.85 + j * 1.7 / 8
                    point = (round(76 + math.cos(a) * 105), round(108 + math.sin(a) * 105))
                    A.dust(front, point, age, 20 + j)
                A.burst(front, (114, 113), age, 19)
            elif attack == "charge" and age >= 0:
                for born in range(0, min(age, s) + 1, 5):
                    A.dust(front, (round(76 + born * 6.6), 110), age - born, born + 42)
                if age >= s:
                    A.burst(front, (264, 108), age - s, 51)
            elif attack == "eruption":
                local = A.root_effect(age, tick).crop((173, 63, 253, 143))
                for point in SITES:
                    A.stamp(front, local, point, (40, 44))
                escape = max(0, min(1, (tick - 8) / 31))
                A.stamp(scene, hero, (round(178 + 25 * escape), round(61 + 52 * escape)), hero_anchor)
            scene.alpha_composite(front)
            body = bodies[key]
            A.stamp(scene, body, at, R.STAG_A)
            A.stamp(scene, A.horn_glow(body, horns[key], tick, .4 + .6 * min(1, tick / w)), at, R.STAG_A)
            scene.alpha_composite(warn)
            ImageDraw.Draw(scene).rectangle((0, 0, 383, 22), fill=C["0"])
            A.text(scene, (5, 2), titles[attack])
            A.text(scene, (5, 12), f"{phase} / REVIEW CHOREOGRAPHY ONLY", "i")
            frames.append(scene)
        encode(attack, frames)
        clips[attack] = frames
        pick = frames[(w + 3) // 3]
        pick.resize((1152, 648), Image.Resampling.NEAREST).save(OUT / f"{attack}_strike.png")
        stills.append(pick)
    moths = [Image.open(PROTECTED / f"frames/glowmoth_idle/glowmoth_idle_right_{i}.png").convert("RGBA") for i in range(1, 25)]
    sites = [(150, 68), (214, 64), (291, 85), (285, 151), (177, 166)]
    deaths = [48, 68, 88, 108, 132]
    frames, records = [], []
    for frame in range(180):
        live = [j for j in range(5) if frame < deaths[j]]
        heals = min(frame // 20, 6)
        hp_percent = 50 + heals * 2
        scene = ground.copy()
        d = ImageDraw.Draw(scene)
        for j in live:
            point = sites[j]
            for n in range(7):
                t = ((frame + n * 9) % 60) / 60
                x = round(point[0] * (1 - t) + 98 * t)
                y = round(point[1] * (1 - t) + 94 * t - 13 * math.sin(t * math.pi))
                d.point((x, y), fill=C["u"])
            A.stamp(scene, moths[(int(frame * 1.5) + j * 5) % 24], point, (16, 29))
        A.stamp(scene, bodies[f"idle_{1 + frame // 5 % 4}"], (86, 133), R.STAG_A)
        if live and 0 < frame % 20 < 10 and frame >= 20:
            A.text(scene, (76, 53 - frame % 20), "+2%", "p")
            d.line((103, 92, 109, 92), fill=C["u"])
            d.line((106, 89, 106, 95), fill=C["u"])
        d.rectangle((0, 0, 383, 35), fill=C["0"])
        A.text(scene, (5, 2), "SUMMONED MOTHS / 2% MAX HP PER SECOND")
        A.text(scene, (5, 13), f"ALIVE: {len(live)} / 5   HP: {hp_percent}%   TIME: {frame / 20:.1f}s", "i")
        A.text(scene, (5, 24), "REGEN ACTIVE" if live else "LAST MOTH DEAD / HEALING STOPPED", "u")
        d.rectangle((65, 184, 320, 194), fill=C["8"], outline=C["i"])
        d.rectangle((67, 186, 67 + round(251 * hp_percent / 100), 192), fill=C["u"])
        A.text(scene, (65, 200), "ILLUSTRATIVE KILLS / REVIEW ONLY", "i")
        frames.append(scene)
        records.append({"frame": frame, "alive": len(live), "hp_percent": hp_percent})
    encode("moth_regeneration", frames)
    frames[145].resize((1152, 648), Image.Resampling.NEAREST).save(OUT / "regeneration_stopped.png")
    encode("revised_attacks", sum(clips.values(), []))
    contact = Image.new("RGBA", (768, 432))
    for i, im in enumerate(stills + [frames[100]]):
        contact.paste(im, (i % 2 * 384, i // 2 * 216))
    contact.resize((1536, 864), Image.Resampling.NEAREST).save(OUT / "contact.png")
    assert len(SITES) == len(set(SITES)) == 8
    assert all(records[f]["hp_percent"] == 62 for f in range(132, 180))
    assert hashes() == before
    (OUT / "validation.json").write_text(json.dumps({"status": "PASS", "native_size": SIZE,
        "slam_reach": 125, "charge_speed_proposed": 6.6, "charge_strike_ticks_proposed": 24,
        "eruption_radius": 34, "eruption_sites_illustrative": SITES,
        "regen_records": records, "approved_glowmoth_hashes_unchanged": before,
        "checks": A.CHECKS, "runtime_verified": False}, indent=2))
    print("PASS: palette, hard alpha, exact GIF palette/timing, 8 sites, regeneration stop, approved Glowmoth hashes")

if __name__ == "__main__":
    main()
