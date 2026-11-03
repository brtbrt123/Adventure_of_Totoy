"""Review only: discrete blade-tip positions; straight connectors are guides, not measured in-between motion."""
from pathlib import Path
import json
from PIL import Image, ImageDraw, ImageFont
import build_review as B
OUT=B.OUT/'attack_trace'
OUT.mkdir(exist_ok=True)
FONT=ImageFont.truetype(str(B.ROOT/'presentation/fonts/Cinzel.ttf'),16)
COLORS=[(255,210,80),(255,110,210)] # diagnostic markers only, never runtime art
records={}
for weapon,cfg in B.WEAPONS.items():
 frames=[]; rows=[]; records[weapon]=[]
 for swing in range(1,cfg['swings']+1):
  geo=[B.geometry(weapon,swing,n) for n in range(1,7)]
  records[weapon].append(geo)
  for n in range(1,7):
   pose=B.sprite(f'{cfg["prefix"]}_attack{swing}_right_{n}')
   trace=Image.new('RGBA',B.SIZE); d=ImageDraw.Draw(trace)
   for hand in range(len(geo[n-1])):
    points=[tuple(round(g[hand]['tip'][k]+B.ANCHOR[k]) for k in (0,1)) for g in geo[:n]]
    color=COLORS[hand%2]
    if len(points)>1:d.line(points,fill=color,width=1)
    for point in points:d.rectangle((point[0]-1,point[1]-1,point[0]+1,point[1]+1),outline=color)
   effect=Image.new('RGBA',B.SIZE)
   fp=B.OUT/'frames'/weapon/f'path_swing{swing}_{n}.png'
   if fp.exists():effect=Image.open(fp).convert('RGBA')
   panel=Image.new('RGB',(1152,344),(26,24,32)); pd=ImageDraw.Draw(panel)
   labels=['Pose only','Tip positions / straight guides','Existing effect + tip trace']
   for col,label in enumerate(labels):
    base=Image.new('RGBA',B.SIZE,(37,43,32,255))
    if col==2:base.alpha_composite(effect)
    base.alpha_composite(pose)
    if col:base.alpha_composite(trace)
    panel.paste(base.resize((384,288),Image.Resampling.NEAREST),(col*384,56))
    pd.text((col*384+8,31),label,font=FONT,fill='white')
   pd.text((8,5),f'{cfg["name"]} | attack {swing} | pose {n}/6 | yellow/pink = separate blade tips',font=FONT,fill='white')
   frames.append(panel)
   if n in (3,4):rows.append(panel)
  frames.extend([frames[-1]]*2)
 frames[0].save(OUT/f'{weapon}_trace.gif',save_all=True,append_images=frames[1:],duration=220,loop=0,disposal=2)
 sheet=Image.new('RGB',(1152,344*len(rows)))
 for i,row in enumerate(rows):sheet.paste(row,(0,344*i))
 sheet.save(OUT/f'{weapon}_active_trace.png')
(OUT/'measured_tips.json').write_text(json.dumps(records,indent=2))
(OUT/'README.md').write_text('Review diagnostic only. Left: unchanged attack poses. Middle: blade-tip positions taken from source pose geometry. Right: existing FX overlaid with those markers. Yellow and pink distinguish weapons/hands. Straight connectors show pose order ONLY: the six source frames cannot prove an interpolated sweep direction. No glow hides alignment. Pose 1-2 windup, 3-4 active, 5-6 recovery: lingering FX intentionally remain at the strike location. Diagnostic colours are not game assets. Rebuild: python art/reference/weapon_paths_review_v1/trace_review.py\n')
print('Saved three trace GIFs and active contact sheets; runtime unchanged')
