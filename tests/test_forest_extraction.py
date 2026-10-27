"""The forest cut-outs (data/props/cutouts_forest) and tools/art/normalize_state_pairs.py.

The cut-outs are generated sources, not palette-converted art: Codex converts and cleans them. These tests check that
the extraction output is consistent with the shared defs and that the two states of a prop share one canvas and anchor.
"""
import json
import sys
import tempfile
import unittest
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools" / "art"))
import normalize_state_pairs as nsp  # noqa: E402

CUTOUTS = ROOT / "data" / "props" / "cutouts_forest"
DEFS = ROOT / "data" / "props" / "prop_defs.json"
PAIRS = [("forest_pedestal", "forest_pedestal_lit"), ("forest_gate_closed", "forest_gate_open")]


def forest_defs() -> dict:
    props = json.loads(DEFS.read_text(encoding="utf-8"))["props"]
    return {k: v for k, v in props.items() if k.startswith("forest_")}


class ForestCutoutsTest(unittest.TestCase):
    def test_every_forest_type_has_a_cutout_of_the_defs_size_with_hard_alpha(self) -> None:
        defs = forest_defs()
        self.assertEqual(len(defs), 25)
        for name, entry in defs.items():
            image = Image.open(CUTOUTS / entry["image"]).convert("RGBA")
            self.assertEqual(image.size, (entry["w"], entry["h"]), name)
            alphas = set(image.tobytes()[3::4])
            self.assertTrue(alphas <= {0, 255}, f"{name}: alpha must be fully transparent or opaque, got {sorted(alphas)[:4]}")
            ax, ay = entry["anchor"]
            self.assertTrue(0 <= ax <= entry["w"] and 0 <= ay <= entry["h"], f"{name}: anchor inside the sprite")
            bottom = [image.getpixel((x, entry["h"] - 1))[3] for x in range(entry["w"])]
            self.assertTrue(any(bottom), f"{name}: the bottom row (the ground line) has pixels")

    def test_the_two_states_share_canvas_and_anchor_and_stay_aligned(self) -> None:
        defs = forest_defs()
        for base, variant in PAIRS:
            a, b = defs[base], defs[variant]
            self.assertEqual((a["w"], a["h"], a["anchor"]), (b["w"], b["h"], b["anchor"]), f"{base}/{variant}")
            first = Image.open(CUTOUTS / a["image"]).convert("RGBA")
            second = Image.open(CUTOUTS / b["image"]).convert("RGBA")
            self.assertEqual(first.size, second.size)
            overlap = len(nsp.opaque(first) & nsp.opaque(second)) / len(nsp.opaque(first) | nsp.opaque(second))
            self.assertGreater(overlap, 0.65, f"{base}/{variant} are one object in two states (overlap {overlap:.2f})")
            # both stand on the same ground line: the lowest opaque row is the same
            low = lambda im: max(y for _x, y in nsp.opaque(im))  # noqa: E731
            self.assertEqual(low(first), low(second), f"{base}/{variant}: same ground line")


class NormalizeToolTest(unittest.TestCase):
    def _write(self, folder: Path, name: str, size: tuple[int, int], box: tuple[int, int, int, int], colour: tuple[int, int, int]) -> None:
        image = Image.new("RGBA", size, (0, 0, 0, 0))
        for y in range(box[1], box[3]):
            for x in range(box[0], box[2]):
                image.putpixel((x, y), (*colour, 255))
        image.save(folder / f"{name}.png")

    def test_the_variant_is_aligned_on_the_ground_line_and_both_get_one_canvas(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            folder = Path(tmp)
            self._write(folder, "a", (10, 12), (1, 2, 9, 12), (200, 0, 0))      # 8 wide, ends on the last row
            self._write(folder, "b", (11, 9), (3, 1, 11, 9), (0, 0, 200))       # shifted right by 2, 3 rows shorter
            defs = folder / "defs.json"
            entry = lambda n, w, h: {"w": w, "h": h, "anchor": [5.0, float(h)], "base_width": 8, "image": f"{n}.png"}  # noqa: E731
            defs.write_text(json.dumps({"props": {"a": entry("a", 10, 12), "b": entry("b", 11, 9)}}), encoding="utf-8")
            report = nsp.normalize(defs, folder, "a", "b", 4, False)
            document = json.loads(defs.read_text(encoding="utf-8"))["props"]
            self.assertEqual((document["a"]["w"], document["a"]["h"]), (document["b"]["w"], document["b"]["h"]))
            self.assertEqual(document["a"]["anchor"], document["b"]["anchor"])
            a = Image.open(folder / "a.png").convert("RGBA")
            b = Image.open(folder / "b.png").convert("RGBA")
            self.assertEqual(a.size, b.size)
            self.assertEqual(max(y for _x, y in nsp.opaque(a)), max(y for _x, y in nsp.opaque(b)), "same ground line")
            raw = a.tobytes()
            self.assertEqual({tuple(raw[i:i + 3]) for i in range(0, len(raw), 4) if raw[i + 3]}, {(200, 0, 0)}, "pixels are copied, never recoloured")
            self.assertEqual(len(nsp.opaque(b)), 8 * 8, "the variant keeps all its pixels")
            self.assertGreater(report["overlap"], 0.5)


if __name__ == "__main__":
    unittest.main()
