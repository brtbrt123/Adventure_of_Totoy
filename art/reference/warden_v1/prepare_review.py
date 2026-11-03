"""Review-only palette/alpha/size normalization. Never installs or builds game assets."""
from pathlib import Path
import argparse
import hashlib
import json
from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
DEFAULT_SOURCE = Path('C:/Users/Admin/.codex/generated_images/01a18724-62d3-7302-bf71-18d4fa3ef8c6/exec-cc985b2e-45f2-43af-911a-934913648ba4.png')
ANCHOR = (20, 44)
PALETTE = json.loads((ROOT / 'art/palette.json').read_text())
C = {p['symbol']: tuple(bytes.fromhex(p['hex'].lstrip('#'))) + (255,) for p in PALETTE['colors']}
BODY_COLORS = {k: v for k, v in C.items() if k in '02345689abcdefghijtuop'}
FRAMES = [
    ('idle', 'IDLE', (40,170,410,540), (185,529)),
    ('rune_cleave', 'RUNE CLEAVE', (420,45,715,540), (568,529)),
    ('root_lash', 'ROOT LASH', (760,170,1195,540), (907,529)),
    ('spore_ring', 'SPORE RING', (1190,200,1536,540), (1339,529)),
    ('guarded', 'GUARDED / RUNE LIT', (40,570,410,970), (183,953)),
    ('exposed', 'EXPOSED / RUNE DARK', (430,590,785,970), (570,953)),
    ('defeat', 'DEFEAT', (790,675,1220,970), (924,953)),
]

def label(canvas, at, value, color='1', scale=2):
    font = ImageFont.load_default()
    # Monochrome FreeType hinting may round advances differently from getbbox().
    im = Image.new('RGBA', (len(value) * 12 + 4, 16))
    d = ImageDraw.Draw(im)
    d.fontmode = '1'
    d.text((0, 0), value, font=font, fill=C[color])
    canvas.alpha_composite(im.resize((im.width * scale, im.height * scale), Image.Resampling.NEAREST), at)

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, default=DEFAULT_SOURCE)
    args = parser.parse_args()
    raw = Image.open(args.source).convert('RGBA')
    assert raw.size == (1536,1024)
    folder = HERE / 'frames'
    folder.mkdir(exist_ok=True)
    report = {'status': 'PASS', 'review_only': True, 'cell': [48,48], 'feet_anchor': list(ANCHOR),
              'source_sha256': hashlib.sha256(args.source.read_bytes()).hexdigest(), 'frames': {}}
    sprites = []
    for name, _, rect, feet in FRAMES:
        src = Image.new('RGBA', raw.size)
        src.paste(raw.crop(rect), rect[:2])
        # Fixed scale across every pose, not separate pose-fitting that would shrink the Cleave.
        native = src.transform((48,48), Image.Transform.AFFINE,
            (11, 0, feet[0] - ANCHOR[0]*11, 0, 11, feet[1] - ANCHOR[1]*11),
            Image.Resampling.NEAREST)
        result = Image.new('RGBA', native.size)
        used = set()
        colors = {k:v for k,v in BODY_COLORS.items() if name not in ('exposed','defeat') or k not in 'uop'}
        for y in range(48):
            for x in range(48):
                p = native.getpixel((x,y))
                if p[3] < 128:
                    continue
                symbol = min(colors, key=lambda k: sum((p[i] - colors[k][i])**2 for i in range(3)))
                result.putpixel((x,y), colors[symbol])
                used.add(symbol)
        assert used.isdisjoint(PALETTE['reserved'])
        if name in ('exposed','defeat'):
            assert used.isdisjoint('uop')
        assert all(p[3] in (0,255) and (not p[3] or p in BODY_COLORS.values()) for p in result.get_flattened_data())
        bounds = result.getbbox()
        assert bounds and bounds[0] > 0 and bounds[1] > 0 and bounds[2] < 48 and bounds[3] < 48, (name,bounds)
        result.save(folder / (name + '.png'))
        sprites.append(result)
        report['frames'][name] = {'bbox': bounds, 'palette_symbols': sorted(used), 'alpha': '0 or 255'}
    sheet = Image.new('RGBA', (1536,992), C['0'])
    label(sheet, (24,10), 'RUNEBOUND WARDEN / DESIGN REVIEW / 8x NEAREST', scale=3)
    label(sheet, (24,47), '48x48 CELLS / RIGHT-FACING / FEET (20,44) / NOT IMPORTED', color='i')
    for i, ((name, title, _, _), im) in enumerate(zip(FRAMES,sprites)):
        x, y = i % 4 * 384, 88 + i // 4 * 432
        for yy in range(0,384,64):
            for xx in range(0,384,64):
                ImageDraw.Draw(sheet).rectangle((x+xx,y+yy,x+xx+63,y+yy+63),fill=C['e'] if (xx//64+yy//64)%2 else C['f'])
        sheet.alpha_composite(im.resize((384,384),Image.Resampling.NEAREST),(x,y))
        label(sheet,(x+14,y+390),title,scale=2)
    label(sheet,(1180,548),'ONE-FRAME GUARD CUE',color='u')
    label(sheet,(1180,584),'LIT: INTACT TEAL RUNE',color='i')
    label(sheet,(1180,616),'DARK: CRACKED INSET',color='i')
    label(sheet,(1180,668),'NATIVE 1x / GUARDED + EXPOSED',color='i',scale=1)
    sheet.alpha_composite(sprites[4],(1200,710))
    sheet.alpha_composite(sprites[5],(1296,710))
    label(sheet,(1180,800),'LOOK APPROVAL FIRST',color='u')
    label(sheet,(1180,836),'NO RUNTIME CHANGES',color='i')
    label(sheet,(24,963),'BARK + MOSS / STONE CHEST / TEAL RUNE / NO GOLD OR RED',color='i')
    sheet.save(HERE/'contact_sheet_8x.png')
    assert all(p[3]==255 and p in C.values() for p in sheet.get_flattened_data())
    baseline = json.loads((HERE/'runtime_baseline.json').read_text())
    assert all(hashlib.sha256((ROOT/p).read_bytes()).hexdigest()==digest for p,digest in baseline.items())
    report['runtime_files_unchanged'] = list(baseline)
    (HERE/'validation.json').write_text(json.dumps(report,indent=2))
    print('PASS: 7 cells,48x48,unclipped,Totoy36,no reserved colours,hard alpha,runtime hashes unchanged')

if __name__ == '__main__':
    main()
