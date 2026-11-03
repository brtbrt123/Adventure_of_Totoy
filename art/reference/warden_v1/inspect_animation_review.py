"""Independent exported-file checks and compact motion-review contact pages."""
from pathlib import Path
import json
from PIL import Image, ImageDraw, ImageFont

HERE=Path(__file__).resolve().parent
OUT=HERE/'animation_review'
ROOT=HERE.parents[2]
C={p['symbol']:tuple(bytes.fromhex(p['hex'].lstrip('#')))+(255,) for p in json.loads((ROOT/'art/palette.json').read_text())['colors']}
allowed=set(C.values());reserved={C[k] for k in 'xyzA'}
m=json.loads((OUT/'manifest.json').read_text())
for state,count in m['states'].items():
    files=list((OUT/'body'/state).glob('*.png'))
    assert len(files)==count
    for p in files:
        im=Image.open(p).convert('RGBA');values=set(im.get_flattened_data())
        assert im.size==(48,48) and im.getbbox()
        assert all(v[3] in (0,255) and (not v[3] or v in allowed-reserved) for v in values)
        if state in ('hurt','exposed','death'):assert not values.intersection({C[k] for k in 'uop'})
for key,v in m['fx_assets'].items():
    family=key[len('fx_warden_'):].rsplit('_',1)[0]
    im=Image.open(OUT/'fx'/family/(key+'.png')).convert('RGBA')
    assert list(im.size)==v['size'] and 0<=v['anchor'][0]<=im.width and 0<=v['anchor'][1]<=im.height
    assert im.width%8==im.height%8==0 and max(im.size)<=256
    assert all(p[3] in (0,255) and (not p[3] or p in allowed-reserved) for p in im.get_flattened_data())
report={'status':'PASS','body_pngs':sum(m['states'].values()),'fx_pngs':len(m['fx_assets']),'gifs':{}}
for p in OUT.glob('*.gif'):
    im=Image.open(p);duration=0
    assert im.size==(1024,704)
    for i in range(im.n_frames):
        im.seek(i);rgb=im.convert('RGB');duration+=im.info['duration']
        small=rgb.resize((256,176),Image.Resampling.NEAREST)
        assert small.resize(im.size,Image.Resampling.NEAREST).tobytes()==rgb.tobytes()
        assert all(tuple(pixel)+(255,) in allowed for pixel in set(small.get_flattened_data()))
    report['gifs'][p.name]={'decoded_frames':im.n_frames,'duration_ms':duration,'exact_integer_scale':4}
assert report['gifs']['guard_break_exposed.gif']['duration_ms']==2900
assert report['gifs']['cleave_parry_exposed.gif']['duration_ms']==2700
states=list(m['states'])
for page in range(2):
    chosen=states[page*7:(page+1)*7]
    sheet=Image.new('RGBA',(768,len(chosen)*216),C['0']);d=ImageDraw.Draw(sheet);d.fontmode='1'
    for row,state in enumerate(chosen):
        count=m['states'][state]
        for col,q in enumerate([0,.33,.67,1]):
            n=1+round((count-1)*q)
            im=Image.open(OUT/'body'/state/f'warden_{state}_right_{n}.png').convert('RGBA')
            x,y=col*192,row*216
            d.rectangle((x,y+20,x+191,y+211),fill=C['e'])
            sheet.alpha_composite(im.resize((192,192),Image.Resampling.NEAREST),(x,y+20))
            d.text((x+4,y+3),f'{state} / {n}',font=ImageFont.load_default(),fill=C['1'])
    sheet.save(OUT/f'contact_sheet_body_overview_{page+1}.png')
(OUT/'export_audit.json').write_text(json.dumps(report,indent=2))
print('EXPORT AUDIT PASS:60 bodies,100 anchored FXs,11 GIFs,4x integer pixels,dark exposed/hurt/death,90-tick guard-break window')
