"""Writes one editable Godot scene per prop type: presentation/props/<type>.tscn.

    python tools/godot/generate_prop_scenes.py            # all types; keeps what the owner set in existing scenes
    python tools/godot/generate_prop_scenes.py --reset    # rebuild every scene from the JSON (drops editor changes)
    python tools/godot/generate_prop_scenes.py --out DIR  # write somewhere else (tests)

Inputs (all existing, nothing is changed): data/props/prop_defs*.json (anchor, colliders, solid), presentation/common/
prop_art.json (trim, contact shadow, cast shadow names, sort strips), presentation/common/local_lights.json (light
sockets), art/build/sprites.json (atlas anchors of the cast-shadow masks), art/build/sprites/<name>.png (the textures).

The scene of a type (root Node2D named after the type, standing on the prop's FEET):
    Sprite          Sprite2D, the art, `offset` = -anchor so the anchor (middle of the base) is the root origin
    CastShadow      Sprite2D, the moon cast-shadow mask (hidden: the renderer draws it in its own pass)
    CastShadowFlipped  the mask for the mirrored prop
    Colliders       StaticBody2D (no layers: it only shows the circles) with one CollisionShape2D (circle) per collider,
                    position = (dx, dy) from the anchor, radius = r. Edit them in the editor; the baker writes them back.
    Light1..        Marker2D at a light socket (position = socket pixel - anchor); the socket numbers are in metadata
Root metadata holds the numbers the scene does not draw: w, h, base_width, solid, image, note, locked, state_pair,
src_bbox, contact_shadow, sort_strips, flip_offset.

The owner's rule: a position, size or radius set in the editor is never overwritten; an existing scene is only refreshed
where the art changed (texture, region, metadata). Use --reset to start over.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import tscn  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
DEF_FILES = ["data/props/prop_defs.json", "data/props/prop_defs_woodland.json", "data/props/prop_defs_root_hollow.json", "data/props/prop_defs_hollow_trial.json"]
OUT_DIR = ROOT / "presentation" / "props"
SPRITES_DIR = "res://art/build/sprites/"


def load_defs() -> dict[str, dict]:
    """The merged catalogue, the way core/prop_scene.gd load_defs() merges it (an earlier file wins)."""
    merged: dict[str, dict] = {}
    for rel in DEF_FILES:
        for type_id, definition in json.loads((ROOT / rel).read_text(encoding="utf-8"))["props"].items():
            merged.setdefault(type_id, definition)
    return merged


def build_scene(type_id: str, definition: dict, art: dict, lights: list[dict], frames: dict) -> tscn.Scene:
    scene = tscn.Scene()
    anchor = definition["anchor"]
    trim = art.get("trim")
    tex = scene.add_ext("1_art", "Texture2D", f"{SPRITES_DIR}{type_id}.png")
    texture = tex
    if trim:
        texture = scene.add_sub("AtlasTexture_art", "AtlasTexture", {"atlas": tex, "region": tscn.rect2(*trim)})
    frame = frames[type_id]
    size = (trim[2], trim[3]) if trim else (frame["w"], frame["h"])

    root_props: dict[str, str] = {}
    for key in ("w", "h", "base_width", "solid", "image", "note", "locked", "state_pair", "src_bbox"):
        if key in definition:
            root_props[f"metadata/{key}"] = tscn.variant(definition[key])
    if "contact_shadow" in art:
        root_props["metadata/contact_shadow"] = tscn.variant(art["contact_shadow"])
    if "sort_strips" in art:
        root_props["metadata/sort_strips"] = tscn.variant(art["sort_strips"])
    root_props["metadata/flip_offset"] = tscn.vec2(-(size[0] - anchor[0]), -anchor[1])
    scene.add(type_id, "Node2D", None, root_props)

    scene.add("Sprite", "Sprite2D", ".", {
        "texture_filter": "1",
        "texture": texture,
        "centered": "false",
        "offset": tscn.vec2(-anchor[0], -anchor[1]),
    })

    cast = art.get("cast_shadow", {})
    for node_name, key in (("CastShadow", "normal"), ("CastShadowFlipped", "flipped")):
        name = cast.get(key)
        if not name or name not in frames:
            continue
        cast_frame = frames[name]
        ref = scene.add_ext(f"cast_{key}", "Texture2D", f"{SPRITES_DIR}{name}.png")
        scene.add(node_name, "Sprite2D", ".", {
            "visible": "false",
            "modulate": tscn.color(0, 0, 0, 0.35),
            "texture_filter": "1",
            "texture": ref,
            "centered": "false",
            "offset": tscn.vec2(-cast_frame["ax"], -cast_frame["ay"]),
        })

    colliders = definition.get("colliders", [])
    if colliders:
        scene.add("Colliders", "StaticBody2D", ".", {"collision_layer": "0", "collision_mask": "0"})
        for i, (dx, dy, r) in enumerate(colliders, start=1):
            shape = scene.add_sub(f"CircleShape2D_{i}", "CircleShape2D", {"radius": tscn.num(r)})
            scene.add(f"Circle{i}", "CollisionShape2D", "Colliders", {"position": tscn.vec2(dx, dy), "shape": shape})

    for i, socket in enumerate(lights, start=1):
        px, py = socket["pixel"]
        scene.add(f"Light{i}", "Marker2D", ".", {
            "position": tscn.vec2(px - anchor[0], py - anchor[1]),
            "metadata/socket": tscn.variant(socket),
        })
    return scene


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--out", type=Path, default=OUT_DIR)
    parser.add_argument("--reset", action="store_true", help="ignore existing scenes (drops editor changes)")
    args = parser.parse_args()

    defs = load_defs()
    art = json.loads((ROOT / "presentation/common/prop_art.json").read_text(encoding="utf-8"))["props"]
    lights = json.loads((ROOT / "presentation/common/local_lights.json").read_text(encoding="utf-8"))
    frames = json.loads((ROOT / "art/build/sprites.json").read_text(encoding="utf-8"))["frames"]

    written = kept = 0
    for type_id in sorted(defs):
        scene = build_scene(type_id, defs[type_id], art.get(type_id, {}), lights.get(type_id, []), frames)
        path = args.out / f"{type_id}.tscn"
        if path.exists() and not args.reset:
            scene = tscn.merge_owner_values(scene, tscn.parse(path.read_text(encoding="utf-8")))
        text = tscn.render(scene)
        if path.exists() and path.read_text(encoding="utf-8") == text:
            kept += 1
            continue
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8", newline="\n")
        written += 1
    print(f"prop scenes: {len(defs)} types, {written} written, {kept} unchanged -> {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
