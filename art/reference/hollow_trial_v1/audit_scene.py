"""Exact asset/atlas parity and approval checks; no core/data writes."""
from pathlib import Path
import hashlib
import json
from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent


def main():
    report = json.loads((HERE/'scene_registration.json').read_text())
    approval = json.loads((HERE/'APPROVAL.json').read_text())
    assert hashlib.sha256((ROOT/'presentation/forest/hollow_trial_layered_ground.png').read_bytes()).hexdigest()==approval['sha256']
    frames = json.loads((ROOT/'art/build/sprites.json').read_text())['frames']
    atlas = Image.open(ROOT/'art/build/sprites.png').convert('RGBA')
    assert atlas.height<=8192
    for name,meta in report['approved_art'].items():
        source = ROOT/meta['source']
        assert hashlib.sha256(source.read_bytes()).hexdigest()==meta['sha256'],name
        expected = Image.open(source).convert('RGBA')
        frame = frames[name]
        actual = atlas.crop((frame['x'],frame['y'],frame['x']+frame['w'],frame['y']+frame['h']))
        assert actual.size==expected.size and actual.tobytes()==expected.tobytes(),name
        assert [frame['ax'],frame['ay']]==meta['anchor'],name
    assert len(report['props'])==22 and len(report['placements'])==32
    assert hashlib.sha256((ROOT/'presentation/maps/hollow_trial_layered.tscn').read_bytes()).hexdigest()==report['generated_scene_sha256']
    print('SCENE ART PASS:approved ground SHA,22 byte-identical atlas assets/anchors,32 placements,scene source SHA,atlas <=8192')


if __name__=='__main__':
    main()
