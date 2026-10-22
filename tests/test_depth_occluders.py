"""The depth occluders (tools/art/make_depth_occluders.py, presentation/common/depth_occluders.json).

Checks: the committed atlases and manifests are exactly what the tool makes from the table (reproducible, up to
date); every atlas has hard alpha and only palette colours; every occluder's pixels are the ground's own pixels at its
world position (cut, not painted); every scene has its occluders and the ids/bases are sane.
Run: python -m unittest discover -s tests -v
"""
from __future__ import annotations

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
TOOL = ROOT / "tools" / "art" / "make_depth_occluders.py"
TABLE = ROOT / "presentation" / "common" / "depth_occluders.json"
OUT = ROOT / "presentation" / "common" / "occluders"
SCENES = ("village", "forest", "glade", "arena")
MAX_GROUND_SHARE = 0.15


def palette_rgb() -> set[tuple[int, int, int]]:
    data = json.loads((ROOT / "art" / "palette.json").read_text(encoding="utf-8"))
    return {tuple(int(c["hex"][i:i + 2], 16) for i in (1, 3, 5)) for c in data["colors"]}


class DepthOccluders(unittest.TestCase):
    def test_committed_files_are_the_tools_output(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            run = subprocess.run([sys.executable, str(TOOL), "--out", tmp], capture_output=True, text=True, cwd=ROOT)
            self.assertEqual(run.returncode, 0, run.stdout + run.stderr)
            for scene in SCENES:
                for suffix in ("_occluders.png", "_occluders.json"):
                    made = (Path(tmp) / f"{scene}{suffix}").read_bytes()
                    committed = (OUT / f"{scene}{suffix}").read_bytes()
                    self.assertEqual(made, committed, f"{scene}{suffix} is stale: run python tools/art/make_depth_occluders.py")

    def test_atlases_have_hard_alpha_palette_colours_and_the_grounds_pixels(self) -> None:
        palette = palette_rgb()
        table = json.loads(TABLE.read_text(encoding="utf-8"))["scenes"]
        for scene in SCENES:
            manifest = json.loads((OUT / f"{scene}_occluders.json").read_text(encoding="utf-8"))
            atlas = Image.open(OUT / f"{scene}_occluders.png").convert("RGBA")
            ground = Image.open(ROOT / table[scene]["ground"]).convert("RGBA")
            self.assertTrue(manifest["occluders"], f"{scene} has occluders")
            apx = atlas.load()
            gpx = ground.load()
            for x in range(atlas.width):
                for y in range(atlas.height):
                    r, g, b, a = apx[x, y]
                    self.assertIn(a, (0, 255), f"{scene}: alpha {a} at {x},{y}")
                    if a == 255:
                        self.assertIn((r, g, b), palette, f"{scene}: non-palette colour at {x},{y}")
            ids = set()
            for occ in manifest["occluders"]:
                self.assertNotIn(occ["id"], ids)
                ids.add(occ["id"])
                rx, ry, rw, rh = occ["rect"]
                ax, ay = occ["atlas"]
                self.assertTrue(0 <= rx and 0 <= ry and rx + rw <= ground.width and ry + rh <= ground.height, occ["id"])
                self.assertGreaterEqual(occ["base_y"], ry, f"{scene}/{occ['id']}: the base is not above the cut")
                # (an overhead part, like the village gate's lintel, has its base well below its cut)
                self.assertLessEqual(occ["base_y"], ground.height, f"{scene}/{occ['id']}: the base is in the world")
                opaque = 0
                for dy in range(rh):
                    for dx in range(rw):
                        p = apx[ax + dx, ay + dy]
                        if p[3] == 255:
                            opaque += 1
                            self.assertEqual(p, gpx[rx + dx, ry + dy], f"{scene}/{occ['id']}: pixel {rx + dx},{ry + dy} is not the ground's")
                self.assertEqual(opaque, occ["pixels"], f"{scene}/{occ['id']}: pixel count")
                self.assertGreater(opaque, 20, f"{scene}/{occ['id']}: a real prop")

    def test_refined_occluders_hold_almost_no_floor(self) -> None:
        # the human's playtest (2026-10-22): "some FLOOR painting is there". Every refined occluder keeps at most
        # MAX_GROUND_SHARE floor-like pixels (make_depth_occluders.ground_like_share); the hand-drawn ones
        # ("refine": false: the dark village, the brown root gate / arch / mossy stone) are only reported.
        table = json.loads(TABLE.read_text(encoding="utf-8"))["scenes"]
        for scene in SCENES:
            refine = {o["id"]: o.get("refine", True) for o in table[scene]["occluders"]}
            manifest = json.loads((OUT / f"{scene}_occluders.json").read_text(encoding="utf-8"))
            for occ in manifest["occluders"]:
                if refine[occ["id"]]:
                    self.assertLessEqual(occ["ground_share"], MAX_GROUND_SHARE, f"{scene}/{occ['id']}: floor share")
                else:
                    print(f"  (hand polygon) {scene}/{occ['id']}: floor-like share {occ['ground_share']:.2f}")

    def test_pieces_never_cover_pixels_outside_their_polygons(self) -> None:
        sys.path.insert(0, str(ROOT / "tools" / "art"))
        import make_depth_occluders as tool  # noqa: E402
        table = json.loads(TABLE.read_text(encoding="utf-8"))["scenes"]
        for scene in SCENES:
            polys = {o["id"]: o["poly"] for o in table[scene]["occluders"]}
            manifest = json.loads((OUT / f"{scene}_occluders.json").read_text(encoding="utf-8"))
            atlas = Image.open(OUT / f"{scene}_occluders.png").convert("RGBA").load()
            for occ in manifest["occluders"]:
                rx, ry, rw, rh = occ["rect"]
                ax, ay = occ["atlas"]
                for dy in range(rh):
                    for dx in range(rw):
                        if atlas[ax + dx, ay + dy][3] == 255:
                            self.assertTrue(tool.point_in_polygon(rx + dx + 0.5, ry + dy + 0.5, polys[occ["id"]]),
                                            f"{scene}/{occ['id']}: pixel {rx + dx},{ry + dy} outside its polygon")

    def test_the_root_gate_door_hides_while_the_gate_is_open(self) -> None:
        manifest = json.loads((OUT / "forest_occluders.json").read_text(encoding="utf-8"))
        hide = {o["id"]: o["hide_when"] for o in manifest["occluders"]}
        self.assertEqual(hide.get("root_gate_middle"), "gate_open")
        self.assertEqual(hide.get("root_gate_left"), "")


if __name__ == "__main__":
    unittest.main()
