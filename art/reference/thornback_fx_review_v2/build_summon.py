"""Review-only Thornback chant/summon. Never modifies runtime or the approved moth poses."""
from pathlib import Path
import sys,json,math,hashlib
from PIL import Image,ImageDraw,ImageFont
sys.dont_write_bytecode = True
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).resolve().parent;OUT=HERE/'summon';OUT.mkdir(exist_ok=True)
sys.path.insert(0,str(ROOT/'tools/art'))
import make_chapter1_creatures_art as R
PAL=json.loads((ROOT/'art/palette.json').read_text());C={c['symbol']:tuple(bytes.fromhex(c['hex'][1:]))+(255,) for c in PAL['colors']};ALLOWED=set(C.values());SAFE={v for k,v in C.items() if k not in PAL['reserved']}
FONT=ImageFont.truetype(str(ROOT/'presentation/fonts/Cinzel.ttf'),19)
GROUND=Image.open(ROOT/'presentation/forest/root_hollow_layered_ground.png').convert('RGBA').crop((185,110,441,270))
MOTH_DIR=ROOT/'art/reference/glowmoth_stag_animation_review_v1/frames/glowmoth_idle'
MOTHS=[Image.open(MOTH_DIR/f'glowmoth_idle_right_{i}.png').convert('RGBA') for i in range(1,25)]
SITES=[(37,108),(61,67),(135,60),(192,97),(171,143)]
FEET=(100,118);ANCHOR=R.STAG_A

def stamp(im,sprite,anchor,point):im.alpha_composite(sprite,(round(point[0]-anchor[0]),round(point[1]-anchor[1])))
def check(im):assert all(p[3] in (0,255) and (p[3]==0 or p in SAFE) for p in im.getdata())
def body(t):
 if t<12:neck=-3;head=-2;rim=0;glow=1;mouth=0
 elif t<36:
  q=(t-12)/24;neck=-3-20*q;head=-2-12*q;rim=1;glow=2;mouth=.7 if t%6<3 else 0
 elif t<68:neck=-23+math.sin(t*.5)*1.2;head=-14;rim=2;glow=3;mouth=.9 if t%6<3 else .1
 elif t<88:neck=-25+math.sin(t*.4)*2;head=-16;rim=3;glow=3;mouth=1 if t<78 else .1
 else:
  q=min(1,(t-88)/18);neck=-25+20*q;head=-16+14*q;rim=2 if q<.6 else 1;glow=2 if q<.8 else 1;mouth=0
 return R.to_image(R.stag(by=40+math.sin(t*.15)*.35,neck=neck,head=head,rim=rim,glow=glow,mouth=mouth))
def mask(im):
 pixels=im.load();return {(x,y) for y in range(38) for x in range(15,im.width) if pixels[x,y][3] and pixels[x,y][:3] in [C[k][:3] for k in 'hij1tuop']}
def antler_fx(im,t):
 fx=Image.new('RGBA',(128,96));d=ImageDraw.Draw(fx);points=mask(im)
 intensity=0 if t<12 else (1 if t<36 else 2 if t<68 else 3 if t<88 else 1)
 if intensity:
  for radius,color in [(intensity+1,'k'),(max(1,intensity),'t'),(1,'u')]:
   for x,y in sorted(points):d.ellipse((x+16-radius,y+16-radius,x+16+radius,y+16+radius),fill=C[color])
  for x,y in sorted(points):d.point((x+16,y+16),fill=C['p' if intensity==3 and (x+y+t)%3==0 else 'o'])
 check(fx);return fx,points

def sparkles(layer,origin,t,count=12,radius=24):
 d=ImageDraw.Draw(layer)
 for j in range(count):
  age=(t+j*11)%32;angle=j*2.399+t*.035;r=radius*(.3+.7*age/32);x=round(origin[0]+math.cos(angle)*r);y=round(origin[1]+math.sin(angle)*r*.6-age*.35)
  d.point((x,y),fill=C['p' if age<5 else 'u' if age<18 else 't'])
  if age<4:d.point((x+1,y),fill=C['u'])
