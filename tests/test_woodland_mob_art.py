import json
import unittest
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
class MobArt(unittest.TestCase):
    def test_import_preserves_every_source_pixel_and_anchor(self):
        frames=json.loads((ROOT/'art/build/sprites.json').read_text())['frames']
        for mob,base,prefix in [('mossling','creature_mossling_v1','creature_mossling'),('boar','creature_thornback_boar_v1','creature_thornback_boar')]:
            source=ROOT/'art/reference/chapter1_creatures'/base
            sheet=Image.open(source.with_suffix('.png')).convert('RGBA')
            meta=json.loads(source.with_suffix('.json').read_text())
            for name,f in meta['frames'].items():
                state,n=name.removeprefix(prefix+'_').rsplit('_',1)
                key=mob+'_'+state+'_right_'+n
                built=Image.open(ROOT/'art/build/sprites'/(key+'.png')).convert('RGBA')
                self.assertEqual(built.tobytes(),sheet.crop((f['x'],f['y'],f['x']+f['w'],f['y']+f['h'])).tobytes())
                self.assertEqual([f['ax'],f['ay']],[frames[key]['ax'],frames[key]['ay']])
