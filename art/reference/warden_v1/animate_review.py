"""Deterministic articulated pixel animation of the approved Warden; review outputs only."""
from pathlib import Path
import hashlib
import json
import math
from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
OUT = HERE / 'animation_review'
ROOT = HERE.parents[2]
P = json.loads((ROOT/'art/palette.json').read_text())
C = {p['symbol']: tuple(bytes.fromhex(p['hex'].lstrip('#')))+(255,) for p in P['colors']}
ALLOWED = set(C.values())
RESERVED = {C[k] for k in P['reserved']}
SIZE = (256,176)
ANCHOR = (20,44)
AT = (66,108)
COUNTS = {'idle':6,'wake':4,'walk':6,'cleave_tell':5,'cleave_strike':3,'lash_tell':5,
          'lash_strike':3,'ring_tell':5,'ring_strike':3,'recover':4,'guard_hit':2,'exposed':4,'hurt':2,'death':8}

def blank(size=(48,48)):
    return Image.new('RGBA',size)

def check(im, warning=False):
    values=set(im.get_flattened_data())
    assert all(p[3] in (0,255) and (not p[3] or p in ALLOWED) for p in values)
    assert warning or not values.intersection(RESERVED)

def save(im, path, warning=False):
    check(im,warning)
    if not path.name.startswith('contact_sheet'):
        assert im.width%8==im.height%8==0 and max(im.size)<=256
    path.parent.mkdir(parents=True,exist_ok=True)
    im.save(path)

def parts(source):
    out={k:blank() for k in ['head','torso','arm','blade','rear_leg','front_leg']}
    for y in range(48):
        for x in range(48):
            p=source.getpixel((x,y))
            if not p[3]:continue
            k='torso'
            blade_edge=26 if y<33 else 27 if y<36 else 28 if y<38 else 30 if y<40 else 32
            if x>=blade_edge and y>=26:k='blade'
            elif 17<=x<=27 and y<=19:k='head'
            elif x<17 and 24<=y<35:k='arm'
            elif y>=32:k='rear_leg' if x<20 else 'front_leg'
            out[k].putpixel((x,y),p)
    return out

def moved(im,pivot=(20,30),angle=0,dx=0,dy=0):
    big=blank((80,80));big.alpha_composite(im,(16,16))
    px,py=pivot[0]+16,pivot[1]+16
    a=math.radians(angle);c,s=math.cos(a),math.sin(a)
    result=big.transform((80,80),Image.Transform.AFFINE,
        (c,s,px-c*(px+dx)-s*(py+dy),-s,c,py+s*(px+dx)-c*(py+dy)),Image.Resampling.NEAREST)
    box=result.getbbox()
    assert not box or (box[0]>=16 and box[1]>=16 and box[2]<=64 and box[3]<=64), ('clipped limb',pivot,angle,dx,dy,box)
    return result.crop((16,16,64,64))

def pose(rig,arm=0,bob=0,lean=0,head=0,stride=0,lift=0):
    out=blank()
    for key,im in rig.items():
        if key=='blade':layer=moved(im,(26,25),arm,lean-(2 if -100<arm<-35 else 0),min(0,bob))
        elif key=='rear_leg':layer=moved(im,(17,33),stride,0,-lift)
        elif key=='front_leg':layer=moved(im,(23,33),-stride,0,-(lift if stride<0 else 0))
        elif key=='head':layer=moved(im,(22,20),head,lean,bob)
        elif key=='arm':layer=moved(im,(15,24),-arm*.12,lean,bob)
        else:layer=moved(im,(20,30),0,lean,bob)
        out.alpha_composite(layer)
    return out

def pulse(im,phase):
    out=im.copy()
    ramp=[C['t'],C['u'],C['o'],C['p']]
    for y in range(18,31):
        for x in range(17,31):
            p=out.getpixel((x,y))
            if p in ramp:
                n=ramp.index(p)
                out.putpixel((x,y),ramp[max(1,min(3,n+phase))])
    return out