frames=[];labels=[];records=[];bodies=OUT/'body_frames';halos=OUT/'antler_fx';layers=OUT/'summon_fx';bodies.mkdir(exist_ok=True);halos.mkdir(exist_ok=True);layers.mkdir(exist_ok=True)
for t in range(160):
 im=GROUND.copy();d=ImageDraw.Draw(im);d.ellipse((FEET[0]-22,FEET[1]-2,FEET[0]+22,FEET[1]+2),fill=C['8'])
 b=body(t);check(b);halo,points=antler_fx(b,t)
 # Brightest region is computed from this actual pose, so the effect follows the moving antlers.
 center=(sum(x for x,y in points)/len(points),sum(y for x,y in points)/len(points)) if points else (60,20)
 origin=(FEET[0]+center[0]-ANCHOR[0],FEET[1]+center[1]-ANCHOR[1])
 if t>=12:stamp(im,halo,(ANCHOR[0]+16,ANCHOR[1]+16),FEET)
 fx=Image.new('RGBA',(256,160));f=ImageDraw.Draw(fx)
 if 12<=t<88:
  sparkles(fx,origin,t,8 if t<36 else 20,16 if t<36 else 27)
  # Three small rune shapes orbit the charged horns: teal summon language, no damage warning colours.
  if t>=36:
   for j in range(3):
    angle=t*.055+j*math.tau/3;x=round(origin[0]+math.cos(angle)*28);y=round(origin[1]+math.sin(angle)*13)
    f.line([(x-2,y),(x,y-3),(x+2,y),(x,y+3),(x-2,y)],fill=C['u'],width=1);f.point((x,y),fill=C['p'])
 # Five energy seeds -> five portals -> exactly five moths. No extra silhouette afterimages.
 visible=0
 for j,(x,y) in enumerate(SITES):
  release=68+j*2;birth=release+8;age=t-release
  if 46<=t<birth:
   pulse=(t+j)%10;r=4+(pulse//4);f.ellipse((x-r,y-r//2,x+r,y+r//2),outline=C['t'],width=1)
  if release<=t<birth:
   q=age/8;px=origin[0]+(x-origin[0])*q;py=origin[1]+(y-12-origin[1])*q-math.sin(q*math.pi)*10
   for trail in range(5):
    u=max(0,q-trail*.06);tx=origin[0]+(x-origin[0])*u;ty=origin[1]+(y-12-origin[1])*u-math.sin(u*math.pi)*10;f.point((round(tx),round(ty)),fill=C['t' if trail>2 else 'u'])
   f.ellipse((round(px)-2,round(py)-2,round(px)+2,round(py)+2),fill=C['o']);f.point((round(px),round(py)),fill=C['p'])
  if t>=birth:
   visible+=1;a=t-birth;radius=max(3,12-min(a,18)//2)
   if a<18:
    f.ellipse((x-radius,y-radius//2,x+radius,y+radius//2),outline=C['u' if a<8 else 't'],width=1)
    for k in range(6):
     ang=k*math.tau/6;dist=3+a*.6;f.point((round(x+math.cos(ang)*dist),round(y-10+math.sin(ang)*dist*.6)),fill=C['p' if a<4 else 'u' if a<10 else 't'])
   d.ellipse((x-4,y-1,x+4,y+1),fill=C['8'])
 # Back FX, then separate creature sprites, then sparse foreground antler glints.
 check(fx);im.alpha_composite(fx);stamp(im,b,ANCHOR,FEET)
 if 60<=t<88:
  front=ImageDraw.Draw(im)
  for x,y in sorted(points):
   if (x*3+y+t)%7==0:front.point((round(FEET[0]+x-ANCHOR[0]),round(FEET[1]+y-ANCHOR[1])),fill=C['p'])
 for j,(x,y) in enumerate(SITES):
  if t>=76+j*2:
   # These exact approved sprites are reused without pixel edits.
   moth=MOTHS[(int(t*1.5)+j*5)%24];stamp(im,moth,(16,29),(x+math.sin(t*.08+j)*1.5,y+math.sin(t*.1+j)*1))
 assert 0<=visible<=5
 if t>=84:assert visible==5
 check(im);frames.append(im)
 phase='IDLE' if t<12 else 'CHANT / HORNS BRIGHTEN' if t<36 else 'CHANT / ANTLER MAGIC BUILDS' if t<68 else 'SUMMON / '+str(visible)+' OF 5 GLOWMOTHS' if t<88 else 'FIVE GLOWMOTHS / RELEASE COMPLETE'
 labels.append(phase);records.append({'frame':t,'time_ms':t*50,'phase':phase,'moths_visible':visible,'antler_origin':[round(origin[0],2),round(origin[1],2)]})
 b.save(bodies/f'stag_chant_right_{t+1:03}.png');halo.save(halos/f'antlers_{t+1:03}.png');fx.save(layers/f'summon_{t+1:03}.png')
rendered=[]
for im,label in zip(frames,labels):
 canvas=Image.new('RGB',(1024,674),C['0'][:3]);canvas.paste(im.resize((1024,640),Image.Resampling.NEAREST).convert('RGB'),(0,34));ImageDraw.Draw(canvas).text((12,7),'Thornback Stag / '+label,font=FONT,fill=C['1'][:3]);rendered.append(canvas)
samples=Image.new('RGB',(1024,674*4))
for row,n in enumerate([24,55,78,120]):samples.paste(rendered[n],(0,row*674))
adaptive=samples.quantize(colors=220).getpalette();palette=Image.new('P',(1,1));raw=[v for c in C.values() for v in c[:3]]+adaptive[:660];palette.putpalette((raw+[0]*768)[:768])
indexed=[im.quantize(palette=palette,dither=Image.Dither.NONE) for im in rendered]
indexed[0].save(OUT/'chant_summon_five.gif',save_all=True,append_images=indexed[1:],duration=50,loop=0,disposal=2,optimize=True)
contact=Image.new('RGB',(1024,674*2),C['0'][:3])
for i,n in enumerate([20,60,80,110]):contact.paste(rendered[n].resize((512,337),Image.Resampling.NEAREST),((i%2)*512,(i//2)*337))
# Trim unused rows: four panels, each2x native instead of4x.
contact=contact.crop((0,0,1024,674));contact.save(OUT/'chant_contact.png');rendered[120].save(OUT/'five_moths_revealed.png')
manifest={'review_only':True,'new_attack':'chanting antler glow -> exactly five Glowmoths','gameplay_rules_not_implemented':True,'frame_ms':50,'duration_ms':8000,'stag_anchor':list(ANCHOR),'antler_fx_anchor':[ANCHOR[0]+16,ANCHOR[1]+16],'moth_anchor':[16,29],'summon_fx_anchor':[100,118],'spawn_offsets_preview_only':[[x-100,y-118] for x,y in SITES],'spawn_positions_preview_only':[list(v) for v in SITES],'moth_approval':'Owner: i approved on th glowmoth','moth_files_sha256':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(MOTH_DIR.glob('*.png'))},'timeline':records}
(OUT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
check_image=Image.open(OUT/'chant_summon_five.gif');ms=0
for i in range(check_image.n_frames):check_image.seek(i);ms+=check_image.info.get('duration',0)
assert ms==8000;assert records[-1]['moths_visible']==5
print('SUMMON REVIEW OK:8.0s, exactly5 approved moths, hard-alpha/Totoy36 layers, antler tracking, no runtime writes')
