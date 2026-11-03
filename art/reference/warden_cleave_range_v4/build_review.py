"""Keep Astra V3's blade trace; add a separate exact-core-range strike sweep."""
from pathlib import Path
import importlib.util
import json
import math
import sys
from PIL import Image

sys.dont_write_bytecode=True
OUT=Path(__file__).resolve().parent
V3=OUT.parent/'warden_fx_astra_v3'
spec=importlib.util.spec_from_file_location('astra_visibility',V3/'build_review.py')
a=importlib.util.module_from_spec(spec);spec.loader.exec_module(a)
a.OUT=OUT;a.v.OUT=OUT;a.v.b.OUT=OUT
C,X,Y,SIZE=a.C,a.X,a.Y,a.SIZE
OLD_FX=a.fx
OLD_SCENE=a.scene
REACH=46;MOB_RADIUS=11;RADIUS=REACH+MOB_RADIUS;HALF_ANGLE=.9

def fx(name,n,count):
    if name!='cleave_range':return OLD_FX(name,n,count)
    im=a.v.b.blank(SIZE)
    front=[18,28,38,48,57,57][n]
    # Rasterize the same feet-centred cone as core; no painted overshoot at corners.
    for dy in range(-45,46):
        for dx in range(58):
            radius=math.hypot(dx,dy)
            angle=math.atan2(dy,dx)
            if radius>RADIUS or abs(angle)>HALF_ANGLE:continue
            edge=radius>=54.5
            side=radius>=12 and radius*math.sin(HALF_ANGLE-abs(angle))<1.1
            wave=abs(radius-front)<1.6 and radius>=12
            ray=radius>14 and min(abs(radius*math.sin(angle-theta)) for theta in (-.72,-.48,-.24,0,.24,.48,.72))<.65
            if edge:
                color='p' if n<2 else 'o' if n<5 else 'u'
            elif wave:color='p' if n<3 else 'o'
            elif side:color='o' if n<4 else 't'
            elif ray and radius<front:color='u' if (dx+dy+n)%5 else 'o'
            else:continue
            im.putpixel((X+dx,Y+dy),C[color])
    a.v.b.check(im)
    return im

def scene(body,effects,ground,state,index,label,families=(),warning=None,t=0):
    families=list(families)
    arc=next((n for family,n in families if family=='cleave_arc'),None)
    if arc is not None and state!='recover':
        effects=dict(effects,cleave_range=[fx('cleave_range',i,6) for i in range(6)])
        families.append(('cleave_range',arc))
        # V2's old compositor cannot display a newly named family; comparisons
        # below use actual decoded V3 frames instead of that legacy callback.
        a.v.CAPTURES.setdefault(label,(ground.copy(),ground.copy()))
    return OLD_SCENE(body,effects,ground,state,index,label,families,warning,t)

def comparisons():
    before=a.decode(V3/'cleave.gif')
    after=a.NATIVE['cleave']
    cases=[(13,'windup'),(14,'strike_1'),(15,'strike_2'),(17,'recovery')]
    sheet=Image.new('RGBA',(512,196*len(cases)),C['0'])
    for row,(index,name) in enumerate(cases):
        old,new=before[index],after[index]
        y=row*196
        a.v.b.text(sheet,(4,y+2),'BEFORE / '+name.upper())
        a.v.b.text(sheet,(260,y+2),'RANGE FIX / '+name.upper())
        sheet.alpha_composite(old,(0,y+20));sheet.alpha_composite(new,(256,y+20))
        new.save(OUT/f'cleave_{name}_native.png')
        new.resize((768,528),Image.Resampling.NEAREST).save(OUT/f'cleave_{name}_3x.png')
    sheet.save(OUT/'contact_sheet_range_before_after_native.png')
    sheet.resize((1536,sheet.height*3),Image.Resampling.NEAREST).save(OUT/'contact_sheet_range_before_after_3x.png')
    for state in ('windup','strike_1','strike_2'):
        im=Image.open(OUT/f'cleave_{state}_native.png').convert('RGBA')
        crop=im.crop((40,48,128,158))
        crop.resize((440,550),Image.Resampling.NEAREST).save(OUT/f'cleave_{state}_closeup.png')

def main():
    OUT.mkdir(exist_ok=True)
    protected={p.relative_to(V3).as_posix():a.v.sha(p) for p in V3.rglob('*') if p.is_file() and p.suffix!='.import'}
    a.fx=fx;a.scene=scene;a.comparisons=comparisons
    a.main()
    manifest=json.loads((OUT/'manifest.json').read_text())
    bounds=[]
    for n in range(6):
        im=fx('cleave_range',n,6)
        points=[(x-X,y-Y) for y in range(SIZE[1]) for x in range(SIZE[0]) if im.getpixel((x,y))[3]]
        assert all(math.hypot(x,y)<=57 and abs(math.atan2(y,x))<=.9 for x,y in points)
        assert im.getpixel((X+57,Y))[3]==255,'Full core reach is not shown'
        key,meta=a.v.compact_export('cleave_range',n,im)
        manifest['fx_assets'][key]=meta
        bounds.append({'frame':n+1,'opaque_pixels':len(points),'max_radius':max(math.hypot(x,y) for x,y in points)})
    manifest['fx_families']['cleave_range']=6
    manifest['fx_frames']=120
    manifest['generated_with']='Astra V3 visuals plus exact-range Cleave sweep correction'
    manifest['cleave_range_fix']={'reach':46,'mob_radius':11,'radius':57,'half_angle':.9,'active_only':True,
        'method':'Separate feet-centred impact sweep; preserve attached blade trace and all core numbers','frames':bounds}
    manifest['validation']='Native cone bounded exactly to radius57 and half-angle0.9; reaches57 in every active frame; original body/timing/warnings preserved; independent audit follows.'
    (OUT/'manifest.json').write_text(json.dumps(manifest,indent=2))
    assert all(a.v.sha(V3/rel)==digest for rel,digest in protected.items())
    print('CLEAVE RANGE PASS: six impact frames reach57, remain inside core cone, only active during strike; no core/runtime edits')

if __name__=='__main__':main()
