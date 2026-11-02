"""Writes the Star Staff's game sprites into art/src (owner 2026-11-01: "yes i like what you did, wire them").

Hero frames (totoy_staff_<pose>_right_<n>): built from the 8 key poses cut from the staff concept
(tools/art/import_staff_concept.py, art/reference/staff_v1/imported/hero_<n>.png), with the frame counts every hero set has
(presentation/arena/animation.gd); the run is a real 12-frame cycle (tools/art/import_staff_run.py). Elsewhere only key poses
exist so far, so motion is a pixel-art breath (the upper body sinks one pixel) and pose changes.

    idle      pose 1, breathing              walk      the 12-frame run (tools/art/import_staff_run.py), leaning forward
    dash      pose 6 (the blink dissolve)    parry     pose 5 (the staff planted)
    hurt      pose 7                         victory   pose 8 (the staff raised), breathing
    attack1/2 the cast: pose 3 (pointing the staff), back to 1 at the end of the recovery
    attack3   the Great Burst: pose 4 (overhead) then 5 (the staff slammed down)
    cast      Disintegration: 1 point (3), 2 plant (5), 3 call (8)
(The Stone Ward poses totoy_staff_ward_* come from tools/art/import_echo_ward_sprint_sprites.py like every set's, and the
aspects' per-frame overlays from the aspect importers: run them after this.)

Effect frames (fx_staff_*): drawn by tools/art/staff_fx.py, the same code as the approved preview GIFs, each with its anchor:
cast flash, bolt, Arcane Burst and Great Burst (air, centre), light pillars (base), sparkles, the rune circle (forming; charged
ground and air layers; the small circle of the Great Burst), the meteor (the bottom of the rock), the fire ring, the explosion
(the ground point), the crater (cooling, then fading), and the rocks the particles throw.

Then run, as for any art: python tools/art/validate_art.py; python tools/art/build_art.py; python tools/art/preview_art.py.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import staff_fx as F  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "art/src"
IMPORTED = ROOT / "art/reference/staff_v1/imported"
SYMBOL_OF = {rgb: sym for sym, rgb in F.PAL.items()}
PREFIX_HERO = "totoy_staff_"
PREFIX_FX = "fx_staff_"


def grid_of(img: Image.Image) -> dict[tuple[int, int], str]:
    out = {}
    px = img.convert("RGBA").load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            if a > 127:
                out[(x, y)] = SYMBOL_OF[(r, g, b)]
    return out


def write(name: str, canvas: dict[tuple[int, int], str], anchor: tuple[int, int], written: list[str]) -> None:
    """Rows padded to multiples of 8 around the content (the anchor kept inside), with the anchor header."""
    xs = [x for x, _ in canvas] + [anchor[0]]
    ys = [y for _, y in canvas] + [anchor[1]]
    left, top = min(xs), min(ys)
    width = (max(xs) + 1 - left + 7) // 8 * 8
    height = (max(ys) + 1 - top + 7) // 8 * 8
    rows = ["".join(canvas.get((x, y), ".") for x in range(left, left + width)) for y in range(top, top + height)]
    assert width <= 256 and height <= 256, (name, width, height)
    text = f"# kind: sprite\n# anchor: {anchor[0] - left},{anchor[1] - top}\n" + "\n".join(rows) + "\n"
    (SRC / f"{name}.txt").write_text(text, encoding="utf-8", newline="\n")
    written.append(name)


def write_sprite(name: str, s: F.Sprite, written: list[str]) -> None:
    write(name, grid_of(s.img), (s.ax, s.ay), written)


# ------------------------------------------------------------------------------------------------------------- hero
POSES = {m["file"]: m for m in json.loads((IMPORTED / "imported.json").read_text(encoding="utf-8"))["sets"]["hero"]}


def pose(n: int) -> tuple[dict, tuple[int, int]]:
    m = POSES[f"hero_{n}.png"]
    return grid_of(Image.open(IMPORTED / m["file"])), (m["ax"], m["ay"])


def breathe(canvas: dict, anchor: tuple[int, int]) -> dict:
    """The upper body sinks one pixel (the feet stay): a pixel-art breath or a walking bob."""
    ys = [y for _, y in canvas]
    split = min(ys) + int((anchor[1] - min(ys)) * 0.45)
    out = {}
    for (x, y), s in canvas.items():
        if y < split:
            out[(x, y + 1)] = s
        elif y > split or (x, y) not in out:
            out.setdefault((x, y), s)
    for (x, y), s in canvas.items():  # what the shift uncovered keeps its own pixel (no holes at the split)
        if y == split and (x, y) not in out:
            out[(x, y)] = s
    return out


RUN = {m["file"]: m for name in ("run.json", "run_ib.json") for m in json.loads((IMPORTED / name).read_text(encoding="utf-8"))["frames"]}


def run_frame(n: int) -> tuple[dict, tuple[int, int]]:
    """Frame n (1-12) of the run cycle (owner 2026-11-02: "try 12 frames"): the six generated run poses (run_<k>.png, the katana
    run's poses with the staff) interleaved with their six generated in-betweens (run_ib_<k>.png), both cut to game scale by
    tools/art/import_staff_run.py: odd frames are run_1..6, even frames run_ib_1..6."""
    k = (n + 1) // 2
    m = RUN[f"run_{k}.png" if n % 2 else f"run_ib_{k}.png"]
    return grid_of(Image.open(IMPORTED / m["file"])), (m["ax"], m["ay"])


HERO_FRAMES: dict[str, list[tuple[int, bool]]] = {  # pose -> [(key pose, breath)] per frame
    "idle": [(1, False), (1, False), (1, True), (1, True)],
    "walk": [(0, False)] * 12,  # the generated 12-frame run cycle (run_frame()), not a key pose
    "dash": [(6, False)] * 4,
    "parry": [(5, False)] * 6,
    "hurt": [(7, False)] * 4,
    "victory": [(8, False), (8, False), (8, True), (8, True), (8, False), (8, False)],
    "attack1": [(3, False)] * 5 + [(1, False)],
    "attack2": [(3, False)] * 5 + [(1, False)],
    "attack3": [(4, False), (4, False), (5, False), (5, False), (5, False), (1, False)],
    "cast": [(3, False), (5, False), (8, False)],
}


def hero_sprites(written: list[str]) -> None:
    for name, frames in HERO_FRAMES.items():
        for i, (key, breath) in enumerate(frames, start=1):
            canvas, anchor = run_frame(i) if name == "walk" else pose(key)
            if breath:
                canvas = breathe(canvas, anchor)
            write(f"{PREFIX_HERO}{name}_right_{i}", canvas, anchor, written)


# ---------------------------------------------------------------------------------------------------------- effects
CIRCLE_RX = 58
CIRCLE_FORM_FRAMES = 12
CIRCLE_LOOP_FRAMES = 8
MINI_RX = 30


def effect_sprites(written: list[str]) -> None:
    for i in range(4):
        write_sprite(f"{PREFIX_FX}cast_{i + 1}", F.cast_flash(i), written)
    for i in range(2):
        write_sprite(f"{PREFIX_FX}bolt_{i + 1}", F.bolt(i), written)
    for i in range(6):
        write_sprite(f"{PREFIX_FX}burst_{i + 1}", F.arcane_burst(i, 1.25), written)
        write_sprite(f"{PREFIX_FX}burst_big_{i + 1}", F.arcane_burst(i, 1.6), written)
        write_sprite(f"{PREFIX_FX}column_{i + 1}", F.light_column(i, 6, 14, 64), written)
    for i in range(5):
        write_sprite(f"{PREFIX_FX}blink_column_{i + 1}", F.light_column(i, 5, 6, 36), written)
    for k in range(3):
        write_sprite(f"{PREFIX_FX}twinkle_{k + 1}", F.twinkle(k), written)
    for i in range(CIRCLE_FORM_FRAMES):  # the circle drawing itself in, dim (no rays yet)
        t = (i + 1) / CIRCLE_FORM_FRAMES
        ground, _ = F.rune_circle(CIRCLE_RX, F.ease_out(t), 0.15 + 0.4 * t, rot=i * 2.0, k=i)
        write_sprite(f"{PREFIX_FX}circle_form_{i + 1}", ground, written)
    step = 360.0 / 16 / CIRCLE_LOOP_FRAMES  # one glyph step over the loop, so it turns seamlessly
    for i in range(CIRCLE_LOOP_FRAMES):  # charged: blazing, rays rising (behind the target on the ground layer, in front on the air)
        ground, air = F.rune_circle(CIRCLE_RX, 1.0, 1.0, rot=i * step, spikes=1.0, k=i)
        write_sprite(f"{PREFIX_FX}circle_charge_{i + 1}", ground, written)
        write_sprite(f"{PREFIX_FX}circle_rays_{i + 1}", air, written)
    for i in range(6):  # the Great Burst's small circle: forms in 4, then 2 blazing frames
        t = min(1.0, (i + 1) / 4)
        ground, _ = F.rune_circle(MINI_RX, F.ease_out(t), 0.6 + 0.4 * t, rot=i * 6.0, k=i, glyphs=10)
        write_sprite(f"{PREFIX_FX}circle_small_{i + 1}", ground, written)
    for t in range(6):
        write_sprite(f"{PREFIX_FX}meteor_{t + 1}", F.meteor(t, r=13, flame=74), written)
    for i in range(5):
        write_sprite(f"{PREFIX_FX}fire_ring_{i + 1}", F.fire_ring(i), written)
    for i in range(F.EXPLOSION_FRAMES):
        write_sprite(f"{PREFIX_FX}explosion_{i + 1}", F.explosion(i), written)
    for i, heat in enumerate((1.0, 0.8, 0.6, 0.4, 0.2, 0.0)):
        write_sprite(f"{PREFIX_FX}crater_{i + 1}", F.crater(heat, 1.0), written)
    for i, fade in enumerate((0.7, 0.45, 0.2)):
        write_sprite(f"{PREFIX_FX}crater_fade_{i + 1}", F.crater(0.0, fade), written)
    for k in range(len(F.ROCKS)):
        write_sprite(f"{PREFIX_FX}rock_{k + 1}", F.rock_sprite(k), written)


# ------------------------------------------------------------------------------------------------------------ icons
def _medallion(base: str, inner: float) -> tuple[dict, tuple[int, int], float, float, str]:
    """Another weapon's medallion with its picture cleared: the stone ring stays, the inside is refilled with its own dark."""
    text = (SRC / f"{base}.txt").read_text(encoding="utf-8").splitlines()
    anchor = next(tuple(int(v) for v in line.split(":")[1].split(",")) for line in text if line.startswith("# anchor:"))
    rows = [line for line in text if line and not line.startswith("#")]
    canvas = {(x, y): ch for y, row in enumerate(rows) for x, ch in enumerate(row) if ch != "."}
    cx, cy = (len(rows[0]) - 1) / 2, (len(rows) - 1) / 2
    fills = [s for (x, y), s in canvas.items() if inner - 4 <= ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5 < inner - 1]
    dark = max(set(fills), key=fills.count)
    for (x, y) in list(canvas):
        if ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5 < inner:
            canvas[(x, y)] = dark
    return canvas, anchor, cx, cy, dark


def _line(canvas: dict, a: tuple[float, float], b: tuple[float, float], sym: str) -> None:
    n = int(max(abs(b[0] - a[0]), abs(b[1] - a[1]))) + 1
    for i in range(n + 1):
        t = i / n
        canvas[(round(a[0] + (b[0] - a[0]) * t), round(a[1] + (b[1] - a[1]) * t))] = sym


def icon_sprites(written: list[str]) -> None:
    import math
    # the weapon medallion (48x48): a staff of dark wood leaning across, a blue cloth wrap, the crescent crystal and its star
    canvas, anchor, cx, cy, _ = _medallion("ui_weapon_chain_scythe_1", 19.5)
    _line(canvas, (13, 37), (29, 16), "9")
    _line(canvas, (14, 37), (30, 16), "b")
    _line(canvas, (12, 38), (13, 37), "8")
    for t in range(4):
        canvas[(20 + t // 2, 28 - t)] = "l"
        canvas[(21 + t // 2, 28 - t)] = "m"
    for a in range(0, 276, 6):  # the crescent around the crystal, open to the upper right like the concept
        r = math.radians(a)
        for rr, sym in ((7.0, "n"), (6.0, "o"), (5.0, "p")):
            canvas[(round(31 + math.cos(r) * rr * 0.9), round(13 + math.sin(r) * rr))] = sym
    for x, y, sym in ((32, 12, "1"), (31, 12, "1"), (32, 11, "1"), (33, 12, "p"), (32, 13, "p"), (36, 7, "p"), (25, 9, "o"), (37, 18, "o")):
        canvas[(x, y)] = sym
    write("ui_weapon_star_staff_1", canvas, anchor, written)
    # the active icon (24x24): the circle on the ground and the meteor coming down onto it
    canvas, anchor, cx, cy, _ = _medallion("ui_aspect_reapers_coil_1", 9.5)
    for a in range(0, 360, 12):
        r = math.radians(a)
        canvas[(round(cx + math.cos(r) * 6.5), round(cy + 4 + math.sin(r) * 2.4))] = "u" if math.sin(r) < 0 else "o"
    for (x, y), sym in {(15, 6): "z", (14, 7): "y", (13, 8): "x", (14, 6): "A", (13, 7): "y", (12, 8): "x", (12, 9): "1",
                        (11, 9): "b", (11, 10): "b", (12, 10): "9", (10, 10): "c", (11, 11): "8"}.items():
        canvas[(x, y)] = sym
    write("ui_aspect_disintegration_1", canvas, anchor, written)


def main() -> int:
    for stale in list(SRC.glob(PREFIX_HERO + "*.txt")) + list(SRC.glob(PREFIX_FX + "*.txt")):
        stale.unlink()
    written: list[str] = []
    hero_sprites(written)
    hero = len(written)
    effect_sprites(written)
    effects = len(written) - hero
    icon_sprites(written)
    print(f"wrote {hero} hero frames, {effects} effect frames and {len(written) - hero - effects} icons to art/src")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
