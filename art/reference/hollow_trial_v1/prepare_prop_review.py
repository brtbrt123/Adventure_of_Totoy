"""Palette-limited owner-review props only. Never writes sources, atlas, data or runtime catalogues."""
from pathlib import Path
import hashlib
import json
import math
import sys
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
sys.path.insert(0,str(ROOT/'tools/art'))
import make_arena_ground_from_reference as ground

NAMES = ['altar_dark','altar_lit','chest_closed','chest_open','rune_rock_1',
         'rune_rock_2','rune_rock_3','rune_rock_4','rune_rock_5','rune_rock_6',
         'bush_1','bush_2','bush_3','bush_4','roots_1',
         'roots_2','fern_1','fern_2','tree_1','tree_2']
LIMITS = [(56,42),(56,42),(32,32),(32,32),(40,32),
          (32,48),(36,28),(40,32),(48,36),(32,40),
          (48,28),(40,32),(44,30),(36,24),(44,24),
          (48,24),(24,24),(20,28),(104,120),(120,112)]
BASES = [(44,20),(44,20),(24,12),(24,12),(30,16),
         (20,12),(26,12),(30,16),(36,18),(22,14),
         (30,14),(26,16),(30,14),(24,12),(0,0),
         (0,0),(0,0),(0,0),(30,18),(36,20)]
BOTTOM_CROPS = [(15,900,320,1090),(330,900,550,1090),(570,890,770,1090),
                (790,770,1070,1095),(1070,770,1402,1095)]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    approved = json.loads((HERE/'APPROVAL.json').read_text())
    ground_path = HERE/approved['native_asset']
    assert sha(ground_path) == approved['sha256']
    sheet = Image.open(HERE/'props_raw.png').convert('RGBA')
    snapper = ground.Snapper()
    folder = HERE/'prop_review/native'
    folder.mkdir(parents=True,exist_ok=True)
    art = {}
    records = {}
    for i,name in enumerate(NAMES):
        row,col = divmod(i,5)
        # The generator shifts the tree canopies upward: use inspected gutters, not equal-row assumptions.
        top,bottom = [(0,320),(320,620),(620,785),(785,sheet.height)][row]
        box = (round(col*sheet.width/5),top,round((col+1)*sheet.width/5),bottom)
        if row == 3:
            box = BOTTOM_CROPS[col]
        im = sheet.crop(box)
        im.putalpha(im.getchannel('A').point(lambda a:255 if a>=244 else 0))
        bounds = im.getbbox()
        assert bounds,name
        assert bounds[0]>0 and bounds[1]>0 and bounds[2]<im.width and bounds[3]<im.height,(name,'crop touches opaque pixels')
        im = im.crop(bounds)
        maxw,maxh = LIMITS[i]
        # Keep paired states at the same image-to-game pixel scale, not individually stretched to limits.
        scale = min(maxw/im.width,maxh/im.height)
        if name.startswith('altar_'):
            scale = 56/240
        elif name.startswith('chest_'):
            scale = 32/204
        im = im.resize((max(1,round(im.width*scale)),max(1,round(im.height*scale))),Image.Resampling.NEAREST)
        px = im.load()
        for y in range(im.height):
            for x in range(im.width):
                r,g,b,a = px[x,y]
                px[x,y] = (*ground.palette.by_symbol[snapper.snap((r,g,b))],255) if a else (0,0,0,0)
        if name.startswith('altar_'):
            size = (64,48)
        elif name.startswith('chest_'):
            size = (40,40)
        else:
            size = (math.ceil(im.width/8)*8,math.ceil(im.height/8)*8)
        assert im.width<=size[0] and im.height<=size[1],(name,im.size,size)
        canvas = Image.new('RGBA',size)
        canvas.alpha_composite(im,((size[0]-im.width)//2,size[1]-im.height))
        canvas.save(folder/(name+'.png'))
        art[name] = canvas
        records[name] = {'source_crop':box,'opaque_bounds':list(bounds),'scale':scale,
            'size':list(size),'anchor':[size[0]//2,size[1]],'suggested_base_size':BASES[i],
            'collision_registered':False,'runtime_installed':False}
    for first,second in [('altar_dark','altar_lit'),('chest_closed','chest_open')]:
        assert art[first].size==art[second].size and records[first]['anchor']==records[second]['anchor']
    palette = set(ground.palette.by_symbol.values())
    assert all(p[3] in (0,255) and (p[3]==0 or p[:3] in palette) for im in art.values() for p in im.get_flattened_data())
    assert all(p[3]==0 or p[:3] not in {ground.palette.by_symbol[c] for c in ground.palette.reserved} for im in art.values() for p in im.get_flattened_data())
    contact = Image.new('RGBA',(1200,734),(28,24,36,255))
    draw = ImageDraw.Draw(contact)
    font = ImageFont.truetype(str(ROOT/'presentation/fonts/Cinzel.ttf'),15)
    draw.text((16,10),'HOLLOW TRIAL / PROP REVIEW / SAME 2x GAME SCALE',font=font,fill=(244,236,214,255))
    for i,name in enumerate(NAMES):
        row,col = divmod(i,5)
        cellx,celly = col*240,[42,190,338,454][row]
        row_height = [148,148,116,280][row]
        im = art[name].resize((art[name].width*2,art[name].height*2),Image.Resampling.NEAREST)
        draw.text((cellx+8,celly+4),name.replace('_',' ').upper(),font=font,fill=(244,236,214,255))
        contact.alpha_composite(im,(cellx+(240-im.width)//2,celly+row_height-12-im.height))
    contact.save(HERE/'prop_review/contact_sheet_props_2x.png')
    report = {'status':'PASS palette/alpha/paired canvas and anchor checks; owner look approval pending',
        'count':20,'source_sha256':sha(HERE/'props_raw.png'),'props':records,
        'approved_ground_sha256':sha(ground_path),'native_asset_folder':'prop_review/native',
        'shadow_masks':'Deferred until selected prop art is approved; no baked sprite shadows',
        'limitations':'Review reductions only; paired artwork may still need pixel registration polish after look approval. Bases are suggestions, not collision certification.'}
    (HERE/'prop_review/manifest.json').write_text(json.dumps(report,indent=2)+'\n')
    assert sha(ground_path)==approved['sha256']
    print('PASS:20 review props, hard alpha, non-reserved Totoy36, paired canvas/anchors, approved ground unchanged. No runtime/source import.')


if __name__=='__main__':
    main()
