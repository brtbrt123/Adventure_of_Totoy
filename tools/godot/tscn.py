"""Tiny reader/writer for Godot 4 text scenes (.tscn), just enough for the scenes the generators in this folder write.

The generators build a `Scene` (ext resources, sub resources, nodes) and call `write()`. Output is deterministic: ids are
stable strings, order is the order of the lists, numbers keep their Python int/float spelling (so `22` stays `22` and
`6.0` stays `6.0`, which the JSON the baker writes back relies on).

`parse()` reads a file written by this module OR saved by the Godot editor (it ignores `uid=`/`unique_id=` and keeps
every property line raw), so a generator can keep the values the owner set in the editor (`merge_owner_values`).
"""
from __future__ import annotations

import re
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any


def num(v: float | int) -> str:
    """A number the way Python spells it, readable by Godot (no exponent for the values we use)."""
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, int):
        return str(v)
    text = repr(float(v))
    if "e" in text or "E" in text:
        text = format(float(v), "f").rstrip("0")
        if text.endswith("."):
            text += "0"
    return text


def vec2(x: float | int, y: float | int) -> str:
    return f"Vector2({num(x)}, {num(y)})"


def rect2(x: float | int, y: float | int, w: float | int, h: float | int) -> str:
    return f"Rect2({num(x)}, {num(y)}, {num(w)}, {num(h)})"


def color(r: float, g: float, b: float, a: float = 1.0) -> str:
    return f"Color({num(r)}, {num(g)}, {num(b)}, {num(a)})"


def variant(v: Any) -> str:
    """A Python value as a Godot variant literal (bool, int, float, str, list, dict)."""
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return num(v)
    if isinstance(v, str):
        return '"' + v.replace("\\", "\\\\").replace('"', '\\"') + '"'
    if isinstance(v, (list, tuple)):
        return "[" + ", ".join(variant(x) for x in v) + "]"
    if isinstance(v, dict):
        return "{" + ", ".join(f"{variant(str(k))}: {variant(x)}" for k, x in v.items()) + "}"
    raise TypeError(f"cannot write {v!r}")


def packed_vec2(points: list[tuple[float, float]]) -> str:
    return "PackedVector2Array(" + ", ".join(f"{num(x)}, {num(y)}" for x, y in points) + ")"


@dataclass
class ExtResource:
    id: str
    type: str
    path: str


@dataclass
class SubResource:
    id: str
    type: str
    props: dict[str, str] = field(default_factory=dict)


@dataclass
class Node:
    name: str
    type: str = ""            # empty for an instanced scene
    parent: str | None = None  # None for the root, "." for a child of the root, "A/B" below that
    instance: str = ""         # ExtResource id of the instanced PackedScene
    props: dict[str, str] = field(default_factory=dict)  # raw property text, written in insertion order

    @property
    def path(self) -> str:
        if self.parent is None:
            return "."
        return self.name if self.parent == "." else f"{self.parent}/{self.name}"


@dataclass
class Scene:
    ext: list[ExtResource] = field(default_factory=list)
    subs: list[SubResource] = field(default_factory=list)
    nodes: list[Node] = field(default_factory=list)

    def add_ext(self, id: str, type: str, path: str) -> str:
        if not any(e.id == id for e in self.ext):
            self.ext.append(ExtResource(id, type, path))
        return f'ExtResource("{id}")'

    def add_sub(self, id: str, type: str, props: dict[str, str]) -> str:
        self.subs.append(SubResource(id, type, props))
        return f'SubResource("{id}")'

    def add(self, name: str, type: str = "", parent: str | None = ".", props: dict[str, str] | None = None, instance: str = "") -> Node:
        node = Node(name, type, parent, instance, dict(props or {}))
        self.nodes.append(node)
        return node

    def by_path(self) -> dict[str, Node]:
        return {n.path: n for n in self.nodes}


def render(scene: Scene) -> str:
    steps = len(scene.ext) + len(scene.subs) + 1
    lines = [f"[gd_scene load_steps={steps} format=3]", ""]
    for e in scene.ext:
        lines.append(f'[ext_resource type="{e.type}" path="{e.path}" id="{e.id}"]')
    if scene.ext:
        lines.append("")
    for s in scene.subs:
        lines.append(f'[sub_resource type="{s.type}" id="{s.id}"]')
        lines.extend(f"{k} = {v}" for k, v in s.props.items())
        lines.append("")
    for n in scene.nodes:
        head = f'[node name="{n.name}"'
        if n.type:
            head += f' type="{n.type}"'
        if n.parent is not None:
            head += f' parent="{n.parent}"'
        if n.instance:
            head += f' instance=ExtResource("{n.instance}")'
        lines.append(head + "]")
        lines.extend(f"{k} = {v}" for k, v in n.props.items())
        lines.append("")
    return "\n".join(lines).rstrip("\n") + "\n"


