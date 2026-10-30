"""Pixel/anchor contract for the padded village sprites and converted runtime grounds."""
import json
import unittest
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]


class VillageSpriteImportTests(unittest.TestCase):
    def test_padding_preserves_shared_content_and_base(self):
        defs = json.loads((ROOT / 'data/props/prop_defs.json').read_text())['props']
        defs.update(json.loads((ROOT / 'data/props/prop_defs_woodland.json').read_text())['props'])
        defs.update(json.loads((ROOT / 'data/props/prop_defs_root_hollow.json').read_text())['props'])
        manifest = json.loads((ROOT / 'art/reference/layered_village/import_manifest.json').read_text())['props']
        art = json.loads((ROOT / 'presentation/common/prop_art.json').read_text())['props']
        frames = json.loads((ROOT / 'art/build/sprites.json').read_text())['frames']
        self.assertEqual(31, len(manifest))
        self.assertNotIn('village_anvil', frames)
        self.assertNotIn('village_bench', frames)
        for name, entry in manifest.items():
            with self.subTest(prop=name):
                source = Image.open(ROOT / 'art/reference/layered_village/props' / defs[name]['image']).convert('RGBA')
                built = Image.open(ROOT / 'art/build/sprites' / (name + '.png')).convert('RGBA')
                left, top, right, bottom = entry['padding']
                self.assertEqual(0, bottom, 'Never pad below the base')
                self.assertEqual(entry['shared_anchor'], defs[name]['anchor'])
                self.assertEqual([source.width, source.height], entry['source_size'])
                self.assertEqual([built.width, built.height], entry['padded_size'])
                self.assertEqual((0, 0), (built.width % 8, built.height % 8))
                self.assertEqual(built.height, built.getbbox()[3], 'Lowest opaque row stays at the base')
                self.assertEqual(source.tobytes(), built.crop((left, top, left + source.width, top + source.height)).tobytes())
                self.assertEqual(entry['header_anchor'], [frames[name]['ax'], frames[name]['ay']])
                self.assertEqual([left, top, source.width, source.height], art[name]['trim'])

    def test_runtime_grounds_have_exact_palette_and_size(self):
        pal = json.loads((ROOT / 'art/palette.json').read_text())
        allowed = {tuple(bytes.fromhex(c['hex'][1:])) for c in pal['colors'] if c['symbol'] not in pal['reserved']}
        for name, size in [('presentation/village/village_layered_ground.png', (571, 336)),
                           ('presentation/forest/glade_layered_ground.png', (560, 336))]:
            with self.subTest(ground=name):
                with Image.open(ROOT / name) as image:
                    self.assertEqual(size, image.size)
                    self.assertTrue(set(image.convert('RGB').getdata()) <= allowed)

    def test_contact_shadows_do_not_bridge_gate_or_float_below_bases(self):
        art = json.loads((ROOT / 'presentation/common/prop_art.json').read_text())['props']
        defs = json.loads((ROOT / 'data/props/prop_defs.json').read_text())['props']
        defs.update(json.loads((ROOT / 'data/props/prop_defs_woodland.json').read_text())['props'])
        defs.update(json.loads((ROOT / 'data/props/prop_defs_root_hollow.json').read_text())['props'])
        self.assertEqual(set(defs), set(art))
        for name, metadata in art.items():
            with self.subTest(prop=name):
                shadow = metadata['contact_shadow']
                width, height = shadow['size']
                self.assertEqual([defs[name]['w'], defs[name]['h']], [width, height])
                core = {(x, y) for start, y, length in shadow['core'] for x in range(start, start + length)}
                edge = {(x, y) for start, y, length in shadow['edge'] for x in range(start, start + length)}
                self.assertTrue(core)
                self.assertFalse(core & edge, 'Soft edge must not double-darken the core')
                self.assertTrue(all(-1 <= x < width + 3 and height - 20 <= y <= height + 3 for x, y in core | edge))
                if name == 'village_gate':
                    self.assertFalse(any(34 <= x <= 52 for x, y in core | edge), 'Gate passage must stay clear of contact shadow')


if __name__ == '__main__':
    unittest.main()
