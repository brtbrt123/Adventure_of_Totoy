"""Astra FX polish: import the approved rig without running or writing its main.

Only this directory is writable. No image generation, body repaint, runtime edits.
The original main's timeline is reused through a small AST scene substitution.
"""
from pathlib import Path
import ast
import hashlib
import importlib.util
import json
import math
import sys
from PIL import Image, ImageDraw

sys.dont_write_bytecode = True
OUT = Path(__file__).resolve().parent
BASE = OUT.parent / 'warden_v1'
spec = importlib.util.spec_from_file_location('approved_warden', BASE / 'animate_review.py')
b = importlib.util.module_from_spec(spec)
spec.loader.exec_module(b)
b.OUT = OUT
C, AT, SIZE = b.C, b.AT, b.SIZE
X, Y = AT
OLD_FX = b.fx
BODY = {}
CAPTURES = {}
FRAMES = {}
TIMELINE = {}
POSE_RECORDS = {}
SOURCE_HASHES = {}
BASE_MANIFEST = json.loads((BASE / 'animation_review/manifest.json').read_text())


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def line(d, points, color, width=1):
    d.line([(round(x), round(y)) for x, y in points], fill=C[color], width=width)


def dot(d, x, y, color):
    d.point((round(x), round(y)), fill=C[color])


def chip(d, x, y, color='h', size=2, phase=0):
    x, y = round(x), round(y)
    if size < 2:
        dot(d, x, y, color)
    else:
        d.polygon([(x-size, y), (x, y-size), (x+size, y), (x+size-1, y+1), (x, y+1)], fill=C['f'])
        line(d, [(x-size+1, y), (x, y-size+1), (x+size-1, y)], color)
        if phase % 2 == 0:
            dot(d, x, y, 'i')


def glyph(d, x, y, color, variant=0):
    x, y = round(x), round(y)
    patterns = [([(0, 2), (0, -1), (2, -1)], [(0, 0), (1, 1)]),
                ([(-1, -2), (1, 0), (-1, 2)], [(0, 0), (2, 0)]),
                ([(-1, 1), (1, 1), (1, -2)], [(0, -1), (1, 0)])]
    for stroke in patterns[variant % 3]:
        line(d, [(x+dx, y+dy) for dx, dy in stroke], color)


def hook(angle, lean=0):
    a = math.radians(angle)
    return (X+6+lean-(2 if -100 < angle < -35 else 0)+11*math.cos(a)-10*math.sin(a),
            Y-19+11*math.sin(a)+10*math.cos(a))


def dust(d, n, origin, count=11, spread=12):
    """Small low dust lobes; ballistic chips; late frames settle into dirt."""
    q = n / 5
    for i in range(count):
        side = -1 if i % 2 else 1
        dx = side*(2+(i % 5)*1.7+q*spread*(.35+(i % 3)*.15))
        height = math.sin(min(1, q)*math.pi)*(2+i % 4)
        yy = origin[1]-height-(i % 3)
        color = ('c' if i % 3 else 'i') if n < 2 else 'b' if n < 4 else '9'
        if (i+n) % 5 == 0 and n > 3:
            continue
        chip(d, origin[0]+dx, yy, color, 2 if n < 3 and i % 3 == 0 else 1, i)
        if n < 4 and i % 3 == 0:
            line(d, [(origin[0]+dx-1, yy+2), (origin[0]+dx+2, yy+2)], 'a')


