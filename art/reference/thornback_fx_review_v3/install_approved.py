"""Import approved native review layers into the standard text-grid art pipeline."""
from pathlib import Path
import importlib.util
import json
import sys
from PIL import Image

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
V1 = HERE.parent / 'glowmoth_stag_animation_review_v1'
V2 = HERE.parent / 'thornback_fx_review_v2'
COLORS = json.loads((ROOT / 'art/palette.json').read_text())['colors']
SYMBOLS = {tuple(bytes.fromhex(c['hex'].lstrip('#'))) + (255,): c['symbol'] for c in COLORS}
WRITTEN = []

def install(path, name, anchor):
    im = Image.open(path).convert('RGBA') if isinstance(path, Path) else path
    original, original_anchor = im.copy(), anchor
    if name.startswith(('fx_stag_horn_', 'fx_stag_chant_', 'fx_stag_summon_')):
        bounds = im.getbbox()
        if bounds:
            x, y, right, bottom = bounds
            x, y = min(x, anchor[0]), min(y, anchor[1])
            right, bottom = max(right, anchor[0]), max(bottom, anchor[1])
            width, height = (right - x + 7) // 8 * 8, (bottom - y + 7) // 8 * 8
            im = im.crop((x, y, x + width, y + height))
            anchor = (anchor[0] - x, anchor[1] - y)
    reconstructed = Image.new('RGBA', original.size)
    reconstructed.alpha_composite(im, (original_anchor[0] - anchor[0], original_anchor[1] - anchor[1]))
    assert reconstructed.tobytes() == original.tobytes(), f'Changed visible pixels/anchor: {name}'
    assert im.width % 8 == im.height % 8 == 0
    rows = []
    for y in range(im.height):
        row = ''
        for x in range(im.width):
            p = im.getpixel((x, y))
            assert p[3] in (0, 255)
            row += '.' if not p[3] else SYMBOLS[p]
        rows.append(row)
    target = ROOT / 'art/src' / (name + '.txt')
    target.write_text(f'# kind: sprite\n# anchor: {anchor[0]},{anchor[1]}\n' + '\n'.join(rows) + '\n')
    WRITTEN.append(name)

def main():
    meta = json.loads((V1 / 'manifest.json').read_text())
    for folder in (V1 / 'frames').iterdir():
        if folder.name.startswith('glowmoth_') or folder.name in ('stag_idle', 'stag_move'):
            for p in folder.glob('*.png'):
                name = p.stem.replace('stag_idle_', 'stag_breathe_').replace('stag_move_', 'stag_amble_')
                install(p, name, meta['sources'][folder.name]['anchor'])
    for folder in (V1 / 'effects').iterdir():
        if folder.is_dir():
            for p in folder.glob('*.png'):
                install(p, p.stem, meta['fx_anchors'][folder.name])
    # Register all existing attack horns to their exact body pose, including asymmetric anchors.
    spec = importlib.util.spec_from_file_location('astra_layers', V2 / 'build_attacks_astra.py')
    a = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(a)
    for p in (V2 / 'attacks_astra/bodies').glob('*.png'):
        body = Image.open(p).convert('RGBA')
        mask_im = Image.open(V2 / 'attacks_astra/horn_masks' / p.name).convert('RGBA')
        mask = {(x, y) for y in range(mask_im.height) for x in range(mask_im.width) if mask_im.getpixel((x, y))[3]}
        for phase, tick in enumerate((0, 5, 10, 15), 1):
            install(a.horn_glow(body, mask, tick, 1), 'fx_stag_horn_' + p.stem.removesuffix('_right') + '_' + str(phase), (36, 62))
    for state, indices in [('chant', range(12, 68, 2)), ('summon', range(68, 88, 2))]:
        for n, i in enumerate(indices, 1):
            install(V2 / f'summon/body_frames/stag_chant_right_{i+1:03}.png', f'stag_{state}_right_{n}', (36, 62))
            install(V2 / f'summon/antler_fx/antlers_{i+1:03}.png', f'fx_stag_{state}_{n}', (52, 78))
    (HERE / 'installed_assets.json').write_text(json.dumps({'owner_approved_wiring': True,
        'native_pixel_and_anchor_parity': 'PASS', 'sprites': WRITTEN}, indent=2))
    print(f'Installed {len(WRITTEN)} native approved layers; no core/data changes.')

if __name__ == '__main__':
    main()
