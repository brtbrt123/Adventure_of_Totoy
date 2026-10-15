"""Tests for the art validator: it must pass on the real art and fail on deliberately bad art.

Run: python -m unittest discover -s tests -v
"""
from __future__ import annotations

import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
VALIDATE = ROOT / "tools" / "art" / "validate_art.py"

GOOD_TILE = "# kind: tile\n# seamless: true\n" + "\n".join(["b" * 16] * 16) + "\n"


def run_validator(*args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run([sys.executable, str(VALIDATE), *args], capture_output=True, text=True, check=False)


class RealArt(unittest.TestCase):
    def test_project_art_passes(self) -> None:
        result = run_validator()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


class BadArt(unittest.TestCase):
    def check_fails(self, files: dict[str, str], expected: str) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            for name, content in files.items():
                (Path(tmp) / name).write_text(content, encoding="utf-8")
            result = run_validator("--src", tmp, "--no-png")
        self.assertEqual(result.returncode, 1, result.stdout)
        self.assertIn(expected, result.stdout)

    def test_good_fixture_passes(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            (Path(tmp) / "ok.txt").write_text(GOOD_TILE, encoding="utf-8")
            result = run_validator("--src", tmp, "--no-png")
        self.assertEqual(result.returncode, 0, result.stdout)

    def test_wrong_tile_size(self) -> None:
        rows = "\n".join(["b" * 15] * 16)
        self.check_fails({"bad.txt": f"# kind: tile\n{rows}\n"}, "tile must be 16x16")

    def test_off_palette_symbol(self) -> None:
        rows = ["b" * 16] * 16
        rows[3] = "bbbb!bbbbbbbbbbb"
        self.check_fails({"bad.txt": "# kind: tile\n" + "\n".join(rows) + "\n"}, "off-palette symbol '!'")

    def test_reserved_combat_color_in_tile(self) -> None:
        rows = ["b" * 16] * 16
        rows[3] = "bbbbxbbbbbbbbbbb"  # x = combat gold, reserved
        self.check_fails({"bad.txt": "# kind: tile\n" + "\n".join(rows) + "\n"}, "reserved combat color 'x'")

    def test_reserved_combat_color_allowed_in_sprite(self) -> None:
        rows = ["b" * 8] * 8
        rows[3] = "bbbxxbbb"
        with tempfile.TemporaryDirectory() as tmp:
            (Path(tmp) / "ok.txt").write_text("# kind: sprite\n" + "\n".join(rows) + "\n", encoding="utf-8")
            result = run_validator("--src", tmp, "--no-png")
        self.assertEqual(result.returncode, 0, result.stdout)

    def test_ragged_rows(self) -> None:
        rows = ["b" * 16] * 16
        rows[5] = "b" * 12
        self.check_fails({"bad.txt": "# kind: tile\n" + "\n".join(rows) + "\n"}, "rows are not all")

    def test_missing_kind(self) -> None:
        self.check_fails({"bad.txt": "\n".join(["b" * 16] * 16) + "\n"}, "missing or invalid '# kind:'")

    def test_seam_mismatch(self) -> None:
        rows = ["f" + "b" * 14 + "6"] * 16  # left edge f, right edge 6: 6 never touches f inside the tile
        self.check_fails({"bad.txt": "# kind: tile\n# seamless: true\n" + "\n".join(rows) + "\n"}, "seam mismatch")

    def test_bad_sprite_size(self) -> None:
        rows = "\n".join(["b" * 10] * 12)
        self.check_fails({"bad.txt": f"# kind: sprite\n{rows}\n"}, "sprite size must be a multiple of 8")

    def test_empty_source_dir_fails(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            result = run_validator("--src", tmp, "--no-png")
        self.assertEqual(result.returncode, 1)


class BadPng(unittest.TestCase):
    def check_png_fails(self, pixel: tuple[int, int, int, int], expected: str) -> None:
        with tempfile.TemporaryDirectory() as src, tempfile.TemporaryDirectory() as build:
            (Path(src) / "ok.txt").write_text(GOOD_TILE, encoding="utf-8")
            image = Image.new("RGBA", (16, 16), (0x7F, 0x93, 0x48, 255))  # grass_4 in art/palette.json
            image.putpixel((2, 2), pixel)
            image.save(Path(build) / "bad.png")
            result = run_validator("--src", src, "--build", build)
        self.assertEqual(result.returncode, 1, result.stdout)
        self.assertIn(expected, result.stdout)

    def test_partial_transparency(self) -> None:
        self.check_png_fails((0x7F, 0x93, 0x48, 128), "partially transparent")

    def test_off_palette_color(self) -> None:
        self.check_png_fails((1, 2, 3, 255), "off-palette pixel")


if __name__ == "__main__":
    unittest.main()
