"""Rootcrown, the chapter 1 final map (docs/FINAL_SCENE_chapter1.md): the floor painting and the props sheet the owner approved on
2026-11-09 (art/reference/rootcrown_v1/ground_raw.png, props_raw.png) become the game's art.

    python tools/art/make_rootcrown_art.py      # then: validate_art.py, build_art.py, preview_art.py; tools/godot/generate_prop_scenes.py

Floor: ground_raw.png -> presentation/forest/rootcrown_layered_ground.png at 640x360 in Totoy 36 without the reserved colours, the
same conversion as the arena and the Hollow Trial (tools/art/make_arena_ground_from_reference.py).
Props: props_raw.png is lifted a little first (x1.35 +6 on every non-magenta pixel) so the dark bricks keep their detail in the
palette, cut by tools/art/extract_props.py at 0.3 of the sheet (two debris specks skipped), and the tower's dark and lit states are
put on one canvas with one anchor (tools/art/normalize_state_pairs.py). Each cut-out becomes a text grid in art/src padded to
multiples of 8 on the top and right, and an entry in data/props/prop_defs_rootcrown.json whose size and anchor are the padded
canvas's, so no trim is needed. Colliders: the cutter's circles along the base, except the tower's, set by hand (its body only;
the spreading roots are walkable). Review copies of the cut-outs and the cutter's raw data: art/reference/rootcrown_v1/props/.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import artlib  # noqa: E402
import extract_props  # noqa: E402
import make_arena_ground_from_reference as ground  # noqa: E402
import normalize_state_pairs  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
REF = ROOT / "art" / "reference" / "rootcrown_v1"
CUTS = REF / "props"
FLOOR = ROOT / "presentation" / "forest" / "rootcrown_layered_ground.png"
DEFS = ROOT / "data" / "props" / "prop_defs_rootcrown.json"
SIZE = (640, 360)
SHEET_SCALE = 0.3
LIFT = 1.35
## The props in the sheet's reading order; "-" skips a debris speck the cutter finds between them.
NAMES = ["rootcrown_tower_dark", "rootcrown_tower_lit", "rootcrown_stone_1", "rootcrown_stone_2", "rootcrown_stone_3",
         "rootcrown_lantern_1", "rootcrown_lantern_2", "rootcrown_rubble_1", "-", "-", "rootcrown_rubble_2", "rootcrown_roots_1",
         "rootcrown_roots_2", "rootcrown_roots_3", "rootcrown_briars_1", "rootcrown_briars_2"]
TOWER_PAIR = ("rootcrown_tower_dark", "rootcrown_tower_lit")
## The tower's body: five circles across its base (the roots that spread from it stay walkable).
TOWER_COLLIDERS = [[-28.0, -10.0, 10.0], [-14.0, -12.0, 11.0], [0.0, -12.0, 11.0], [14.0, -12.0, 11.0], [28.0, -10.0, 10.0]]
NOTES = {
    "rootcrown_tower_dark": "the forest beacon, dark, crowned by the Colossus's roots; lit once the guardian falls (state pair)",
    "rootcrown_tower_lit": "the forest beacon lit: a blue-white flame and blue light in its cracks (state pair)",
    "rootcrown_lantern_1": "a dead stone lantern beside the stair",
    "rootcrown_lantern_2": "a dead stone lantern beside the stair",
}


def pad8(n: int) -> int:
    return (n + 7) // 8 * 8


def make_floor() -> None:
    ground.W, ground.H = SIZE
    raw = Image.open(REF / "ground_raw.png").convert("RGB").resize(SIZE, Image.Resampling.LANCZOS)
    floor = ground.to_image(ground.cleanup(ground.snap_image(raw))).convert("RGBA")
    palette = artlib.load_palette()
    allowed = {rgb for sym, rgb in palette.by_symbol.items() if sym not in palette.reserved}
    assert floor.size == SIZE and all(p[3] == 255 and p[:3] in allowed for p in floor.get_flattened_data()), "the floor left the palette"
    floor.save(FLOOR)
    print(f"floor: {FLOOR.relative_to(ROOT)} {floor.size[0]}x{floor.size[1]}")


def cut_props() -> dict:
    sheet = Image.open(REF / "props_raw.png").convert("RGB")
    pixels = sheet.load()
    for y in range(sheet.height):
        for x in range(sheet.width):
            r, g, b = pixels[x, y]
            if not (r > 200 and b > 200 and g < 90):  # the magenta background stays
                pixels[x, y] = (min(255, int(r * LIFT + 6)), min(255, int(g * LIFT + 6)), min(255, int(b * LIFT + 6)))
    lifted = REF / "props_lifted.png"
    sheet.save(lifted)
    CUTS.mkdir(parents=True, exist_ok=True)
    cut_defs = CUTS / "cut_defs.json"
    extract_props.extract(lifted, CUTS, cut_defs, NAMES, world_width=sheet.width * SHEET_SCALE, prefix="rootcrown")
    normalize_state_pairs.normalize(cut_defs, CUTS, TOWER_PAIR[0], TOWER_PAIR[1], 8, False)
    return json.loads(cut_defs.read_text(encoding="utf-8"))["props"]


def main() -> int:
    make_floor()
    cut = cut_props()
    palette = artlib.load_palette()
    symbol_of = {rgb: sym for sym, rgb in palette.by_symbol.items()}
    props: dict[str, dict] = {}
    for name in [n for n in NAMES if n != "-"]:
        info = cut[name]
        img = Image.open(CUTS / info["image"]).convert("RGBA")
        w, h = img.size
        pw, ph = pad8(w), pad8(h)
        top = ph - h
        rows = []
        for y in range(ph):
            row = []
            for x in range(pw):
                if y < top or x >= w:
                    row.append(palette.transparent)
                    continue
                r, g, b, a = img.getpixel((x, y - top))
                row.append(palette.transparent if a < 128 else symbol_of[(r, g, b)])
            rows.append("".join(row))
        ax = round(float(info["anchor"][0]))
        ay = round(float(info["anchor"][1])) + top
        header = ["# kind: sprite", f"# anchor: {ax},{ay}", "# Cut from art/reference/rootcrown_v1/props_raw.png by tools/art/make_rootcrown_art.py"]
        (ROOT / "art" / "src" / f"{name}.txt").write_text("\n".join(header + rows) + "\n", encoding="utf-8")
        entry = {"w": pw, "h": ph, "anchor": [ax, ay], "base_width": int(info["base_width"]), "solid": bool(info["solid"]),
                 "colliders": TOWER_COLLIDERS if name in TOWER_PAIR else info["colliders"], "image": f"{name}.png", "locked": True,
                 "note": NOTES.get(name, name.replace("rootcrown_", "").replace("_", " "))}
        if name in TOWER_PAIR:
            entry["solid"] = True
            entry["state_pair"] = list(TOWER_PAIR)
        props[name] = entry
        print(f"{name:22s} {w:3d}x{h:3d} -> {pw:3d}x{ph:3d} anchor {ax},{ay}")
    DEFS.write_text(json.dumps({"version": 1, "props": props}, indent=1) + "\n", encoding="utf-8")
    print(f"{len(props)} props -> {DEFS.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