def fx(name, n, count):
    im = b.blank(SIZE)
    d = ImageDraw.Draw(im)
    q = n/max(1, count-1)
    cx, cy = X+5, Y-18
    if name in ('rune_glow', 'wake_flare'):
        # Narrow broken emission flanking the embedded glyph, never a halo circle.
        strength = [0, 1, 2, 2, 1, 0][min(n, 5)]
        for side in (-1, 1):
            line(d, [(cx+side*4, cy+2), (cx+side*5, cy), (cx+side*4, cy-2)], 't')
            if strength:
                dot(d, cx+side*5, cy-1, 'u' if strength == 1 else 'o')
        for i in range(4 if name == 'rune_glow' else 7):
            age = (n+i*2) % 6
            side = -1 if i % 2 else 1
            xx, yy = cx+side*(7+i % 3), cy+3-age*2-i % 2
            if age < 4:
                if i % 2 == 0 and age in (1, 2):
                    glyph(d, xx, yy, 'u' if age == 1 else 't', i)
                else:
                    dot(d, xx, yy, 'o' if age == 1 else 't')
        if name == 'wake_flare':
            for i in range(5):
                line(d, [(X-11+i*6, Y-2-n), (X-10+i*6, Y-3-n)], 't' if n > 1 else 'u')
    elif name == 'arrival':
        # Quiet stepped rim and grounding flecks; no new silhouette shell.
        sections = [[(X-15,Y-3),(X-16,Y-11),(X-13,Y-16)],
                    [(X-13,Y-22),(X-11,Y-28),(X-6,Y-31)],
                    [(X+10,Y-31),(X+13,Y-27)],[(X+17,Y-19),(X+18,Y-12)]]
        for i, pts in enumerate(sections):
            if (i+n) % 5 < 3 and n < 5:
                line(d, pts, 't' if n > 2 else 'u')
                dot(d, *pts[min(2, len(pts)-1)], 'o' if n == 1 else 't')
        dust(d, n, (X, Y), count=7, spread=3)
    elif name in ('guard_hit', 'guard_break', 'hit_burst', 'death_flash'):
        breaking = name in ('guard_break', 'death_flash')
        rays = 9 if breaking else 6
        for i in range(rays):
            a = i*2.39996+.2
            r = (7 if breaking else 5)+n*(1.7 if breaking else 1.25)
            xx, yy = cx+math.cos(a)*r, cy+math.sin(a)*r*.68+n*n*.13
            color = ('p' if n == 0 else 'o' if n < 2 else 'u' if n < 4 else 't' if n < 5 else 'g')
            if n >= count-1 and i % 3:
                continue
            if breaking and n < 5 and i % 2 == 0:
                glyph(d, xx, yy, color, i+n//2)
            else:
                length = 3 if n < 2 else 2 if n < 4 else 1
                line(d, [(xx-math.cos(a)*length, yy-math.sin(a)*length), (xx, yy)], color)
            if i % 3 == 0:
                chip(d, xx+2, yy+3, 'i' if n < 2 else 'g', 2 if n < 3 else 1, i)
        if n < 2 and name != 'death_flash':
            for side in (-1, 1):
                line(d, [(cx+side*5,cy+4),(cx+side*7,cy),(cx+side*5,cy-4)], 'u')
                dot(d,cx+side*7,cy,'p')
    elif name == 'idle_spores':
        for i in range(7):
            age = (n+i*3) % 9
            xx = X-13+i*4+math.sin((n+i)*.8)*2
            yy = Y-3-age*2-(i % 3)*4
            color = '6' if age < 3 else '5' if age < 6 else '3'
            dot(d,xx,yy,color)
            if age < 3 and i % 3 == 0:
                dot(d,xx+1,yy+1,'4')
    elif name == 'exposed_dust':
        # All dust sinks and loses chroma; deliberately no rune-light colors.
        for i in range(9):
            xx = X-10+(i*7)%24+(n//3)*(i%3-1)
            yy = min(Y-1, Y-22+i%5+n*(2+i%2))
            if n == 5 and i % 2:
                continue
            color = 'h' if n < 2 else 'g' if n < 4 else 'f'
            if i % 4 == 0 and n < 3:
                line(d,[(xx,yy),(xx+1,yy+1)],color)
            else:
                dot(d,xx,yy,color)
    elif name == 'cleave_arc':
        pose_index = n//2
        angle = [-105,-15,18][pose_index]
        lean = [0,2,1][pose_index]
        start = [-145,-105,-15][pose_index]
        # Three narrow tip-traced ribbons; head is EXACT approved hook position.
        for ring, color in [(0,'o'),(-1,'p'),(-3,'t')]:
            pts=[]
            for k in range(22):
                a=start+(angle-start)*k/21
                px,py=hook(a,lean)
                if ring:
                    pivot=(X+6+lean-(2 if -100<angle<-35 else 0),Y-19)
                    scale=(math.hypot(11,10)+ring)/math.hypot(11,10)
                    px,py=pivot[0]+(px-pivot[0])*scale,pivot[1]+(py-pivot[1])*scale
                pts.append((px,py))
            line(d,pts[3 if ring == -3 else 0:],color)
        tip=hook(angle,lean)
        dot(d,*tip,'p')
        if pose_index == 2:
            dust(d,n-3,(round(tip[0]),Y-1),count=9,spread=7)
    elif name == 'cleave_contact':
        dust(d,n,(X+16,Y-1),count=14,spread=12)
        if n < 4:
            for i in range(4):
                xx=X+12+i*4+n
                line(d,[(xx,Y),(xx+2,Y-1)],'a' if n < 2 else '9')
    elif name == 'lash_creep':
        end=round(147*q)
        for strand in range(2):
            pts=[(X+i,Y+round(math.sin(i*.11+strand*2)*2)+strand*2-2) for i in range(0,end+1,2)]
            if len(pts)>1:
                line(d,pts,'8',2)
                line(d,pts,'a' if strand else 't')
        for i in range(10,end,17):
            side=-1 if i%2 else 1
            line(d,[(X+i,Y),(X+i+3,Y+side*3),(X+i+6,Y+side*4)],'9')
            dot(d,X+i+4,Y+side*3,'u' if (i+n)%3 == 0 else 'b')
    elif name == 'lash_strike':
        index=[0,0,0,1,1,2][n]
        tip=hook([-28,-72,-35][index],[0,1,0][index])
        # Both strands originate at the moving hook. End is inside reach150.
        end=(X+148,Y-1)
        rope=[]
        for i in range(101):
            t=i/100
            rope.append((tip[0]+(end[0]-tip[0])*t,tip[1]+(end[1]-tip[1])*t))
        line(d,rope,'8',4)
        for strand in range(2):
            pts=[]
            for i,(xx,yy) in enumerate(rope):
                t=i/100
                weave=math.sin(i*.30+strand*math.pi+n*.6)*1.35*math.sin(math.pi*t)
                pts.append((xx,yy+weave))
            line(d,pts,'b' if strand else 'i')
        for i in range(9,98,9):
            xx,yy=rope[i]
            side=-1 if i%2 else 1
            line(d,[(xx-1,yy),(xx+2,yy+side*3),(xx+3,yy+side*2)],'a')
            dot(d,xx+1,yy,'o' if n < 2 and i%3 == 0 else 'u')
        dot(d,*tip,'p' if n < 2 else 'i')
    elif name == 'lash_splinters':
        for i in range(17):
            xx=X+13+i*8+(i%3-1)*n
            yy=Y-2-math.sin(q*math.pi)*(2+i%5)
            if xx > X+148 or (n > 3 and i%3 == 0):
                continue
            line(d,[(xx,yy),(xx+2,min(Y+4,yy+(i%3-1)*2))], 'c' if n < 2 else 'a' if n < 4 else '9')
            if n < 3 and i%4 == 0:
                chip(d,xx,yy+3,'h',2,i)
    elif name in ('ring_charge','ring_burst','scorch'):
        # Broken botanical clusters replace full circles. Every ground pixel <=48.
        for i in range(25):
            a=i*math.tau/25
            if name == 'scorch':
                if (i*7)%11 < n*2:
                    continue
                radius=25+(i*13)%19
                xx,yy=X+math.cos(a)*radius,Y+math.sin(a)*radius
                tangent=(-math.sin(a),math.cos(a))
                line(d,[(xx-tangent[0]*2,yy-tangent[1]*2),(xx,yy),(xx+tangent[0]*2,yy+tangent[1]*2)],'8' if n < 3 else '9')
                if n < 2:
                    dot(d,xx,yy,'f')
                continue
            radius=(12+q*30+(i%3)) if name == 'ring_charge' else (12+min(1,q*1.8)*31+i%3)
            xx,yy=X+math.cos(a)*radius,Y+math.sin(a)*radius
            if name == 'ring_charge':
                if i%3 > min(2,n//2):
                    continue
                color='5' if i%2 else 't'
                dot(d,xx,yy,color)
                line(d,[(xx-1,yy+1),(xx,yy-1),(xx+1,yy)],'4' if i%3 else 'u')
                if n > 2 and i%4 == 0:
                    dot(d,xx,yy-2,'o')
            else:
                if n > 4 and (i+n)%4 == 0:
                    continue
                color='p' if n < 2 and i%3 == 0 else '7' if n < 3 else '5' if n < 5 else '3'
                line(d,[(xx-math.cos(a)*3,yy-math.sin(a)*3),(xx,yy)],'u' if n < 3 else '4')
                dot(d,xx,yy,color)
                if n < 5:
                    dot(d,xx+1,yy-1,'6')
                    dot(d,xx-1,yy+1,'4')
                if n < 3 and i%4 == 0:
                    dot(d,xx,yy-2,'o')
        # Strict support mask avoids an accidental larger advertised danger ring.
        for yy in range(SIZE[1]):
            for xx in range(SIZE[0]):
                if (xx-X)**2+(yy-Y)**2 > 48**2:
                    im.putpixel((xx,yy),(0,0,0,0))
    elif name == 'death_debris':
        for i in range(17):
            side=-1 if i%2 else 1
            xx=X+side*(4+i%5+n*(.7+i%3*.3))
            yy=min(Y-1,Y-17+(i%4)*2-n*(1.2+i%3*.4)+n*n*.62)
            if n == 7 and i%4 == 0:
                continue
            if i%3 == 0:
                line(d,[(xx-2,yy),(xx,yy+1),(xx+2,yy-1)],'a' if n < 5 else '9',2)
                dot(d,xx-1,yy,'c' if n < 3 else 'b')
            else:
                chip(d,xx,yy,'i' if n < 2 else 'h' if n < 5 else 'g',2 if i%2 else 1,i)
        if n > 3:
            dust(d,min(5,n-3),(X,Y),9,11)
    else:
        raise ValueError(name)
    b.check(im)
    return im


def approved_bodies():
    for state,count in b.COUNTS.items():
        BODY[state]=[]
        for i in range(count):
            src=BASE/'animation_review/body'/state/f'warden_{state}_right_{i+1}.png'
            dst=OUT/'body'/state/src.name
            dst.parent.mkdir(parents=True,exist_ok=True)
            dst.write_bytes(src.read_bytes())
            assert sha(src)==sha(dst)
            BODY[state].append(Image.open(src).convert('RGBA'))
    return BODY


def emit_warning(im, warning):
    if not warning:
        return
    d=ImageDraw.Draw(im)
    col=C['y' if warning == 'cleave' else 'A']
    if warning == 'cleave':
        pts=[(round(X+math.cos(-.9+i*1.8/32)*57),round(Y+math.sin(-.9+i*1.8/32)*57)) for i in range(33)]
        d.line([AT]+pts+[AT],fill=col)
    elif warning == 'lash':
        d.rectangle((X,Y-10,X+150,Y+10),outline=col)
    else:
        d.ellipse((X-48,Y-48,X+48,Y+48),outline=col)


def scene(body,effects,ground,state,index,label,families=(),warning=None,t=0):
    families=list(families)
    # Catalogue demonstrates registered emitters against the corresponding pose.
    if label.startswith('FX / ') and families:
        family,n=families[0]
        if family == 'cleave_arc': state,index='cleave_strike',n//2
        elif family == 'lash_strike': state,index='lash_strike',[0,0,0,1,1,2][n]
        elif family == 'ring_burst': state,index='ring_strike',min(2,n//2)
        elif family == 'wake_flare': state,index='wake',min(3,n)
        elif family == 'death_debris': state,index='death',n
    index=min(index,len(body[state])-1)
    current=body[state][index]
    im=ground.copy()
    ImageDraw.Draw(im).ellipse((X-10,Y-2,X+12,Y+2),fill=C['8'])
    rune=[(x,y) for y in range(18,36) for x in range(17,32) if current.getpixel((x,y)) in {C[c] for c in 'tuop'}]
    rune_at=(round(X-20+sum(p[0] for p in rune)/len(rune)),round(Y-44+sum(p[1] for p in rune)/len(rune))) if rune else (X+5,Y-18)
    used=[]
    for family,n in families:
        if family == 'cleave_arc' and state == 'recover':
            family='cleave_contact'
            n=min(5,index+2)
            effect=fx(family,n,6)
        else:
            n=min(n,len(effects[family])-1)
            effect=effects[family][n]
        offset=(rune_at[0]-(X+5),rune_at[1]-(Y-18)) if family in ('rune_glow','wake_flare','guard_hit','hit_burst') else (0,0)
        im.alpha_composite(effect,offset)
        used.append({'family':family,'frame':n+1,'stage_offset':offset})
    # Re-stamp ALL opaque body pixels after FX. Warnings remain final and exact.
    b.stamp(im,current,AT)
    emit_warning(im,warning)
    d=ImageDraw.Draw(im)
    d.rectangle((0,0,255,22),fill=C['0'])
    b.text(im,(4,0),label)
    b.text(im,(4,11),'REVIEW ONLY / NOT IN GAME','i')
    key=hashlib.sha256(im.tobytes()).hexdigest()
    POSE_RECORDS[key]={'state':state,'body_frame':index+1,'fx':used,'warning':warning}
    # Same background, pose, label and warning: show original composite vs polish.
    if families and label not in CAPTURES:
        old_effects={family:[OLD_FX(family,j,c) for j in range(c)] for family,c in BASE_MANIFEST['fx_families'].items()}
        before=b.original_scene(state,index,label,families,warning,t,body=body,effects=old_effects,ground=ground)
        CAPTURES[label]=(before.copy(),im.copy())
    return im


def encode(name,frames):
    FRAMES[name]=[im.copy() for im in frames]
    TIMELINE[name]=[POSE_RECORDS.get(hashlib.sha256(im.tobytes()).hexdigest(),{}) for im in frames]
    ORIGINAL_ENCODE(name,frames)


def compact_export(family,n,im):
    bounds=im.getbbox()
    if bounds:
        x,y=min(bounds[0],X),min(bounds[1],Y)
        w,h=(max(bounds[2],X+1)-x+7)//8*8,(max(bounds[3],Y+1)-y+7)//8*8
        compact=im.crop((x,y,x+w,y+h))
        anchor=(X-x,Y-y)
    else:
        compact=b.blank((8,8));anchor=(4,4);x,y=X-4,Y-4
    rebuilt=b.blank(SIZE);rebuilt.alpha_composite(compact,(x,y))
    assert rebuilt.tobytes()==im.tobytes()
    key=f'fx_warden_{family}_{n+1}'
    b.save(compact,OUT/'fx'/family/(key+'.png'))
    return key,{'size':compact.size,'anchor':anchor}


def comparison():
    chosen=[('CLEAVE / STRIKE',1),('CLEAVE / RECOVER',2),('LASH / STRIKE',1),('RING / STRIKE',1),
            ('GUARD HIT / REDUCED DAMAGE',0),('PARRY / GUARD BREAK',0),
            ('EXPOSED / DARK / 90T TOTAL',0),('DEFEAT / RUNE EXTINGUISHED',0)]
    # Select actual impact/settle frames, rather than only first-frame captures.
    grid=Image.new('RGBA',(1024,len(chosen)*304+32),C['0'])
    b.text(grid,(8,8),'BEFORE (LEFT) / ASTRA V2 (RIGHT) / SAME BACKGROUND + APPROVED BODY')
    for row,(label,_) in enumerate(chosen):
        before,after=CAPTURES[label]
        for col,im in enumerate((before,after)):
            # Full native width retained; crop only empty top/bottom for comparison.
            tile=im.crop((0,24,256,176)).resize((512,304),Image.Resampling.NEAREST)
            grid.alpha_composite(tile,(col*512,32+row*304))
            b.text(grid,(col*512+6,36+row*304),('BASELINE / ' if col == 0 else 'ASTRA V2 / ')+label)
    grid.save(OUT/'contact_sheet_before_after.png')
    families=list(BASE_MANIFEST['fx_families'])+['cleave_contact']
    proof=Image.new('RGBA',(1320,len(families)*216),C['0'])
    for row,family in enumerate(families):
        count=BASE_MANIFEST['fx_families'].get(family,6)
        for col,n in enumerate([0,(count-1)//2,count-1]):
            layer=fx(family,n,count)
            tile=Image.new('RGBA',SIZE,C['e']);tile.alpha_composite(layer)
            crop=tile.crop((14,46,234,142)).resize((440,192),Image.Resampling.NEAREST)
            proof.alpha_composite(crop,(col*440,row*216+20))
            b.text(proof,(col*440+4,row*216+3),family+' / '+str(n+1))
    proof.save(OUT/'contact_sheet_fx_families.png')
    for name,indices in {'all_attacks':[13,14,15,16,52,53,54,55,96,97,98,100],
                         'guard_break_exposed':[14,17,18,20,23,25,26,35,43,48],
                         'defeat':[0,2,4,7,10,14,18,24]}.items():
        selected=[FRAMES[name][min(i,len(FRAMES[name])-1)] for i in indices]
        sheet=Image.new('RGBA',(1024,math.ceil(len(selected)/2)*352),C['0'])
        for i,im in enumerate(selected):
            sheet.alpha_composite(im.resize((512,352),Image.Resampling.NEAREST),(i%2*512,i//2*352))
        sheet.save(OUT/f'contact_sheet_motion_{name}.png')


def main():
    for p in sorted((BASE/'frames').glob('*.png')):
        SOURCE_HASHES[str(p.relative_to(BASE))]=sha(p)
    for p in sorted((BASE/'animation_review').rglob('*')):
        if p.suffix in ('.png','.gif','.json'):
            SOURCE_HASHES[str(p.relative_to(BASE))]=sha(p)
    # Save baseline scene as callable with explicit closure arguments, then swap
    # only the scene implementation in the baseline main. Its timing stays literal.
    tree=ast.parse((BASE/'animate_review.py').read_text())
    main_node=next(n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name == 'main')
    original_scene=next(n for n in main_node.body if isinstance(n,ast.FunctionDef) and n.name == 'scene')
    import copy
    fn=copy.deepcopy(original_scene);fn.name='original_scene'
    fn.args.kwonlyargs=[ast.arg(arg=x) for x in ('body','effects','ground')]
    fn.args.kw_defaults=[None,None,None]
    exec(compile(ast.fix_missing_locations(ast.Module(body=[fn],type_ignores=[])),str(BASE/'animate_review.py'),'exec'),b.__dict__)
    original_scene.body=ast.parse('return enhanced_scene(body, effects, ground, state, index, label, families, warning, t)').body
    b.enhanced_scene=scene
    b.bodies=approved_bodies
    b.fx=fx
    b.encode=encode
    exec(compile(ast.fix_missing_locations(ast.Module(body=[main_node],type_ignores=[])),str(BASE/'animate_review.py'),'exec'),b.__dict__)
    b.main()
    manifest=json.loads((OUT/'manifest.json').read_text())
    for n in range(6):
        key,meta=compact_export('cleave_contact',n,fx('cleave_contact',n,6))
        manifest['fx_assets'][key]=meta
    # Reconstruction from every compact PNG must exactly equal the stage layer.
    for key,meta in manifest['fx_assets'].items():
        family,number=key[len('fx_warden_'):].rsplit('_',1)
        im=Image.open(OUT/'fx'/family/(key+'.png')).convert('RGBA')
        b.check(im)
        assert im.width%8 == im.height%8 == 0 and max(im.size)<=256
        stage=b.blank(SIZE);stage.alpha_composite(im,(X-meta['anchor'][0],Y-meta['anchor'][1]))
        expected=fx(family,int(number)-1,BASE_MANIFEST['fx_families'].get(family,6))
        assert stage.tobytes()==expected.tobytes(),key
    assert all(sha(BASE/rel)==digest for rel,digest in SOURCE_HASHES.items())
    manifest.update({'fx_frames':106,'fx_families':dict(BASE_MANIFEST['fx_families'],cleave_contact=6),
                     'generated_with':'Astra role: deterministic code-native FX, unchanged approved body PNG bytes',
                     'composition':'FX below opaque body, then original warning overlay last; body anchor20,44',
                     'body_file_hashes':{str(p.relative_to(OUT)):sha(p) for p in sorted((OUT/'body').rglob('*.png'))},
                     'baseline_source_hashes':SOURCE_HASHES,
                     'attachment':{'rune_glow':'rune centroid offset','wake_flare':'rune centroid offset','guard_hit':'rune centroid offset','hit_burst':'rune centroid offset','other':'feet'},
                     'registration':{'cleave_pose_by_fx':[0,0,1,1,2,2],'lash_pose_by_fx':[0,0,0,1,1,2],
                                     'hook_native':[37,35],'pivot_native':[26,25],'lash_end_offset':[148,-1]},
                     'graphify':'Query attempted: No module named graphify. No graph writes allowed in this task.',
                     'validation':'PASS:106 compact reconstructions;60 byte-identical body copies; protected baseline hashes; palette; hard alpha; no reserved FX/body; baseline encode palette roundtrip and duration. Parent independent audit pending.'})
    (OUT/'manifest.json').write_text(json.dumps(manifest,indent=2))
    # Chain/parry labels are stamped after the baseline scene call; derive tracks
    # with the same literal slicing used by the unchanged baseline timeline.
    TIMELINE['cleave_lash_chain']=TIMELINE['cleave'][:20]+TIMELINE['lash']
    TIMELINE['cleave_parry_exposed']=TIMELINE['cleave'][:14]+TIMELINE['guard_break_exposed'][18:]
    (OUT/'timeline.json').write_text(json.dumps({'sample_ticks':3,'frame_ms':50,'clips':TIMELINE},indent=2))
    comparison()
    print('ASTRA READY: 60 exact bodies, 106 compact FX, same11 GIF schedules, comparison + motion proofs.')


ORIGINAL_ENCODE=b.encode
if __name__ == '__main__':
    main()