def write(scene: Scene, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(render(scene), encoding="utf-8", newline="\n")


_HEADER = re.compile(r"^\[(?P<kind>gd_scene|ext_resource|sub_resource|node|connection|editable)\s*(?P<attrs>.*)\]\s*$")
_ATTR = re.compile(r'(\w+)=("(?:[^"\\]|\\.)*"|ExtResource\("[^"]*"\)|[^\s\]]+)')


def parse(text: str) -> Scene:
    """Reads a .tscn (ours or the editor's). Multi-line values (arrays continued over lines) are joined."""
    scene = Scene()
    current: Any = None
    pending = ""
    for raw in text.splitlines():
        line = raw.rstrip()
        if pending:
            pending += " " + line.strip()
            if pending.count("(") <= pending.count(")") and pending.count("[") <= pending.count("]") and pending.count("{") <= pending.count("}"):
                k, v = pending.split(" = ", 1)
                _assign(current, k, v)
                pending = ""
            continue
        m = _HEADER.match(line)
        if m:
            attrs = {k: v.strip('"') for k, v in _ATTR.findall(m["attrs"])}
            kind = m["kind"]
            if kind == "ext_resource":
                scene.ext.append(ExtResource(attrs["id"], attrs.get("type", ""), attrs["path"]))
                current = None
            elif kind == "sub_resource":
                current = SubResource(attrs["id"], attrs["type"])
                scene.subs.append(current)
            elif kind == "node":
                inst = attrs.get("instance", "")
                if inst.startswith("ExtResource("):
                    inst = inst[len('ExtResource("'):-2]
                current = Node(attrs["name"], attrs.get("type", ""), attrs.get("parent"), inst)
                scene.nodes.append(current)
            else:
                current = None
            continue
        if " = " in line and current is not None and not line.startswith("["):
            k, v = line.split(" = ", 1)
            if v.count("(") > v.count(")") or v.count("[") > v.count("]") or v.count("{") > v.count("}"):
                pending = line
                continue
            _assign(current, k, v)
    return scene


def _assign(target: Any, key: str, value: str) -> None:
    if isinstance(target, (Node, SubResource)):
        target.props[key] = value


# Properties a human sets in the editor; a regeneration keeps the scene's value over the generator's.
OWNER_KEYS = {"position", "offset", "scale", "rotation", "polygon", "size", "radius", "visible", "z_index", "modulate"}


def merge_owner_values(fresh: Scene, existing: Scene) -> Scene:
    """Returns `fresh` with the values the owner set in `existing` laid over it: for every node and shape present in
    both, the OWNER_KEYS values of the existing scene win; nodes only in the existing scene (added in the editor) are
    kept at the end. Generated, derived values (textures, regions, metadata from the art) come from `fresh`."""
    old_nodes = existing.by_path()
    old_subs = {s.id: s for s in existing.subs}
    for node in fresh.nodes:
        old = old_nodes.get(node.path)
        if old is None:
            continue
        for key in OWNER_KEYS:
            if key in old.props:
                node.props[key] = old.props[key]
            elif key in node.props and node.type and old.type == node.type and key != "visible":
                del node.props[key]  # reset to the default in the editor: keep it reset
        # the shape resources a node uses carry the owner's size/radius under the node's own sub resource
        if "shape" in node.props and "shape" in old.props:
            fresh_id = node.props["shape"][len('SubResource("'):-2]
            old_id = old.props["shape"][len('SubResource("'):-2]
            fsub = next((s for s in fresh.subs if s.id == fresh_id), None)
            osub = old_subs.get(old_id)
            if fsub is not None and osub is not None:
                for key in ("size", "radius"):
                    if key in osub.props:
                        fsub.props[key] = osub.props[key]
    known = {n.path for n in fresh.nodes}
    for old in existing.nodes:
        if old.path not in known:
            fresh.nodes.append(old)
            refs = " ".join(old.props.values()) + " " + old.instance
            for sub in existing.subs:
                if f'SubResource("{sub.id}")' in refs and not any(s.id == sub.id for s in fresh.subs):
                    fresh.subs.append(sub)
            for ext in existing.ext:
                if (f'ExtResource("{ext.id}")' in refs or ext.id == old.instance) and not any(e.id == ext.id for e in fresh.ext):
                    fresh.ext.append(ext)
    return fresh
