"""Report native strike-pixel luminance contrast on the unchanged busy ground.

This is an objective diagnostic, not a claim of perceived combat readability.
"""
from pathlib import Path
import json
from PIL import Image

ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).resolve().parent
OLD=ROOT/'art/reference/warden_fx_astra_v2'
NEW=ROOT/'art/reference/warden_fx_astra_v3'
GROUND=Image.open(ROOT/'presentation/forest/root_hollow_layered_ground.png').convert('RGBA').crop((120,70,376,246))

def luma(p):
    return .2126*p[0]+.7152*p[1]+.0722*p[2]

def measure(folder,family):
    m=json.loads((folder/'manifest.json').read_text())
    records=[]
    for path in sorted((folder/'fx'/family).glob('*.png')):
        im=Image.open(path).convert('RGBA');ax,ay=m['fx_assets'][path.stem]['anchor']
        bright=0;strong=0;visible=0;peak=0
        for y in range(im.height):
            for x in range(im.width):
                p=im.getpixel((x,y))
                xx,yy=66-ax+x,108-ay+y
                if not p[3] or not(0<=xx<256 and 0<=yy<176):continue
                delta=luma(p)-luma(GROUND.getpixel((xx,yy)))
                visible+=1
                bright+=int(delta>=70)
                strong+=int(abs(delta)>=70)
                peak=max(peak,abs(delta))
        records.append({'frame':path.name,'opaque_pixels':visible,'bright_pixels_delta_luma_ge70':bright,
                        'strong_contrast_pixels_abs_delta_luma_ge70':strong,'peak_abs_delta_luma':round(peak,1)})
    return {'frames':records,'mean_bright_pixels':round(sum(x['bright_pixels_delta_luma_ge70'] for x in records)/len(records),1),
            'mean_strong_contrast_pixels':round(sum(x['strong_contrast_pixels_abs_delta_luma_ge70'] for x in records)/len(records),1)}

if __name__=='__main__':
    report={'diagnostic_only':True,'comparison':'Astra v2 versus readability revision v3','families':{}}
    for family in ('cleave_arc','lash_strike','ring_burst'):
        old,new=measure(OLD,family),measure(NEW,family)
        report['families'][family]={'v2':old,'v3':new}
        print(family,'mean bright native pixels:',old['mean_bright_pixels'],'->',new['mean_bright_pixels'],
              '/ mean strong contrast:',old['mean_strong_contrast_pixels'],'->',new['mean_strong_contrast_pixels'])
    (HERE/'contrast_v3.json').write_text(json.dumps(report,indent=2))
