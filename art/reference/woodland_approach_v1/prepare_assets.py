"""Approved woodland source import; writes only art/ and presentation/."""
from pathlib import Path
import hashlib
import copy
import importlib.util
import json
import math
import sys
from PIL import Image
ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / 'tools/art'))
import make_village_ground_from_reference as ground
spec = importlib.util.spec_from_file_location('forest_import', ROOT / 'art/reference/layered_forest/prepare_assets.py')
forest = importlib.util.module_from_spec(spec)
spec.loader.exec_module(forest)
CROPS = {
 'tree_broad': (10,12,505,475), 'tree_slender': (510,12,805,475),
 'bush': (840,240,1135,470), 'brambles': (1180,200,1530,475),
 'rocks': (40,515,395,735), 'log': (440,530,780,735),
 'stump': (820,510,1165,740), 'lantern': (1250,465,1440,750),
 'sign': (60,745,315,1020), 'fire_ring': (430,795,760,1015),
 'bedroll': (830,835,1150,1000), 'supplies': (1180,770,1536,1024)}
def main():
    palette = ground.palette
    sheet = Image.open(HERE / 'props_raw.png').convert('RGBA')
    defs = {'version':1, 'props':{}}
    art_path = ROOT / 'presentation/common/prop_art.json'
    art = json.loads(art_path.read_text())
    manifest = {'scale':0.23,'alpha_threshold':244,'ground_size':[640,400], 'props':{}, 'approvals': {'ground':'2026-10-27: yes i approved','props':'2026-10-27: aight thats good'}, 'source_sha256': {n:hashlib.sha256((HERE/n).read_bytes()).hexdigest() for n in ['ground_raw.png','props_raw.png']}}
    (HERE / 'props').mkdir(exist_ok=True)
    floor = Image.open(HERE / 'ground_raw.png').convert('RGB').resize((640,400), Image.Resampling.LANCZOS)
    ground.to_image(ground.cleanup(ground.snap_image(floor))).save(ROOT / 'presentation/forest/woodland_approach_ground.png')
    snapper = ground.Snapper()
    for suffix, crop in CROPS.items():
        name = 'woodland_' + suffix
        image = sheet.crop(crop)
        alpha = image.getchannel('A').point(lambda a: 255 if a >= 244 else 0)
        image.putalpha(alpha)
        bounds = image.getbbox()
        assert bounds, name
        image = image.crop(bounds)
        image = image.resize((round(image.width*.23),round(image.height*.23)), Image.Resampling.NEAREST)
        pixels = image.load()
        for y in range(image.height):
            for x in range(image.width):
                r,g,b,a = pixels[x,y]
                pixels[x,y] = (*palette.by_symbol[snapper.snap((r,g,b))],255) if a else (0,0,0,0)
        image.save(HERE / 'props' / (name+'.png'))
        anchor = [round(image.width*.5),image.height]
        w,h = math.ceil(image.width/8)*8,math.ceil(image.height/8)*8
        top = h-image.height
        padded = Image.new('RGBA',(w,h));padded.paste(image,(0,top))
        forest.write_grid(name,padded,[anchor[0],anchor[1]+top])
        metadata={'trim':[0,top,image.width,image.height],'contact_shadow':forest.contact(image),'cast_shadow':{}}
        for flipped, orientation in [(False,'normal'),(True,'flipped')]:
            shadow_name='fx_shadow_'+name+('_flipped' if flipped else '')+'_1'
            forest.cast(image,anchor,flipped,shadow_name)
            metadata['cast_shadow'][orientation]=shadow_name
        art['props'][name]=metadata
        # No gameplay collider guesses: Claude supplies base footprints before live integration.
        defs['props'][name]={'w':image.width,'h':image.height,'anchor':anchor,'image':name+'.png','solid':False,'colliders':[]}
        manifest['props'][name]={'crop':list(crop),'alpha_crop':list(bounds),'size':list(image.size),'anchor':anchor,'padded':[w,h]}
        print(name,image.size,anchor)
    art_path.write_text(json.dumps(art,indent=2)+'\n')
    (HERE/'imported_prop_geometry.json').write_text(json.dumps(defs,indent=2)+'\n')
    (HERE/'import_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    lights_path=ROOT/'presentation/common/local_lights.json'
    lights=json.loads(lights_path.read_text()); lights['woodland_lantern']=copy.deepcopy(lights['forest_lantern_post'])
    # Match the new fixture position rather than reuse the old socket geometry.
    for socket in lights['woodland_lantern']:
        socket['pixel']=[12,22]
    lights_path.write_text(json.dumps(lights,indent=2)+'\n')
if __name__ == '__main__':
    main()
