"""Review-only panel contracts; does not install or change production assets."""
from pathlib import Path
from PIL import Image
import json, hashlib
ROOT=Path(__file__).resolve().parents[3]
BASE=Path(__file__).resolve().parent
def main():
    manifest=json.loads((BASE/'manifest.json').read_text())
    beats=json.loads((ROOT/'data/cutscenes/intro.json').read_text())['cutscenes']['intro']['beats']
    palette=json.loads((ROOT/'art/palette.json').read_text())
    allowed={tuple(bytes.fromhex(c['hex'][1:]))+(255,) for c in palette['colors'] if c['symbol'] not in palette['reserved']}
    assert len(manifest['panels'])==len(beats)==7
    assert [p['id'] for p in manifest['panels']]==[p['art'] for p in beats]
    for panel in manifest['panels']:
        name=panel['id']+'.png'
        assert hashlib.sha256((BASE/'raw'/name).read_bytes()).hexdigest()==panel['raw_sha256']
        image=Image.open(BASE/'native'/name).convert('RGBA')
        assert image.size==(320,180),name
        assert set(image.getdata())<=allowed,name
    print('INTRO ART REVIEW OK:7 matching IDs, raw hashes,320x180, opaque fixed palette, no reserved scenery colours')
if __name__=='__main__':main()
