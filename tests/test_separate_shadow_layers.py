"""Separate shadow assets keep object identity, transparent edges and aligned feet."""
import hashlib
import json
import unittest
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]


class SeparateShadowLayerTests(unittest.TestCase):
    def test_all_props_have_independent_shadow_layers(self):
        manifest = json.loads((ROOT / 'art/reference/shadow_layers/manifest.json').read_text())
        defs = json.loads((ROOT / 'data/props/prop_defs.json').read_text())['props']
        defs.update(json.loads((ROOT / 'data/props/prop_defs_woodland.json').read_text())['props'])
        defs.update(json.loads((ROOT / 'data/props/prop_defs_root_hollow.json').read_text())['props'])
        frames = json.loads((ROOT / 'art/build/sprites.json').read_text())['frames']
        renderer = json.loads((ROOT / 'presentation/common/prop_art.json').read_text())['props']
        self.assertEqual(set(defs), set(manifest['props']))
        names = set()
        for name, entry in manifest['props'].items():
            with self.subTest(prop=name):
                with Image.open(ROOT / entry['object_source']) as source:
                    obj = source.convert('RGBA')
                self.assertEqual(entry['object_rgba_sha256'], hashlib.sha256(obj.tobytes()).hexdigest(), 'Shadow must match this exact object')
                self.assertEqual(entry['object_anchor'], defs[name]['anchor'])
                for orientation in ['normal', 'flipped']:
                    shadow = entry['shadows'][orientation]
                    self.assertEqual(shadow['sprite'], renderer[name]['cast_shadow'][orientation], 'Renderer must use this exact object shadow')
                    names.add(shadow['sprite'])
                    self.assertNotEqual(name, shadow['sprite'], 'Object and shadow are separate assets')
                    with Image.open(ROOT / 'art/build/sprites' / (shadow['sprite'] + '.png')) as image:
                        pixels = image.convert('RGBA')
                    self.assertEqual(list(pixels.size), shadow['size'])
                    self.assertEqual([frames[shadow['sprite']]['ax'], frames[shadow['sprite']]['ay']], shadow['anchor'])
                    self.assertTrue(all(a in (0, 255) and (a == 0 or (r, g, b) == (28, 24, 36))
                                        for r, g, b, a in pixels.getdata()))
                    self.assertGreater(pixels.getbbox()[2], pixels.getbbox()[0])
                    x0, y0, x1, y1 = shadow['bounds_relative_to_feet']
                    self.assertEqual(0, y0, 'Projected shadows start at the feet')
                    self.assertLessEqual(y1, obj.height * abs(manifest['projection']['dy_per_height']) + 2)
                    self.assertGreaterEqual(x0, -obj.width - obj.height * abs(manifest['projection']['dx_per_height']) - 2)
                    self.assertLessEqual(x1, obj.width + obj.height * abs(manifest['projection']['dx_per_height']) + 2)
        self.assertEqual(2 * len(defs), len(names))


if __name__ == '__main__':
    unittest.main()
