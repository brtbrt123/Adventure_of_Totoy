"""Review assets must satisfy the same palette/anchor contract as runtime sprites."""
import json
import unittest
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]


class LayeredGladeArtTests(unittest.TestCase):
    def test_palette_alpha_and_registered_anchors(self):
        palette = json.loads((ROOT / 'art/palette.json').read_text())
        allowed = {tuple(bytes.fromhex(c['hex'][1:])) for c in palette['colors']
                   if c['symbol'] not in palette['reserved']}
        base = ROOT / 'art/reference/layered_pilot'
        defs = json.loads((base / 'prop_defs_review.json').read_text())['props']
        frames = json.loads((ROOT / 'art/build/sprites.json').read_text())['frames']
        scene = json.loads((ROOT / 'data/scenes/glade_layered_props.json').read_text())
        self.assertEqual(20, len(defs))
        self.assertEqual(set(defs), {p['type'] for p in scene['props']})
        self.assertEqual(20, len({p['id'] for p in scene['props']}))
        for name, info in defs.items():
            with self.subTest(prop=name):
                with Image.open(base / 'props' / info['image']) as source:
                    image = source.convert('RGBA')
                self.assertTrue(all(a in (0, 255) and (a == 0 or (r, g, b) in allowed)
                                    for r, g, b, a in image.getdata()))
                self.assertEqual(info['anchor'], [frames[name]['ax'], frames[name]['ay']])
                ax, ay = info['anchor']
                self.assertTrue(0 <= ax <= image.width)
                self.assertEqual(image.getbbox()[3], ay, 'Anchor must mark the bottom base line')
                with Image.open(ROOT / 'art/build/sprites' / (name + '.png')) as built:
                    self.assertEqual(image.tobytes(), built.convert('RGBA').crop((0, 0, image.width, image.height)).tobytes())
        with Image.open(base / 'glade_ground_totoy36.png') as ground:
            self.assertEqual((560, 336), ground.size)
            self.assertTrue(set(ground.convert('RGB').getdata()) <= allowed)


if __name__ == '__main__':
    unittest.main()
