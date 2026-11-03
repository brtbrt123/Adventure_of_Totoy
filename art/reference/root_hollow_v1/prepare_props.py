"""Import Root Hollow's separate prop sprites; never writes core/ or data/."""
from pathlib import Path
import sys,importlib.util,json,math,hashlib
from PIL import Image
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(ROOT/'tools/art'))
import make_arena_ground_from_reference as ground
# The former village helper was removed; reuse the available equivalent palette implementation.
sys.modules['make_village_ground_from_reference']=ground
spec=importlib.util.spec_from_file_location('forest_assets',ROOT/'art/reference/layered_forest/prepare_assets.py')
forest=importlib.util.module_from_spec(spec);spec.loader.exec_module(forest)
CROPS={
 'tree_ancient':(0,0,474,480),'tree_rootwall':(475,0,771,480),'roots':(772,0,1120,480),'barrier_closed':(1121,0,1536,480),
 'barrier_open':(0,481,474,760),'shrine':(475,481,771,760),'rune_stones':(772,481,1120,760),'boulder':(1121,481,1536,760),
 'stump':(0,761,474,1024),'mushrooms':(475,761,771,1024),'branches':(772,761,1120,1024),'antlers':(1121,761,1536,1024)}
LIMITS={'tree_ancient':(160,145),'tree_rootwall':(110,125),'roots':(48,28),'barrier_closed':(72,44),'barrier_open':(72,44),'shrine':(48,42),'rune_stones':(64,45),'boulder':(56,40),'stump':(48,44),'mushrooms':(36,24),'branches':(44,24),'antlers':(32,20)}
BASES={'tree_ancient':[48,24],'tree_rootwall':[30,18],'roots':[32,14],'barrier_closed':[76,18],'barrier_open':[0,0],'shrine':[32,18],'rune_stones':[50,18],'boulder':[44,20],'stump':[40,20],'mushrooms':[0,0],'branches':[0,0],'antlers':[0,0]}
def main():
 sheet=Image.open(HERE/'props_raw.png').convert('RGBA');snapper=ground.Snapper();palette=ground.palette
 artpath=HERE/'pending_prop_art.json';art={'status':'Merge after Claude collision registration','props':{}}
 shadowpath=HERE/'pending_shadow_manifest.json';shadows={'version':1,'status':'Pending Claude collision registration; do not merge production manifest yet','props':{}}
 entries={};geom={};native=HERE/'props';native.mkdir(exist_ok=True)
 for suffix,box in CROPS.items():
  name='root_hollow_'+suffix
  im=sheet.crop(box);im.putalpha(im.getchannel('A').point(lambda a:255 if a>=244 else 0));bounds=im.getbbox();assert bounds,name
  im=im.crop(bounds);limit=LIMITS[suffix];scale=min(.32,limit[0]/im.width,limit[1]/im.height);im=im.resize((max(1,round(im.width*scale)),max(1,round(im.height*scale))),Image.Resampling.NEAREST)
  px=im.load()
  for y in range(im.height):
   for x in range(im.width):
    r,g,b,a=px[x,y];px[x,y]=(*palette.by_symbol[snapper.snap((r,g,b))],255) if a else (0,0,0,0)
  # Both barrier states must have identical canvas and feet anchor.
  if suffix.startswith('barrier_'):
   canvas=Image.new('RGBA',(80,48));canvas.alpha_composite(im,((80-im.width)//2,48-im.height));im=canvas
  im.save(native/(name+'.png'));anchor=[im.width//2,im.height]
  w,h=math.ceil(im.width/8)*8,math.ceil(im.height/8)*8;top=h-im.height
  padded=Image.new('RGBA',(w,h));padded.alpha_composite(im,(0,top));forest.write_grid(name,padded,[anchor[0],anchor[1]+top])
  metadata={'trim':[0,top,im.width,im.height],'contact_shadow':forest.contact(im),'cast_shadow':{}}
  shadow_entry={'object':name,'object_source':(native/(name+'.png')).relative_to(ROOT).as_posix(),'object_size':list(im.size),'object_anchor':anchor,'object_rgba_sha256':hashlib.sha256(im.tobytes()).hexdigest(),'shadows':{}}
  for flip,orientation in [(False,'normal'),(True,'flipped')]:
   shadow='fx_shadow_'+name+('_flipped' if flip else '')+'_1';shadow_entry['shadows'][orientation]=forest.cast(im,anchor,flip,shadow);metadata['cast_shadow'][orientation]=shadow
  art['props'][name]=metadata
  shadows['props'][name]=shadow_entry
  entries[name]={'scale':scale,'crop':box,'alpha_crop':list(bounds),'size':list(im.size),'anchor':anchor,'padded':[w,h]}
  geom[name]={'size':list(im.size),'anchor':anchor,'suggested_base_size':BASES[suffix],'suggested_solid':suffix not in ('mushrooms','branches','antlers','barrier_open'),'collision_registered':False}
  print(name,im.size,anchor)
 artpath.write_text(json.dumps(art,indent=2)+'\n')
 shadowpath.write_text(json.dumps(shadows,indent=2)+'\n')
 (HERE/'import_manifest.json').write_text(json.dumps({'scale':.32,'alpha_threshold':244,'raw_sha256':hashlib.sha256((HERE/'props_raw.png').read_bytes()).hexdigest(),'props':entries},indent=2)+'\n')
 (HERE/'imported_prop_geometry.json').write_text(json.dumps({'status':'PROPOSAL: Claude must register actual collision geometry before placement','props':geom},indent=2)+'\n')
 # Native-scale contact sheet: these are independent transparent assets, not terrain paint.
 contact=Image.new('RGBA',(768,600),(28,24,36,255))
 from PIL import ImageDraw,ImageFont
 d=ImageDraw.Draw(contact);font=ImageFont.truetype(str(ROOT/'presentation/fonts/Cinzel.ttf'),12)
 for i,name in enumerate(entries):
  im=Image.open(native/(name+'.png'));im=im.resize((im.width*1,im.height*1),Image.Resampling.NEAREST)
  x=(i%4)*192+(192-im.width)//2;y=(i//4)*200+28
  contact.alpha_composite(im,(x,y));d.text(((i%4)*192+5,(i//4)*200+5),name.removeprefix('root_hollow_'),font=font,fill=(244,236,214,255))
 contact.save(HERE/'props_native_contact.png')
if __name__=='__main__':main()
