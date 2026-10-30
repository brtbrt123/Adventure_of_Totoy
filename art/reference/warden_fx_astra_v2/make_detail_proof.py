"""Review-only cropped evidence from decoded GIF times, not GIF frame indices."""
from pathlib import Path
import json
from PIL import Image, ImageDraw, ImageFont

OUT=Path(__file__).resolve().parent
BASE=OUT.parent/'warden_v1/animation_review'
manifest=json.loads((OUT/'manifest.json').read_text())


def at_time(path,ms):
    with Image.open(path) as gif:
        elapsed=0
        for i in range(gif.n_frames):
            gif.seek(i)
            elapsed+=gif.info['duration']
            if elapsed>ms:
                return gif.convert('RGB').resize((256,176),Image.Resampling.NEAREST)
    raise ValueError((path,ms))


def label(im,xy,value):
    d=ImageDraw.Draw(im);d.fontmode='1'
    d.text(xy,value,font=ImageFont.load_default(),fill='#f4ecd6')


cases=[('cleave',700,(38,54,110,118),'CLEAVE / TIP TRACE'),
       ('cleave',750,(38,54,110,118),'CLEAVE / CONTACT'),
       ('cleave',850,(38,54,110,118),'CLEAVE / DUST SETTLE'),
       ('lash',750,(44,70,224,118),'LASH / ROOTED STRANDS'),
       ('ring',1000,(14,58,118,160),'RING / OUTWARD SPORES'),
       ('ring',1200,(14,58,118,160),'RING / BROKEN SCORCH'),
       ('guard_break_exposed',700,(38,54,110,118),'GUARD / HIT'),
       ('guard_break_exposed',950,(38,54,110,118),'GUARD / BREAK GLYPHS'),
       ('guard_break_exposed',1500,(38,54,110,118),'EXPOSED / DARK CHEST'),
       ('defeat',450,(38,54,110,118),'DEATH / ROOT AND STONE')]
for page in range(2):
    selected=cases[page*5:(page+1)*5]
    sheet=Image.new('RGB',(1472,sum((c[2][3]-c[2][1])*4+28 for c in selected)+28),'#1c1824')
    label(sheet,(8,6),'BASELINE (LEFT) / ASTRA V2 (RIGHT) / DECODED GIF TIME / EXACT 4x PIXELS')
    y=28
    for name,ms,box,title in selected:
        for col,root in enumerate((BASE,OUT)):
            crop=at_time(root/(name+'.gif'),ms).crop(box)
            crop=crop.resize((crop.width*4,crop.height*4),Image.Resampling.NEAREST)
            label(sheet,(col*736+8,y+3),title+' / '+str(ms)+'ms')
            sheet.paste(crop,(col*736+8,y+24))
        y+=(box[3]-box[1])*4+28
    sheet.save(OUT/f'contact_sheet_impact_detail_{page+1}.png')

# First/middle/last of every native FX family, always exact2x pixels.
families=manifest['fx_families']
sheet=Image.new('RGBA',(1320,len(families)*216),'#1c1824')
for row,(family,count) in enumerate(families.items()):
    for col,n in enumerate([1,1+(count-1)//2,count]):
        key=f'fx_warden_{family}_{n}'
        meta=manifest['fx_assets'][key]
        frame=Image.open(OUT/'fx'/family/(key+'.png')).convert('RGBA')
        stage=Image.new('RGBA',(256,176),'#2f3231')
        stage.alpha_composite(frame,(66-meta['anchor'][0],108-meta['anchor'][1]))
        tile=stage.crop((14,46,234,142)).resize((440,192),Image.Resampling.NEAREST)
        sheet.alpha_composite(tile,(col*440,row*216+20))
        label(sheet,(col*440+4,row*216+3),family+' / '+str(n))
sheet.save(OUT/'contact_sheet_fx_families.png')
print('Detail proofs ready: decoded before/after GIF times at4x;18 FX family rows at2x.')
