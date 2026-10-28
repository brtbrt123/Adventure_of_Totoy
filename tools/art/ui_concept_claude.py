"""UI concept by Claude (review only, not installed): a fantasy HUD, dialogue card, status and Aspects screens, cards and a
component sheet drawn in the game's own graphics. Totoy 36 pixels at the 320x180 base resolution, scaled x4 with
nearest-neighbour, over real game captures, the game's own sprites and portraits. Words use Cinzel (the game's title and
menu font) rendered at window resolution like the game does (docs/decisions/0004-sharp-ui-text.md); numbers and key
letters use a small hand-made pixel font (below), because Pixelify Sans draws 5, Z and C almost like S, 2 and O at HUD size.

    python tools/art/ui_concept_claude.py        -> docs/previews/ui_concept_claude_v3/*.png

Every UI pixel is a Totoy 36 colour, fully opaque or fully transparent (the warning lane and the dimming veil are game
effects, not UI art). Gold and red stay reserved for combat cues: bronze, teal, leaf green and violet carry the UI.
"""
from __future__ import annotations

import json
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "docs" / "previews" / "ui_concept_claude_v3"
S = 4  # window scale: 320x180 -> 1280x720
W, H = 320, 180

_PAL = json.loads((ROOT / "art" / "palette.json").read_text())["colors"]
SYM = {c["symbol"]: c["hex"] for c in _PAL}
NAME = {c["name"]: c["hex"] for c in _PAL}


def rgb(name: str) -> tuple[int, int, int, int]:
    h = NAME.get(name, SYM.get(name, name))
    return (int(h[1:3], 16), int(h[3:5], 16), int(h[5:7], 16), 255)


INK, CREAM = rgb("ink"), rgb("cream")
BR_L, BR, BR_M, BR_D, BR_DD = rgb("dirt_6"), rgb("dirt_5"), rgb("dirt_4"), rgb("dirt_3"), rgb("dirt_1")
ST1, ST2, ST3, ST4, ST5, ST6 = rgb("stone_1"), rgb("stone_2"), rgb("stone_3"), rgb("stone_4"), rgb("stone_5"), rgb("stone_6")
T1, T2, W5, W6 = rgb("teal_1"), rgb("teal_2"), rgb("water_5"), rgb("water_6")
G2, G3, G4, G5, G6 = rgb("grass_2"), rgb("grass_3"), rgb("grass_4"), rgb("grass_5"), rgb("grass_6")
LIL = rgb("lilac")
SK2, SK3 = rgb("skin_2"), rgb("skin_3")
DIRT2 = rgb("dirt_2")

FONT_DIR = ROOT / "presentation" / "fonts"


def cinzel(size: float, weight: int) -> ImageFont.FreeTypeFont:
    f = ImageFont.truetype(str(FONT_DIR / "Cinzel.ttf"), int(round(size * S)))
    f.set_variation_by_axes([weight])
    return f


SPRITES = Image.open(ROOT / "art" / "build" / "sprites.png").convert("RGBA")
FRAMES = json.loads((ROOT / "art" / "build" / "sprites.json").read_text())["frames"]
_PDIR = ROOT / "art" / "reference" / "chapter1_characters_v2"
PORTRAITS = Image.open(_PDIR / "portraits_v2.png").convert("RGBA")
PORTRAIT_FRAMES = json.loads((_PDIR / "portraits_v2.json").read_text())["frames"]

# ---- the pixel font: 4x6 cells (I and the punctuation narrower), drawn with an ink outline ------------------------------
GLYPHS = {
    "0": [".##.", "#..#", "#.##", "##.#", "#..#", ".##."],
    "1": [".#.", "##.", ".#.", ".#.", ".#.", "###"],
    "2": [".##.", "#..#", "..#.", ".#..", "#...", "####"],
    "3": ["###.", "...#", ".##.", "...#", "...#", "###."],
    "4": ["#..#", "#..#", "####", "...#", "...#", "...#"],
    "5": ["####", "#...", "###.", "...#", "...#", "###."],
    "6": [".##.", "#...", "###.", "#..#", "#..#", ".##."],
    "7": ["####", "...#", "..#.", ".#..", ".#..", ".#.."],
    "8": [".##.", "#..#", ".##.", "#..#", "#..#", ".##."],
    "9": [".##.", "#..#", "#..#", ".###", "...#", ".##."],
    "/": ["...#", "..#.", "..#.", ".#..", ".#..", "#..."],
    "+": ["...", ".#.", "###", ".#.", "...", "..."],
    "-": ["...", "...", "###", "...", "...", "..."],
    "%": ["#..#", "...#", "..#.", ".#..", "#...", "#..#"],
    "x": ["....", "#..#", ".##.", ".##.", "#..#", "...."],
    " ": ["..", "..", "..", "..", "..", ".."],
    "A": [".##.", "#..#", "#..#", "####", "#..#", "#..#"],
    "B": ["###.", "#..#", "###.", "#..#", "#..#", "###."],
    "C": [".###", "#...", "#...", "#...", "#...", ".###"],
    "E": ["####", "#...", "###.", "#...", "#...", "####"],
    "F": ["####", "#...", "###.", "#...", "#...", "#..."],
    "H": ["#..#", "#..#", "####", "#..#", "#..#", "#..#"],
    "I": ["#", "#", "#", "#", "#", "#"],
    "L": ["#...", "#...", "#...", "#...", "#...", "####"],
    "P": ["###.", "#..#", "###.", "#...", "#...", "#..."],
    "Q": [".##.", "#..#", "#..#", "#.##", "#..#", ".##"],
    "R": ["###.", "#..#", "###.", "#.#.", "#..#", "#..#"],
    "S": [".###", "#...", ".##.", "...#", "...#", "###."],
    "T": ["###", ".#.", ".#.", ".#.", ".#.", ".#."],
    "V": ["#..#", "#..#", "#..#", "#..#", ".##.", ".##."],
    "X": ["#..#", "#..#", ".##.", ".##.", "#..#", "#..#"],
    "Z": ["####", "...#", "..#.", ".#..", "#...", "####"],
}


def pwidth(s: str, scale: int = 1) -> int:
    return (sum(len(GLYPHS[c][0]) for c in s) + max(0, len(s) - 1)) * scale


