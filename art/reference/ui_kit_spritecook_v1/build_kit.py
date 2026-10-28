"""Cut the SpriteCook component sheet into the Totoy 36 UI kit (review only).

Every part is cropped from raw/sheet_1.png by the rectangle SpriteCook's extraction returned
(raw/sheet_1_extraction.json) and resampled with to_palette.convert (hard alpha, Totoy 36 only,
no reserved gold/red). Frames are converted at a fine scale so their bronze stays about 3 px
thick and are 9-sliced to the size a screen needs (corners kept, edges tiled, never stretched).
Fixed objects (medallion, sockets, shield, icons) are converted at the size they are used at.
Four clean-ups, all mechanical: icons are cut from inside their framed tiles with the ink
backing cleared; the level pillar came pre-filled with violet, so its tube is emptied to ink
(the game draws the fill); the active socket's sample rune and the locked button's padlock are
cleared so any Aspect icon or label fits.
Output:
  kit/<name>.png    each part at 1x (game pixels), plus the slot states assembled at 24x24
  kit/kit.json      sizes, 9-slice borders and interiors in game pixels
  kit_sheet.png     every part at 4x on one sheet, for review

  python -P art/reference/ui_kit_spritecook_v1/build_kit.py
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))  # our own scripts only; downloads live in raw/
import to_palette as tp  # noqa: E402

ROOT = HERE.parents[2]
SHEET = HERE / "raw" / "sheet_1.png"
RECTS = {c["kit_name"]: c for c in json.loads((HERE / "raw" / "sheet_1_extraction.json").read_text())["components"]}
KIT = HERE / "kit"
INK = (0x1C, 0x18, 0x24, 255)
LILAC = (0x8A, 0x6F, 0xA8)

# name: (scale, 9-slice borders l,t,r,b in game pixels or None, source part, inner crop as fractions or None).
# scale is a float (source pixels per game pixel) or an exact (w, h) game size.
Scale = float | tuple[int, int]
PARTS: dict[str, tuple[Scale, tuple[int, int, int, int] | None, str, tuple[float, float, float, float] | None]] = {
    "panel_large_ornate":   (7.0, (30, 20, 30, 20), "panel_large_ornate", None),
    "panel_medium":         (6.0, (10, 10, 10, 10), "panel_medium", None),
    "panel_small":          (6.0, (10, 10, 10, 10), "panel_small", None),
    "slot_frame":           (6.0, (8, 8, 8, 8), "slot_empty", None),
    "slot_floor":           (6.0, None, "slot_normal", (0.25, 0.25, 0.75, 0.75)),
    "cooldown_sweep":       ((12, 12), None, "slot_cooldown", (0.2, 0.2, 0.8, 0.8)),
    "aspect_socket_active": (11.0, None, "aspect_socket_active", None),
    "aspect_socket_locked": (11.0, None, "aspect_socket_locked", None),
    "weapon_medallion":     ((40, 44), None, "weapon_medallion", None),
    "health_bar_frame":     (8.0, (14, 0, 13, 0), "health_bar_frame", None),
    "fill_health":          (7.25, (2, 0, 4, 0), "fill_health", None),  # 8 px tall: fills the trough exactly
    "fill_ghost":           (7.25, (2, 0, 4, 0), "fill_ghost", None),
    "fill_edge":            (7.25, (2, 0, 4, 0), "fill_edge", None),
    "fill_exp":             (7.25, (2, 0, 4, 0), "fill_exp", None),
    "thin_bar_frame":       (11.0, (4, 0, 4, 0), "thin_bar_frame", None),
    "fill_edge_thin":       (11.6, (1, 0, 2, 0), "fill_edge", None),   # 5 px tall, the thin trough's inside
    "fill_exp_thin":        (11.6, (1, 0, 2, 0), "fill_exp", None),
    "fill_health_thin":     (11.6, (1, 0, 2, 0), "fill_health", None),
    "fill_ghost_thin":      (11.6, (1, 0, 2, 0), "fill_ghost", None),
    "level_pillar":         (8.0, (0, 28, 0, 10), "level_pillar", None),
    "level_shield":         ((18, 21), None, "level_shield", None),
    "name_ribbon":          ((88, 16), (26, 0, 26, 0), "name_ribbon", None),
    "tab_on":               (8.0, (6, 5, 6, 5), "tab_on", None),
    "tab_off":              (8.0, (6, 5, 6, 5), "tab_off", None),
    "button_normal":        (9.0, (6, 6, 6, 6), "button_normal", None),
    "button_pressed":       (9.0, (6, 6, 6, 6), "button_pressed", None),
    "button_locked":        (9.0, (6, 6, 6, 6), "button_locked", None),
    "key_badge":            (10.0, (4, 4, 4, 4), "key_badge", None),
    "icon_padlock":         ((8, 10), None, "icon_padlock", None),
    "icon_herb":            ((14, 14), None, "icon_herb", (0.14, 0.14, 0.86, 0.86)),
    "icon_katana":          ((20, 20), None, "icon_katana", (0.14, 0.14, 0.86, 0.86)),
    "icon_sprint":          ((13, 13), None, "icon_sprint", (0.14, 0.14, 0.86, 0.86)),
    "icon_check":           ((12, 12), None, "icon_check", (0.16, 0.16, 0.84, 0.84)),
    "icon_rune":            ((12, 12), None, "icon_rune", (0.16, 0.16, 0.84, 0.84)),
}
SLOT = 24  # item slot size on the HUD


# ---- pixel helpers (also used by mockups.py) -------------------------------------------------------------------------

def nine(img: Image.Image, borders: tuple[int, int, int, int], size: tuple[int, int]) -> Image.Image:
    """9-slice img to size: corners copied, edges and centre tiled (pixel art is never stretched)."""
    l, t, r, b = borders
    sw, sh = img.size
    w, h = size
    if w < l + r or h < t + b:
        raise ValueError(f"{size} is smaller than the 9-slice corners {borders}")
    out = Image.new("RGBA", size, (0, 0, 0, 0))
    for (sy0, sy1), (dy0, dy1) in zip(((0, t), (t, sh - b), (sh - b, sh)), ((0, t), (t, h - b), (h - b, h))):
        for (sx0, sx1), (dx0, dx1) in zip(((0, l), (l, sw - r), (sw - r, sw)), ((0, l), (l, w - r), (w - r, w))):
            if sx1 <= sx0 or sy1 <= sy0 or dx1 <= dx0 or dy1 <= dy0:
                continue
            tile = img.crop((sx0, sy0, sx1, sy1))
            for y in range(dy0, dy1, tile.height):
                for x in range(dx0, dx1, tile.width):
                    out.paste(tile.crop((0, 0, min(tile.width, dx1 - x), min(tile.height, dy1 - y))), (x, y))
    return out


def region(img: Image.Image, seed: tuple[int, int]) -> set[tuple[int, int]]:
    """Pixels of the seed's colour connected to the seed (4-neighbour flood fill)."""
    px = img.load()
    want = px[seed]
    w, h = img.size
    seen: set[tuple[int, int]] = set()
    todo = [seed]
    while todo:
        x, y = todo.pop()
        if (x, y) in seen or not (0 <= x < w and 0 <= y < h) or px[x, y] != want:
            continue
        seen.add((x, y))
        todo += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
    return seen


