"""Round trips of the editable Godot scenes (docs/GODOT_EDITABLE_PLAN.md phases 0-2).

JSON -> .tscn (tools/godot/generate_*.py) -> headless Godot baker (tools/godot/bake_*.gd) -> JSON must give back exactly
what the core reads today:
  * the five map files data/scenes/*_props.json come back BYTE FOR BYTE;
  * the three prop definition files data/props/prop_defs*.json come back value for value (the baker writes whole
    numbers as integers, so `61.0` may return as `61`; the core reads both as the same number).
Also: a value set in the editor survives a regeneration, and an edit in a scene reaches the baked JSON (so the baker
is not just copying the old file).

Needs the Godot console build (GODOT env var or C:\\Tools\\Godot\\...); skipped when it is missing. Do not run it while
build_art.py runs (the art folder is briefly incomplete). Scratch scenes go to tests/_tmp_godot (removed afterwards).
"""
from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools" / "godot"))
import tscn  # noqa: E402

GODOT = Path(os.environ.get("GODOT", r"C:\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe"))
TMP = ROOT / "tests" / "_tmp_godot"
DEF_FILES = ["prop_defs.json", "prop_defs_woodland.json", "prop_defs_root_hollow.json"]


def run_python(script: str, *args: str) -> None:
    subprocess.run([sys.executable, str(ROOT / "tools" / "godot" / script), *args], cwd=ROOT, check=True, capture_output=True)


def run_godot(script: str, *args: str) -> str:
    result = subprocess.run([str(GODOT), "--headless", "--path", str(ROOT), "--script", f"res://tools/godot/{script}", "--", *args],
                            cwd=ROOT, capture_output=True, text=True, timeout=300)
    out = result.stdout + result.stderr
    assert result.returncode == 0, out
    assert "SCRIPT ERROR" not in out and "ERROR:" not in out, out
    return out


def res(path: Path) -> str:
    return "res://" + path.relative_to(ROOT).as_posix()


