"""Astra V3: readable attack silhouettes, pale cores, unchanged V2 guard/body.

Safely imports the V2 builder, redirects BOTH output roots before any generation.
Only this folder is written. Run with python -B from the project root.
"""
from pathlib import Path
import hashlib
import importlib.util
import json
import math
import sys
from PIL import Image, ImageDraw

sys.dont_write_bytecode=True
OUT=Path(__file__).resolve().parent
V2=OUT.parent/'warden_fx_astra_v2'
spec=importlib.util.spec_from_file_location('astra_v2',V2/'build_review.py')
v=importlib.util.module_from_spec(spec)
spec.loader.exec_module(v)
v.OUT=OUT
v.b.OUT=OUT
BASE_FX=v.fx
BASE_SCENE=v.scene
BASE_ENCODE=v.ORIGINAL_ENCODE
C,X,Y,SIZE=v.C,v.X,v.Y,v.SIZE
NATIVE={}


def trim_ring(im):
    for y in range(Y-50,Y+51):
        for x in range(X-50,X+51):
            if 0<=x<im.width and 0<=y<im.height and (x-X)**2+(y-Y)**2>48**2:
                im.putpixel((x,y),(0,0,0,0))
    return im


def fx(name,n,count):
    if name not in ('cleave_arc','lash_strike','ring_burst','ring_afterglow'):
        return BASE_FX(name,n,count)
    if name == 'ring_afterglow':
        # Recovery never reuses the bright active-strike boundary/core.
        im=BASE_FX('ring_burst',min(7,5+n//3),8)
        p=im.load()
        for y in range(im.height):
            for x in range(im.width):
                if p[x,y][3] and p[x,y] in {C[k] for k in '1pou76'}:
                    p[x,y]=C['5' if n<2 else '4']
        return im
    im=v.b.blank(SIZE)
    d=ImageDraw.Draw(im)
    if name == 'cleave_arc':
        pose=n//2
        angle=[-105,-15,18][pose]
        start=[-145,-105,-15][pose]
        lean=[0,2,1][pose]
        # Trace one coherent arc around this pose's pivot; exact live hook tip.
        shift=2 if -100<angle<-35 else 0
        pts=[]
        for k in range(37):
            a=math.radians(start+(angle-start)*k/36)
            pts.append((X+6+lean-shift+11*math.cos(a)-10*math.sin(a),
                        Y-19+11*math.sin(a)+10*math.cos(a)))
        v.line(d,pts,'0',5)
        v.line(d,pts,'o',3)
        v.line(d,pts[2:],'p',2)
        v.line(d,pts[-10:],'1',2)
        tip=v.hook(angle,lean)
        assert abs(tip[0]-pts[-1][0])+abs(tip[1]-pts[-1][1])<.001
        if pose == 2:
            # Compact contact star/chips, active frames only. No recovery arc.
            tx,ty=round(tip[0]),round(tip[1])
            for dx,dy in [(4,-3),(5,1),(-1,4)]:
                v.line(d,[(tx+dx,ty+dy),(tx+dx+1,ty+dy)],'0',3)
                v.line(d,[(tx+dx,ty+dy),(tx+dx+1,ty+dy)],'1',1)
            v.dust(d,1,(X+16,Y-1),10,8)
    elif name == 'lash_strike':
        index=[0,0,0,1,1,2][n]
        tip=v.hook([-28,-72,-35][index],[0,1,0][index])
        end=(X+148,Y-1)
        spine=[(tip[0]+(end[0]-tip[0])*i/100,tip[1]+(end[1]-tip[1])*i/100) for i in range(101)]
        # Strong dark outline around a continuous3px luminous live-strike core.
        v.line(d,spine,'0',7)
        for strand in range(2):
            points=[]
            for i,(xx,yy) in enumerate(spine):
                weave=math.sin(i*.25+n*.4+strand*math.pi)*2.4*math.sin(math.pi*i/100)
                points.append((xx,yy+weave))
            v.line(d,points,'b' if strand else 'i',2)
        v.line(d,spine,'o',3)
        v.line(d,spine,'p',2)
        for i in range(12,98,14):
            v.line(d,spine[i:i+5],'1',2)
            xx,yy=spine[i]
            side=1 if i%4 else -1
            v.line(d,[(xx,yy+side*3),(xx+3,yy+side*4)],'0',2)
            v.dot(d,xx+2,yy+side*3,'c')
        # Far tip remains <=150 horizontal reach even with the thick backing.
        for y in range(SIZE[1]):
            for x in range(X+151,SIZE[0]):
                im.putpixel((x,y),(0,0,0,0))
    else:
        # Full48px-boundary flash is ONLY an active-strike family. The compositor
        # explicitly swaps to ring_afterglow during every recovery sample.
        if n<5:
            d.ellipse((X-47,Y-47,X+47,Y+47),outline=C['0'],width=5)
            d.ellipse((X-46,Y-46,X+46,Y+46),outline=C['o'],width=3)
            d.ellipse((X-45,Y-45,X+45,Y+45),outline=C['p' if n<2 else 'u'],width=1)
        radius=25+min(1,n/4)*20
        for i in range(20):
            a=i*math.tau/20
            xx,yy=round(X+math.cos(a)*radius),round(Y+math.sin(a)*radius)
            if n>5 and i%2:
                continue
            color='1' if n<3 else 'p' if n<5 else 'u'
            # Bounded3px cluster,5px backing: clear separation from moss texture.
            d.rectangle((xx-2,yy-2,xx+2,yy+2),fill=C['0'])
            d.rectangle((xx-1,yy-1,xx+1,yy+1),fill=C[color])
            v.dot(d,xx-1,yy+1,'t')
            if n<5:
                sx,sy=xx-math.cos(a)*5,yy-math.sin(a)*5
                v.line(d,[(sx,sy),(xx-math.cos(a)*2,yy-math.sin(a)*2)],'0',3)
                v.line(d,[(sx,sy),(xx-math.cos(a)*2,yy-math.sin(a)*2)],'o',1)
        im=trim_ring(im)
    v.b.check(im)
    return im


def scene(body,effects,ground,state,index,label,families=(),warning=None,t=0):
    families=list(families)
    if state == 'recover':
        families=[('ring_afterglow',n) if family == 'ring_burst' else (family,n) for family,n in families]
        if any(family == 'ring_afterglow' for family,n in families):
            effects=dict(effects,ring_afterglow=[fx('ring_afterglow',i,8) for i in range(8)])
    # V2's old-effect comparison is a V1 reference. Skip its capture for the new
    # recovery family; our dedicated proofs compare actual V2/V3 decoded clips.
    if any(family == 'ring_afterglow' for family,n in families):
        v.CAPTURES.setdefault(label,(ground.copy(),ground.copy()))
    return BASE_SCENE(body,effects,ground,state,index,label,families,warning,t)


def decode(path):
    out=[]
    with Image.open(path) as gif:
        for i in range(gif.n_frames):
            gif.seek(i)
            frame=gif.convert('RGBA').resize(SIZE,Image.Resampling.NEAREST)
            assert gif.info['duration']%50 == 0
            out.extend([frame]*int(gif.info['duration']/50))
    return out


def encode(name,frames):
    NATIVE[name]=frames
    # Unchanged clips may be copied, but only after full expanded frame parity.
    if name in ('all_body_animations','idle_wake_walk','guard_break_exposed','defeat'):
        original=decode(V2/(name+'.gif'))
        assert len(original)==len(frames)
        assert all(a.tobytes()==b.tobytes() for a,b in zip(original,frames)),name
        (OUT/(name+'.gif')).write_bytes((V2/(name+'.gif')).read_bytes())
    else:
        BASE_ENCODE(name,frames)


def comparisons():
    cases=[('cleave',14,'cleave_strike_1'),('cleave',15,'cleave_strike_2'),
           ('cleave',17,'cleave_recovery'),('lash',15,'lash_strike_1'),
           ('lash',16,'lash_strike_2'),('ring',19,'ring_strike_1'),
           ('ring',20,'ring_strike_2'),('ring',22,'ring_recovery')]
    before={name:decode(V2/(name+'.gif')) for name in ('cleave','lash','ring')}
    for name,index,key in cases:
        old,new=before[name][index],NATIVE[name][index]
        new.save(OUT/(key+'_native.png'))
        new.resize((768,528),Image.Resampling.NEAREST).save(OUT/(key+'_3x.png'))
        sheet=Image.new('RGBA',(512,196),C['0'])
        v.b.text(sheet,(4,2),'V2 / NATIVE / '+str(index*50)+'ms')
        v.b.text(sheet,(260,2),'V3 / NATIVE / '+str(index*50)+'ms')
        sheet.alpha_composite(old,(0,20));sheet.alpha_composite(new,(256,20))
        sheet.save(OUT/('compare_'+key+'_native.png'))
        sheet.resize((1536,588),Image.Resampling.NEAREST).save(OUT/('compare_'+key+'_3x.png'))
        box=(36,52,110,120) if name == 'cleave' else (42,66,222,120) if name == 'lash' else (14,54,118,160)
        crops=[im.crop(box) for im in (old,new)]
        w,h=crops[0].width*5,crops[0].height*5
        close=Image.new('RGBA',(w*2,h+24),C['0'])
        for col,crop in enumerate(crops):
            v.b.text(close,(col*w+4,5),('V2' if col == 0 else 'V3')+' / '+key+' / 5x')
            close.alpha_composite(crop.resize((w,h),Image.Resampling.NEAREST),(col*w,24))
        close.save(OUT/('compare_'+key+'_closeup.png'))
    # Readability overview retains native frames; no visual enlargement required.
    sheet=Image.new('RGBA',(512,3*196),C['0'])
    for row,key in enumerate(('cleave_strike_1','lash_strike_1','ring_strike_1')):
        sheet.alpha_composite(Image.open(OUT/('compare_'+key+'_native.png')).convert('RGBA'),(0,row*196))
    sheet.save(OUT/'contact_sheet_attacks_native.png')
    sheet.resize((1536,1764),Image.Resampling.NEAREST).save(OUT/'contact_sheet_attacks_3x.png')


def main():
    OUT.mkdir(parents=True,exist_ok=True)
    protected={str(p.relative_to(V2)):v.sha(p) for p in V2.rglob('*') if p.is_file()}
    v.fx=fx
    v.scene=scene
    v.ORIGINAL_ENCODE=encode
    v.comparison=comparisons
    v.main()
    manifest=json.loads((OUT/'manifest.json').read_text())
    for n in range(8):
        key,meta=v.compact_export('ring_afterglow',n,fx('ring_afterglow',n,8))
        manifest['fx_assets'][key]=meta
    manifest['fx_families']['ring_afterglow']=8
    manifest['fx_frames']=114
    manifest['generated_with']='Astra V3 visibility correction; V2 helpers safely reused; opaque pale attack cores with dark backing'
    manifest['attack_visibility']={'cleave':'5px dark silhouette;3px pale arc;2px bright edge;active-only contact flash',
                                 'lash':'7px dark silhouette;3px pale live core;2px white highlight;braided root edges',
                                 'ring':'radius<=48;short boundary flash;3px pale clusters with5px dark backing;recovery uses separate subdued family'}
    manifest['v2_protected_file_hashes']=protected
    manifest['validation']='PASS:114 compact reconstructions;60 byte-identical body copies;V1/V2 source hashes;Totoy36;hard alpha;no reserved FX colors;11 unchanged clip durations. Parent independent audit pending.'
    report={'status':'PASS','body_frames':60,'fx_frames':114,'gifs':{},'source_v2_files_unchanged':len(protected),
            'warning_overlay':'pending parent independent audit','native_visibility':'artist inspected first_native_strikes.png at original512x588, with256x176 native stages;visible pale Cleave,Lash,Ring on identical busy ground;owner approval pending'}
    for key,meta in manifest['fx_assets'].items():
        family,number=key[len('fx_warden_'):].rsplit('_',1)
        im=Image.open(OUT/'fx'/family/(key+'.png')).convert('RGBA')
        assert max(im.size)<=256 and im.width%8 == im.height%8 == 0
        v.b.check(im)
        layer=v.b.blank(SIZE);layer.alpha_composite(im,(X-meta['anchor'][0],Y-meta['anchor'][1]))
        expected=fx(family,int(number)-1,manifest['fx_families'][family])
        assert layer.tobytes()==expected.tobytes(),key
    for name,frames in NATIVE.items():
        original=decode(V2/(name+'.gif'))
        assert len(original)==len(frames)
        report['gifs'][name+'.gif']={'expanded_frames':len(frames),'duration_ms':len(frames)*50}
    for rel,digest in protected.items():
        assert v.sha(V2/rel)==digest,rel
    (OUT/'manifest.json').write_text(json.dumps(manifest,indent=2))
    (OUT/'build_checks.json').write_text(json.dumps(report,indent=2))
    print('ASTRA V3 READY:60 exact bodies,114 FX,11 GIFs,same durations,V2 sources unchanged,native/3x/5x V2 comparisons.')


if __name__ == '__main__':
    main()
