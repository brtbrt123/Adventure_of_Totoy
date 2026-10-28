"""Only review-source contracts; no runtime assets are installed by this stage."""
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
                self.assertFalse((ROOT/'art/src'/('polish_'+path.name)).exists(),'review sources must not install themselves')
    def test_all_requested_effects_have_six_review_frames(self):
        root=ROOT/'art/reference/woodland_polish_v1/grids'
        for effect in ['heal','alert','hit','parry','dust','stagger','death','exposed']:
            self.assertTrue(all((root/(effect+'_'+str(i)+'.txt')).exists() for i in range(1,7)))
