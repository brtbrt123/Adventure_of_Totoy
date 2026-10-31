"""Root Hollow palette workflow, proposal only: no runtime texture or map-data writes."""
from pathlib import Path
import hashlib
import json
import sys
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
sys.path.insert(0,str(ROOT/'tools/art'))
import make_arena_ground_from_reference as ground


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    layout_path = ROOT/'docs/previews/hollow_trial_v1/layout.json'
    layout = json.loads(layout_path.read_text())
    ground.W, ground.H = layout['size']
    raw = Image.open(HERE/'ground_raw.png').convert('RGB')
    resized = raw.resize(tuple(layout['size']),Image.Resampling.LANCZOS)
    result = ground.to_image(ground.cleanup(ground.snap_image(resized))).convert('RGBA')
    palette = json.loads((ROOT/'art/palette.json').read_text())
    allowed = {tuple(bytes.fromhex(c['hex'][1:])) for c in palette['colors'] if c['symbol'] not in palette['reserved']}
    assert result.size == (512,352)
    pixels = list(result.get_flattened_data())
    assert all(p[3] == 255 and p[:3] in allowed for p in pixels)
    native = HERE/'native'
    native.mkdir(exist_ok=True)
    result.save(native/'hollow_trial_ground.png')
    result.resize((1024,704),Image.Resampling.NEAREST).save(HERE/'ground_full_2x.png')
    x,y,w,h = layout['fight_floor']
    result.crop((x,y,x+w,y+h)).resize((w*3,h*3),Image.Resampling.NEAREST).save(HERE/'fight_floor_3x.png')
    # A separately labelled registration proof; these lines are never part of the painting.
    proof = result.resize((1024,704),Image.Resampling.NEAREST)
    draw = ImageDraw.Draw(proof)
    draw.line([(x*2,y*2) for x,y in layout['outline']],fill=(244,236,214,255),width=2)
    x,y,w,h = layout['fight_floor']
    draw.rectangle((x*2,y*2,(x+w)*2,(y+h)*2),outline=(130,170,210,255),width=2)
    draw.text((12,12),'REGISTRATION PROOF ONLY - LINES NOT IN PAINTING',fill=(244,236,214,255))
    proof.save(HERE/'contact_sheet_layout_registration.png')
    report = {'status':'PASS','scope':'ground-only offline proposal, owner approval pending',
        'size':list(result.size),'opaque_pixels':len(pixels),'used_colours':len({p[:3] for p in pixels}),
        'off_palette_pixels':0,'reserved_combat_colour_pixels':0,'transparent_pixels':0,
        'raw_size':list(raw.size),'resampling':'Root Hollow workflow: LANCZOS downsample; existing Lab snap/cleanup; nearest-neighbour previews',
        'source_sha256':digest(HERE/'ground_raw.png'),'layout_sha256':digest(layout_path),
        'guide_sha256':digest(ROOT/'docs/previews/hollow_trial_v1/walkable_guide.png'),
        'painting_sha256':digest(native/'hollow_trial_ground.png'),
        'geometry':'Painting follows layout as a visual reference. No collision or runtime map is changed; outline registration is for human inspection, not automatic collision certification.',
        'not_verified':['owner appearance approval','runtime night exposure','combat warning readability','collision/playthrough','props/lighting/audio'],
        'no_runtime_install':True}
    (HERE/'validation.json').write_text(json.dumps(report,indent=2)+'\n')
    print('PASS:512x352,180224 opaque palette pixels,no reserved colours; raw/guide/layout hashes recorded; no runtime changes')


if __name__=='__main__':
    main()
