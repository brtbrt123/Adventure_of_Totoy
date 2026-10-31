"""Package actual renderer captures for owner review; no fabricated gameplay frames."""
from pathlib import Path
from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent


def main():
    frames = []
    for p in sorted(HERE.glob('loop_*.png')):
        im = Image.open(p).convert('RGB').resize((384,216),Image.Resampling.NEAREST)
        frames.append(im.resize((1152,648),Image.Resampling.NEAREST))
    frames[0].save(HERE/'cleave_parry_exposed.gif',save_all=True,append_images=frames[1:],duration=50,loop=0,disposal=2)
    names = ['warden_cleave_windup','warden_cleave_strike','warden_lash_windup','warden_lash_strike',
             'warden_ring_windup','warden_ring_strike','guard_hit','exposed','death_12','death_38','right_windup','right_strike']
    sheet = Image.new('RGB',(768,240*((len(names)+1)//2)),(28,24,36))
    draw = ImageDraw.Draw(sheet)
    for i,name in enumerate(names):
        image = Image.open(HERE/(name+'.png')).convert('RGB').resize((384,216),Image.Resampling.NEAREST)
        x,y = i%2*384,i//2*240
        draw.text((x+4,y+4),name,fill=(244,236,214))
        sheet.paste(image,(x,y+24))
    sheet.save(HERE/'contact_sheet_runtime.png')
    print(f'Packaged {len(frames)} real-renderer frames, 50ms per 3 core ticks; {len(names)} labelled captures')


if __name__=='__main__':
    main()