class Canvas:
    """Shapes go to a 320x180 pixel layer; words and smooth portraits go straight onto the x4 image (flushed in order)."""

    def __init__(self, bg: Image.Image | None = None, size: tuple[int, int] = (W, H), fill=INK):
        self.size = size
        if bg is not None:
            self.big = bg.convert("RGBA").resize((size[0] * S, size[1] * S), Image.NEAREST)
        else:
            self.big = Image.new("RGBA", (size[0] * S, size[1] * S), fill)
        self.ui = Image.new("RGBA", size, (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.ui)

    def flush(self) -> None:
        self.big.alpha_composite(self.ui.resize(self.big.size, Image.NEAREST))
        self.ui = Image.new("RGBA", self.size, (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.ui)

    # --- pixels -------------------------------------------------------------------------------------------------------------
    def rect(self, x: int, y: int, w: int, h: int, c) -> None:
        if w > 0 and h > 0:
            self.d.rectangle([x, y, x + w - 1, y + h - 1], fill=c)

    def px(self, x: int, y: int, c) -> None:
        self.d.point((x, y), fill=c)

    def poly(self, pts, c) -> None:
        self.d.polygon(pts, fill=c)

    def disc(self, cx: int, cy: int, r: int, c) -> None:
        self.d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=c)

    def grid(self, x: int, y: int, rows: list[str], flip_x: bool = False, flip_y: bool = False) -> None:
        rows = [r.replace(" ", "") for r in rows]
        if flip_y:
            rows = rows[::-1]
        for j, row in enumerate(rows):
            if flip_x:
                row = row[::-1]
            for i, ch in enumerate(row):
                if ch != ".":
                    self.px(x + i, y + j, rgb(ch))

    def sprite(self, name: str, fx: int, fy: int, flip: bool = False) -> None:
        f = FRAMES[name]
        im = SPRITES.crop((f["x"], f["y"], f["x"] + f["w"], f["y"] + f["h"]))
        ax = f["ax"]
        if flip:
            im = im.transpose(Image.FLIP_LEFT_RIGHT)
            ax = f["w"] - 1 - f["ax"]
        self.ui.alpha_composite(im, (fx - ax, fy - f["ay"]))

    def shadow(self, cx: int, cy: int, rx: int) -> None:
        for i in range(-rx, rx + 1):
            self.px(cx + i, cy, (20, 16, 26, 255))
            if abs(i) < rx - 2:
                self.px(cx + i, cy + 1, (20, 16, 26, 255))

    def ptext(self, x: int, y: int, s: str, c=CREAM, scale: int = 1, outline=INK, align: str = "l") -> int:
        """The pixel font at design resolution: crisp numbers and key letters, an ink outline all round."""
        w = pwidth(s, scale)
        if align == "c":
            x -= w // 2
        elif align == "r":
            x -= w
        cells = []
        cx = x
        for ch in s:
            g = GLYPHS[ch]
            for j, row in enumerate(g):
                for i, b in enumerate(row):
                    if b == "#":
                        cells.append((cx + i * scale, y + j * scale))
            cx += (len(g[0]) + 1) * scale
        if outline is not None:
            for ox, oy in cells:
                self.rect(ox - 1, oy - 1, scale + 2, scale + 2, outline)
        for ox, oy in cells:
            self.rect(ox, oy, scale, scale, c)
        return w

    # --- window-resolution layers ----------------------------------------------------------------------------------------------
    def text(self, x: float, y: float, s: str, size: float = 6, fill=CREAM, weight: int = 700, anchor: str = "ls", outline: int = 0, ofill=INK) -> None:
        self.flush()
        ImageDraw.Draw(self.big).text((x * S, y * S), s, font=cinzel(size, weight), fill=fill, anchor=anchor,
                                       stroke_width=outline * 2, stroke_fill=ofill)

    def portrait(self, name: str, x: int, y: int, size: int) -> None:
        self.flush()
        f = PORTRAIT_FRAMES[name]
        im = PORTRAITS.crop((f["x"], f["y"], f["x"] + f["w"], f["y"] + f["h"])).resize((size * S, size * S), Image.LANCZOS)
        self.big.alpha_composite(im, (x * S, y * S))

    def veil(self, c=(20, 16, 26, 150)) -> None:
        self.flush()
        self.big.alpha_composite(Image.new("RGBA", self.big.size, c))

    def save(self, name: str) -> Path:
        self.flush()
        OUT.mkdir(parents=True, exist_ok=True)
        path = OUT / name
        self.big.convert("RGB").save(path)
        return path


# ---- icons (palette symbols, as in art/src) ---------------------------------------------------------------------------------
ICON = {
    "herb": [
        ". . . . . . . . . 0 0 . .",
        ". . . . . . . . 0 6 7 0 .",
        ". . . . . . . 0 5 6 6 0 .",
        ". . 0 0 0 . 0 4 5 6 5 0 .",
        ". 0 6 7 6 0 0 4 5 5 0 . .",
        "0 5 6 6 5 4 0 3 4 0 . . .",
        "0 4 5 5 4 3 3 0 2 0 . . .",
        ". 0 4 4 3 0 3 2 0 . . . .",
        ". . 0 0 0 v 0 2 0 . . . .",
        ". . . . 0 1 v 2 0 . . . .",
        ". . . . . 0 0 2 0 . . . .",
        ". . . . . . 0 2 0 . . . .",
        ". . . . . . . 0 . . . . .",
    ],
    "katana": [
        ". . . . . . . . . . . . . 0 0 .",
        ". . . . . . . . . . . . 0 p o 0",
        ". . . . . . . . . . . 0 p o 0 .",
        ". . . . . . . . . . 0 p o 0 . .",
        ". . . . . . . . . 0 p o 0 . . .",
        ". . . . . . . . 0 p o 0 . . . .",
        ". . . . . . . 0 p o 0 . . . . .",
        ". . . . . . 0 p o 0 . . . . . .",
        ". . . . . 0 p n 0 . . . . . . .",
        ". . . 0 0 o n 0 . . . . . . . .",
        ". . . 0 d c 0 0 . . . . . . . .",
        ". . 0 0 c 0 d 0 . . . . . . . .",
        ". 0 9 a 0 . 0 . . . . . . . . .",
        "0 9 a 9 0 . . . . . . . . . . .",
        "0 a 9 0 . . . . . . . . . . . .",
        ". 0 0 . . . . . . . . . . . . .",
    ],
    "sprint": [
        ". . . . . . . . . . . . .",
        ". 0 0 . . . . 0 0 . . . .",
        ". 0 t 0 . . . 0 p 0 . . .",
        ". . 0 t 0 . . . 0 p 0 . .",
        ". . . 0 u 0 . . . 0 p 0 .",
        ". . . . 0 u 0 . . . 0 p 0",
        ". . . 0 u 0 . . . 0 p 0 .",
        ". . 0 t 0 . . . 0 p 0 . .",
        ". 0 t 0 . . . 0 p 0 . . .",
        ". 0 0 . . . . 0 0 . . . .",
        ". . . . . . . . . . . . .",
    ],
    "lock": [
        ". . . 0 0 0 0 . . .",
        ". . 0 i j j i 0 . .",
        ". 0 i 0 0 0 0 i 0 .",
        ". 0 i 0 . . 0 h 0 .",
        "0 0 0 0 0 0 0 0 0 0",
        "0 d d d d d d d c 0",
        "0 d c c 0 0 c c b 0",
        "0 c c c 0 0 c c b 0",
        "0 c c c c 0 c b b 0",
        "0 b b b b b b b a 0",
        ". 0 0 0 0 0 0 0 0 .",
    ],
    "check": [
        ". . . . . . . . 0 0",
        ". . . . . . . 0 7 0",
        ". . . . . . 0 7 5 0",
        "0 0 . . . 0 7 5 0 .",
        "0 7 0 . 0 7 5 0 . .",
        ". 0 7 0 7 5 0 . . .",
        ". . 0 6 5 0 . . . .",
        ". . . 0 0 . . . . .",
    ],
    "rune": [
        ". . . 0 . . .",
        ". . 0 u 0 . .",
        ". 0 u p u 0 .",
        "0 u p p p u 0",
        ". 0 t p t 0 .",
        ". . 0 t 0 . .",
        ". . . 0 . . .",
    ],
    "plus": [
        ". . 0 0 0 . .",
        ". . 0 1 0 . .",
        "0 0 0 1 0 0 0",
        "0 1 1 1 1 1 0",
        "0 0 0 1 0 0 0",
        ". . 0 1 0 . .",
        ". . 0 0 0 . .",
    ],
    "boot": [
        ". . . . . . . . . . . . .",
        ". . . 0 0 0 0 . . . . . .",
        ". . . 0 h h 0 . . . . . .",
        ". . . 0 g h 0 . 0 0 . . .",
        ". . . 0 g h 0 0 u u 0 . .",
        ". . . 0 g h 0 u t 0 . . .",
        ". . 0 g g h 0 t 0 . . . .",
        ". 0 g g h h h 0 . . . . .",
        "0 g g h h h h h 0 . . . .",
        "0 f f f f f f f 0 . . . .",
        ". 0 0 0 0 0 0 0 . . . . .",
    ],
    "fang": [
        ". . . . . . 0 0 . . .",
        ". . . . . 0 j 1 0 . .",
        ". . . . 0 j j 0 . . .",
        ". . . 0 i j 0 . . . .",
        ". . 0 i j 0 . . . . .",
        ". 0 h i 0 . . . . . .",
        "0 h i 0 . . . . . . .",
        "0 h 0 . . . . . . . .",
        ". 0 . . . . . . . . .",
    ],
    "moon": [
        ". . . 0 0 0 0 . .",
        ". . 0 n o p 0 0 .",
        ". 0 n o 0 0 . . .",
        "0 m n 0 . . . . .",
        "0 m n 0 . . . . .",
        "0 l m 0 . . . . .",
        ". 0 l m 0 0 . . .",
        ". . 0 l m n 0 0 .",
        ". . . 0 0 0 0 . .",
    ],
    "shield": [
        "0 0 0 0 0 0 0 0 0",
        "0 j j i i i h h 0",
        "0 j i i h h h g 0",
        "0 i i h u h g g 0",
        "0 i h u u u g f 0",
        ". 0 h h u g g 0 .",
        ". 0 h g g g f 0 .",
        ". . 0 g g f 0 . .",
        ". . . 0 0 0 . . .",
    ],
}

# The corner ornament of the large panels: a gem in a bronze setting with scroll tails running along both edges.
CORNER = [
    ". . 0 0 0 0 0 0 . . . .",
    ". 0 d d d d c c 0 0 0 .",
    "0 d c 0 0 0 0 c d c 0 .",
    "0 d 0 u u u t 0 c 0 . .",
    "0 d 0 u p u t 0 a 0 . .",
    "0 d 0 u u t t 0 0 . . .",
    "0 c 0 t t t 0 a 0 . . .",
    "0 c c 0 0 0 a 0 . . . .",
    ". 0 d c a a 0 . . . . .",
    ". 0 c 0 0 0 . . . . . .",
    ". 0 a 0 . . . . . . . .",
    ". . 0 . . . . . . . . .",
]


def icon(cv: Canvas, name: str, x: int, y: int) -> None:
    cv.grid(x, y, ICON[name])


def icon_size(name: str) -> tuple[int, int]:
    rows = ICON[name]
    return len(rows[0].replace(" ", "")), len(rows)


def gem(cv: Canvas, cx: int, cy: int, core=None) -> None:
    cv.poly([(cx, cy - 2), (cx + 2, cy), (cx, cy + 2), (cx - 2, cy)], INK)
    cv.px(cx, cy - 1, T2)
    cv.px(cx - 1, cy, T2)
    cv.px(cx + 1, cy, T1)
    cv.px(cx, cy + 1, T1)
    cv.px(cx, cy, core or W6)


def corners(cv: Canvas, x: int, y: int, w: int, h: int) -> None:
    cv.grid(x - 3, y - 3, CORNER)
    cv.grid(x + w - 9, y - 3, CORNER, flip_x=True)
    cv.grid(x - 3, y + h - 9, CORNER, flip_y=True)
    cv.grid(x + w - 9, y + h - 9, CORNER, flip_x=True, flip_y=True)


def stone_fill(cv: Canvas, x: int, y: int, w: int, h: int) -> None:
    """The panel's inside: ink, with a dithered lip of stone under the top edge (a carved, slightly lit recess)."""
    cv.rect(x, y, w, h, INK)
    for i in range(x, x + w):
        if i % 2 == 0:
            cv.px(i, y, ST1)
        if i % 4 == 1:
            cv.px(i, y + 1, ST1)
        if i % 8 == 5:
            cv.px(i, y + 2, ST1)


def frame(cv: Canvas, x: int, y: int, w: int, h: int, *, gems: bool = True, ornate: bool = False, crest: bool = False, fill: bool = True) -> None:
    """The carved bronze frame: an ink rim, a bevelled bronze band lit from the top left, an ink line, a stone-dark recess.
    `ornate` puts the scroll-and-gem ornaments on the corners, `gems` small set gems, `crest` an ornament at the top centre."""
    cv.rect(x + 1, y, w - 2, h, INK)
    cv.rect(x, y + 1, w, h - 2, INK)
    cv.rect(x + 1, y + 1, w - 2, h - 2, BR)
    cv.rect(x + 2, y + 1, w - 4, 1, BR_L)
    cv.rect(x + 1, y + 2, 1, h - 4, BR_L)
    cv.rect(x + 2, y + h - 2, w - 4, 1, BR_D)
    cv.rect(x + w - 2, y + 2, 1, h - 4, BR_D)
    cv.rect(x + 2, y + 2, w - 4, h - 4, INK)
    if fill:
        stone_fill(cv, x + 3, y + 3, w - 6, h - 6)
    if ornate:
        corners(cv, x, y, w, h)
    elif gems:
        for gx, gy in ((x + 2, y + 2), (x + w - 3, y + 2), (x + 2, y + h - 3), (x + w - 3, y + h - 3)):
            gem(cv, gx, gy)
    if crest:
        cx = x + w // 2
        cv.poly([(cx - 8, y + 1), (cx, y - 4), (cx + 8, y + 1), (cx, y + 4)], INK)
        cv.poly([(cx - 6, y + 1), (cx, y - 3), (cx + 6, y + 1), (cx, y + 3)], BR)
        cv.poly([(cx - 6, y + 1), (cx, y - 3), (cx, y + 1)], BR_L)
        gem(cv, cx, y)


def divider(cv: Canvas, x: int, y: int, w: int) -> None:
    """A thin bronze rule with a gem at its middle."""
    cv.rect(x, y, w, 1, BR_D)
    cv.rect(x + 2, y, w - 4, 1, BR)
    gem(cv, x + w // 2, y)


def bar(cv: Canvas, x: int, y: int, w: int, h: int, p: float, fill, light, dark, *, ghost: float = 0.0, notches: int = 0) -> None:
    cv.rect(x, y, w, h, INK)
    cv.rect(x + 1, y + 1, w - 2, h - 2, ST1)
    cv.rect(x + 1, y + h - 2, w - 2, 1, INK)
    fw = round((w - 2) * max(0.0, min(1.0, p)))
    gw = round((w - 2) * max(0.0, min(1.0, ghost)))
    if gw > fw:
        cv.rect(x + 1 + fw, y + 1, gw - fw, h - 2, ST5)
        cv.rect(x + 1 + fw, y + 1, gw - fw, 1, ST6)
    cv.rect(x + 1, y + 1, fw, h - 2, fill)
    cv.rect(x + 1, y + 1, fw, 1, light)
    if h >= 6:
        cv.rect(x + 1, y + h - 2, fw, 1, dark)
        for i in range(x + 3, x + 1 + fw - 1, 6):
            cv.px(i, y + 2, light)
            cv.px(i + 1, y + 2, light)
    if notches:
        for k in range(1, notches):
            tx = x + 1 + round((w - 2) * k / notches)
            cv.px(tx, y, BR_L)
            cv.px(tx, y + h - 1, BR_D)


def hp_bar(cv: Canvas, x: int, y: int, w: int, p: float, ghost: float, cur: int, mx: int) -> None:
    """The health vial: bronze end caps (a gem on the left, a pointed tip on the right), a leaf-green fill shaded in three
    steps, bronze notches every tenth on the rim, and a pale 'ghost' segment showing the last hit draining away."""
    bar(cv, x, y, w, 10, p, G5, G6, G3, ghost=ghost, notches=10)
    cv.rect(x - 6, y - 2, 7, 14, INK)
    cv.rect(x - 5, y - 1, 5, 12, BR)
    cv.rect(x - 5, y - 1, 5, 1, BR_L)
    cv.rect(x - 5, y + 10, 5, 1, BR_D)
    gem(cv, x - 3, y + 4)
    cv.poly([(x + w - 1, y - 2), (x + w + 5, y + 4), (x + w + 5, y + 5), (x + w - 1, y + 11)], INK)
    cv.poly([(x + w - 1, y), (x + w + 3, y + 4), (x + w + 3, y + 5), (x + w - 1, y + 9)], BR)
    cv.px(x + w, y + 2, BR_L)
    cv.px(x + w + 1, y + 3, BR_L)
    label = f"{cur}/{mx}"
    covered = round((w - 2) * p) >= pwidth(label) + 6
    cv.ptext(x + 4, y + 2, label, INK if covered else CREAM, outline=None)  # ink on the green, cream on the empty trough


def keycap(cv: Canvas, x: int, y: int, label: str, locked: bool = False) -> None:
    """A little bronze key badge with a crisp pixel letter."""
    w = pwidth(label) + 4
    cv.rect(x, y, w, 9, INK)
    cv.rect(x + 1, y + 1, w - 2, 7, ST2 if locked else BR_D)
    cv.rect(x + 1, y + 1, w - 2, 1, ST3 if locked else BR)
    cv.ptext(x + 2, y + 2, label, ST5 if locked else CREAM, outline=None)


def slot(cv: Canvas, x: int, y: int, s: int, *, ic: str | None = None, key: str | None = None, count: int | None = None,
         locked: bool = False, active: bool = False, cool: float = 0.0) -> None:
    cv.rect(x + 1, y, s - 2, s, INK)
    cv.rect(x, y + 1, s, s - 2, INK)
    cv.rect(x + 1, y + 1, s - 2, s - 2, T2 if active else BR)
    cv.rect(x + 2, y + 1, s - 4, 1, W6 if active else BR_L)
    cv.rect(x + 1, y + 2, 1, s - 4, W6 if active else BR_L)
    cv.rect(x + 2, y + s - 2, s - 4, 1, T1 if active else BR_D)
    cv.rect(x + s - 2, y + 2, 1, s - 4, T1 if active else BR_D)
    cv.rect(x + 2, y + 2, s - 4, s - 4, INK)
    if locked:
        cv.rect(x + 3, y + 3, s - 6, s - 6, INK)
    else:
        stone_fill(cv, x + 3, y + 3, s - 6, s - 6)
    if ic and not locked:
        iw, ih = icon_size(ic)
        icon(cv, ic, x + (s - iw) // 2, y + (s - ih) // 2)
    if cool > 0:
        ch = round((s - 6) * cool)
        for j in range(y + 3, y + 3 + ch):
            for i in range(x + 3, x + s - 3):
                if (i + j) % 2 == 0:
                    cv.px(i, j, INK)
    if locked:
        icon(cv, "lock", x + (s - 10) // 2, y + (s - 11) // 2)
    if key:
        keycap(cv, x + s - pwidth(key) - 3, y + s - 6, key, locked)
    if count is not None and not locked:
        cv.ptext(x + s - 3, y + 2, str(count), CREAM, align="r")


def diamond_socket(cv: Canvas, cx: int, cy: int, r: int, *, ic: str | None = None, locked: bool = False, active: bool = False, key: str = "") -> None:
    cv.poly([(cx, cy - r - 1), (cx + r + 1, cy), (cx, cy + r + 1), (cx - r - 1, cy)], INK)
    cv.poly([(cx, cy - r), (cx + r, cy), (cx, cy + r), (cx - r, cy)], T2 if active else BR)
    cv.poly([(cx - r, cy), (cx, cy - r), (cx, cy - r + 2), (cx - r + 2, cy)], W6 if active else BR_L)
    cv.poly([(cx + r, cy), (cx, cy + r), (cx, cy + r - 2), (cx + r - 2, cy)], T1 if active else BR_D)
    cv.poly([(cx, cy - r + 2), (cx + r - 2, cy), (cx, cy + r - 2), (cx - r + 2, cy)], INK)
    inner = [(cx, cy - r + 3), (cx + r - 3, cy), (cx, cy + r - 3), (cx - r + 3, cy)]
    cv.poly(inner, ST1 if not locked else INK)
    for dx, dy in ((0, -r - 3), (r + 3, 0), (-r - 3, 0)):
        gem(cv, cx + dx, cy + dy) if active else cv.px(cx + dx, cy + dy, BR_D)
    if locked:
        icon(cv, "lock", cx - 5, cy - 5)
    elif ic:
        iw, ih = icon_size(ic)
        icon(cv, ic, cx - iw // 2, cy - ih // 2)
    if key:
        keycap(cv, cx - (pwidth(key) + 4) // 2, cy + r + 3, key, locked)


def ribbon(cv: Canvas, x: int, y: int, w: int, text: str, size: float = 6.4) -> None:
    """A swallowtail banner (area names, the speaker's name)."""
    h = 12
    cv.poly([(x - 7, y), (x + w + 7, y), (x + w + 3, y + h // 2), (x + w + 7, y + h - 1), (x - 7, y + h - 1), (x - 3, y + h // 2)], INK)
    cv.poly([(x - 5, y + 1), (x + w + 5, y + 1), (x + w + 2, y + h // 2), (x + w + 5, y + h - 2), (x - 5, y + h - 2), (x - 2, y + h // 2)], BR_D)
    cv.rect(x, y + 1, w, h - 2, BR)
    cv.rect(x, y + 1, w, 1, BR_L)
    cv.rect(x, y + h - 2, w, 1, BR_D)
    cv.rect(x + 1, y + 3, w - 2, h - 6, INK)
    cv.text(x + w / 2, y + 8.2, text, size, CREAM, 800, "ms")


def mob_plate(cv: Canvas, cx: int, y: int, lv: int, name: str, p: float, ghost: float, above: bool = False) -> None:
    w = 36
    x = cx - w // 2
    cv.text(cx + 5, y - 1.5, name, 5.2, CREAM, 800, "ms", outline=1)
    chip = LIL if above else T1
    cv.poly([(x - 1, y + 3), (x + 2, y), (x + 9, y), (x + 12, y + 3), (x + 9, y + 6), (x + 2, y + 6)], INK)
    cv.poly([(x, y + 3), (x + 2, y + 1), (x + 9, y + 1), (x + 11, y + 3), (x + 9, y + 5), (x + 2, y + 5)], chip)
    cv.ptext(x + 4, y + 1, str(lv), CREAM, outline=None) if lv < 10 else None
    bar(cv, x + 12, y + 1, w - 12, 5, p, G5, G6, G3, ghost=ghost)


def damage(cv: Canvas, x: int, y: int, s: str, kind: str = "hit") -> None:
    if kind == "hit":
        cv.ptext(x, y, s, CREAM, 1, INK, "c")
    elif kind == "counter":
        cv.ptext(x, y, s, W6, 2, LIL, "c")
    elif kind == "hurt":
        cv.ptext(x, y, s, SK3, 1, BR_DD, "c")
    elif kind == "heal":
        cv.ptext(x, y, s, G6, 1, G2, "c")


def level_gauge(cv: Canvas, x: int, y: int, h: int, p: float, lv: int) -> None:
    """A carved pillar on the left edge: a violet EXP fill rising behind glass, small bronze nicks every tenth, a gem cap,
    and the level in a bronze shield at its foot."""
    cv.rect(x, y, 12, h, INK)
    cv.rect(x + 1, y + 1, 10, h - 2, BR)
    cv.rect(x + 1, y + 1, 1, h - 2, BR_L)
    cv.rect(x + 10, y + 1, 1, h - 2, BR_D)
    cv.rect(x + 3, y + 3, 6, h - 6, INK)
    inner = h - 8
    fh = round(inner * p)
    cv.rect(x + 4, y + 4, 4, inner, ST1)
    for j in range(y + 4, y + 4 + inner, 3):
        cv.px(x + 5, j, ST2)
    cv.rect(x + 4, y + 4 + inner - fh, 4, fh, LIL)
    cv.rect(x + 4, y + 4 + inner - fh, 4, 1, W6)
    for j in range(y + 6 + inner - fh, y + 4 + inner, 2):
        cv.px(x + 4, j, W5)
    for k in range(1, 10):
        ty = y + 4 + round(inner * k / 10)
        cv.px(x + 1, ty, BR_D)
        cv.px(x + 2, ty, BR_D)
        cv.px(x + 9, ty, BR_L)
    cv.poly([(x - 1, y + 2), (x + 6, y - 6), (x + 13, y + 2)], INK)
    cv.poly([(x + 1, y + 1), (x + 6, y - 4), (x + 11, y + 1)], BR)
    cv.poly([(x + 1, y + 1), (x + 6, y - 4), (x + 6, y + 1)], BR_L)
    gem(cv, x + 6, y - 1)
    sx, sy = x + 6, y + h + 1
    cv.poly([(sx - 10, sy - 2), (sx + 10, sy - 2), (sx + 10, sy + 7), (sx, sy + 15), (sx - 10, sy + 7)], INK)
    cv.poly([(sx - 9, sy - 1), (sx + 9, sy - 1), (sx + 9, sy + 7), (sx, sy + 14), (sx - 9, sy + 7)], BR)
    cv.poly([(sx - 9, sy - 1), (sx + 9, sy - 1), (sx + 9, sy), (sx - 9, sy)], BR_L)
    cv.poly([(sx + 9, sy + 1), (sx + 9, sy + 7), (sx, sy + 14), (sx, sy + 12), (sx + 7, sy + 6)], BR_D)
    cv.poly([(sx - 7, sy + 1), (sx + 7, sy + 1), (sx + 7, sy + 6), (sx, sy + 12), (sx - 7, sy + 6)], INK)
    cv.text(sx + 0.4, sy + 9.0, str(lv), 9, CREAM, 900, "ms")


def medallion(cv: Canvas, cx: int, cy: int, r: int) -> None:
    cv.disc(cx, cy, r + 1, INK)
    cv.disc(cx, cy, r, BR)
    cv.d.pieslice([cx - r, cy - r, cx + r, cy + r], 160, 290, fill=BR_L)
    cv.d.pieslice([cx - r, cy - r, cx + r, cy + r], 340, 110, fill=BR_D)
    cv.disc(cx, cy, r - 2, INK)
    cv.disc(cx, cy, r - 3, ST1)
    cv.disc(cx, cy, r - 5, INK)
    cv.disc(cx, cy, r - 6, ST1)
    for k in range(12):
        a = math.radians(k * 30)
        cv.px(cx + round((r - 4) * math.cos(a)), cy + round((r - 4) * math.sin(a)), ST3)
    for a in (-90, 0, 90, 180):
        gem(cv, cx + round(r * math.cos(math.radians(a))), cy + round(r * math.sin(math.radians(a))))
    icon(cv, "katana", cx - 8, cy - 8)


def backplate(cv: Canvas, pts: list[tuple[int, int]], rail: tuple[int, int, int]) -> None:
    """The carved console the HUD sits on: an ink slab with a dithered stone face and a bronze rail along its top edge."""
    cv.poly(pts, INK)
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    for j in range(min(ys) + 3, max(ys)):
        for i in range(min(xs), max(xs)):
            if (i + j) % 4 == 0 and cv.ui.getpixel((i, j)) == INK:
                cv.px(i, j, ST1)
    x0, x1, yr = rail
    cv.rect(x0, yr, x1 - x0, 1, INK)
    cv.rect(x0 + 1, yr + 1, x1 - x0 - 2, 1, BR_L)
    cv.rect(x0 + 1, yr + 2, x1 - x0 - 2, 1, BR)
    cv.rect(x0 + 1, yr + 3, x1 - x0 - 2, 1, BR_D)
    for i in range(x0 + 6, x1 - 4, 12):
        cv.px(i, yr + 2, W6)


def objective(cv: Canvas, x: int, y: int, text: str, w: int) -> None:
    frame(cv, x, y, w, 16, gems=False)
    cv.grid(x - 3, y + 2, ICON["rune"])
    cv.text(x + 8, y + 10.8, text, 6.0, CREAM, 700)


# ---- scenes ---------------------------------------------------------------------------------------------------------------------

def capture(name: str) -> Image.Image:
    return Image.open(ROOT / name).convert("RGBA").resize((W, H), Image.NEAREST)


def lane(cv: Canvas, x0: int, y0: int, x1: int, y1: int, width: int) -> None:
    """The red charge warning, as the game draws it (a translucent band with a bright rim); a game effect, not UI art."""
    cv.flush()
    over = Image.new("RGBA", cv.big.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(over)
    dx, dy = x1 - x0, y1 - y0
    ln = math.hypot(dx, dy)
    nx, ny = -dy / ln * width / 2, dx / ln * width / 2
    pts = [((x0 + nx) * S, (y0 + ny) * S), ((x1 + nx) * S, (y1 + ny) * S), ((x1 - nx) * S, (y1 - ny) * S), ((x0 - nx) * S, (y0 - ny) * S)]
    d.polygon(pts, fill=(224, 70, 63, 70), outline=(224, 70, 63, 255), width=S)
    cv.big.alpha_composite(over)


def hud_screen() -> Path:
    cv = Canvas(capture("presentation/review/chapter1_expansion/woodland_view_170_260.png"))
    cv.shadow(252, 110, 10)
    cv.sprite("boar_idle_right_1", 252, 110, flip=True)
    cv.shadow(112, 120, 6)
    cv.sprite("mossling_idle_right_1", 112, 120)
    cv.shadow(186, 132, 6)
    cv.sprite("mossling_idle_right_3", 186, 132, flip=True)
    cv.flush()
    lane(cv, 240, 103, 170, 99, 12)
    mob_plate(cv, 250, 84, 2, "Thornback Boar", 0.62, 0.78, above=True)
    mob_plate(cv, 112, 101, 1, "Mossling", 0.35, 0.5)
    mob_plate(cv, 186, 113, 1, "Mossling", 1.0, 1.0)
    damage(cv, 112, 86, "12", "hit")
    damage(cv, 160, 66, "-20", "hurt")
    damage(cv, 250, 64, "36", "counter")
    objective(cv, 26, 6, "Speak to the Elder at the shrine", 138)
    ribbon(cv, 222, 6, 84, "Woodland Approach", 5.8)
    level_gauge(cv, 6, 34, 92, 0.62, 5)
    cv.text(12, 25.5, "LV", 5.0, BR_L, 900, "ms", outline=1)
    # the console
    backplate(cv, [(0, 180), (0, 150), (40, 142), (176, 142), (186, 152), (186, 180)], (40, 176, 142))
    backplate(cv, [(320, 180), (320, 150), (310, 140), (242, 140), (232, 150), (232, 180)], (242, 310, 140))
    medallion(cv, 25, 157, 17)
    slot(cv, 52, 121, 19, ic="herb", key="1", count=3)
    slot(cv, 74, 121, 19, key="2", locked=True)
    hp_bar(cv, 56, 149, 112, 0.86, 0.95, 118, 138)
    bar(cv, 50, 164, 84, 6, 0.72, T2, W6, T1)
    cv.text(138, 169.2, "Edge", 5.0, T2, 800)
    for i, ready in enumerate((True, False)):
        dx = 160 + i * 9
        cv.poly([(dx, 166), (dx + 3, 163), (dx + 6, 166), (dx + 3, 169)], INK)
        cv.poly([(dx + 1, 166), (dx + 3, 164), (dx + 5, 166), (dx + 3, 168)], CREAM if ready else ST3)
    for i, (k, st) in enumerate((("Z", "sprint"), ("X", None), ("C", None))):
        diamond_socket(cv, 254 + i * 23, 156, 10, ic=st, locked=st is None, active=st is not None, key=k)
    cv.text(254, 141.0, "Sprint", 5.0, T2, 800, "ms", outline=1)
    return cv.save("1_hud.png")


def dialogue_screen() -> Path:
    cv = Canvas(capture("presentation/review/chapter1_expansion/current_village_layered.png"))
    cv.veil((20, 16, 26, 80))
    frame(cv, 10, 116, 300, 60, ornate=True, crest=True)
    cv.rect(17, 123, 50, 47, INK)
    cv.rect(18, 124, 48, 45, BR_D)
    cv.rect(18, 124, 48, 1, BR)
    cv.rect(19, 125, 46, 43, INK)
    cv.rect(20, 126, 44, 41, ST1)
    cv.portrait("portrait_tovan_neutral", 20, 124, 44)
    cv.rect(17, 167, 50, 4, INK)
    cv.rect(18, 167, 48, 2, BR_D)
    ribbon(cv, 84, 110, 46, "Tovan", 7.0)
    cv.text(76, 137, "Hold out your hands, Totoy. This is a Black Katana,", 7.2, CREAM, 600)
    cv.text(76, 148, "and it is yours. It was always yours.", 7.2, CREAM, 600)
    cv.text(76, 160, "Remember the colours: gold, parry. Red, dash.", 7.2, ST5, 600)
    cv.poly([(292, 163), (300, 163), (296, 168)], T2)
    keycap(cv, 281, 161, "E")
    cv.ptext(302, 124, "2/5", ST4, outline=None, align="r")
    keycap(cv, 14, 103, "ESC")
    cv.text(33, 109.5, "skip", 5.2, ST5, 700, outline=1)
    return cv.save("2_dialogue.png")


def menu_shell(cv: Canvas, active: int) -> None:
    cv.veil((20, 16, 26, 205))
    frame(cv, 6, 6, 308, 168, ornate=True, crest=True)
    for i, name in enumerate(["Status", "Aspects", "Items", "Quests"]):
        tx = 16 + i * 58
        on = i == active
        cv.poly([(tx, 25), (tx + 5, 13), (tx + 49, 13), (tx + 54, 25)], INK)
        cv.poly([(tx + 1, 25), (tx + 6, 14), (tx + 48, 14), (tx + 53, 25)], BR if on else ST2)
        cv.rect(tx + 6, 14, 42, 1, BR_L if on else ST3)
        if on:
            gem(cv, tx + 27, 13)
        cv.text(tx + 27, 22.6, name, 6.2, INK if on else ST5, 900, "ms")
    cv.rect(10, 25, 300, 1, BR_L)
    cv.rect(10, 26, 300, 1, BR_D)
    keycap(cv, 268, 15, "TAB")
    cv.text(285, 22, "close", 5.2, ST5, 700)


def status_screen() -> Path:
    cv = Canvas(capture("presentation/review/chapter1_expansion/woodland_view_320_125.png"))
    menu_shell(cv, 0)
    frame(cv, 13, 31, 72, 94, gems=True)
    cv.rect(18, 36, 62, 50, ST1)
    cv.portrait("portrait_totoy_neutral", 24, 35, 51)
    cv.rect(18, 86, 62, 1, BR_D)
    cv.text(49, 96.5, "Totoy", 8.4, CREAM, 900, "ms")
    cv.text(49, 104, "Waykeeper", 5.4, T2, 800, "ms")
    cv.ptext(40, 107, "LV 5", CREAM, outline=None) if False else None
    bar(cv, 19, 108, 60, 6, 0.7, LIL, W6, DIRT2)
    cv.ptext(49, 116, "120/170", ST5, outline=None, align="c")
    frame(cv, 13, 127, 72, 43, gems=False)
    for j, (k, v, col) in enumerate((("Health", "138", G6), ("Edge", "100", T2), ("Damage", "+9%", CREAM), ("Dash", "36", CREAM))):
        cv.text(19, 138 + j * 8.4, k, 5.6, ST5, 700)
        cv.ptext(79, 133 + round(j * 8.4), v, col, outline=None, align="r")
    cv.text(93, 38, "Stat points", 7.4, CREAM, 900)
    cv.poly([(162, 31), (204, 31), (208, 35), (204, 39), (162, 39), (158, 35)], INK)
    cv.poly([(162, 32), (204, 32), (207, 35), (204, 38), (162, 38), (159, 35)], LIL)
    cv.ptext(166, 33, "2", CREAM, outline=None)
    cv.text(173, 37.6, "to spend", 5.2, CREAM, 800)
    stats = (("Vitality", "+6 max health a point", 3, G5, G6), ("Might", "+3% damage a point", 3, BR, BR_L), ("Agility", "quicker dash, lighter step", 2, T2, W6))
    for j, (name, desc, pts, c, cl) in enumerate(stats):
        sy = 43 + j * 28
        frame(cv, 91, sy, 112, 26, gems=False)
        cv.text(97, sy + 10, name, 6.6, CREAM, 900)
        cv.text(97, sy + 17.4, desc, 5.2, ST5, 700)
        for k in range(10):
            bx = 97 + k * 7
            cv.poly([(bx, sy + 21), (bx + 3, sy + 18), (bx + 6, sy + 21), (bx + 3, sy + 24)], INK)
            cv.poly([(bx + 1, sy + 21), (bx + 3, sy + 19), (bx + 5, sy + 21), (bx + 3, sy + 23)], c if k < pts else ST2)
            if k < pts:
                cv.px(bx + 3, sy + 19, cl)
        cv.ptext(176, sy + 4, f"{pts}/10", CREAM, outline=None, align="r")
        cv.rect(181, sy + 11, 14, 12, INK)
        cv.rect(182, sy + 12, 12, 10, BR)
        cv.rect(182, sy + 12, 12, 1, BR_L)
        cv.rect(182, sy + 21, 12, 1, BR_D)
        icon(cv, "plus", 184, sy + 14)
    cv.rect(91, 130, 54, 14, INK)
    cv.rect(92, 131, 52, 12, BR_D)
    cv.rect(92, 131, 52, 1, BR)
    cv.rect(92, 142, 52, 1, BR_DD)
    cv.text(118, 139.8, "Respec", 6.4, CREAM, 900, "ms")
    cv.text(150, 139.6, "free in Lanternfen", 5.2, ST5, 700)
    divider(cv, 93, 150, 108)
    cv.text(93, 160, "Level 6 in 50 EXP: +5 health, 2 points", 5.4, ST5, 700)
    cv.text(93, 168, "Gold attacks: parry.  Red attacks: dash.", 5.4, T2, 700)
    cv.text(212, 38, "Loadout", 7.4, CREAM, 900)
    slot(cv, 212, 43, 22, ic="katana", active=True)
    cv.text(238, 52, "Black Katana", 6.6, CREAM, 800)
    cv.text(238, 60, "three-strike combo", 5.2, ST5, 700)
    divider(cv, 212, 70, 94)
    cv.text(212, 80, "Aspects", 5.8, T2, 900)
    for i, (k, st, lab) in enumerate((("Z", "sprint", "Sprint"), ("X", None, "locked"), ("C", None, "locked"))):
        diamond_socket(cv, 226 + i * 29, 96, 10, ic=st, locked=st is None, active=st is not None, key=k)
        cv.text(226 + i * 29, 123, lab, 5.2, CREAM if st else ST4, 800, "ms")
    divider(cv, 212, 128, 94)
    cv.text(212, 138, "Items", 5.8, T2, 900)
    slot(cv, 212, 142, 21, ic="herb", key="1", count=3)
    slot(cv, 236, 142, 21, key="2", locked=True)
    cv.text(262, 151, "Herb", 6.4, CREAM, 800)
    cv.text(262, 158, "heals 35", 5.2, ST5, 700)
    return cv.save("3_status.png")


def aspects_screen() -> Path:
    cv = Canvas(capture("presentation/review/chapter1_expansion/woodland_view_470_260.png"))
    menu_shell(cv, 1)
    cv.text(16, 39, "Owned", 6.4, T2, 900)
    frame(cv, 14, 43, 116, 30, gems=False)
    diamond_socket(cv, 30, 58, 10, ic="sprint", active=True)
    cv.text(46, 55, "Sprint", 7.2, CREAM, 900)
    cv.text(46, 63, "bound by Edda   in socket Z", 5.2, T2, 700)
    cv.text(16, 86, "Not yet found", 6.4, ST5, 900)
    for i, ic in enumerate(("fang", "moon", "shield", "boot", "rune", "fang", "moon", "shield")):
        gx, gy = 16 + (i % 4) * 29, 92 + (i // 4) * 30
        slot(cv, gx, gy, 24, locked=True)
    cv.text(16, 160, "Defeat Aspect creatures to find more.", 5.2, ST5, 700)
    divider(cv, 140, 34, 1) if False else None
    cv.rect(138, 32, 1, 136, BR_D)
    cv.rect(139, 32, 1, 136, INK)
    frame(cv, 146, 32, 160, 70, ornate=False, gems=True)
    diamond_socket(cv, 168, 56, 13, ic="sprint", active=True)
    cv.text(188, 50, "Sprint", 9.0, CREAM, 900)
    cv.text(188, 59, "Aspect of the fleet-footed", 5.4, T2, 700)
    cv.text(152, 80, "Run twice as fast for 3 seconds.", 5.8, CREAM, 700)
    cv.ptext(152, 86, "20", T2, outline=None)
    cv.text(162, 91.4, "Edge", 5.4, ST5, 700)
    cv.ptext(184, 86, "12", T2, outline=None)
    cv.text(194, 91.4, "s cooldown", 5.4, ST5, 700)
    cv.text(152, 98.5, "Works on the road; Edge refills when no foe is near.", 5.0, ST5, 700)
    cv.text(148, 116, "Sockets", 6.4, T2, 900)
    for i, (k, st) in enumerate((("Z", "sprint"), ("X", None), ("C", None))):
        diamond_socket(cv, 172 + i * 34, 136, 12, ic=st, locked=st is None, active=st is not None, key=k)
    cv.text(272, 132, "1 of 3", 6.4, CREAM, 900, "ms")
    cv.text(272, 140, "open", 5.2, ST5, 700, "ms")
    keycap(cv, 150, 157, "Z")
    cv.text(162, 163.4, "equip to socket", 5.2, ST5, 700)
    return cv.save("6_aspects.png")


def cards_screen() -> Path:
    cv = Canvas(capture("presentation/review/chapter1_expansion/current_glade_layered.png"))
    cv.veil((20, 16, 26, 150))
    # training card
    frame(cv, 10, 8, 150, 34, gems=True)
    cv.text(16, 18, "Training  2 of 4", 5.4, T2, 900)
    cv.text(16, 28.5, "Dash through the ring", 7.4, CREAM, 900)
    keycap(cv, 16, 31, "SHIFT")
    cv.text(42, 38.5, "dash", 5.2, ST5, 700)
    for i in range(4):
        dx = 128 + i * 7
        cv.poly([(dx, 14), (dx + 3, 11), (dx + 6, 14), (dx + 3, 17)], INK)
        cv.poly([(dx + 1, 14), (dx + 3, 12), (dx + 5, 14), (dx + 3, 16)], T2 if i < 1 else (CREAM if i == 1 else ST2))
    # welcome
    frame(cv, 168, 8, 142, 34, ornate=True)
    cv.text(239, 22, "Welcome to Lanternfen", 7.4, CREAM, 900, "ms")
    cv.text(239, 32, "Find Mira by the gate to begin.", 5.6, ST5, 700, "ms")
    # task complete
    frame(cv, 10, 50, 150, 26, gems=True)
    slot(cv, 15, 54, 18)
    icon(cv, "check", 19, 59)
    cv.text(38, 62, "Task complete", 6.4, T2, 900)
    cv.text(38, 70.5, "Strike the post three times", 5.4, CREAM, 700)
    cv.ptext(155, 66, "+10", G6, outline=None, align="r")
    # level up
    cv.poly([(166, 63), (176, 51), (300, 51), (310, 63), (300, 75), (176, 75)], INK)
    cv.poly([(168, 63), (177, 52), (299, 52), (308, 63), (299, 74), (177, 74)], BR_D)
    cv.rect(178, 53, 120, 20, BR)
    cv.rect(178, 53, 120, 1, BR_L)
    cv.rect(178, 72, 120, 1, BR_D)
    cv.rect(180, 55, 116, 16, INK)
    gem(cv, 173, 63)
    gem(cv, 303, 63)
    cv.text(238, 66.6, "Level up", 10.5, CREAM, 900, "ms")
    cv.text(238, 82, "Level 5   +5 health   +2 stat points", 5.6, LIL, 800, "ms", outline=1)
    # item received
    frame(cv, 10, 90, 150, 40, crest=True)
    slot(cv, 17, 99, 24, ic="katana", active=True)
    cv.text(47, 103, "Received", 5.6, T2, 900)
    cv.text(47, 114, "Black Katana", 8.2, CREAM, 900)
    cv.text(47, 123, "A worn blade. It was always yours.", 5.2, ST5, 700)
    # aspect bound
    frame(cv, 166, 90, 144, 40, crest=True)
    diamond_socket(cv, 184, 110, 11, ic="sprint", active=True)
    cv.text(201, 103, "Aspect bound", 5.6, T2, 900)
    cv.text(201, 114, "Sprint", 8.2, CREAM, 900)
    keycap(cv, 201, 117, "Z")
    cv.text(212, 123.4, "run twice as fast", 5.2, ST5, 700)
    # drop and gate
    frame(cv, 10, 138, 150, 34, gems=False)
    slot(cv, 15, 143, 24, ic="herb", count=1)
    cv.text(45, 152, "Herb", 7.0, CREAM, 900)
    cv.text(45, 161, "dropped by a Mossling", 5.2, ST5, 700)
    keycap(cv, 45, 163, "1")
    cv.text(53, 169.2, "heals 35", 5.0, G6, 700)
    frame(cv, 166, 138, 144, 34, gems=True)
    icon(cv, "lock", 174, 150)
    cv.text(190, 152, "The rune gate holds", 6.6, CREAM, 900)
    cv.text(190, 162, "Finish your tasks in Lanternfen.", 5.2, ST5, 700)
    return cv.save("4_cards.png")


def sheet_screen() -> Path:
    cv = Canvas(None, (W, H), ST1)
    for j in range(0, H, 2):
        for i in range(j % 4, W, 4):
            cv.px(i, j, ST2) if False else None
    cv.text(8, 11, "Slots", 6.4, T2, 900)
    states = (("ready", dict(ic="herb", key="1", count=2)), ("worn", dict(ic="katana", active=True)), ("cooling", dict(ic="sprint", key="Z", cool=0.4)), ("empty", dict()), ("locked", dict(key="2", locked=True)))
    for i, (lab, kw) in enumerate(states):
        slot(cv, 8 + i * 29, 15, 22, **kw)
        cv.text(19 + i * 29, 45, lab, 5.0, ST5, 700, "ms")
    cv.text(162, 11, "Sockets", 6.4, T2, 900)
    for i, kw in enumerate((dict(ic="sprint", active=True, key="Z"), dict(ic="boot", key="X"), dict(locked=True, key="C"))):
        diamond_socket(cv, 175 + i * 25, 27, 10, **kw)
    cv.text(244, 11, "Medallion", 6.4, T2, 900)
    medallion(cv, 270, 31, 17)
    cv.text(8, 60, "Bars", 6.4, T2, 900)
    hp_bar(cv, 15, 64, 124, 0.6, 0.78, 83, 138)
    bar(cv, 9, 80, 130, 6, 0.55, T2, W6, T1)
    bar(cv, 9, 90, 130, 6, 0.35, LIL, W6, DIRT2)
    cv.text(148, 71.5, "health, the ghost shows the last hit", 5.0, ST5, 700)
    cv.text(148, 85.5, "edge", 5.0, ST5, 700)
    cv.text(148, 95.5, "experience", 5.0, ST5, 700)
    cv.text(8, 110, "Buttons and tabs", 6.4, T2, 900)
    for i, (lab, body_c, top, txt) in enumerate((("Confirm", BR, BR_L, CREAM), ("Back", ST2, ST3, CREAM), ("Locked", INK, ST1, ST3))):
        bx = 8 + i * 50
        cv.rect(bx, 114, 46, 14, INK)
        cv.rect(bx + 1, 115, 44, 12, body_c)
        cv.rect(bx + 1, 115, 44, 1, top)
        cv.rect(bx + 1, 126, 44, 1, BR_D if i == 0 else INK)
        cv.text(bx + 23, 123.8, lab, 6.2, txt, 900, "ms")
    for i, on in enumerate((True, False)):
        tx = 160 + i * 46
        cv.poly([(tx, 128), (tx + 4, 116), (tx + 40, 116), (tx + 44, 128)], INK)
        cv.poly([(tx + 1, 128), (tx + 5, 117), (tx + 39, 117), (tx + 43, 128)], BR if on else ST2)
        cv.text(tx + 22, 125.6, "On" if on else "Off", 6.2, INK if on else ST5, 900, "ms")
    cv.text(256, 110, "Ribbon", 6.4, T2, 900)
    ribbon(cv, 264, 116, 38, "Mira", 6.4)
    cv.text(8, 143, "Mob plates", 6.4, T2, 900)
    mob_plate(cv, 27, 154, 1, "Mossling", 0.9, 0.9)
    mob_plate(cv, 74, 154, 2, "Boar", 0.45, 0.7)
    mob_plate(cv, 121, 154, 4, "Boar", 0.3, 0.3, above=True)
    cv.text(8, 172, "teal chip: your level or below, violet: above you", 5.0, ST5, 700)
    cv.text(176, 143, "Numbers", 6.4, T2, 900)
    for i, (s, k, lab) in enumerate((("12", "hit", "hit"), ("36", "counter", "counter"), ("-20", "hurt", "you hurt"), ("+35", "heal", "heal"))):
        damage(cv, 188 + i * 34, 150 if k != "counter" else 147, s, k)
        cv.text(188 + i * 34, 172, lab, 5.0, ST5, 700, "ms")
    cv.ptext(176, 162, "0123456789 ZXCEQF", CREAM, outline=None) if False else None
    return cv.save("5_sheet.png")


def contact(paths: list[Path]) -> Path:
    ims = [Image.open(p) for p in paths]
    cols = 2
    tw, th = ims[0].width // 2, ims[0].height // 2
    pad = 12
    rows = (len(ims) + cols - 1) // cols
    out = Image.new("RGB", (cols * (tw + pad) + pad, rows * (th + pad) + pad), (28, 24, 36))
    for k, im in enumerate(ims):
        out.paste(im.resize((tw, th), Image.LANCZOS), (pad + (k % cols) * (tw + pad), pad + (k // cols) * (th + pad)))
    path = OUT / "contact.png"
    out.save(path)
    return path


def main() -> None:
    paths = [hud_screen(), dialogue_screen(), status_screen(), cards_screen(), sheet_screen(), aspects_screen()]
    print("\n".join(str(p.relative_to(ROOT)) for p in paths + [contact(paths)]))


if __name__ == "__main__":
    main()
