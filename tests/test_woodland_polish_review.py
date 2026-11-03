"""Approved review sources retain palette/frame contracts after runtime installation."""
from pathlib import Path
import sys, unittest
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools/art'))
import artlib
class PolishReview(unittest.TestCase):
    def test_native_review_art_has_valid_grids_and_reserved_colour_scope(self):
        palette=artlib.load_palette()
        paths=list((ROOT/'art/reference/woodland_polish_v1/grids').glob('*.txt'))
        self.assertEqual(50,len(paths))
        for path in paths:
            with self.subTest(asset=path.name):
                sprite=artlib.parse_sprite(path)
                self.assertEqual([],artlib.check_sprite(sprite,palette))
                used=set(''.join(sprite.rows))
                if not path.stem.startswith('parry_'):
                    self.assertFalse(used & palette.reserved)
                if path.stem not in ('herb_bundle','lock'):
                    self.assertEqual(path.read_text(),(ROOT/'art/src'/('woodland_fx_'+path.name)).read_text())
    def test_all_requested_effects_have_six_review_frames(self):
        root=ROOT/'art/reference/woodland_polish_v1/grids'
        for effect in ['heal','alert','hit','parry','dust','stagger','death','exposed']:
            self.assertTrue(all((root/(effect+'_'+str(i)+'.txt')).exists() for i in range(1,7)))