def stamp(dst,im,at,anchor=ANCHOR):
    dst.alpha_composite(im,(round(at[0]-anchor[0]),round(at[1]-anchor[1])))

def text(im,at,value,color='1'):
    d=ImageDraw.Draw(im);d.fontmode='1';d.text(at,value,font=ImageFont.load_default(),fill=C[color])

def bodies():
    source={p.stem:Image.open(p).convert('RGBA') for p in (HERE/'frames').glob('*.png')}
    lit,dark=parts(source['idle']),parts(source['exposed'])
    assert pose(lit).tobytes()==source['idle'].tobytes()
    assert pose(dark).tobytes()==source['exposed'].tobytes()
    result={}
    for state,count in COUNTS.items():
        seq=[]
        for i in range(count):
            q=i/max(1,count-1)
            if state=='idle':im=pulse(pose(lit,bob=[0,0,-1,-1,0,0][i],head=[0,0,-2,0,2,0][i]),[0,0,1,0,-1,0][i])
            elif state=='wake':im=pulse(pose(lit,bob=[3,2,1,0][i],head=[4,2,0,-2][i]),i//2)
            elif state=='walk':im=pose(lit,arm=[-6,0,7,6,0,-7][i],bob=[0,-1,0,0,-1,0][i],stride=[-12,-4,8,12,4,-8][i],lift=1 if i in (1,4) else 0)
            elif state=='cleave_tell':im=pose(lit,arm=[0,-28,-72,-112,-145][i],bob=-int(q),lean=-int(q))
            elif state=='cleave_strike':im=pose(lit,arm=[-105,-15,18][i],lean=[0,2,1][i])
            elif state=='lash_tell':im=pose(lit,arm=[0,18,35,55,70][i],lean=-int(q*2),head=-2)
            elif state=='lash_strike':im=pose(lit,arm=[-28,-72,-35][i],lean=[0,1,0][i])
            elif state=='ring_tell':im=pulse(pose(lit,bob=[0,1,2,3,4][i],arm=[0,5,10,15,20][i],head=3),int(q))
            elif state=='ring_strike':im=pose(lit,bob=[3,1,0][i],arm=[18,8,0][i],stride=[-5,0,0][i])
            elif state=='recover':im=pose(lit,arm=[18,12,5,0][i],bob=[1,1,0,0][i])
            elif state=='guard_hit':im=pulse(pose(lit,lean=-1 if i==0 else 0,head=-3 if i==0 else 0),1 if i==0 else 0)
            elif state=='exposed':im=pose(dark,bob=[1,2,1,1][i],head=[-4,-2,0,-2][i])
            elif state=='hurt':im=pose(dark,lean=-2 if i==0 else -1,head=-5 if i==0 else 0)
            else:
                if i<2:im=pose(dark,bob=i+1,head=-5-i*2,lean=-1)
                elif i<4:im=source['defeat'].copy()
                else:
                    im=blank();original=source['defeat']
                    # Broken clusters settle on the same floor; never slide the foot anchor.
                    for y in range(48):
                        for x in range(48):
                            p=original.getpixel((x,y))
                            if not p[3]:continue
                            chunk=(x//5+y//5*3)%7
                            if y<28 and (i+chunk)%7<min(3,i-3):continue
                            xx=max(1,min(46,x+(chunk%3-1)*(i-3)//2))
                            yy=min(43,y+(i-3)*2+(chunk%2))
                            im.putpixel((xx,yy),p)
            check(im)
            seq.append(im)
            save(im,OUT/'body'/state/f'warden_{state}_right_{i+1}.png')
        result[state]=seq
    return result

def sparks(d,origin,age,count=10,colors='tuop',radius=1):
    for i in range(count):
        a=i*2.39996;r=radius+age*(.45+(i%4)*.11)
        x=round(origin[0]+math.cos(a)*r);y=round(origin[1]+math.sin(a)*r*.7-age*.18)
        color=C[colors[min(len(colors)-1,int(age/8))%len(colors)]]
        d.point((x,y),fill=color)

def fx(name,n,count):
    im=blank(SIZE);d=ImageDraw.Draw(im);q=n/max(1,count-1)
    cx,cy=AT[0]+5,AT[1]-18
    floor=AT[1]
    if name in ('rune_glow','guard_hit','guard_break','wake_flare','arrival'):
        radius=3+q*(16 if name=='guard_break' else 6)
        if name=='arrival':
            d.line([(AT[0]-14,floor),(AT[0]-15,floor-28),(AT[0]-4,floor-35)],fill=C['t'])
            d.line([(AT[0]+18,floor),(AT[0]+17,floor-25)],fill=C['u'])
        else:d.ellipse((round(cx-radius),round(cy-radius*.7),round(cx+radius),round(cy+radius*.7)),outline=C['p' if n<2 else 'u' if q<.6 else 't'])
        if name!='rune_glow':sparks(d,(cx,cy),n*3,12,colors='pout')
    elif name in ('idle_spores','exposed_dust','death_debris','hit_burst'):
        for i in range(12):
            a=(n*3+i*7)%31
            x=round(AT[0]+math.sin(i*2.3)*(6+a*.4))
            y=round(floor-6-a*.7) if name=='idle_spores' else min(floor,round(floor-25+a*.9))
            d.point((x,y),fill=C['5' if name=='idle_spores' else 'c' if i%2 else 'g'])
        if name=='hit_burst':sparks(d,(cx,cy),n*2,12,colors='poit')
    elif name=='cleave_arc':
        # Trace the same pivot and hook-tip used by the articulated body, not a guessed sword arc.
        arm=[-105,-105,-15,-15,18,18][n]
        lean=[0,0,2,2,1,1][n]
        start=math.radians(max(-145,arm-60));end=math.radians(arm)
        points=[]
        for i in range(15):
            a=start+(end-start)*i/14
            points.append((round(AT[0]+6+lean+11*math.cos(a)-10*math.sin(a)),
                           round(floor-19+11*math.sin(a)+10*math.cos(a))))
        d.line(points,fill=C['p' if n<3 else 'o'],width=2)
        d.line([(x-1,y+1) for x,y in points],fill=C['t'])
        sparks(d,points[-1],n+1,5,colors='poj')
    elif name in ('lash_creep','lash_strike','lash_splinters'):
        reach=150*(q if name=='lash_creep' else 1)
        points=[(AT[0]+i,round(floor+math.sin(i*.14+n*.6)*(2 if name=='lash_creep' else 1))) for i in range(0,round(reach)+1,3)]
        if len(points)>1:
            if name=='lash_creep':d.line(points,fill=C['8'],width=2);d.line(points,fill=C['t'])
            elif name=='lash_strike':
                index=[0,0,0,1,1,2][n];arm=[-28,-72,-35][index];lean=[0,1,0][index]
                a=math.radians(arm)
                muzzle=(AT[0]+6+lean-(2 if -100<arm<-35 else 0)+11*math.cos(a)-10*math.sin(a),
                        floor-19+11*math.sin(a)+10*math.cos(a))
                rope=[(round(muzzle[0]+(AT[0]+150-muzzle[0])*i/50),
                       round(muzzle[1]+(floor-15-muzzle[1])*i/50+math.sin(i*.35+n)*2)) for i in range(51)]
                d.line(rope,fill=C['8'],width=3)
                d.line(rope,fill=C['p' if n<2 else 'i'],width=1)
        if name=='lash_splinters':
            for i in range(15):
                x=AT[0]+i*10;y=round(floor-15-n*2+math.sin(i*3)*n)
                d.line((x,y,x+2,y-2),fill=C['c' if i%2 else 'i'])
    elif name in ('ring_charge','ring_burst','scorch'):
        radius=48*(q if name!='scorch' else 1)
        if name=='scorch':
            for i in range(24):
                a=i*math.tau/24
                if (i+n)%7>n:
                    x=round(AT[0]+math.cos(a)*radius*.7);y=round(floor+math.sin(a)*radius*.7)
                    d.line((x-2,y,x+2,y+1),fill=C['8'])
        else:
            d.ellipse((round(AT[0]-radius),round(floor-radius),round(AT[0]+radius),round(floor+radius)),outline=C['t' if name=='ring_charge' else 'u'])
            for i in range(18):
                a=i*math.tau/18;x=round(AT[0]+math.cos(a)*radius);y=round(floor+math.sin(a)*radius-q*9)
                d.rectangle((x,y,x+1,y+1),fill=C['5' if i%3 else 'p'])
    elif name=='death_flash':
        if n<3:sparks(d,(cx,cy),n*4,16,colors='pout',radius=3)
    check(im)
    return im

def encode(name,frames):
    pal=Image.new('P',(1,1));flat=[v for p in C.values() for v in p[:3]];pal.putpalette(flat+[0]*(768-len(flat)))
    seq=[]
    for im in frames:
        check(im,True)
        rgb=im.convert('RGB').resize((SIZE[0]*4,SIZE[1]*4),Image.Resampling.NEAREST)
        p=rgb.quantize(palette=pal,dither=Image.Dither.NONE)
        assert p.convert('RGB').tobytes()==rgb.tobytes()
        seq.append(p)
    seq[0].save(OUT/f'{name}.gif',save_all=True,append_images=seq[1:],duration=50,loop=0,optimize=False,disposal=2)
    with Image.open(OUT/f'{name}.gif') as im:
        duration=0
        for i in range(im.n_frames):im.seek(i);duration+=im.info['duration']
        assert duration==len(frames)*50

def main():
    OUT.mkdir(exist_ok=True)
    protected={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in (HERE/'frames').glob('*.png')}
    body=bodies()
    families={'rune_glow':6,'idle_spores':6,'wake_flare':4,'arrival':6,'guard_hit':4,'guard_break':8,'exposed_dust':6,
              'cleave_arc':6,'lash_creep':5,'lash_strike':6,'lash_splinters':6,'ring_charge':6,'ring_burst':8,'scorch':6,'death_flash':4,'death_debris':8,'hit_burst':5}
    effects={};fx_metadata={}
    for family,count in families.items():
        effects[family]=[fx(family,i,count) for i in range(count)]
        for i,im in enumerate(effects[family]):
            key=f'fx_warden_{family}_{i+1}'
            bounds=im.getbbox()
            if bounds:
                x,y=min(bounds[0],AT[0]),min(bounds[1],AT[1])
                right,bottom=max(bounds[2],AT[0]+1),max(bounds[3],AT[1]+1)
                width,height=(right-x+7)//8*8,(bottom-y+7)//8*8
                compact=im.crop((x,y,x+width,y+height));anchor=(AT[0]-x,AT[1]-y)
                rebuilt=blank(SIZE);rebuilt.alpha_composite(compact,(x,y))
                assert rebuilt.tobytes()==im.tobytes()
            else:compact=blank((8,8));anchor=(4,4)
            save(compact,OUT/'fx'/family/f'{key}.png')
            fx_metadata[key]={'size':compact.size,'anchor':anchor}
    ground=Image.open(ROOT/'presentation/forest/root_hollow_layered_ground.png').convert('RGBA').crop((120,70,376,246))
    check(ground)
    def scene(state,index,label,families=(),warning=None,t=0):
        im=ground.copy();d=ImageDraw.Draw(im)
        d.ellipse((AT[0]-10,AT[1]-2,AT[0]+12,AT[1]+2),fill=C['8'])
        for family,n in families:
            if family in ('rune_glow','guard_hit','guard_break','cleave_arc','death_flash','hit_burst'):continue
            im.alpha_composite(effects[family][min(n,len(effects[family])-1)])
        current_body=body[state][min(index,len(body[state])-1)]
        stamp(im,current_body,AT)
        rune=[(x,y) for y in range(18,36) for x in range(17,32) if current_body.getpixel((x,y)) in {C[c] for c in 'tuop'}]
        rune_at=(round(AT[0]-20+sum(p[0] for p in rune)/len(rune)),round(AT[1]-44+sum(p[1] for p in rune)/len(rune))) if rune else (AT[0]+5,AT[1]-18)
        for family,n in families:
            if family in ('rune_glow','guard_hit','guard_break','cleave_arc','death_flash','hit_burst'):
                offset=(rune_at[0]-(AT[0]+5),rune_at[1]-(AT[1]-18)) if family!='cleave_arc' else (0,0)
                im.alpha_composite(effects[family][min(n,len(effects[family])-1)],offset)
        if warning:
            col=C['y' if warning=='cleave' else 'A']
            if warning=='cleave':
                pts=[(round(AT[0]+math.cos(-.9+i*1.8/32)*57),round(AT[1]+math.sin(-.9+i*1.8/32)*57)) for i in range(33)]
                d.line([AT]+pts+[AT],fill=col)
            elif warning=='lash':d.rectangle((AT[0],AT[1]-10,AT[0]+150,AT[1]+10),outline=col)
            else:d.ellipse((AT[0]-48,AT[1]-48,AT[0]+48,AT[1]+48),outline=col)
        d.rectangle((0,0,255,22),fill=C['0'])
        text(im,(4,0),label);text(im,(4,11),'REVIEW ONLY / NOT IN GAME','i')
        return im
    movement=[]
    for state,ticks in [('idle',120),('wake',24),('walk',108)]:
        for tick in range(0,ticks,3):
            index=(tick//(12 if state=='idle' else 6))%len(body[state])
            movement.append(scene(state,index,state.upper()+' / ROOTED KNIGHT',[('idle_spores',(tick//6)%6),('rune_glow',(tick//12)%6)]))
    encode('idle_wake_walk',movement)
    attacks=[];attack_clips={}
    for name,w,s,r in [('cleave',40,6,44),('lash',44,8,40),('ring',56,5,44)]:
        frames=[]
        for tick in range(0,w+s+r+24,3):
            age=tick-w
            if age<0:
                state=name+'_tell';n=min(4,tick*5//w)
                f=[('rune_glow',min(5,tick*6//w))]
                if name=='lash':f.append(('lash_creep',min(4,tick*5//w)))
                if name=='ring':f.append(('ring_charge',min(5,tick*6//w)))
                im=scene(state,n,name.upper()+' / WINDUP',f,name,tick)
            elif age<s:
                state=name+'_strike';n=min(2,age*3//s)
                f=[({'cleave':'cleave_arc','lash':'lash_strike','ring':'ring_burst'}[name],min(5,age*6//s))]
                im=scene(state,n,name.upper()+' / STRIKE',f)
            else:
                f=[]
                if name=='cleave' and age<16:f=[('cleave_arc',min(5,age//2))]
                elif name=='lash' and age<22:f=[('lash_splinters',min(5,(age-s)//3))]
                elif name=='ring' and age<32:f=[('ring_burst',min(7,age//3)),('scorch',min(5,(age-s)//5))]
                im=scene('recover',min(3,(age-s)//8),name.upper()+' / RECOVER',f)
            frames.append(im)
        encode(name,frames);attacks.extend(frames);attack_clips[name]=frames
    encode('all_attacks',attacks)
    guards=[]
    for phase,ticks in [('guarded',42),('hit',12),('break',24),('exposed',66),('restore',30)]:
        for tick in range(0,ticks,3):
            if phase in ('guarded','restore'):im=scene('idle',(tick//12)%6,'GUARDED / RUNE LIT',[('rune_glow',(tick//9)%6)])
            elif phase=='hit':im=scene('guard_hit',tick//6,'GUARD HIT / REDUCED DAMAGE',[('guard_hit',tick//3)])
            elif phase=='break':im=scene('exposed',tick//6,'PARRY / GUARD BREAK',[('guard_break',tick//3)])
            else:im=scene('exposed',(tick//9)%4,'EXPOSED / DARK / 90T TOTAL',[('exposed_dust',(tick//6)%6)])
            guards.append(im)
    encode('guard_break_exposed',guards)
    chain=[im.copy() for im in attack_clips['cleave'][:20]+attack_clips['lash']]
    for im in chain:text(im,(4,162),'UNPARRIED CHAIN / 12T FOLLOWUP','i')
    encode('cleave_lash_chain',chain)
    parry=[im.copy() for im in attack_clips['cleave'][:14]+guards[18:]]
    for im in parry:text(im,(4,162),'PARRY FIXTURE / DARK RUNE WINDOW','i')
    encode('cleave_parry_exposed',parry)
    death=[]
    for tick in range(0,120,3):
        n=min(7,tick//9)
        f=[('death_debris',min(7,tick//6))]
        if tick<12:f.append(('death_flash',tick//3))
        death.append(scene('death',n,'DEFEAT / RUNE EXTINGUISHED',f))
    encode('defeat',death)
    gallery=[]
    for state,seq in body.items():
        for t in range(max(24,len(seq)*3)):
            gallery.append(scene(state,min(len(seq)-1,t//3),'BODY SET / '+state.upper()))
    encode('all_body_animations',gallery)
    catalogue=[]
    for family,seq in effects.items():
        for i in range(max(18,len(seq)*2)):
            state='exposed' if family in ('guard_break','exposed_dust') else 'death' if family in ('death_flash','death_debris') else 'idle'
            catalogue.append(scene(state,0,'FX / '+family.upper(),[(family,min(len(seq)-1,i//2))]))
    encode('all_effects',catalogue)
    # Each state's native body frames on its own contact row, max4 columns per page.
    for state,seq in body.items():
        rows=math.ceil(len(seq)/4);page=Image.new('RGBA',(1536,rows*424+44),C['0'])
        text(page,(8,8),'WARDEN / '+state.upper()+' / 8x NATIVE / ANCHOR20,44')
        for i,im in enumerate(seq):
            x=i%4*384;y=40+i//4*424
            ImageDraw.Draw(page).rectangle((x,y,x+383,y+383),fill=C['e'])
            page.alpha_composite(im.resize((384,384),Image.Resampling.NEAREST),(x,y))
            text(page,(x+8,y+390),f'{state} / {i+1}')
        save(page,OUT/f'contact_sheet_{state}.png')
    assert all(hashlib.sha256((HERE/'frames'/name).read_bytes()).hexdigest()==digest for name,digest in protected.items())
    (OUT/'manifest.json').write_text(json.dumps({'review_only':True,'body_anchor':ANCHOR,'body_cell':[48,48],
        'states':COUNTS,'body_frames':sum(COUNTS.values()),'fx_frames':sum(families.values()),'fx_families':families,
        'fx_assets':fx_metadata,'preview_canvas':SIZE,'preview_mob_feet':AT,'simulation_hz':60,'preview_sample_ticks':3,'gif_frame_ms':50,
        'core_attack_timings':{'cleave':[40,6,44],'lash':[44,8,40],'ring':[56,5,44]},
        'warning_geometry':{'cleave':{'radius':57,'half_angle':.9},'lash':{'length':150,'width':20},'ring':{'radius':48}},
        'chain_delay_ticks':12,'exposed_ticks':90,'blade_trace':{'pivot':[26,25],'hook_tip':[37,35],'cleave_angles':[-105,-15,18],'lash_angles':[-28,-72,-35]},
        'protected_design_hashes':protected,'validation':'PASS: palette,hard alpha,no body/FX reserved colours,no clipped limbs,GIF durations,palette round-trip,design hashes',
        'runtime_installed':False,'generated_with':'deterministic articulated rig of approved native design; no new imagegen call'},indent=2))
    print('WARDEN REVIEW PASS:',sum(COUNTS.values()),'body frames,',sum(families.values()),'FX frames,11 GIFs; no runtime writes')

if __name__=='__main__':main()
