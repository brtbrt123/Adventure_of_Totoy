"""Village wall and fence: the cut-outs of art/reference/village_wall_fence_v1 (an image generation approved by the owner
2026-11-03, cut by tools/art/extract_props.py) become text-grid sprites in art/src and entries in presentation/common/prop_art.json.

    python tools/art/extract_props.py --sheet art/reference/village_wall_fence_v1/concept_2_front.png \
        --names village_fence,village_wall --world-width 209 --merge --out art/reference/village_wall_fence_v1/props
    python tools/art/make_village_walls.py        # then: validate_art, build_art, tools/godot/generate_prop_scenes.py

Same rules as the other village props (art/reference/layered_village/INTEGRATION.md): padding on the top and right up to a
multiple of 8, none at the bottom, the header anchor is the rounded shared anchor plus the top padding, and prop_art.json
trims the padding off again. Also writes each prop's contact shadow plan, its two cast-shadow sprites and its shadow manifest entry.
"""
from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
import artlib  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
CUTS = ROOT / "art" / "reference" / "village_wall_fence_v1" / "props"
DEFS = ROOT / "data" / "props" / "prop_defs.json"
ART = ROOT / "presentation" / "common" / "prop_art.json"
SHADOW = ROOT / "art" / "reference" / "shadow_layers" / "manifest.json"
TYPES = ["village_wall", "village_fence"]
INK = (28, 24, 36)  # the cast-shadow colour every fx_shadow_* uses
PAD = 4  # blur padding around the projected shadow
DX, DY = 0.3, 0.25  # the manifest's projection: moonlight from the upper left, per pixel of height


def contact_shadow(w: int, h: int) -> dict:
    """The soft ellipse the renderer draws under a prop: a core and a one pixel edge, in the prop's own pixels (size w x h)."""
    cx, rx, ry, base = w / 2.0, w * 0.47, 5.0, h - 1.0
    core: set[tuple[int, int]] = set()
    for y in range(int(base - ry), int(base + 2)):
        t = (y - base) / ry
        if abs(t) > 1.0:
            continue
        half = rx * (1.0 - t * t) ** 0.5
        for x in range(int(round(cx - half)), int(round(cx + half)) + 1):
            core.add((x, y))
    edge = {(x + dx, y + dy) for x, y in core for dx, dy in ((1, 0), (-1, 0), (0, 1)) if (x + dx, y + dy) not in core}
    runs = lambda cells: [[x0, y, n] for y, x0, n in _runs(cells)]  # noqa: E731
    return {"core": runs(core), "edge": runs(edge), "size": [w, h]}


def _runs(cells: set[tuple[int, int]]) -> list[tuple[int, int, int]]:
    out = []
    for y in sorted({c[1] for c in cells}):
        xs = sorted(c[0] for c in cells if c[1] == y)
        start = prev = xs[0]
        for x in xs[1:] + [None]:
            if x is None or x != prev + 1:
                out.append((y, start, prev - start + 1))
                start = x
            prev = x if x is not None else prev
    return out


def cast_shadow(img: Image.Image, anchor: tuple[float, float], flipped: bool) -> tuple[Image.Image, list[int], list[int]]:
    """The silhouette projected onto the ground (filled quadrilaterals per pixel), relative to the feet."""
    if flipped:
        img = img.transpose(Image.FLIP_LEFT_RIGHT)
        anchor = (img.width - anchor[0], anchor[1])
    w, h = img.size
    quads = []
    for y in range(h):
        for x in range(w):
            if img.getpixel((x, y))[3] < 128:
                continue
            pts = []
            for cx, cy in ((x, y), (x + 1, y), (x + 1, y + 1), (x, y + 1)):
                height = anchor[1] - cy
                pts.append((cx - anchor[0] + DX * height, DY * height))
            quads.append(pts)
    xs = [p[0] for q in quads for p in q]
    ys = [p[1] for q in quads for p in q]
    x0, x1 = int(min(xs) // 1), int(-(-max(xs) // 1))
    y0, y1 = 0, int(-(-max(ys) // 1))
    size = (pad8(x1 - x0 + 2 * PAD), pad8(y1 - y0 + 2 * PAD))
    ox, oy = PAD - x0, PAD - y0  # the feet inside the shadow sprite
    canvas = Image.new("L", size, 0)
    draw = ImageDraw.Draw(canvas)
    for q in quads:
        draw.polygon([(px + ox, py + oy) for px, py in q], fill=255)
    out = Image.new("RGBA", size, (0, 0, 0, 0))
    out.putdata([INK + (255,) if v >= 128 else (0, 0, 0, 0) for v in canvas.getdata()])
    return out, [ox, oy], [x0, y0, x1, y1]


def pad8(n: int) -> int:
    return (n + 7) // 8 * 8


def main() -> int:
    palette = artlib.load_palette()
    symbol_of = {rgb: sym for sym, rgb in palette.by_symbol.items()}
    defs = json.loads(DEFS.read_text(encoding="utf-8"))["props"]
    art = json.loads(ART.read_text(encoding="utf-8"))
    shadows = json.loads(SHADOW.read_text(encoding="utf-8"))
    for name in TYPES:
        img = Image.open(CUTS / f"{name}.png").convert("RGBA")
        w, h = img.size
        pw, ph = pad8(w), pad8(h)
        top = ph - h
        rows = []
        for y in range(ph):
            row = []
            for x in range(pw):
                if y < top or x >= w:
                    row.append(palette.transparent)
                    continue
                r, g, b, a = img.getpixel((x, y - top))
                row.append(palette.transparent if a < 128 else symbol_of[(r, g, b)])
            rows.append("".join(row))
        ax, ay = defs[name]["anchor"]
        header = [f"# kind: sprite", f"# anchor: {round(ax)},{round(ay) + top}",
                  "# Cut from art/reference/village_wall_fence_v1 by tools/art/make_village_walls.py (padding: top/right)"]
        (ROOT / "art" / "src" / f"{name}.txt").write_text("\n".join(header + rows) + "\n", encoding="utf-8")
        entry = {"trim": [0, top, w, h], "contact_shadow": contact_shadow(w, h), "cast_shadow": {}}
        manifest = {"object": name, "object_source": f"art/reference/village_wall_fence_v1/props/{name}.png",
                    "object_size": [w, h], "object_anchor": [ax, ay], "shadows": {}}
        for orientation in ("normal", "flipped"):
            image, feet, bounds = cast_shadow(img, (ax, ay), orientation == "flipped")
            sprite = f"fx_shadow_{name}_1" if orientation == "normal" else f"fx_shadow_{name}_flipped_1"
            grid = [f"# kind: sprite", f"# anchor: {feet[0]},{feet[1]}"]
            for y in range(image.height):
                grid.append("".join(symbol_of[INK] if image.getpixel((x, y))[3] else palette.transparent for x in range(image.width)))
            (ROOT / "art" / "src" / f"{sprite}.txt").write_text("\n".join(grid) + "\n", encoding="utf-8")
            entry["cast_shadow"][orientation] = sprite
            manifest["shadows"][orientation] = {"sprite": sprite, "size": list(image.size), "anchor": feet,
                                                "bounds_relative_to_feet": bounds, "blur_padding": PAD}
        manifest["object_rgba_sha256"] = hashlib.sha256(img.tobytes()).hexdigest()
        art["props"][name] = entry
        shadows["props"][name] = manifest
        print(f"{name}: {w}x{h} -> {pw}x{ph}, top pad {top}")
    ART.write_text(json.dumps(art, indent=2) + "\n", encoding="utf-8")
    SHADOW.write_text(json.dumps(shadows, indent=2) + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    sys.exit(main())
