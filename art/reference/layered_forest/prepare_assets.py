"""Reproducible forest import. Run from the repository root; never edits shared data."""
from pathlib import Path
import hashlib
import json
import math
import shutil
import sys

from PIL import Image, ImageDraw, ImageEnhance

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'tools/art'))
import make_village_ground_from_reference as ground

HERE = Path(__file__).resolve().parent
PALETTE = ground.palette
SYMBOLS = {rgb: symbol for symbol, rgb in PALETTE.by_symbol.items()}


def write_grid(name, image, anchor):
    rows = []
    for y in range(image.height):
        rows.append(''.join(SYMBOLS[image.getpixel((x, y))[:3]] if image.getpixel((x, y))[3] else '.' for x in range(image.width)))
    (ROOT / 'art/src' / (name + '.txt')).write_text(
        '# kind: sprite\n# anchor: %d,%d\n# Forest import; base preserved, no bottom padding.\n' % tuple(anchor)
        + '\n'.join(rows) + '\n', encoding='utf-8')


def runs(points):
    result = []
    for y in sorted({y for x, y in points}):
        xs = sorted(x for x, py in points if py == y)
        if not xs:
            continue
        start = previous = xs[0]
        for x in xs[1:] + [xs[-1] + 2]:
            if x != previous + 1:
                result.append([start, y, previous - start + 1])
                start = x
            previous = x
    return result


def contact(image):
    core = set()
    for x in range(image.width):
        ys = [y for y in range(image.height - 18, image.height) if y >= 0 and image.getpixel((x, y))[3]]
        if ys:
            bottom = max(ys)
            core.update((x, bottom + d) for d in (0, 1))
    edge = {(x + dx, y + dy) for x, y in core for dx, dy in [(-1, 0), (1, 0), (0, 1)]} - core
    return {'size': list(image.size), 'core': runs(core), 'edge': runs(edge)}


def cast(image, anchor, flipped, name):
    # Project actual opaque pixel quadrilaterals onto a common ground plane.
    polygons = []
    ax, ay = anchor
    for y in range(image.height):
        for x in range(image.width):
            if not image.getpixel((x, y))[3]:
                continue
            points = []
            for dx, dy in [(0, 0), (1, 0), (1, 1), (0, 1)]:
                height = max(0, ay - (y + dy))
                sx = image.width - x - dx - (image.width - ax) if flipped else x + dx - ax
                points.append((sx + height * .30, height * .25))
            polygons.append(points)
    x0 = math.floor(min(x for poly in polygons for x, y in poly))
    x1 = math.ceil(max(x for poly in polygons for x, y in poly))
    y1 = math.ceil(max(y for poly in polygons for x, y in poly))
    guard = 4
    width = math.ceil((x1 - x0 + guard * 2 + 1) / 8) * 8
    height = math.ceil((y1 + guard * 2 + 1) / 8) * 8
    mask = Image.new('RGBA', (width, height))
    draw = ImageDraw.Draw(mask)
    for poly in polygons:
        draw.polygon([(round(x - x0 + guard), round(y + guard)) for x, y in poly], fill=(*PALETTE.by_symbol['0'], 255))
    shadow_anchor = [guard - x0, guard]
    write_grid(name, mask, shadow_anchor)
    bbox = mask.getbbox()
    return {'sprite': name, 'size': [width, height], 'anchor': shadow_anchor,
            'bounds_relative_to_feet': [bbox[0] - shadow_anchor[0], bbox[1] - guard, bbox[2] - shadow_anchor[0], bbox[3] - guard],
            'blur_padding': guard}


def main():
    if '--skip-ground' not in sys.argv:
        source = Image.open(HERE / 'forest_ground_only.png').convert('RGB').resize((480, 288), Image.Resampling.LANCZOS)
        source = ImageEnhance.Brightness(source).enhance(1.08)
        source = ImageEnhance.Contrast(source).enhance(1.05)
        source = ImageEnhance.Color(source).enhance(.95)
        ground.to_image(ground.cleanup(ground.snap_image(source))).save(ROOT / 'presentation/forest/forest_layered_ground.png')
    defs = json.loads((ROOT / 'data/props/prop_defs.json').read_text())['props']
    art_path = ROOT / 'presentation/common/prop_art.json'
    art = json.loads(art_path.read_text())
    shadows_path = ROOT / 'art/reference/shadow_layers/manifest.json'
    shadows = json.loads(shadows_path.read_text())
    imported = {'version': 1, 'props': {}}
    (HERE / 'props').mkdir(exist_ok=True)
    for name, definition in defs.items():
        if not name.startswith('forest_'):
            continue
        source = ROOT / 'data/props/cutouts_forest' / definition['image']
        target = HERE / 'props' / definition['image']
        shutil.copyfile(source, target)
        image = Image.open(target).convert('RGBA')
        assert image.size == (definition['w'], definition['h'])
        assert all(a in (0, 255) and (not a or SYMBOLS[(r, g, b)] not in PALETTE.reserved) for r, g, b, a in image.getdata())
        width, height = math.ceil(image.width / 8) * 8, math.ceil(image.height / 8) * 8
        top = height - image.height
        anchor = [math.floor(definition['anchor'][0] + .5), int(definition['anchor'][1]) + top]
        padded = Image.new('RGBA', (width, height))
        padded.paste(image, (0, top))
        write_grid(name, padded, anchor)
        imported['props'][name] = {'source_size': list(image.size), 'padded_size': [width, height],
                                  'padding': [0, top, width - image.width, 0], 'shared_anchor': definition['anchor'], 'header_anchor': anchor}
        metadata = {'trim': [0, top, image.width, image.height], 'contact_shadow': contact(image), 'cast_shadow': {}}
        shadow_entry = {'object': name, 'object_source': target.relative_to(ROOT).as_posix(), 'object_size': list(image.size),
                        'object_anchor': definition['anchor'], 'object_rgba_sha256': hashlib.sha256(image.tobytes()).hexdigest(), 'shadows': {}}
        for flipped, orientation in [(False, 'normal'), (True, 'flipped')]:
            shadow_name = 'fx_shadow_' + name + ('_flipped' if flipped else '') + '_1'
            metadata['cast_shadow'][orientation] = shadow_name
            shadow_entry['shadows'][orientation] = cast(image, definition['anchor'], flipped, shadow_name)
        if name.startswith('forest_log_'):
            metadata['sort_strips'] = []
            for x in range(0, image.width, 4):
                width = min(4, image.width - x)
                ys = [y for y in range(image.height) for px in range(x, x + width) if image.getpixel((px, y))[3]]
                if ys:
                    metadata['sort_strips'].append([x, width, max(ys) + 1])
        art['props'][name] = metadata
        shadows['props'][name] = shadow_entry
        print(name, imported['props'][name]['padded_size'], anchor)
    for path, data in [(art_path, art), (shadows_path, shadows), (HERE / 'import_manifest.json', imported)]:
        path.write_text(json.dumps(data, indent=2) + '\n', encoding='utf-8')


if __name__ == '__main__':
    main()
