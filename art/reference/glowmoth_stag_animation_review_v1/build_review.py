"""Review-only animated creature/effect proposals; original rigs and runtime are read-only."""
from pathlib import Path
import sys,json,math,hashlib
from PIL import Image,ImageDraw,ImageFont,ImageOps
ROOT=Path(__file__).resolve().parents[3];OUT=Path(__file__).resolve().parent
sys.path.insert(0,str(ROOT/'tools/art'))
import make_chapter1_creatures_art as R
PAL=json.loads((ROOT/'art/palette.json').read_text());C={c['symbol']:tuple(bytes.fromhex(c['hex'][1:]))+(255,) for c in PAL['colors']};ALLOWED=set(C.values());BODY={v for k,v in C.items() if k not in PAL['reserved']}
FONT=ImageFont.truetype(str(ROOT/'presentation/fonts/Cinzel.ttf'),18)
GROUND=Image.open(ROOT/'presentation/forest/root_hollow_layered_ground.png').convert('RGBA')
STAG=R.stag_frames();MOTH=R.glowmoth_frames();FX=R.fx_sets();FX['fx_glowmoth_orb']=[R.orb(i) for i in range(4)];FX['fx_glowmoth_orb_pop']=[R.orb_pop(i) for i in range(4)];HERO,HA=R.hero_and_golem()[0]
META={'review_only':True,'fps':20,'frame_ms':50,'native_right_facing':True,'clips':{},'fx_anchors':{k:list(v[2]) for k,v in R.FX_INFO.items()}}
META['fx_anchors'].update({'fx_glowmoth_orb':[8,8],'fx_glowmoth_orb_pop':[8,8]})
def stamp(canvas,image,anchor,at,flip=False):
 image=R.to_image(image) if isinstance(image,list) else image
 ax,ay=anchor
 if flip:image=ImageOps.mirror(image);ax=image.width-ax
 canvas.alpha_composite(image,(round(at[0]-ax),round(at[1]-ay)))
def validate(image,body=False):
 assert all(p[3] in (0,255) and (p[3]==0 or p in (BODY if body else ALLOWED)) for p in image.getdata())
def export(name,frames,anchor):
 folder=OUT/'frames'/name;folder.mkdir(parents=True,exist_ok=True)
 for i,image in enumerate(frames,1):
  image=R.to_image(image) if isinstance(image,list) else image;validate(image,True);image.save(folder/f'{name}_right_{i}.png')
 META.setdefault('sources',{})[name]={'frames':len(frames),'size':list(image.size),'anchor':list(anchor)}
def bg(size):
 w,h=size;im=GROUND.crop((230,140,230+w,140+h));return im

def shadow(im,at,r):ImageDraw.Draw(im).ellipse((round(at[0]-r),round(at[1]-2),round(at[0]+r),round(at[1]+2)),fill=C['8'])
def motes(im,at,t,count=6,spread=10):
 d=ImageDraw.Draw(im)
 for j in range(count):
  age=(t+j*7)%24;x=round(at[0]+math.sin(j*2.4)*spread+math.sin(t*.12+j)*2);y=round(at[1]-age*.6)
  d.point((x,y),fill=C['p' if age<5 else ('u' if age<15 else 't')])
def ring(im,at,r,color):
 d=ImageDraw.Draw(im);d.ellipse((round(at[0]-r),round(at[1]-r*.42),round(at[0]+r),round(at[1]+r*.42)),outline=C[color],width=1)
