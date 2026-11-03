"""Install owner-requested enlarged bodies and V4 compact FX, without tooling edits."""
from pathlib import Path
import json
from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
V4 = HERE.parent / 'warden_cleave_range_v4'
GEOMETRY_FAMILIES = {'cleave_range','lash_creep','lash_strike','lash_splinters','ring_burst','ring_afterglow','scorch'}


def main():
    palette = json.loads((ROOT / 'art/palette.json').read_text())
    symbols = {tuple(bytes.fromhex(c['hex'][1:])): c['symbol'] for c in palette['colors']}
    manifest = json.loads((V4 / 'manifest.json').read_text())
    attachments = {}
    rgb = {c['symbol']:tuple(bytes.fromhex(c['hex'][1:])) for c in palette['colors']}
    for p in sorted((V4 / 'body').rglob('*.png')):
        im = Image.open(p).convert('RGBA')
        rune = [(x,y) for y in range(18,36) for x in range(17,32)
                if im.getpixel((x,y))[:3] in {rgb[c] for c in 'tuop'} and im.getpixel((x,y))[3]]
        chest = [sum(q[0] for q in rune)/len(rune)-20,sum(q[1] for q in rune)/len(rune)-44] if rune else [5,-18]
        points = [(x,y) for y in range(8,48) for x in range(28,48) if im.getpixel((x,y))[3]]
        tip = max(points,key=lambda q:q[0]) if points else (35,30)
        attachments[p.stem] = {'chest':chest,'hook':[tip[0]-20,tip[1]-44]}
    (ROOT / 'presentation/explore/warden_attachments.json').write_text(json.dumps(attachments,indent=2)+'\n')
    # Remove only this installer's superseded, unreferenced ground-family outputs.
    for family in GEOMETRY_FAMILIES:
        for n in range(1,manifest['fx_families'][family]+1):
            key = f'fx_warden_{family}_{n}'
            for target in [ROOT/'art/src'/(key+'.txt'), ROOT/'art/build/sprites'/(key+'.png'), ROOT/'art/build/sprites'/(key+'.png.import')]:
                assert target.resolve().is_relative_to(ROOT.resolve())
                target.unlink(missing_ok=True)
    paths = [(p, (50,110)) for p in sorted((HERE / 'body').rglob('*.png'))]
    for p in sorted((V4 / 'fx').rglob('*.png')):
        if p.parent.name in GEOMETRY_FAMILIES:
            # These ground layers are drawn from real snapshot geometry, not frozen review-sized PNGs.
            continue
        paths.append((p, manifest['fx_assets'][p.stem]['anchor']))
    for path, anchor in paths:
        im = Image.open(path).convert('RGBA')
        # Atlas is nearly full: trim transparent padding, preserving the exact feet registration.
        bounds = im.getbbox()
        if bounds:
            x, y, right, bottom = bounds
            x, y = min(x,anchor[0]), min(y,anchor[1])
            right, bottom = max(right,anchor[0]+1), max(bottom,anchor[1]+1)
            width, height = (right-x+7)//8*8, (bottom-y+7)//8*8
            im = im.crop((x,y,x+width,y+height))
            anchor = (anchor[0]-x, anchor[1]-y)
        rows = []
        for y in range(im.height):
            rows.append(''.join('.' if im.getpixel((x,y))[3] == 0 else symbols[im.getpixel((x,y))[:3]] for x in range(im.width)))
        target = ROOT / 'art/src' / (path.stem + '.txt')
        target.write_text(f'# kind: sprite\n# anchor: {anchor[0]},{anchor[1]}\n' + '\n'.join(rows) + '\n')
    print(f'Installed {len(paths)} Warden source grids')


if __name__ == '__main__':
    main()