def interior(img: Image.Image, seed: tuple[int, int] | None = None) -> tuple[int, int, int, int]:
    """Bounding box (x0, y0, x1, y1) of the ink area around the seed (default: the centre)."""
    pts = region(img, seed or (img.width // 2, img.height // 2))
    xs, ys = [p[0] for p in pts], [p[1] for p in pts]
    return min(xs), min(ys), max(xs) + 1, max(ys) + 1


def enclosed(img: Image.Image, seed: tuple[int, int]) -> set[tuple[int, int]]:
    """The ink area around the seed plus every pixel it encloses (e.g. a rune drawn inside it)."""
    inner = region(img, seed)
    w, h = img.size
    outside: set[tuple[int, int]] = set()
    todo = [(x, y) for x in range(w) for y in (0, h - 1)] + [(x, y) for y in range(h) for x in (0, w - 1)]
    while todo:
        x, y = todo.pop()
        if (x, y) in outside or (x, y) in inner or not (0 <= x < w and 0 <= y < h):
            continue
        outside.add((x, y))
        todo += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
    x0, y0, x1, y1 = interior(img, seed)
    return {(x, y) for x in range(x0, x1) for y in range(y0, y1) if (x, y) not in outside}


def centre_in(base: Image.Image, top: Image.Image, box: tuple[int, int, int, int], mask: set | None = None) -> Image.Image:
    """Paste top centred in box of base (only inside mask, if given)."""
    out = base.copy()
    ox = box[0] + (box[2] - box[0] - top.width) // 2
    oy = box[1] + (box[3] - box[1] - top.height) // 2
    tp_ = top.load()
    op = out.load()
    for y in range(top.height):
        for x in range(top.width):
            if tp_[x, y][3] and (mask is None or (ox + x, oy + y) in mask):
                op[ox + x, oy + y] = tp_[x, y]
    return out


def clear_backing(img: Image.Image) -> Image.Image:
    """Make the ink backing around an icon transparent: ink pixels connected to the border."""
    img = img.copy()
    px = img.load()
    w, h = img.size
    todo = [(x, y) for x in range(w) for y in (0, h - 1)] + [(x, y) for y in range(h) for x in (0, w - 1)]
    seen: set[tuple[int, int]] = set()
    while todo:
        x, y = todo.pop()
        if (x, y) in seen or not (0 <= x < w and 0 <= y < h):
            continue
        seen.add((x, y))
        r, g, b, a = px[x, y]
        if a and (r, g, b) != INK[:3]:
            continue
        px[x, y] = (0, 0, 0, 0)
        todo += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
    return img


def socket_seed(img: Image.Image) -> tuple[int, int]:
    """An ink pixel inside a socket's diamond: walk left from the diamond's centre past the icon."""
    px = img.load()
    cy = img.width // 2  # the diamond is as tall as the part is wide; the badge stem hangs below
    for x in range(img.width // 2, 0, -1):
        if px[x, cy][:3] == INK[:3] and px[x - 1, cy][:3] == INK[:3]:
            return x, cy
    raise ValueError("no ink inside the socket")


# ---- build -------------------------------------------------------------------------------------------------------------

def convert_parts() -> dict[str, Image.Image]:
    sheet = Image.open(SHEET).convert("RGBA")
    parts: dict[str, Image.Image] = {}
    for name, (scale, _nine, src, inner) in PARTS.items():
        r = RECTS[src]
        crop = sheet.crop((r["x"], r["y"], r["x"] + r["w"], r["y"] + r["h"]))
        if inner:
            crop = crop.crop((round(inner[0] * r["w"]), round(inner[1] * r["h"]), round(inner[2] * r["w"]), round(inner[3] * r["h"])))
        size = scale if isinstance(scale, tuple) else (round(crop.width / scale), round(crop.height / scale))
        img, _ = tp.convert(crop, size)
        if name.startswith("icon_") and inner or name == "cooldown_sweep":
            img = clear_backing(img)
        parts[name] = img
    # the pillar arrived filled with violet: empty its tube so the game can draw the level
    pil = parts["level_pillar"].copy()
    px = pil.load()
    for y in range(pil.height):
        for x in range(pil.width):
            if px[x, y][3] and px[x, y][:3] == LILAC:
                px[x, y] = INK
    parts["level_pillar"] = pil
    # the active socket came with a sample rune; clear it so any Aspect icon can sit there
    sock = parts["aspect_socket_active"].copy()
    spx = sock.load()
    for p in enclosed(sock, socket_seed(sock)):
        spx[p] = INK
    parts["aspect_socket_open"] = sock
    # the locked button came with a padlock in its face; clear it so the button 9-slices at any width
    # and carries a dimmed label next to icon_padlock instead
    btn = parts["button_locked"].copy()
    bpx = btn.load()
    seed = (8, btn.height // 2)
    for p in enclosed(btn, seed):
        bpx[p] = bpx[seed]
    parts["button_locked"] = btn
    return parts


def slot(parts: dict[str, Image.Image], state: str, size: int = SLOT, icon: str | None = None) -> Image.Image:
    """An item slot assembled from kit parts: empty, normal (stone floor), locked, cooldown."""
    img = nine(parts["slot_frame"], PARTS["slot_frame"][1], (size, size))
    box = interior(img)
    if state == "normal":
        floor = parts["slot_floor"]
        tiled = nine(floor, (0, 0, 0, 0), (box[2] - box[0], box[3] - box[1]))
        img.paste(tiled, box[:2])
    if state == "locked":
        img = centre_in(img, parts["icon_padlock"], box)
    if state == "cooldown":
        img = centre_in(img, parts["cooldown_sweep"], box)
    if icon:
        img = centre_in(img, parts[icon], box)
    return img


def build() -> tuple[dict[str, Image.Image], dict[str, Image.Image]]:
    parts = convert_parts()
    assembled = {f"slot_{s}": slot(parts, s) for s in ("empty", "normal", "locked", "cooldown")}
    sock = parts["aspect_socket_open"]
    assembled["aspect_socket_sprint"] = centre_in(sock, parts["icon_sprint"], (0, 0, sock.width, sock.width),
                                                  enclosed(sock, socket_seed(sock)))
    KIT.mkdir(exist_ok=True)
    meta: dict[str, dict] = {}
    for name, img in {**parts, **assembled}.items():
        tp.check(img)
        img.save(KIT / f"{name}.png")
        entry: dict = {"size": list(img.size)}
        if name in PARTS:
            entry["nine_slice"] = list(PARTS[name][1]) if PARTS[name][1] else None
            r = RECTS[PARTS[name][2]]
            entry["source_rect"] = [r["x"], r["y"], r["w"], r["h"]]
        else:
            entry["assembled_from_kit"] = True
        meta[name] = entry
    (KIT / "kit.json").write_text(json.dumps({"units": "game pixels (320x180 base)", "source_sheet": "raw/sheet_1.png",
                                              "parts": meta}, indent=1) + "\n", encoding="utf-8")
    return parts, assembled


def sheet_png(parts: dict[str, Image.Image], assembled: dict[str, Image.Image], scale: int = 4) -> Path:
    """All parts at 4x on ink, in labelled rows."""
    font = ImageFont.truetype(str(ROOT / "presentation" / "fonts" / "Cinzel.ttf"), 22)
    font.set_variation_by_axes([700])
    head = ImageFont.truetype(str(ROOT / "presentation" / "fonts" / "Cinzel.ttf"), 30)
    head.set_variation_by_axes([900])
    hp = nine(parts["health_bar_frame"], PARTS["health_bar_frame"][1], (112, 14))
    box = interior(hp)
    bar = hp.copy()
    for fill, frac in (("fill_ghost", 0.8), ("fill_health", 0.62)):
        w = round((box[2] - box[0]) * frac)
        strip = nine(parts[fill], PARTS[fill][1], (w, parts[fill].height))
        bar.alpha_composite(strip, (box[0], box[1] + (box[3] - box[1] - strip.height) // 2))
    thin = nine(parts["thin_bar_frame"], PARTS["thin_bar_frame"][1], (84, 9))
    tbox = interior(thin)
    edge = thin.copy()
    thin_fill = parts["fill_edge_thin"]
    strip = nine(thin_fill, PARTS["fill_edge_thin"][1], (round((tbox[2] - tbox[0]) * 0.7), thin_fill.height))
    edge.alpha_composite(strip, (tbox[0], tbox[1] + (tbox[3] - tbox[1] - thin_fill.height) // 2))
    examples = {
        "health 62%, ghost 80%": bar,
        "edge 70%": edge,
        "ribbon 9-sliced": nine(parts["name_ribbon"], PARTS["name_ribbon"][1], (120, 16)),
        "panel 9-sliced 120x48": nine(parts["panel_large_ornate"], PARTS["panel_large_ornate"][1], (120, 48)),
        "button 9-sliced": nine(parts["button_normal"], PARTS["button_normal"][1], (52, 16)),
        "tab 9-sliced": nine(parts["tab_on"], PARTS["tab_on"][1], (56, 16)),
    }
    sections = [
        ("Panels and medallion (9-slice frames)", ["panel_large_ornate", "panel_medium", "panel_small", "weapon_medallion"]),
        ("Item slots, assembled 24x24", ["slot_normal", "slot_empty", "slot_locked", "slot_cooldown", "slot_frame",
                                         "slot_floor", "cooldown_sweep"]),
        ("Aspect sockets, level pillar and shield", ["aspect_socket_sprint", "aspect_socket_open", "aspect_socket_locked",
                                                    "aspect_socket_active", "level_shield", "level_pillar"]),
        ("Bars", ["health_bar_frame", "thin_bar_frame", "fill_health", "fill_ghost", "fill_edge", "fill_exp",
                  "fill_health_thin", "fill_ghost_thin", "fill_edge_thin", "fill_exp_thin"]),
        ("Ribbon, tabs, buttons, key badge", ["name_ribbon", "tab_on", "tab_off", "button_normal", "button_pressed",
                                              "button_locked", "key_badge"]),
        ("Icons", ["icon_herb", "icon_katana", "icon_sprint", "icon_check", "icon_rune", "icon_padlock"]),
        ("In use (9-sliced and filled at game size)", list(examples)),
    ]
    imgs = {**parts, **assembled, **examples}
    pad, label_h, maxw = 28, 34, 1880
    layout: list[tuple[str, int, int, str]] = []
    y = pad
    for title, names in sections:
        layout.append((title, pad, y, "head"))
        y += 44
        x, rh = pad, 0
        for name in names:
            w, h = imgs[name].width * scale, imgs[name].height * scale
            cw = max(w, int(font.getlength(name)) + 8)
            if x + cw > maxw and x > pad:
                y += rh + label_h + pad
                x, rh = pad, 0
            layout.append((name, x, y, "part"))
            x += cw + pad
            rh = max(rh, h)
        y += rh + label_h + pad
    out = Image.new("RGBA", (1920, y), INK)
    d = ImageDraw.Draw(out)
    for name, x, y0, kind in layout:
        if kind == "head":
            d.text((x, y0), name, font=head, fill=(0x6A, 0xA8, 0x9A))
            continue
        p = imgs[name]
        out.alpha_composite(p.resize((p.width * scale, p.height * scale), Image.NEAREST), (x, y0))
        d.text((x, y0 + p.height * scale + 6), name, font=font, fill=(0xC6, 0xBF, 0xAA))
    path = HERE / "kit_sheet.png"
    out.convert("RGB").save(path)
    return path


if __name__ == "__main__":
    built, made = build()
    print(sheet_png(built, made).relative_to(ROOT), f"{len(built)} parts + {len(made)} assembled")
