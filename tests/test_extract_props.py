"""tools/art/extract_props.py on a synthetic prop sheet (magenta background, pink fringe, a detached glow, a flat decor
blob, a speck): the props are found in reading order, hard alpha, palette-only (no gold/red), the anchor sits on the base
line, the colliders follow the base, decor has none, a locked entry survives a re-run, the output is deterministic.
Run: python -m unittest discover -s tests -v
"""
from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools" / "art"))
import artlib  # noqa: E402
import extract_props  # noqa: E402

MAGENTA = (255, 0, 255)
PINK = (230, 90, 230)


def make_sheet(path: Path) -> None:
    img = Image.new("RGB", (837, 496), MAGENTA)
    d = ImageDraw.Draw(img)
    # a tall stone with a detached rune glow 3 px above it (one prop), pink fringe round it
    d.rectangle([98, 78, 142, 242], fill=PINK)
    d.rectangle([100, 80, 140, 240], fill=(110, 118, 120))
    d.rectangle([112, 70, 118, 76], fill=(70, 200, 190))
    # a wide low bush, second in the row
    d.rectangle([298, 178, 402, 240], fill=(60, 110, 50))
    # a flat antler bone (decor) in the second row, and a speck
    d.rectangle([200, 380, 260, 392], fill=(220, 210, 180))
    d.rectangle([500, 400, 501, 401], fill=(10, 10, 10))
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path)


class ExtractPropsTest(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.dir = Path(self.tmp.name)
        self.sheet = self.dir / "sheet.png"
        make_sheet(self.sheet)
        self.palette = artlib.load_palette()

    def tearDown(self) -> None:
        self.tmp.cleanup()

    def run_tool(self, out: str = "out", defs: str = "defs.json", names: list[str] | None = None) -> dict:
        return extract_props.extract(self.sheet, self.dir / out, self.dir / defs, names, 560.0, 60, self.palette)

    def test_finds_the_props_in_reading_order(self) -> None:
        data = self.run_tool(names=["stone", "bush", "bone"])
        self.assertEqual(list(data["props"]), ["stone", "bush", "bone"], "the speck is dropped, rows read left to right")
        self.assertAlmostEqual(data["scale"], 560 / 837, places=4)

    def test_cutouts_are_hard_alpha_palette_only_and_unreserved(self) -> None:
        self.run_tool(names=["stone", "bush", "bone"])
        allowed = {rgb for sym, rgb in self.palette.by_symbol.items() if sym not in self.palette.reserved}
        for name in ("stone", "bush", "bone"):
            img = Image.open(self.dir / "out" / f"{name}.png").convert("RGBA")
            raw = img.tobytes()
            for r, g, b, a in (raw[i:i + 4] for i in range(0, len(raw), 4)):
                self.assertIn(a, (0, 255), name)
                if a:
                    self.assertIn((r, g, b), allowed, f"{name}: palette colour, not gold/red")
                    self.assertFalse(r > 200 and b > 200 and g < 120, f"{name}: no magenta left")

    def test_the_glow_is_part_of_the_stone_and_the_fringe_is_gone(self) -> None:
        data = self.run_tool(names=["stone", "bush", "bone"])
        stone = data["props"]["stone"]
        self.assertGreaterEqual(stone["h"], round(172 * 560 / 837) - 2, "the glow above the stone is in the same cut-out")
        img = Image.open(self.dir / "out" / "stone.png").convert("RGBA")
        self.assertLessEqual(stone["w"], round(46 * 560 / 837) + 1, "the pink fringe did not widen the prop")
        self.assertGreater(img.getpixel((img.size[0] // 2, img.size[1] - 2))[3], 0)

    def test_anchor_base_and_colliders(self) -> None:
        data = self.run_tool(names=["stone", "bush", "bone"])
        stone = data["props"]["stone"]
        self.assertTrue(stone["solid"])
        self.assertEqual(stone["anchor"][1], stone["h"], "the anchor is the lowest opaque row's bottom edge")
        self.assertGreaterEqual(len(stone["colliders"]), 1)
        for dx, dy, r in stone["colliders"]:
            self.assertGreater(r, 0)
            self.assertLessEqual(abs(dx) + r, stone["base_width"] / 2.0 + 0.6, "colliders stay on the base")
            self.assertLessEqual(dy, 0, "centres sit at or above the base line")
        bush = data["props"]["bush"]
        self.assertGreater(len(bush["colliders"]), len(stone["colliders"]) - 1, "a wider base gets at least as many circles")
        self.assertGreaterEqual(len(bush["colliders"]), 2)
        bone = data["props"]["bone"]
        self.assertFalse(bone["solid"])
        self.assertEqual(bone["colliders"], [], "flat decor is walkable")

    def test_locked_entries_survive_a_rerun(self) -> None:
        self.run_tool(names=["stone", "bush", "bone"])
        path = self.dir / "defs.json"
        data = json.loads(path.read_text(encoding="utf-8"))
        data["props"]["stone"]["colliders"] = [[0, 0, 9.0]]
        data["props"]["stone"]["locked"] = True
        path.write_text(json.dumps(data), encoding="utf-8")
        again = self.run_tool(names=["stone", "bush", "bone"])
        self.assertEqual(again["props"]["stone"]["colliders"], [[0, 0, 9.0]])
        self.assertNotEqual(again["props"]["bush"]["colliders"], [[0, 0, 9.0]])

    def test_merge_keeps_other_sheets_and_prefix_names_the_rest(self) -> None:
        self.run_tool(names=["stone", "bush", "bone"])
        again = extract_props.extract(self.sheet, self.dir / "out2", self.dir / "defs.json", None, 560.0, 60, self.palette,
                                      merge=True, prefix="village")
        self.assertEqual(list(again["props"])[:3], ["village_01", "village_02", "village_03"])
        for name in ("stone", "bush", "bone"):
            self.assertIn(name, again["props"], "the first sheet's props survive --merge")
        plain = extract_props.extract(self.sheet, self.dir / "out3", self.dir / "defs3.json", None, 560.0, 60, self.palette)
        self.assertEqual(list(plain["props"]), ["prop_01", "prop_02", "prop_03"], "the default prefix")

    def test_deterministic(self) -> None:
        self.run_tool(out="a", defs="a.json", names=["stone", "bush", "bone"])
        self.run_tool(out="b", defs="b.json", names=["stone", "bush", "bone"])
        self.assertEqual((self.dir / "a.json").read_text(), (self.dir / "b.json").read_text())
        for name in ("stone", "bush", "bone"):
            self.assertEqual((self.dir / "a" / f"{name}.png").read_bytes(), (self.dir / "b" / f"{name}.png").read_bytes())


if __name__ == "__main__":
    unittest.main()
