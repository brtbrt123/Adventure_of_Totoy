"""The village's extracted prop cut-outs (tools/art/extract_props.py on the two approved sheets, art/reference/layered_village/props/):
every cut-out is hard alpha, uses only Totoy 36 colours (no gold/red, no magenta left), matches its entry in
data/props/prop_defs.json (size, anchor on the lowest opaque row), the glade's entries are untouched, and the gate keeps
its see-through opening. Run: python -m unittest discover -s tests -v
"""
from __future__ import annotations

import json
import sys
import unittest
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools" / "art"))
import artlib  # noqa: E402

DEFS = ROOT / "data" / "props" / "prop_defs.json"
CUTS = ROOT / "art" / "reference" / "layered_village" / "props"


class VillageExtractionTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.defs = json.loads(DEFS.read_text(encoding="utf-8"))["props"]
        cls.village = {k: v for k, v in cls.defs.items() if k.startswith("village_")}
        pal = artlib.load_palette()
        cls.allowed = {rgb for sym, rgb in pal.by_symbol.items() if sym not in pal.reserved}

    def test_there_are_31_village_types_and_the_glade_is_intact(self) -> None:
        self.assertEqual(len(self.village), 31)
        glade = [k for k in self.defs if k.startswith("glade_")]
        self.assertEqual(len(glade), 20)
        for k in glade:
            self.assertTrue(self.defs[k].get("locked"), f"{k} stays locked")

    def test_cutouts_match_the_data_and_are_clean(self) -> None:
        for name, d in self.village.items():
            img = Image.open(CUTS / d["image"]).convert("RGBA")
            self.assertEqual(list(img.size), [d["w"], d["h"]], name)
            raw = img.tobytes()
            alphas = set()
            for i in range(0, len(raw), 4):
                r, g, b, a = raw[i:i + 4]
                alphas.add(a)
                if a:
                    self.assertIn((r, g, b), self.allowed, f"{name}: palette colour, not gold/red/magenta")
            self.assertTrue(alphas <= {0, 255}, f"{name}: hard alpha")
            alpha = img.getchannel("A").load()
            lowest = max(y for y in range(img.size[1]) for x in range(img.size[0]) if alpha[x, y])
            self.assertEqual(d["anchor"][1], lowest + 1, f"{name}: the anchor sits on the lowest opaque row")
            self.assertTrue(0 <= d["anchor"][0] <= d["w"], name)

    def test_the_gate_keeps_its_opening_and_holes(self) -> None:
        d = self.village["village_gate"]
        img = Image.open(CUTS / d["image"]).convert("RGBA")
        alpha = img.getchannel("A").load()
        w, h = img.size
        # between the left pillar and the door leaf the whole height is open at the base rows
        base_gap = [x for x in range(w) if not any(alpha[x, y] for y in range(h - 14, h))]
        self.assertGreaterEqual(len([x for x in base_gap if 30 <= x <= 55]), 20, "a 20+ px opening at the gate's base")
        # the see-through hole under the lintel (magenta was keyed out, not filled)
        self.assertFalse(any(alpha[x, h - 40] for x in range(34, 52)), "open between the pillars below the lintel")

    def test_no_forge_duplicates(self) -> None:
        self.assertNotIn("village_anvil", self.village)
        self.assertNotIn("village_bench", self.village)


if __name__ == "__main__":
    unittest.main()
