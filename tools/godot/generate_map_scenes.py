"""Converts the map data (data/scenes/<id>_props.json) into editable Godot scenes: presentation/maps/<id>.tscn.

    python tools/godot/generate_map_scenes.py                 # all maps; keeps what the owner set in existing scenes
    python tools/godot/generate_map_scenes.py --only glade_layered
    python tools/godot/generate_map_scenes.py --reset         # rebuild from the JSON (drops editor changes)
    python tools/godot/generate_map_scenes.py --out res-dir   # another folder inside the project (tests)

This is the one-time conversion. After it the scene is the source of truth: you edit it in Godot and
`tools/godot/bake_maps.gd` writes the JSON the core reads. A scene that already exists is never overwritten from the
JSON (positions, sizes and polygons set in the editor win); `--reset` starts over.

Scene layout (root Node2D named after the scene id; scalar data in the root's metadata, see bake_lib.gd bake_map):
    Ground       Sprite2D, the painted floor
    Walkable     Polygon2D, the walkable outline (the edges on the world border are the openings)
    Entries      Marker2D per entry point            Checkpoints  Marker2D per checkpoint
    Exits        Area2D per exit (child "Rect" = the zone; metadata target_scene, target_entry, gate, requires_flag, ...)
    Npcs         Marker2D per person (metadata visual, face_left)
    Objects      Marker2D per object (metadata kind, child "Stand" = where the hero uses it)
    StagStart / FightArea   the Thornback Stag room (glade only)
    Encounters   one Node2D per encounter (metadata title, leash, reward), child "Zone" Area2D and one Marker2D per mob
                 (metadata mob = the mob type, pick it in the Inspector)
    Props        y-sorted instances of presentation/props/<type>.tscn (position = feet, scale.x -1 = mirrored; metadata
                 shadow_radius, and when/on_type for the props that change with a state)
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import tscn  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
SCENES_DIR = ROOT / "data" / "scenes"
OUT_DIR = ROOT / "presentation" / "maps"
PROP_SCENE = "res://presentation/props/{}.tscn"
WALK_COLOUR = tscn.color(0.25, 0.85, 0.45, 0.22)
ZONE_COLOUR = tscn.color(0.9, 0.7, 0.2, 0.25)


def meta(node_props: dict[str, str], key: str, value) -> None:
    node_props[f"metadata/{key}"] = tscn.variant(value)


def add_rect_area(scene: tscn.Scene, name: str, parent: str, rect: list, sub_id: str, props: dict[str, str], area_at_corner: bool) -> None:
    """An Area2D whose child "Rect" is the zone. `area_at_corner`: the Area2D stands on the rect's top left."""
    x, y, w, h = rect
    if area_at_corner:
        props = {"position": tscn.vec2(x, y), **props}
        shape_at = tscn.vec2(w / 2, h / 2)
    else:
        shape_at = tscn.vec2(x + w / 2, y + h / 2)
    scene.add(name, "Area2D", parent, props)
    shape = scene.add_sub(sub_id, "RectangleShape2D", {"size": tscn.vec2(w, h)})
    path = name if parent == "." else f"{parent}/{name}"
    scene.add("Rect", "CollisionShape2D", path, {"position": shape_at, "shape": shape})


