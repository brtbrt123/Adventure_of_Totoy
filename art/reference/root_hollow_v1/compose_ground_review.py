from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).resolve().parent
font=ImageFont.truetype(str(ROOT/'presentation/fonts/Cinzel.ttf'),24)
canvas=Image.new('RGB',(1920,408),(28,24,36));d=ImageDraw.Draw(canvas)
for col,name in enumerate(['woodland','forest','central']):
 image=Image.open(HERE/f'gameplay_{name}_4x.png').convert('RGB').resize((640,360),Image.Resampling.NEAREST)
 canvas.paste(image,(col*640,48))
 d.text((col*640+12,10),{'central':'Root Hollow - proposal'}.get(name,name.title()),font=font,fill=(244,236,214))
canvas.save(HERE/'ground_renderer_comparison.png')