@unittest.skipUnless(GODOT.exists(), "Godot console build not found (set GODOT)")
class SceneRoundTrip(unittest.TestCase):
    def setUp(self) -> None:
        shutil.rmtree(TMP, ignore_errors=True)
        TMP.mkdir(parents=True)
        self.out = Path(tempfile.mkdtemp())

    def tearDown(self) -> None:
        shutil.rmtree(TMP, ignore_errors=True)
        shutil.rmtree(self.out, ignore_errors=True)

    # -- props ---------------------------------------------------------------------------------------------------
    def bake_props(self) -> None:
        run_godot("bake_props.gd", "--scenes", res(TMP / "props"), "--out", str(self.out))

    def test_prop_scenes_bake_back_to_the_definitions(self) -> None:
        run_python("generate_prop_scenes.py", "--reset", "--out", str(TMP / "props"))
        self.assertGreaterEqual(len(list((TMP / "props").glob("*.tscn"))), 100)
        self.bake_props()
        for name in DEF_FILES:
            original = json.loads((ROOT / "data" / "props" / name).read_text(encoding="utf-8"))
            baked = json.loads((self.out / name).read_text(encoding="utf-8"))
            self.assertEqual(original, baked, name)

    def test_collider_edit_in_a_prop_scene_reaches_the_definitions(self) -> None:
        run_python("generate_prop_scenes.py", "--reset", "--out", str(TMP / "props"))
        path = TMP / "props" / "forest_sign.tscn"
        text = path.read_text(encoding="utf-8")
        self.assertIn("radius = 4", text)
        path.write_text(text.replace("radius = 4", "radius = 5", 1), encoding="utf-8", newline="\n")
        self.bake_props()
        baked = json.loads((self.out / "prop_defs.json").read_text(encoding="utf-8"))
        self.assertEqual(baked["props"]["forest_sign"]["colliders"], [[0, -3, 5]])

    def test_every_type_has_a_scene_with_its_colliders_and_art(self) -> None:
        run_python("generate_prop_scenes.py", "--reset", "--out", str(TMP / "props"))
        defs = {}
        for name in DEF_FILES:
            for k, v in json.loads((ROOT / "data" / "props" / name).read_text(encoding="utf-8"))["props"].items():
                defs.setdefault(k, v)
        for type_id, definition in defs.items():
            scene = tscn.parse((TMP / "props" / f"{type_id}.tscn").read_text(encoding="utf-8"))
            nodes = scene.by_path()
            self.assertIn("Sprite", nodes, type_id)
            circles = [n for p, n in nodes.items() if p.startswith("Colliders/")]
            self.assertEqual(len(circles), len(definition["colliders"]), type_id)
            for ext in scene.ext:
                self.assertTrue((ROOT / ext.path.removeprefix("res://")).exists(), f"{type_id}: {ext.path}")

    # -- maps ----------------------------------------------------------------------------------------------------
    def bake_maps(self) -> None:
        run_godot("bake_maps.gd", "--scenes", res(TMP / "maps"), "--out", str(self.out))

    def test_maps_bake_back_byte_for_byte(self) -> None:
        run_python("generate_map_scenes.py", "--reset", "--out", str(TMP / "maps"))
        self.bake_maps()
        files = sorted((ROOT / "data" / "scenes").glob("*_props.json"))
        self.assertGreaterEqual(len(files), 5)
        for original in files:
            self.assertEqual(original.read_bytes(), (self.out / original.name).read_bytes(), original.name)

    def test_prop_move_in_a_map_scene_reaches_the_json(self) -> None:
        run_python("generate_map_scenes.py", "--reset", "--out", str(TMP / "maps"))
        path = TMP / "maps" / "glade_layered.tscn"
        text = path.read_text(encoding="utf-8")
        self.assertIn("position = Vector2(170, 140)", text)
        path.write_text(text.replace("position = Vector2(170, 140)", "position = Vector2(171, 141)", 1), encoding="utf-8", newline="\n")
        self.bake_maps()
        baked = json.loads((self.out / "glade_layered_props.json").read_text(encoding="utf-8"))
        stone = next(p for p in baked["props"] if p["id"] == "glade_stone_1")
        self.assertEqual((stone["x"], stone["y"]), (171, 141))

    def test_map_instances_use_existing_prop_scenes(self) -> None:
        run_python("generate_map_scenes.py", "--reset", "--out", str(TMP / "maps"))
        for path in (TMP / "maps").glob("*.tscn"):
            for ext in tscn.parse(path.read_text(encoding="utf-8")).ext:
                self.assertTrue((ROOT / ext.path.removeprefix("res://")).exists(), f"{path.name}: {ext.path}")


class OwnerValuesSurvive(unittest.TestCase):
    """The rule: a position or size set in the editor is never overwritten by a generator."""

    def test_regeneration_keeps_editor_values(self) -> None:
        tmp = Path(tempfile.mkdtemp())
        try:
            run_python("generate_map_scenes.py", "--only", "glade_layered", "--out", str(tmp))
            path = tmp / "glade_layered.tscn"
            edited = path.read_text(encoding="utf-8").replace("position = Vector2(170, 140)", "position = Vector2(99, 98)", 1)
            path.write_text(edited, encoding="utf-8", newline="\n")
            run_python("generate_map_scenes.py", "--only", "glade_layered", "--out", str(tmp))
            self.assertEqual(path.read_text(encoding="utf-8"), edited)  # a map scene is never rewritten from the JSON

            props = tmp / "props"
            run_python("generate_prop_scenes.py", "--out", str(props))
            sign = props / "forest_sign.tscn"
            text = sign.read_text(encoding="utf-8")
            moved = text.replace("position = Vector2(0, -3)", "position = Vector2(2, -4)", 1).replace("radius = 4", "radius = 7", 1)
            self.assertNotEqual(text, moved)
            sign.write_text(moved, encoding="utf-8", newline="\n")
            run_python("generate_prop_scenes.py", "--out", str(props))
            again = sign.read_text(encoding="utf-8")
            self.assertIn("position = Vector2(2, -4)", again)
            self.assertIn("radius = 7", again)
            run_python("generate_prop_scenes.py", "--reset", "--out", str(props))
            self.assertIn("position = Vector2(0, -3)", sign.read_text(encoding="utf-8"))
        finally:
            shutil.rmtree(tmp, ignore_errors=True)


if __name__ == "__main__":
    unittest.main()