def build_map(data: dict) -> tscn.Scene:
    scene = tscn.Scene()
    sid = data["scene"]
    props: dict[str, str] = {}
    meta(props, "version", data["version"])
    meta(props, "title", data["name"])
    meta(props, "size", data["size"])
    for key in ("boundary_radius", "boundary_spacing", "prop_margin"):
        if key in data:
            meta(props, key, data[key])
    meta(props, "default_entry", data["default_entry"])
    if "puzzle" in data:
        meta(props, "puzzle", data["puzzle"])
    if "trial" in data:  # a trial room (core/trial.gd): waves, spawn points, reward; edited in the Inspector for now
        meta(props, "trial", data["trial"])
    scene.add(sid, "Node2D", None, props)

    if (ROOT / data["ground"].removeprefix("res://")).exists():
        ground = scene.add_ext("ground", "Texture2D", data["ground"])
        scene.add("Ground", "Sprite2D", ".", {"texture_filter": "1", "texture": ground, "centered": "false"})
    else:  # the floor painting is not delivered yet: keep its path, the scene still opens
        gp: dict[str, str] = {"texture_filter": "1", "centered": "false"}
        meta(gp, "ground", data["ground"])
        scene.add("Ground", "Sprite2D", ".", gp)
    scene.add("Walkable", "Polygon2D", ".", {"color": WALK_COLOUR, "polygon": tscn.packed_vec2([tuple(p) for p in data["outline"]])})

    scene.add("Entries", "Node2D")
    for name, at in data["entries"].items():
        scene.add(name, "Marker2D", "Entries", {"position": tscn.vec2(*at)})

    scene.add("Exits", "Node2D")
    for i, row in enumerate(data["exits"], start=1):
        p: dict[str, str] = {}
        for key in ("target_scene", "target_entry", "gate", "requires_flag", "blocked_text"):
            if key in row:
                meta(p, key, row[key])
        add_rect_area(scene, row["id"], "Exits", row["rect"], f"Exit_{i}", p, True)

    scene.add("Checkpoints", "Node2D")
    for row in data["checkpoints"]:
        scene.add(row["id"], "Marker2D", "Checkpoints", {"position": tscn.vec2(*row["position"])})

    if "npcs" in data:
        scene.add("Npcs", "Node2D")
        for row in data["npcs"]:
            p = {"position": tscn.vec2(*row["position"])}
            meta(p, "visual", row["visual"])
            if "face_left" in row:
                meta(p, "face_left", row["face_left"])
            scene.add(row["id"], "Marker2D", "Npcs", p)

    if "objects" in data:
        scene.add("Objects", "Node2D")
        for row in data["objects"]:
            p = {"position": tscn.vec2(*row["position"])}
            meta(p, "kind", row["kind"])
            scene.add(row["id"], "Marker2D", "Objects", p)
            scene.add("Stand", "Marker2D", f"Objects/{row['id']}", {"position": tscn.vec2(row["stand"][0] - row["position"][0], row["stand"][1] - row["position"][1])})

    if "stag_start" in data:
        p = {"position": tscn.vec2(*data["stag_start"])}
        meta(p, "stag_radius", data["stag_radius"])
        scene.add("StagStart", "Marker2D", ".", p)
        add_rect_area(scene, "FightArea", ".", data["fight_area"], "FightArea", {}, False)

    if "encounters" in data:
        scene.add("Encounters", "Node2D")
        for i, row in enumerate(data["encounters"], start=1):
            p = {}
            meta(p, "title", row["name"])
            meta(p, "leash", row["leash"])
            if "managed" in row:
                meta(p, "managed", row["managed"])
            if "reward" in row:
                meta(p, "reward", row["reward"])
            scene.add(row["id"], "Node2D", "Encounters", p)
            add_rect_area(scene, "Zone", f"Encounters/{row['id']}", row["rect"], f"Zone_{i}", {}, False)
            for n, mob in enumerate(row["mobs"], start=1):
                mp: dict[str, str] = {"position": tscn.vec2(mob["x"], mob["y"])}
                meta(mp, "mob", mob["type"])
                scene.add(f"{mob['type']}_{n}", "Marker2D", f"Encounters/{row['id']}", mp)

    scene.add("Props", "Node2D", ".", {"y_sort_enabled": "true"})
    for row in data["props"]:
        ext_id = "p_" + row["type"]
        scene.add_ext(ext_id, "PackedScene", PROP_SCENE.format(row["type"]))
        p = {"position": tscn.vec2(row["x"], row["y"])}
        if row.get("flip") is True:
            p["scale"] = tscn.vec2(-1, 1)
        if "flip" in row:
            meta(p, "flip", row["flip"])
        if "shadow_radius" in row:
            meta(p, "shadow_radius", row["shadow_radius"])
        if "when" in row:
            meta(p, "when", row["when"])
            meta(p, "on_type", row["on_type"])
        scene.add(row["id"], "", "Props", p, instance=ext_id)
    return scene


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--out", type=Path, default=OUT_DIR)
    parser.add_argument("--only", action="append", help="scene id (repeatable)")
    parser.add_argument("--reset", action="store_true", help="ignore existing scenes (drops editor changes)")
    args = parser.parse_args()

    done = 0
    for path in sorted(SCENES_DIR.glob("*_props.json")):
        data = json.loads(path.read_text(encoding="utf-8"))
        if args.only and data["scene"] not in args.only:
            continue
        target = args.out / f"{data['scene']}.tscn"
        if target.exists() and not args.reset:
            print(f"{target.name}: exists, kept (the scene is the source of truth; --reset rebuilds it)")
            continue
        scene = build_map(data)
        args.out.mkdir(parents=True, exist_ok=True)
        target.write_text(tscn.render(scene), encoding="utf-8", newline="\n")
        done += 1
        print(f"{target.name}: written")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
