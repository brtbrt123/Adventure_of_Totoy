"""Body-size proposal; preserve V4 sources and gameplay geometry."""
from pathlib import Path
import json
import hashlib
from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]
SOURCE = OUT.parent / 'warden_cleave_range_v4'


def main():
    manifest = json.loads((SOURCE / 'manifest.json').read_text())
    protected = {str(p): hashlib.sha256(p.read_bytes()).hexdigest()
                 for p in SOURCE.rglob('*') if p.is_file()}
    ground = Image.open(ROOT / 'presentation/forest/root_hollow_layered_ground.png').convert('RGBA').crop((80,40,464,256))
    frames = []
    idle = []
    for state, count in manifest['states'].items():
        for number in range(1, count + 1):
            source = Image.open(SOURCE / 'body' / state / f'warden_{state}_right_{number}.png').convert('RGBA')
            scaled = source.resize((120,120), Image.Resampling.NEAREST)
            assert set(scaled.getdata()) <= set(source.getdata())
            assert {c[3] for c in scaled.getdata()} <= {0,255}
            target = OUT / 'body' / state / f'warden_{state}_right_{number}.png'
            target.parent.mkdir(parents=True, exist_ok=True)
            scaled.save(target)
            scene = ground.copy()
            draw = ImageDraw.Draw(scene)
            draw.ellipse((66,157,90,163), fill='#222034')
            draw.ellipse((224,154,280,166), fill='#222034')
            scene.alpha_composite(source, (78-20,160-44))
            scene.alpha_composite(scaled, (252-50,160-110))
            draw.rectangle((0,0,383,28), fill='#161923')
            draw.text((8,4), 'CURRENT 1x                 PROPOSED 2.5x', fill='white')
            draw.text((8,17), f'{state.upper()} {number}/{count} | BODY SIZE REVIEW', fill='white')
            frames.extend([scene.resize((1152,648),Image.Resampling.NEAREST)] * 2)
            if state in ('idle','walk'):
                idle.extend([frames[-1]] * 2)
            if state == 'idle' and number == 1:
                frames[-1].save(OUT / 'contact_sheet_size_comparison.png')
    for name, clip in [('all_body_animations',frames),('idle_walk',idle)]:
        clip[0].save(OUT / f'{name}.gif', save_all=True, append_images=clip[1:], duration=100, loop=0, disposal=2)
    assert all(hashlib.sha256(Path(p).read_bytes()).hexdigest()==h for p,h in protected.items())
    (OUT / 'manifest.json').write_text(json.dumps({
        'review_only':True,'source':'warden_cleave_range_v4','scale':2.5,
        'body_cell':[120,120],'body_anchor':[50,110],'body_frames':60,
        'states':manifest['states'],'resampling':'nearest',
        'runtime_installed':False,'attack_ranges_changed':False,
        'limitations':'Body-only comparison. Weapon-attached FX need re-registration before integration; ground damage geometry stays core-owned.'
    },indent=2))
    print('PASS: 60 bodies at 120x120, anchor50,110; palette/alpha preserved; V4 unchanged.')


if __name__ == '__main__':
    main()
