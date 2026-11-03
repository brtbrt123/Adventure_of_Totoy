"""Compose actual game-renderer captures at 4x native pixel scale."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).resolve().parent;RAW=ROOT/'art/build/arena_mob_idle_motion'
font=ImageFont.truetype(str(ROOT/'presentation/fonts/Cinzel.ttf'),18)
frames=[]
for n in range(72):
 canvas=Image.new('RGB',(640,288),(28,24,36));d=ImageDraw.Draw(canvas)
 for col,mob in enumerate(['mossling','boar']):
  pic=Image.open(RAW/f'arena_{mob}_{n:03}.png').convert('RGB').resize((80,64),Image.Resampling.NEAREST).resize((320,256),Image.Resampling.NEAREST)
  canvas.paste(pic,(col*320,32));d.text((col*320+8,5),'Mossling / live game' if col==0 else 'Boar / live game',font=font,fill=(244,236,214))
 frames.append(canvas)
samples=Image.new('RGB',(640,288*3))
for row,index in enumerate([0,12,24]):samples.paste(frames[index],(0,row*288))
pal=samples.quantize(colors=256);indexed=[im.quantize(palette=pal,dither=Image.Dither.NONE) for im in frames]
indexed[0].save(HERE/'ingame_idle.gif',save_all=True,append_images=indexed[1:],duration=100,loop=0,disposal=2,optimize=True)
contact=Image.new('RGB',(640,288*3))
for row,index in enumerate([0,4,8]):contact.paste(frames[index],(0,row*288))
contact.save(HERE/'ingame_contact.png')
print('Live renderer GIF: 72 frames at100 ms, 7.2 s, 4x native pixels')
