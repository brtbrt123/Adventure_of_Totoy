"""Independent review-art audit for Astra's Warden effects. Never edits generated assets."""
from pathlib import Path
import argparse
import hashlib
import json
from PIL import Image

ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).resolve().parent
BASE=ROOT/'art/reference/warden_v1'
OLD=BASE/'animation_review'
NEW=ROOT/'art/reference/warden_fx_astra_v2'
C={p['symbol']:tuple(bytes.fromhex(p['hex'].lstrip('#')))+(255,) for p in json.loads((ROOT/'art/palette.json').read_text())['colors']}
ALLOWED=set(C.values());RESERVED={C[k] for k in 'xyzA'}

def hashes():
    return {p.relative_to(BASE).as_posix():hashlib.sha256(p.read_bytes()).hexdigest()
            for p in BASE.rglob('*') if p.is_file() and p.suffix in ('.png','.gif','.json','.py','.md','.txt')}

def timeline(path):
    frames=[]
    with Image.open(path) as im:
        assert im.size==(1024,704),(path,im.size)
        for n in range(im.n_frames):
            im.seek(n)
            rgb=im.convert('RGBA')
            native=rgb.resize((256,176),Image.Resampling.NEAREST)
            assert native.resize(im.size,Image.Resampling.NEAREST).tobytes()==rgb.tobytes(),('fractional scale',path,n)
            assert all(p in ALLOWED for p in set(native.get_flattened_data())),('GIF palette',path,n)
            duration=im.info['duration']
            assert duration%50==0,(path,duration)
            frames.extend([native.copy()]*(duration//50))
    return frames

def run(report_path):
    baseline=json.loads((HERE/'baseline_hashes.json').read_text())
    assert hashes()==baseline,'Original Warden design/animation/review assets changed'
    report={'status':'PASS','baseline_files_unchanged':len(baseline),'gif_comparisons':{},'native_body_frames':0,'native_fx_frames':0}
    for old in (OLD/'body').rglob('*.png'):
        new=NEW/'body'/old.relative_to(OLD/'body')
        assert new.exists(),('missing body',new)
        assert Image.open(old).convert('RGBA').tobytes()==Image.open(new).convert('RGBA').tobytes(),('body changed',new)
        report['native_body_frames']+=1
    manifest=json.loads((NEW/'manifest.json').read_text())
    old_manifest=json.loads((OLD/'manifest.json').read_text())
    for key in ('body_anchor','body_cell','states','core_attack_timings','warning_geometry','chain_delay_ticks','exposed_ticks'):
        assert manifest[key]==old_manifest[key],('contract changed',key,manifest[key],old_manifest[key])
    family_changes={}
    for path in (NEW/'fx').rglob('*.png'):
        im=Image.open(path).convert('RGBA')
        assert im.width%8==im.height%8==0 and max(im.size)<=256,('FX dimensions',path,im.size)
        assert all(p[3] in (0,255) and (not p[3] or p in ALLOWED-RESERVED) for p in im.get_flattened_data()),('FX palette/alpha',path)
        data=manifest['fx_assets'][path.stem]
        assert list(im.size)==data['size']
        ax,ay=data['anchor'];assert 0<=ax<=im.width and 0<=ay<=im.height,('anchor',path,data)
        report['native_fx_frames']+=1
        if path.stem in old_manifest['fx_assets']:
            old_data=old_manifest['fx_assets'][path.stem]
            old=Image.open(OLD/'fx'/path.relative_to(NEW/'fx')).convert('RGBA')
            a,b=Image.new('RGBA',(256,176)),Image.new('RGBA',(256,176))
            a.alpha_composite(old,(66-old_data['anchor'][0],108-old_data['anchor'][1]))
            b.alpha_composite(im,(66-ax,108-ay))
            family=path.parent.name
            family_changes[family]=family_changes.get(family,0)+int(a.tobytes()!=b.tobytes())
    report['changed_native_frames_by_family']=family_changes
    for old in OLD.glob('*.gif'):
        new=NEW/old.name
        assert new.exists(),('missing clip',new)
        a,b=timeline(old),timeline(new)
        assert len(a)==len(b),('timing changed',old.name,len(a),len(b))
        cues=0;changed=0
        for n,(before,after) in enumerate(zip(a,b)):
            pa=list(before.get_flattened_data());pb=list(after.get_flattened_data())
            for i,(x,y) in enumerate(zip(pa,pb)):
                if x in RESERVED or y in RESERVED:
                    assert x==y,('warning moved/obscured',old.name,n,i%256,i//256,x,y)
                    cues+=1
                changed+=int(x!=y)
        report['gif_comparisons'][old.name]={'duration_ms':len(a)*50,'warning_pixels_preserved':cues,'changed_pixel_samples':changed}
    for clip in ('all_attacks.gif','cleave_parry_exposed.gif','all_effects.gif'):
        assert report['gif_comparisons'][clip]['changed_pixel_samples']>0,('no actual FX changes',clip)
    for clip,start,end in [('guard_break_exposed.gif',1300,2400),('cleave_parry_exposed.gif',1100,2200)]:
        frames=timeline(NEW/clip)
        bright={C[k] for k in 'uop'}
        for index in range(start//50,end//50):
            im=frames[index]
            assert not set(im.crop((69,87,75,95)).get_flattened_data()).intersection(bright),('exposed chest relit',clip,index)
    report['exposed_chest_stays_dark']=True
    assert report['native_body_frames']==60
    assert report['native_fx_frames']>=100
    report['review_folder']=NEW.relative_to(ROOT).as_posix()
    report_path.write_text(json.dumps(report,indent=2))
    print('PASS: original assets unchanged,60 identical body frames, native FX hygiene,11 timed4x clips, pixel-exact warnings,dark exposed rune')

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--baseline',action='store_true')
    parser.add_argument('--new-root',type=Path,default=NEW)
    parser.add_argument('--report',type=Path,default=HERE/'report.json')
    args=parser.parse_args()
    NEW=args.new_root.resolve()
    if args.baseline:
        data=hashes();(HERE/'baseline_hashes.json').write_text(json.dumps(data,indent=2))
        print('Recorded',len(data),'original Warden design/animation/review file hashes')
    else:run(args.report)
