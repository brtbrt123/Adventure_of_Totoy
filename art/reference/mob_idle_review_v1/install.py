"""Install owner-approved idle frames without replacing the original alert/combat poses."""
from pathlib import Path
from PIL import Image
import json
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).resolve().parent
pal=json.loads((ROOT/'art/palette.json').read_text());lookup={tuple(bytes.fromhex(c['hex'][1:])):c['symbol'] for c in pal['colors'] if c['symbol'] not in pal['reserved']}
for mob,state,count in [('mossling','play_idle',24),('boar','graze_idle',36)]:
 for n in range(1,count+1):
  im=Image.open(HERE/'frames'/mob/f'{mob}_idle_{n:02}.png').convert('RGBA');assert im.size==(64,48)
  rows=[]
  for y in range(48):
   row=''
   for x in range(64):
    r,g,b,a=im.getpixel((x,y));assert a in (0,255);row+=lookup[(r,g,b)] if a else '.'
   rows.append(row)
  (ROOT/'art/src'/f'{mob}_{state}_right_{n}.txt').write_text('# kind: sprite\n# anchor: 32,40\n# Owner-approved idle loop; original combat and alert art preserved.\n'+'\n'.join(rows)+'\n')
print('Installed 60 native idle frames')