def save(name,images,labels,notes):
 frames=[]
 for image,label in zip(images,labels):
  validate(image);image=image.resize((image.width*4,image.height*4),Image.Resampling.NEAREST).convert('RGB');canvas=Image.new('RGB',(image.width,image.height+34),C['0'][:3]);canvas.paste(image,(0,34));ImageDraw.Draw(canvas).text((10,6),label,font=FONT,fill=C['1'][:3]);frames.append(canvas)
 samples=Image.new('RGB',(frames[0].width,frames[0].height*4))
 for i,n in enumerate([0,len(frames)//4,len(frames)//2,len(frames)*3//4]):samples.paste(frames[n],(0,i*frames[0].height))
 adaptive=samples.quantize(colors=220).getpalette();palette=Image.new('P',(1,1));colors=[v for c in C.values() for v in c[:3]]+adaptive[:220*3];palette.putpalette((colors+[0]*768)[:768]);indexed=[f.quantize(palette=palette,dither=Image.Dither.NONE) for f in frames]
 indexed[0].save(OUT/(name+'.gif'),save_all=True,append_images=indexed[1:],duration=50,loop=0,disposal=2,optimize=True)
 frames[len(frames)//2].save(OUT/(name+'_still.png'))
 META['clips'][name]={'frames':len(frames),'duration_ms':len(frames)*50,'native_stage':list(images[0].size),'notes':notes}
 return frames

def moth_pose(i,move=False):
 phase=i/12*math.tau
 g=R.glowmoth(by=10+math.sin(phase/2)*.65,flap=15+40*math.sin(phase),abd=88+math.sin(phase/2)*5,glow=1+int((i//3)%3==0),tilt=8 if move else math.sin(phase/2)*2)
 im=Image.new('RGBA',(32,32));stamp(im,g,R.MOTH_A,(16,29));return im
m_idle=[moth_pose(i) for i in range(24)];m_move=[moth_pose(i,True) for i in range(12)]
s_idle=[]
for i in range(24):
 phase=i/24*math.tau;s_idle.append(R.stag(by=40+math.sin(phase)*.45,neck=-2+math.sin(phase)*4,head=math.sin(phase)*5,glow=1+int(i in range(8,15)),eye='closed' if i in (19,20) else 'glow'))
s_walk=[]
for i in range(12):
 ph=i/12*math.tau;a,b=math.sin(ph),math.sin(ph+math.pi);la,lb=max(0,math.cos(ph))*2.6,max(0,math.cos(ph+math.pi))*2.6;G=R.STAG_GROUND
 feet={'ff':(42.8+b*4,G-lb),'fn':(45.4+a*4,G-la),'bf':(23.2+a*4,G-la),'bn':(25.6+b*4,G-lb)}
 s_walk.append(R.stag(by=40-abs(math.sin(ph))*.7,neck=math.sin(ph)*2,head=-1,feet=feet,bends={'fn':.6+la,'ff':.6+lb}))
for name,seq,anchor in [('glowmoth_idle',m_idle,(16,29)),('glowmoth_move',m_move,(16,29)),('stag_idle',s_idle,R.STAG_A),('stag_move',s_walk,R.STAG_A)]:export(name,seq,anchor)
# Preserve existing attack poses, separate from new proposed calm/movement loops.
for species,table,anchor in [('glowmoth',MOTH,R.MOTH_A),('stag',STAG,R.STAG_A)]:
 for state,seq in table.items():
  if state not in ('idle','walk','flutter'):export(species+'_'+state,seq,anchor)
FX['fx_stag_spirit_root']=[[row[:] for row in grid] for grid in FX['fx_ch1_root_spike']]
for k in (2,3,4):
 for y in range(14,33):
  xs=[x for x in range(9,17) if FX['fx_stag_spirit_root'][k][y][x] in '89abc']
  if xs:FX['fx_stag_spirit_root'][k][y][max(xs)]='u' if y%4==0 else 't'
META['fx_anchors']['fx_stag_spirit_root']=[12,36]
for name,seq in FX.items():
 folder=OUT/'effects'/name;folder.mkdir(parents=True,exist_ok=True)
 for i,g in enumerate(seq,1):im=R.to_image(g);validate(im);im.save(folder/f'{name}_{i}.png')
for mob,size,seq,anchor,radius in [('glowmoth',(128,80),m_idle,(16,29),5),('stag',(224,112),s_idle,R.STAG_A,21)]:
 images=[];labels=[]
 for t in range(96):
  im=bg(size);at=(48 if mob=='glowmoth' else 80,62 if mob=='glowmoth' else 92);shadow(im,at,radius);motes(im,(at[0],at[1]-(12 if mob=='glowmoth' else 37)),t,count=3,spread=7 if mob=='glowmoth' else 16);stamp(im,seq[(int(t*1.5) if mob=='glowmoth' else t//2)%len(seq)],anchor,at);images.append(im);labels.append(mob.title()+' / idle: hover + pulse' if mob=='glowmoth' else 'Thornback Stag / idle: breath, head sway, blink')
 save(mob+'_idle',images,labels,'New calm loop; no world movement or gameplay changes.')
 images=[];labels=[]
 for t in range(72):
  ph=t/72*math.tau;x=(60+27*math.sin(ph)) if mob=='glowmoth' else (85+36*math.sin(ph));y=(59+4*math.sin(2*ph)) if mob=='glowmoth' else 92;at=(x,y);flip=math.cos(ph)<0;im=bg(size);shadow(im,(x,62 if mob=='glowmoth' else 92),radius)
  if mob=='glowmoth':
   for age in (4,8,12):ImageDraw.Draw(im).point((round(x-(1 if not flip else -1)*age*.7),round(y-12+math.sin(age)*2)),fill=C['t' if age>8 else 'u'])
  elif t%12<5:stamp(im,FX['fx_ch1_boar_dust'][min(3,t%12)],R.FX_INFO['fx_ch1_boar_dust'][2],(x-12 if not flip else x+12,y),flip)
  stamp(im,m_move[int(t*1.5)%12] if mob=='glowmoth' else s_walk[(t//2)%12],(16,29) if mob=='glowmoth' else R.STAG_A,at,flip);images.append(im);labels.append('Glowmoth / movement: banking flutter + motes' if mob=='glowmoth' else 'Thornback Stag / movement: planted stride + hoof dust')
 save(mob+'_move',images,labels,'Translation/mirroring is review choreography; AI paths and speed unchanged.')
# Proposed moth orb charge/release. White/teal core and particle trail remain separate from its body.
images=[];labels=[]
for t in range(72):
 im=bg((128,80));at=(26,62);shadow(im,at,5);stamp(im,HERO,HA,(110,65),True)
 if t<8:body=m_idle[int(t*1.5)%24];anchor=(16,29);label='Glowmoth / hover'
 elif t<26:
  n=min(3,(t-8)//5);body=MOTH['shot_tell'][n];anchor=R.MOTH_A;label='Glowmoth / charge: abdomen curls + bright core';motes(im,(32,51),t,8,9);ring(im,(26,64),7,'z')
 else:
  body=MOTH['shot_release'][min(1,(t-26)//3)] if t<32 else m_idle[int(t*1.5)%24];anchor=R.MOTH_A if t<32 else (16,29);label='Glowmoth / recoil, spirit orb, trail and impact'
  if 26<=t<46:
   x=38+(t-26)*3.4;stamp(im,FX['fx_ch1_moth_trail'][t%4],R.FX_INFO['fx_ch1_moth_trail'][2],(x,51));stamp(im,R.orb(t%4),(8,8),(x,51))
  if 46<=t<52:stamp(im,R.orb_pop(min(3,(t-46)//2)),(8,8),(106,51));motes(im,(106,51),t,9,10)
 stamp(im,body,anchor,at);images.append(im);labels.append(label)
save('glowmoth_attack',images,labels,'Proposed ranged-orb visuals and review timings ONLY. No Glowmoth combat implementation exists yet. Totoy is a scale marker.')
# Stag: exact current core windup/strike/recovery lengths, sampled at3 ticks per review frame.
images=[];labels=[]
clips=[('slam',54,6,48),('charge',56,36,40),('roots',50,5,40)]
for attack,windup,strike,recover in clips:
 for tick in range(0,windup+strike+recover+30,3):
  im=bg((320,160));at=(52,104);d=ImageDraw.Draw(im)
  if attack=='charge':
   shadow(im,(262,104),20);stamp(im,Image.open(ROOT/'art/reference/root_hollow_v1/props/root_hollow_boulder.png'),(28,40),(262,104))
  stamp(im,HERO,HA,(294,104),True)
  if attack=='charge' and tick>=windup:at=(52+min(strike,max(0,tick-windup))*4.4,104)
  shadow(im,at,21);phase='windup' if tick<windup else ('strike' if tick<windup+strike else 'recover');age=tick-windup
  if attack=='slam':
   key='slam_raise' if phase=='windup' else ('slam_strike' if phase=='strike' else 'slam_recover');n=min(len(STAG[key])-1,int(tick/windup*len(STAG[key]))) if phase=='windup' else (min(2,max(0,age)//2) if phase=='strike' else min(3,max(0,age-strike)//12))
   if phase=='windup':
    points=[(52,104)]+[(round(52+50*math.cos(-.95+1.9*i/20)),round(104+50*math.sin(-.95+1.9*i/20))) for i in range(21)]+[(52,104)];d.line(points,fill=C['x'],width=1)
   if 0<=age<24:stamp(im,FX['fx_ch1_stag_slam_rubble'][(0 if age<3 else 1 if age<6 else 2 if age<11 else 3 if age<17 else 4)],R.FX_INFO['fx_ch1_stag_slam_rubble'][2],(82,104));ring(im,(82,104),5+age//2,'j')
  elif attack=='charge':
   key='charge_tell' if phase=='windup' else ('charge_run' if phase=='strike' else 'charge_crash');n=min(4,int(tick/windup*5)) if phase=='windup' else ((max(0,age)//3)%4 if phase=='strike' else min(2,max(0,age-strike)//14))
   if phase=='windup':d.rectangle((52,89,210,119),outline=C['z'],width=1)
   if phase=='strike':stamp(im,FX['fx_ch1_boar_dust'][(age//3)%4],R.FX_INFO['fx_ch1_boar_dust'][2],(at[0]-16,104));motes(im,(at[0]+25,84),tick,4,5)
   if 0<=age-strike<20:stamp(im,FX['fx_ch1_boar_crash'][min(4,(age-strike)//4)],R.FX_INFO['fx_ch1_boar_crash'][2],(at[0]+26,104))
  else:
   key='phase2_roar' if phase=='windup' else 'slam_recover';n=min(5,int(tick/windup*6)) if phase=='windup' else min(3,max(0,age)//12)
   if phase=='windup':d.ellipse((186,70,254,138),outline=C['z'],width=1);motes(im,(52,70),tick,8,20)
   if -8<=age<30:stamp(im,FX['fx_stag_spirit_root'][0 if age<0 else 1 if age<2 else 2 if age<6 else 3 if age<10 else 4 if age<20 else 5],R.FX_INFO['fx_ch1_root_spike'][2],(220,104));motes(im,(220,98),age,8,14)
  if tick>=windup+strike+recover:key='idle';n=(tick//12)%4
  stamp(im,STAG[key][n],R.STAG_A,at);images.append(im);labels.append('Stag / '+{'slam':'GOLD antler slam + ground impact','charge':'RED charge + hoof dust / crash','roots':'RED root eruption + corruption motes'}[attack]+' / '+phase)
save('stag_attacks',images,labels,'Attack phase lengths match current core54/6/48,56/36/40,50/5/40 ticks. Roots art preview reuses roar gesture; charge includes an optional obstacle-crash ending, not a new rule. Hit geometry and targets stay core-owned.')
(OUT/'manifest.json').write_text(json.dumps(META,indent=2)+'\n')
print('REVIEW OK: six native animation GIFs, separate pose/effect PNGs, palette/hard-alpha checks passed; no runtime writes')
