"""Forest import preserves approved silhouettes, shared anchors and state alignment."""
import json
import unittest
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]


class ForestImportTests(unittest.TestCase):
    def test_pixels_padding_palette_and_state_pairs(self):
        manifest = json.loads((ROOT / 'art/reference/layered_forest/import_manifest.json').read_text())['props']
        frames = json.loads((ROOT / 'art/build/sprites.json').read_text())['frames']
        art = json.loads((ROOT / 'presentation/common/prop_art.json').read_text())['props']
        defs = json.loads((ROOT / 'data/props/prop_defs.json').read_text())['props']
        palette = json.loads((ROOT / 'art/palette.json').read_text())
        allowed = {tuple(bytes.fromhex(c['hex'][1:])) for c in palette['colors'] if c['symbol'] not in palette['reserved']}
        self.assertEqual(25, len(manifest))
        for name, entry in manifest.items():
            with self.subTest(prop=name):
                source = Image.open(ROOT / 'data/props/cutouts_forest' / defs[name]['image']).convert('RGBA')
                image = Image.open(ROOT / 'art/build/sprites' / (name + '.png')).convert('RGBA')
                left, top, right, bottom = entry['padding']
                self.assertEqual(0, bottom)
                self.assertEqual(list(image.size), entry['padded_size'])
                self.assertEqual((0, 0), (image.width % 8, image.height % 8))
                self.assertEqual(source.tobytes(), image.crop((left, top, left + source.width, top + source.height)).tobytes())
                self.assertEqual(image.height, image.getbbox()[3])
                self.assertEqual(defs[name]['anchor'], entry['shared_anchor'])
                self.assertEqual(entry['header_anchor'], [frames[name]['ax'], frames[name]['ay']])
                self.assertEqual([left, top, source.width, source.height], art[name]['trim'])
                self.assertTrue(all(a in (0, 255) and (not a or (r, g, b) in allowed) for r, g, b, a in image.getdata()))
        for first, second in [('forest_pedestal', 'forest_pedestal_lit'), ('forest_gate_closed', 'forest_gate_open')]:
            self.assertEqual(manifest[first], manifest[second], 'A state swap never moves or resizes the canvas')
        ground = Image.open(ROOT / 'presentation/forest/forest_layered_ground.png').convert('RGBA')
        self.assertEqual((480, 288), ground.size)
        self.assertTrue(all(a == 255 and (r, g, b) in allowed for r, g, b, a in ground.getdata()))


if __name__ == '__main__':
    unittest.main()
