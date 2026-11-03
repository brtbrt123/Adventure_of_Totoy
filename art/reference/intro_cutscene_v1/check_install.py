"""Validate installed full-screen panels and music against approved review sources."""
from pathlib import Path
from PIL import Image
import json,wave
ROOT=Path(__file__).resolve().parents[3]
BASE=Path(__file__).resolve().parent
palette=json.loads((ROOT/'art/palette.json').read_text())
allowed={tuple(bytes.fromhex(c['hex'][1:]))+(255,) for c in palette['colors'] if c['symbol'] not in palette['reserved']}
manifest=json.loads((BASE/'manifest.json').read_text())
for panel in manifest['panels']:
    name=panel['id']+'.png'
    installed=ROOT/'presentation/cutscene/panels'/name
    assert installed.read_bytes()==(BASE/'native'/name).read_bytes(),name
    for path,size in [(installed,(320,180)),(installed.with_name(installed.stem+'_overscan.png'),(352,198))]:
        image=Image.open(path).convert('RGBA');assert image.size==size,path
        assert set(image.get_flattened_data())<=allowed,path
with wave.open(str(ROOT/'presentation/audio/music/intro_theme.wav'),'rb') as track:
    assert track.getframerate()==48000 and track.getsampwidth()==2
    assert track.getnframes()/track.getframerate()==32
print('INTRO INSTALL ASSETS OK:7 approved panels,7 palette/opaque overscans,48kHz16bit32s theme')
