from pathlib import Path
import sys
from PIL import Image
ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(ROOT/'tools/art'))
import make_arena_ground_from_reference as ground
HERE=Path(__file__).resolve().parent
ground.W,ground.H=640,400
im=Image.open(HERE/'ground_raw.png').convert('RGB').resize((640,400),Image.Resampling.LANCZOS)
result=ground.to_image(ground.cleanup(ground.snap_image(im)))
result.save(ROOT/'presentation/forest/root_hollow_layered_ground.png')
result.resize((1280,800),Image.Resampling.NEAREST).save(HERE/'ground_full_2x.png')
print('Root Hollow ground imported: 640x400, non-reserved Totoy36')
