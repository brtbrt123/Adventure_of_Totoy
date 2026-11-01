"""Pixel-art effects and particles for the mage staff, drawn in code at game scale (review stage, nothing here is in the game).

Owner 2026-11-01, after the first previews: the bursts were inconsistent (frames cut off), the finisher's circle sat on top of the mob
instead of on the ground, the ultimate looked small and unnatural, and nothing had particles. The ultimate follows the owner's
reference sheet (a teal rune circle forming with rocks lifting off the ground, a flaming meteor falling straight down, a fire and rock
explosion, smoke, a cracked crater). Everything here is drawn in code so every frame has the same size and anchor:

    every effect is a Sprite (an RGBA image in Totoy 36 with hard alpha) and an anchor: the GROUND point it stands on
    ground sprites (circles, rings, the crater) are drawn under the characters, air sprites (bursts, fire, the meteor) over them

Colours: the staff's magic is teal and pale blue with cream starlight (t, u, o, p, 1, deep k); the meteor's fire uses the combat
colours gold and red (x, y, z, A) because it is the skill's hit effect (AGENTS.md: gold and red are reserved for combat cues, hit effects
included); the circle stays teal so it never reads as an enemy's red warning.

Particles (Particles below) live on the ground plane with a height: x, gy (the ground y they stand over) and z (height above it), so
a rock thrown by the explosion arcs up, falls, bounces and sorts in depth with the characters by gy. Deterministic: fixed seeds.
Used by tools/art/preview_staff.py (the preview GIFs) and tools/art/export_staff_cutin.py (the cut-in's backdrop strike).
"""
from __future__ import annotations

import json
import math
import random
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
PAL: dict[str, tuple[int, int, int]] = {c["symbol"]: tuple(bytes.fromhex(c["hex"][1:]))
                                         for c in json.loads((ROOT / "art/palette.json").read_text(encoding="utf-8"))["colors"]}
BAYER = ((0, 8, 2, 10), (12, 4, 14, 6), (3, 11, 1, 9), (15, 7, 13, 5))

MAGIC = ["1", "p", "o", "u", "t"]   # bright to dark: the staff's magic
FIRE = ["1", "x", "y", "z", "A"]    # the meteor's fire
ROCK = ("0", "e", "f", "g")         # outline, shade, fill, light


def clamp01(v: float) -> float:
    return 0.0 if v < 0 else 1.0 if v > 1 else v


def ease_out(v: float) -> float:
    return 1 - (1 - clamp01(v)) ** 3


def ease_in(v: float) -> float:
    return clamp01(v) ** 2


def keep(x: int, y: int, alpha: float) -> bool:
    """Ordered dithering: how a hard-alpha pixel fades (a pixel is drawn or not; fewer are drawn as alpha drops)."""
    return alpha >= 1.0 or (alpha > 0.0 and (BAYER[y & 3][x & 3] + 0.5) / 16.0 < alpha)


def ramp(colours: list[str], t: float) -> str:
    return colours[min(len(colours) - 1, int(clamp01(t) * len(colours)))]


class Sprite:
    """An effect frame and its anchor (the ground point it stands on)."""

    def __init__(self, img: Image.Image, ax: int, ay: int) -> None:
        self.img, self.ax, self.ay = img, int(ax), int(ay)


class Canvas:
    """Drawing in Totoy 36 colours with hard alpha. (ax, ay) is the anchor."""

    def __init__(self, w: float, h: float, ax: float = 0, ay: float = 0) -> None:
        self.w, self.h, self.ax, self.ay = int(w), int(h), int(ax), int(ay)
        self.img = Image.new("RGBA", (self.w, self.h), (0, 0, 0, 0))
        self.px = self.img.load()

    def sprite(self) -> Sprite:
        return Sprite(self.img, self.ax, self.ay)

    def put(self, x: float, y: float, sym: str, alpha: float = 1.0, over: bool = True) -> None:
        x, y = int(round(x)), int(round(y))
        if 0 <= x < self.w and 0 <= y < self.h and keep(x, y, alpha) and (over or not self.px[x, y][3]):
            self.px[x, y] = PAL[sym] + (255,)

    def filled(self, x: int, y: int) -> bool:
        return 0 <= x < self.w and 0 <= y < self.h and self.px[x, y][3] > 0

    def line(self, x0: float, y0: float, x1: float, y1: float, sym: str, alpha: float = 1.0, over: bool = True) -> None:
        n = int(max(abs(x1 - x0), abs(y1 - y0))) + 1
        for i in range(n + 1):
            t = i / n
            self.put(x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, sym, alpha, over)

    def arc(self, cx: float, cy: float, rx: float, ry: float, a0: float, a1: float, sym: str, alpha: float = 1.0) -> None:
        """Ellipse arc, degrees on screen (0 = right, 90 = the front/bottom)."""
        steps = max(8, int(abs(a1 - a0) / 360 * (rx + ry) * 5))
        for i in range(steps + 1):
            a = math.radians(a0 + (a1 - a0) * i / steps)
            self.put(cx + math.cos(a) * rx, cy + math.sin(a) * ry, sym, alpha)

    def disc(self, cx: float, cy: float, rx: float, ry: float, sym: str, alpha: float = 1.0, over: bool = True) -> None:
        for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
            dy = (y - cy) / ry if ry > 0 else 0
            if abs(dy) > 1:
                continue
            half = rx * math.sqrt(1 - dy * dy)
            for x in range(int(math.floor(cx - half)), int(math.ceil(cx + half)) + 1):
                if abs(x - cx) <= half + 0.01:
                    self.put(x, y, sym, alpha, over)

    def halo(self, sym: str, alpha: float = 1.0, only: set[str] | None = None) -> None:
        """A 1px ring of `sym` around what is drawn (on empty pixels only)."""
        want = None if only is None else {PAL[s] for s in only}
        src = [(x, y) for y in range(self.h) for x in range(self.w)
               if self.px[x, y][3] and (want is None or self.px[x, y][:3] in want)]
        for x, y in src:
            for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if 0 <= nx < self.w and 0 <= ny < self.h and not self.px[nx, ny][3]:
                    self.put(nx, ny, sym, alpha)

    def paste(self, s: Sprite, x: float, y: float) -> None:
        """Another sprite with its anchor at (x, y) of this canvas (clipped at the edges)."""
        _paste_clipped(self.img, s, x, y)
        self.px = self.img.load()

    def field(self, heat: np.ndarray, bands: list[tuple[float, str]], alpha: np.ndarray | None = None) -> None:
        """Colour a heat field by thresholds (highest first) onto the empty pixels; `alpha` (0..1) fades by dithering."""
        h, w = heat.shape
        arr = np.array(self.img)
        empty = arr[..., 3] == 0
        if alpha is not None:
            bay = np.tile((np.array(BAYER) + 0.5) / 16.0, (h // 4 + 1, w // 4 + 1))[:h, :w]
            empty &= bay < alpha
        done = np.zeros((h, w), bool)
        for thr, sym in bands:
            m = (heat > thr) & ~done & empty
            arr[m] = PAL[sym] + (255,)
            done |= heat > thr
        self.img = Image.fromarray(arr).copy()  # a copy: an image made from an array is read-only
        self.px = self.img.load()


def _paste_clipped(dst: Image.Image, s: Sprite, x: float, y: float) -> None:
    left, top = int(round(x - s.ax)), int(round(y - s.ay))
    if left >= dst.width or top >= dst.height or left + s.img.width <= 0 or top + s.img.height <= 0:
        return
    src = s.img.crop((max(0, -left), max(0, -top), s.img.width, s.img.height))
    dst.alpha_composite(src, (max(0, left), max(0, top)))


# --------------------------------------------------------------------------------------------------- noise
def _hash(ix: np.ndarray, iy: np.ndarray, seed: int) -> np.ndarray:
    h = (ix * 374761393 + iy * 668265263 + seed * 2654435761) & 0xFFFFFFFF
    h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
    return ((h ^ (h >> 16)) & 0xFFFF) / 65535.0


def vnoise(x: np.ndarray, y: np.ndarray, seed: int) -> np.ndarray:
    fx0, fy0 = np.floor(x), np.floor(y)
    fx, fy = x - fx0, y - fy0
    sx, sy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
    ix, iy = fx0.astype(np.int64), fy0.astype(np.int64)
    a, b = _hash(ix, iy, seed), _hash(ix + 1, iy, seed)
    c, d = _hash(ix, iy + 1, seed), _hash(ix + 1, iy + 1, seed)
    return a + (b - a) * sx + (c - a) * sy + (a - b - c + d) * sx * sy


def fbm(x: np.ndarray, y: np.ndarray, seed: int, octaves: int = 3) -> np.ndarray:
    total, amp, norm = np.zeros_like(x, dtype=float), 1.0, 0.0
    for o in range(octaves):
        total += vnoise(x * (2 ** o), y * (2 ** o), seed + o * 17) * amp
        norm += amp
        amp *= 0.5
    return total / norm


def grid(w: int, h: int) -> tuple[np.ndarray, np.ndarray]:
    ys, xs = np.mgrid[0:h, 0:w].astype(float)
    return xs, ys


# --------------------------------------------------------------------------------------------- rock shapes
def _rock_shapes() -> list[list[str]]:
    """Small rocks (2-6 px) as symbol grids: outline ink, a lit top-left, a shaded bottom-right."""
    rng = random.Random(4242)
    shapes = []
    for size in (2, 2, 3, 3, 3, 4, 4, 5, 5, 6, 6, 7):
        c = (size - 1) / 2
        pts = []
        for y in range(size + 2):
            row = ""
            for x in range(size + 2):
                d = math.hypot((x - 1 - c) / (size / 2 + 0.01), (y - 1 - c) / (size / 2 * rng.uniform(0.7, 1.0) + 0.01))
                row += "#" if d <= 1.0 + rng.uniform(-0.25, 0.15) else "."
            pts.append(row)
        rows = [list(r) for r in pts]
        out = []
        for y, row in enumerate(rows):
            line = ""
            for x, ch in enumerate(row):
                if ch != "#":
                    line += "."
                    continue
                edge = any(not (0 <= x + dx < len(row) and 0 <= y + dy < len(rows)) or rows[y + dy][x + dx] != "#"
                           for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
                if size <= 2:
                    line += "e" if (x + y) % 2 else "f"
                elif edge and (x - c - 1) + (y - c - 1) > 0:
                    line += "0"
                elif edge:
                    line += "g" if (x - c - 1) + (y - c - 1) < -1 else "e"
                else:
                    line += "f" if (x - c - 1) + (y - c - 1) < 0.5 else "e"
            out.append(line)
        shapes.append(out)
    return shapes


ROCKS = _rock_shapes()


def rock_sprite(k: int, spin: int = 0) -> Sprite:
    shape = ROCKS[k % len(ROCKS)]
    if spin % 2:
        shape = ["".join(r[i] for r in shape) for i in range(len(shape[0]))][::-1]
    c = Canvas(len(shape[0]), len(shape), len(shape[0]) // 2, len(shape) - 1)
    for y, row in enumerate(shape):
        for x, ch in enumerate(row):
            if ch != ".":
                c.put(x, y, ch)
    return c.sprite()


# ---------------------------------------------------------------------------------------- small magic effects
def cast_flash(i: int) -> Sprite:
    """The staff crystal flaring as he casts (4 frames). Anchor = the crystal."""
    c = Canvas(17, 17, 8, 8)
    arm = [3, 6, 5, 3][i]
    for d in range(1, arm + 1):
        sym = "1" if d <= 1 else "p" if d <= arm // 2 + 1 else "o"
        if i >= 2:
            sym = "o" if d <= 2 else "u"
        for x, y in ((8 + d, 8), (8 - d, 8), (8, 8 + d), (8, 8 - d)):
            c.put(x, y, sym, 1.0 if i < 3 else 0.6)
    if i < 3:
        c.put(8, 8, "1")
        for dx, dy in ((1, 1), (-1, -1), (1, -1), (-1, 1)):
            c.put(8 + dx, 8 + dy, "p" if i < 2 else "o")
    return c.sprite()


def bolt(i: int) -> Sprite:
    """The arcane bolt in flight (it flickers). Anchor = its centre."""
    c = Canvas(9, 9, 4, 4)
    c.disc(4, 4, 1.6, 1.6, "1")
    c.halo("p")
    c.halo("o", 0.6 if i % 2 else 1.0)
    if i % 2 == 0:
        for d in (3, 4):
            for x, y in ((4 + d, 4), (4 - d, 4), (4, 4 + d), (4, 4 - d)):
                c.put(x, y, "o" if d == 3 else "u")
    return c.sprite()


def arcane_burst(i: int, scale: float = 1.0) -> Sprite:
    """The basic attack's small explosion in the air (6 frames, 41x41 at scale 1; the finisher uses a bigger one).
    Anchor = its centre (presentation lifts it off the ground)."""
    size = int(41 * scale) | 1
    c = Canvas(size, size, size // 2, size // 2)
    cx = cy = size // 2
    s_ = scale
    if i == 0:
        c.disc(cx, cy, 2.2 * s_, 2.2 * s_, "1")
        for d in range(3, int(7 * s_)):
            for x, y in ((cx + d, cy), (cx - d, cy), (cx, cy + d), (cx, cy - d)):
                c.put(x, y, "p" if d < 5 * s_ else "o")
        c.halo("o", 1.0, {"1"})
    elif i in (1, 2):
        long_, short, core = (12 * s_, 8 * s_, 3.2 * s_) if i == 1 else (15 * s_, 10 * s_, 4.2 * s_)
        for k in range(16):
            ang = math.radians(k * 22.5 + (11.25 if i == 2 else 0))
            ln = long_ if k % 4 == 0 else short if k % 2 == 0 else short * 0.6
            for s in range(int(ln) + 1):
                f = s / ln
                c.put(cx + math.cos(ang) * s, cy + math.sin(ang) * s, "1" if f < 0.3 else "p" if f < 0.6 else "o" if f < 0.85 else "u")
                if scale > 1.2 and k % 4 == 0 and f < 0.6:  # the long spikes are thicker on the big burst
                    c.put(cx + math.cos(ang) * s - math.sin(ang), cy + math.sin(ang) * s + math.cos(ang), "p")
        c.disc(cx, cy, core, core, "1")
        c.halo("p", 1.0, {"1"})
        if i == 2:
            c.arc(cx, cy, 9 * s_, 9 * s_, 0, 360, "o", 0.55)
        c.halo("t", 0.5)
    elif i == 3:
        c.arc(cx, cy, 12 * s_, 12 * s_, 0, 360, "o")
        c.arc(cx, cy, 13 * s_, 13 * s_, 0, 360, "u", 0.7)
        c.arc(cx, cy, 11 * s_, 11 * s_, 0, 360, "p", 0.5)
        for k in range(8):
            ang = math.radians(k * 45)
            for s in range(int(14 * s_), int(18 * s_)):
                c.put(cx + math.cos(ang) * s, cy + math.sin(ang) * s, "o" if s < 16 * s_ else "u")
        c.disc(cx, cy, 1.5 * s_, 1.5 * s_, "p")
    elif i == 4:
        for k in range(12):
            a0 = k * 30 + 6
            c.arc(cx, cy, 15 * s_, 15 * s_, a0, a0 + 14, "u" if k % 2 else "o")
        c.put(cx, cy, "o")
    else:
        for k in range(10):
            ang = math.radians(k * 36 + 10)
            c.put(cx + math.cos(ang) * 17 * s_, cy + math.sin(ang) * 17 * s_, "t")
            c.put(cx + math.cos(ang) * 16 * s_, cy + math.sin(ang) * 16 * s_, "u", 0.5)
    return c.sprite()


def ground_ring(rx: float, power: float, colours: list[str] | None = None) -> Sprite:
    """A flat ring of light on the ground (rx across, rx*0.38 deep). power 1 = bright and solid, 0 = gone."""
    colours = colours or MAGIC
    ry = rx * 0.38
    c = Canvas(2 * rx + 7, 2 * ry + 7, rx + 3, ry + 3)
    if power <= 0:
        return c.sprite()
    lead = 0 if power > 0.75 else 1 if power > 0.45 else 2
    c.arc(rx + 3, ry + 3, rx, ry, 0, 360, colours[min(len(colours) - 1, lead + 1)], min(1.0, power * 1.4))
    c.arc(rx + 3, ry + 3, rx - 1, ry - 1, 0, 360, colours[lead], min(1.0, power * 1.2))
    if power > 0.5:
        c.arc(rx + 3, ry + 3, rx + 1, ry + 1, 0, 360, colours[min(len(colours) - 1, lead + 3)], 0.5)
    return c.sprite()


def light_column(i: int, n: int, width: int, height: int, colours: list[str] | None = None) -> Sprite:
    """A pillar of light erupting from the ground (n frames: full, then thinning and fading). Anchor = its base."""
    colours = colours or MAGIC
    c = Canvas(width + 8, height + 4, (width + 8) // 2, height + 2)
    t = i / max(1, n - 1)
    w = max(1.0, width * (1 - 0.75 * t))
    top = height * (0.75 + 0.25 * min(1.0, i / 2))
    cx = (width + 8) / 2 - 0.5
    for y in range(int(top) + 1):
        f = y / top
        alpha = clamp01((1 - f) / 0.22) * (1.0 if t < 0.5 else 1.6 - 1.2 * t)
        half = w / 2 * (1 - 0.35 * f)
        shift = min(2, int(f * 3))  # it cools toward the top: each band one step darker
        for x in range(int(cx - half - 2), int(cx + half + 3)):
            d = abs(x - cx) / max(0.6, half)
            band = 0 if d < 0.45 else 1 if d < 0.9 else 2 if d < 1.5 else 3 if d < 2.1 else None
            if band is not None and band + shift < len(colours):
                c.put(x, height + 2 - y, colours[band + shift], alpha)
    return c.sprite()


def twinkle(k: int) -> Sprite:
    """A four-point sparkle (k: 0 small .. 2 big)."""
    arm = (1, 2, 3)[k]
    c = Canvas(2 * arm + 3, 2 * arm + 3, arm + 1, arm + 1)
    for d in range(1, arm + 1):
        for x, y in ((arm + 1 + d, arm + 1), (arm + 1 - d, arm + 1), (arm + 1, arm + 1 + d), (arm + 1, arm + 1 - d)):
            c.put(x, y, "p" if d < arm else "o")
    c.put(arm + 1, arm + 1, "1")
    return c.sprite()


# ------------------------------------------------------------------------------------------------ rune circle
GLYPHS = [["#.#", ".#.", "#.#"], ["###", ".#.", ".#."], ["#..", "###", "..#"], [".#.", "###", ".#."],
          ["##.", ".#.", ".##"], ["#.#", "###", "..."], [".##", "#..", ".##"], ["###", "#.#", "..."]]


def rune_circle(rx: float, draw: float = 1.0, power: float = 1.0, rot: float = 0.0, spikes: float = 0.0, beam: float = 0.0,
                k: int = 0, glyphs: int = 16, fill: bool = False) -> tuple[Sprite, Sprite]:
    """The staff's magic circle lying on the ground: an outer double ring with runes between, a hexagram, a centre ring.

    draw 0..1 traces it in (outer ring, inner ring, runes, hexagram, centre); power 0..1 dim to blazing; rot turns the runes (degrees);
    spikes 0..1 grows rays of light up from the ring; beam 0..1 a beam up from the centre; k is the frame (flicker).
    Returns (ground, air): the circle and the rays behind the characters, and the rays in front plus the beam over them.
    Anchor = the centre of the circle (the ground point under the target)."""
    ry = rx * 0.4
    up = int(rx * 1.4) if (spikes > 0 or beam > 0) else 4
    w, h = int(2 * rx + 9), int(2 * ry + up + 8)
    cx, cy = w // 2, up + int(ry) + 4
    ground, air = Canvas(w, h, cx, cy), Canvas(w, h, cx, cy)
    rng = random.Random(k * 7 + int(rx))
    hot = power >= 0.55
    line, light, edge = ("o", "p", "u") if hot else ("u", "o", "t")
    if power < 0.25:
        line, light, edge = "t", "u", "t"
    rin, rin_y = rx * 0.78, ry * 0.78
    sweep = 360 * clamp01(draw / 0.35)
    s2 = 360 * clamp01((draw - 0.22) / 0.3)
    xs, ys = grid(w, h)
    nx_, ny_ = (xs - cx) / rx, (ys - cy) / ry
    rr = np.sqrt(nx_ * nx_ + ny_ * ny_)
    rel = (np.degrees(np.arctan2(ny_, nx_)) - 90) % 360
    if fill and power > 0.1:  # the ground lit inside the circle (a sparse dither: hard alpha)
        inner = (rr < rin / rx - 0.03) & (rel <= s2)
        ground.field(np.where(inner, 1.0, -1), [(0.5, "t")], alpha=np.full(rr.shape, 0.05 + 0.08 * power))
    if sweep > 0:  # the band between the two rings, solid teal: the runes sit on it
        band = (rr < 1 - 1.5 / rx) & (rr > (rin + 1.0) / rx) & (rel <= sweep)
        ground.field(np.where(band, 1.0, -1), [(0.5, "t" if power >= 0.25 else "k")], alpha=np.full(rr.shape, min(1.0, 0.35 + power)))
        ground.arc(cx, cy, rx + 1, ry + 1, 90, 90 + sweep, "k" if hot else "t", 0.6)
        ground.arc(cx, cy, rx, ry, 90, 90 + sweep, edge)
        ground.arc(cx, cy, rx - 1, ry - 1, 90, 90 + sweep, line)
        if hot:
            ground.arc(cx, cy, rx - 1, ry - 1, 90, 90 + sweep, light, 0.35 + 0.3 * math.sin(k * 0.7) ** 2)
    if s2 > 0:
        ground.arc(cx, cy, rin + 1, rin_y + 1, 270, 270 + s2, line)
        ground.arc(cx, cy, rin, rin_y, 270, 270 + s2, edge)
    for j in range(glyphs):  # runes between the rings, appearing one by one
        if draw < 0.42 + 0.33 * j / glyphs:
            continue
        a = math.radians(j * 360 / glyphs + rot)
        gx, gy = cx + math.cos(a) * rx * 0.89, cy + math.sin(a) * ry * 0.89
        pat = GLYPHS[(j * 3 + int(rot // 45)) % len(GLYPHS)]
        for yy, row in enumerate(pat):
            for xx, ch in enumerate(row):
                if ch == "#":
                    ground.put(gx - 1 + xx, gy - 1 + yy, "1" if hot and (j + k // 3) % 5 == 0 else light)
    hp = clamp01((draw - 0.6) / 0.3)
    if hp > 0:  # the hexagram: two triangles inscribed in the inner ring
        for start in (-90, 90):
            pts = [(cx + math.cos(math.radians(start + 120 * q)) * rin, cy + math.sin(math.radians(start + 120 * q)) * rin_y) for q in range(4)]
            for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
                ground.line(x0, y0, x0 + (x1 - x0) * hp, y0 + (y1 - y0) * hp, line)
    if draw > 0.85:
        ground.arc(cx, cy, rx * 0.2, ry * 0.2, 0, 360, light)
        ground.put(cx, cy, "1" if hot else light)
    if hot:
        ground.halo("k", 0.35 + 0.25 * power)
    if spikes > 0:  # rays of light rising from the ring
        for j in range(12):
            a = math.radians(j * 30 + rot * 0.5 + 15)
            px_, py_ = cx + math.cos(a) * rx, cy + math.sin(a) * ry
            hgt = spikes * (rx * 0.25 + rx * 0.45 * rng.random()) * (0.75 + 0.25 * math.sin(k * 0.9 + j))
            target = air if math.sin(a) > 0 else ground
            for s in range(int(hgt) + 1):
                f = s / max(1, hgt)
                target.put(px_, py_ - s, "1" if f < 0.12 else "p" if f < 0.4 else "o" if f < 0.75 else "u", clamp01((1 - f) / 0.5))
    if beam > 0:  # the beam from the centre
        top = cy - up * beam
        for y in range(int(top), cy + 1):
            f = (cy - y) / max(1, cy - top)
            a = clamp01((1 - f) / 0.6) * (0.75 + 0.25 * math.sin(k * 1.3))
            air.put(cx, y, "1", a)
            air.put(cx - 1, y, "p", a * 0.8)
            air.put(cx + 1, y, "p", a * 0.8)
            air.put(cx - 2, y, "o", a * 0.4)
            air.put(cx + 2, y, "o", a * 0.4)
    return ground.sprite(), air.sprite()


# ------------------------------------------------------------------------------------------------------ meteor
def meteor(t: int, r: int = 9, flame: int = 52, seed: int = 5) -> Sprite:
    """The flaming meteor falling straight down: a rock with a hot underside, wrapped in fire that streams up behind it.
    t flickers the fire. Anchor = the bottom of the rock (where it hits)."""
    w, h = 2 * r + 20, flame + 2 * r + 8
    cx, cy = w / 2 - 0.5, h - r - 4
    c = Canvas(w, h, int(cx + 0.5), int(cy + r + 1))
    xs, ys = grid(w, h)
    up = cy - ys
    half = (r + 6) - np.clip(up, 0, None) * (r + 6) / (flame * 1.15)
    u = (xs - cx) / np.maximum(half, 1.0)
    v = np.clip(up, 0, None) / flame
    n1 = fbm(xs * 0.17, ys * 0.10 + t * 1.9, seed)
    n2 = fbm(xs * 0.33, ys * 0.055 + t * 2.6, seed + 3)
    heat = 1.25 - v * 1.3 - np.abs(u) ** 1.6 * 0.95 + (n1 - 0.5) * 0.85 + (n2 - 0.5) * 0.8 * v
    heat = np.where(up < 0, heat - (-up) / r * 1.1, heat)
    heat = np.where(half < 1.0, -1, heat)
    c.field(heat, [(1.0, "1"), (0.8, "x"), (0.6, "y"), (0.42, "z"), (0.27, "A")])
    rock = Canvas(w, h, c.ax, c.ay)  # the rock on top of the fire
    for y in range(int(cy - r) - 1, int(cy + r) + 2):
        for x in range(int(cx - r) - 1, int(cx + r) + 2):
            dx, dy = x - cx, y - cy
            d = math.hypot(dx, dy)
            if d > r + 0.3:
                continue
            light = (-dx - dy * 1.2) / (r * 1.5)
            sym = "d" if light > 0.45 else "c" if light > 0.15 else "b" if light > -0.2 else "a" if light > -0.5 else "9"
            if dy > r * 0.45 and d > r - 2.2:
                sym = "x" if d > r - 1.2 else "y"  # the hot leading edge
            elif d > r - 0.9:
                sym = "8"
            rock.put(x, y, sym)
    for s in range(26):  # the swirl on the rock face
        a = s / 25 * math.tau * 1.3 + t * 0.15
        rr = r * 0.62 * (s / 25)
        rock.put(cx - 1 + math.cos(a) * rr, cy - 1 + math.sin(a) * rr * 0.9, "9" if s % 3 else "a")
    c.img.alpha_composite(rock.img)
    c.px = c.img.load()
    return c.sprite()


def meteor_shadow(rx: float, power: float) -> Sprite:
    """The meteor's shadow growing on the circle as it comes down."""
    ry = rx * 0.4
    c = Canvas(2 * rx + 4, 2 * ry + 4, rx + 2, ry + 2)
    c.disc(rx + 2, ry + 2, rx, ry, "0", 0.25 + 0.45 * power)
    c.disc(rx + 2, ry + 2, rx * 0.6, ry * 0.6, "0", 0.4 + 0.5 * power)
    return c.sprite()


def fire_ring(i: int, n: int = 5, rx_max: float = 66) -> Sprite:
    """The fire shock ring racing out along the ground at impact (n frames), with flame tongues on its rim. Anchor = centre."""
    t = (i + 1) / n
    rx = 10 + (rx_max - 10) * ease_out(t)
    ry = rx * 0.4
    w, h = int(2 * rx_max + 12), int(2 * rx_max * 0.4 + 30)
    cx, cy = w // 2, h - int(rx_max * 0.4) - 6
    c = Canvas(w, h, cx, cy)
    fade = 1.0 - 0.75 * t
    for d, sym in ((2, "A"), (1, "z"), (0, "y"), (-1, "x"), (-2, "1")):
        if sym == "1" and i > 1:
            continue
        c.arc(cx, cy, rx + d, ry + d * 0.4, 0, 360, sym, fade)
    rng = random.Random(90 + i)
    for j in range(22):  # tongues of flame on the rim
        a = math.radians(j * 360 / 22 + rng.uniform(-6, 6))
        px_, py_ = cx + math.cos(a) * rx, cy + math.sin(a) * ry
        hgt = rng.uniform(3, 10) * (1.2 - t)
        for s in range(int(hgt) + 1):
            f = s / max(1, hgt)
            c.put(px_, py_ - s, "x" if f < 0.3 else "y" if f < 0.6 else "z" if f < 0.85 else "A", fade)
    return c.sprite()


# --------------------------------------------------------------------------------------------------- explosion
EXPLOSION_FRAMES = 12


def explosion(i: int, size: float = 1.0, seed: int = 11) -> Sprite:
    """The meteor's explosion (12 frames): a dome of fire with rocks and teal light in it that grows (0-3), rages (4-6), then
    falls back into rocks and smoke (7-11). size 1 = 150 px across at its biggest. Anchor = the ground point."""
    W, H = int(176 * size), int(132 * size)
    gx, gy = W // 2, int(108 * size)
    c = Canvas(W, H, gx, gy)
    xs, ys = grid(W, H)
    grow = ease_out((i + 1) / 4)
    R = (16 + 52 * grow) * size
    fire = 1.0 if i < 5 else max(0.0, 1 - (i - 4) / 6.5)
    smoke = clamp01((i - 3) / 3) * (1.0 if i < 8 else max(0.0, 1 - (i - 7) / 3.5))
    dx = (xs - gx) / (R * 1.1)
    hy = (gy - ys) / (R * 1.3)
    hy_eff = np.where(hy < 0, hy * 3.4, hy)
    d = np.sqrt(dx * dx + hy_eff * hy_eff)
    n1 = fbm(xs / size * 0.085, ys / size * 0.085 + i * 0.75, seed)
    n2 = fbm(xs / size * 0.16, ys / size * 0.06 + i * 1.4, seed + 5)
    heat = (1 - d) * 1.35 + (n1 - 0.5) * 1.0 + (n2 - 0.5) * 0.9 * np.clip(hy, 0, 1)
    heat = heat * fire - (1 - fire) * 0.35 + (0.25 if i == 0 else 0)
    alive = (hy > -0.3)
    # smoke: the cooler shell, mostly above and behind; solid clouds that grow as the fire dies, then shrink away
    lift = max(0, i - 5) * 4.5 * size  # the cloud rises as it cools
    hs = (gy - lift - ys) / (R * 1.3)
    ds = np.sqrt(dx * dx + (hs - 0.35) ** 2)
    ns = fbm(xs / size * 0.11, ys / size * 0.11 + i * 0.5, seed + 9)
    sm = (1 - ds * 0.95) * 1.2 + (ns - 0.5) * 1.3 - (1 - smoke) * 1.0 - np.clip(0.3 - hs, 0, None) * 2.2
    smoke_heat = np.where((sm > 0.2) & alive, sm, -1)
    fire_bands = [(0.98, "1"), (0.78, "x"), (0.6, "y"), (0.44, "z"), (0.3, "A")]
    c.field(np.where(alive, heat, -1), fire_bands)
    if smoke > 0:
        c.field(smoke_heat, [(0.6, "f"), (0.2, "e")])
    rng = random.Random(seed * 31 + i)
    if fire > 0.5 and i < 6:  # teal light splashing up out of the core (the circle's magic in the blast)
        for s in range(7):
            a = rng.uniform(math.pi * 1.15, math.pi * 1.85)
            ln = R * rng.uniform(0.35, 0.75) * min(1.0, (i + 1) / 2.5)
            bend = rng.uniform(-0.8, 0.8)
            x0, y0 = gx + rng.uniform(-0.2, 0.2) * R, gy - R * 0.15
            for q in range(int(ln)):
                f = q / ln
                aa = a + bend * f
                x, y = x0 + math.cos(aa) * q * 1.1, y0 + math.sin(aa) * q
                sym = "1" if f < 0.35 else "p" if f < 0.7 else "o"
                c.put(x, y, sym)
                if f < 0.7:
                    c.put(x + 1, y, "p" if f < 0.35 else "o")
    rcount = int((10 + 10 * min(1, i / 4)) * size)
    for j in range(rcount):  # rocks thrown up inside the blast
        rr = random.Random(seed * 97 + j)
        a = rr.uniform(math.pi * 1.05, math.pi * 1.95)
        dist = R * (0.35 + 0.1 * i) * rr.uniform(0.5, 1.15)
        x = gx + math.cos(a) * dist * 1.2
        y = gy + math.sin(a) * dist * 0.95 + (i * i * 0.18 * size if i > 6 else 0)
        c.paste(rock_sprite(rr.randrange(len(ROCKS)), j + i), x, y)
    for j in range(int(18 * size)):  # rubble around the base
        rr = random.Random(seed * 53 + j)
        a = rr.uniform(0, math.tau)
        dist = R * rr.uniform(0.5, 1.15)
        c.paste(rock_sprite(rr.randrange(len(ROCKS) - 3), j), gx + math.cos(a) * dist * 1.25, gy + math.sin(a) * dist * 0.28 + 2)
    return c.sprite()


# ------------------------------------------------------------------------------------------------------- crater
def crater(heat: float, fade: float = 1.0, rx: float = 50, seed: int = 21) -> Sprite:
    """The scorched crater the meteor leaves: a dark cracked patch with cracks running out past its rim.
    heat 1..0 the cracks cool from glowing to dark; fade 1..0 it disappears (dithered). Anchor = the centre."""
    ry = rx * 0.36
    w, h = int(2 * rx + 40), int(2 * ry + 26)
    cx, cy = w // 2, h // 2
    c = Canvas(w, h, cx, cy)
    xs, ys = grid(w, h)
    ang = np.arctan2((ys - cy) / ry, (xs - cx) / rx)
    rad = np.sqrt(((xs - cx) / rx) ** 2 + ((ys - cy) / ry) ** 2)
    edge = 1 + (vnoise(np.cos(ang) * 3 + 5, np.sin(ang) * 3 + 5, seed) - 0.5) * 0.28
    inside = rad < edge
    speck = fbm(xs * 0.3, ys * 0.45, seed + 2)
    base = np.where(inside, 1.0 - rad / edge, -1)
    c.field(np.where(inside & (rad > edge - 0.12), 2.0, -1), [(1.5, "8")], alpha=np.full(base.shape, fade))
    c.field(np.where(inside, np.where(speck > 0.62, 0.9, 0.5), -1), [(0.8, "f"), (0.3, "e")], alpha=np.full(base.shape, fade))
    rng = random.Random(seed)
    glow = ["1", "x", "y", "z", "A", "0"]
    gsym = glow[min(len(glow) - 1, int((1 - heat) * (len(glow) - 1) + 0.0001))]
    for j in range(13):  # cracks from near the centre out past the rim
        a = j * math.tau / 13 + rng.uniform(-0.2, 0.2)
        x, y = cx + math.cos(a) * rx * 0.15, cy + math.sin(a) * ry * 0.15
        ln = rng.uniform(1.0, 1.35)
        steps = int(rx * ln)
        for s in range(steps):
            a += rng.uniform(-0.35, 0.35)
            x += math.cos(a) * 1.0
            y += math.sin(a) * 0.4
            outside = ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 > 1
            c.put(x, y, "0" if outside or s < 3 or s > steps * 0.8 else gsym, fade)
            if s > steps * 0.55 and rng.random() < 0.08:  # a branch
                bx, by, ba = x, y, a + rng.choice((-0.9, 0.9))
                for _ in range(rng.randint(3, 7)):
                    bx += math.cos(ba)
                    by += math.sin(ba) * 0.4
                    c.put(bx, by, "0", fade)
    return c.sprite()


# --------------------------------------------------------------------------------------------------- particles
class Particle:
    __slots__ = ("kind", "x", "gy", "z", "vx", "vgy", "vz", "life", "age", "seed", "r0", "r1", "colours", "shape", "tx", "tgy", "tz",
                 "sx", "sgy", "sz", "bounces")

    def __init__(self, kind: str, x: float, gy: float, z: float = 0.0, vx: float = 0.0, vgy: float = 0.0, vz: float = 0.0,
                 life: int = 20, seed: int = 0, r0: float = 1.0, r1: float = 1.0, colours: list[str] | None = None) -> None:
        self.kind, self.x, self.gy, self.z = kind, x, gy, z
        self.vx, self.vgy, self.vz = vx, vgy, vz
        self.life, self.age, self.seed = life, 0, seed
        self.r0, self.r1 = r0, r1
        self.colours = colours or MAGIC
        self.shape = seed % len(ROCKS)
        self.tx = self.tgy = self.tz = 0.0
        self.sx = self.sgy = self.sz = 0.0
        self.bounces = 0


class Particles:
    """A particle system on the ground plane (x, gy) with a height z. step() advances one frame (1/30 s)."""

    GRAVITY = {"spark": 0.07, "fspark": 0.09, "rock": 0.24, "shard": 0.2, "drip": 0.12}

    def __init__(self, seed: int) -> None:
        self.items: list[Particle] = []
        self.rng = random.Random(seed)

    def add(self, *args, **kwargs) -> Particle:
        p = Particle(*args, **kwargs)
        self.items.append(p)
        return p

    # ---- emitters
    def burst(self, kind: str, x: float, gy: float, z: float, n: int, speed: tuple[float, float], up: tuple[float, float],
              life: tuple[int, int], colours: list[str] | None = None, spread: float = 1.0, r: tuple[float, float] = (1, 1)) -> None:
        for _ in range(n):
            a = self.rng.uniform(0, math.tau)
            s = self.rng.uniform(*speed)
            self.add(kind, x + math.cos(a) * spread, gy + math.sin(a) * spread * 0.4, z,
                     math.cos(a) * s, math.sin(a) * s * 0.4, self.rng.uniform(*up), self.rng.randint(*life),
                     self.rng.randrange(1 << 16), r[0], r[1], colours)

    def ring_emit(self, kind: str, x: float, gy: float, rx: float, n: int, up: tuple[float, float], life: tuple[int, int],
                  colours: list[str] | None = None, out: float = 0.0, r: tuple[float, float] = (1, 1), z: float = 0.0) -> None:
        for _ in range(n):
            a = self.rng.uniform(0, math.tau)
            self.add(kind, x + math.cos(a) * rx, gy + math.sin(a) * rx * 0.4, z, math.cos(a) * out, math.sin(a) * out * 0.4,
                     self.rng.uniform(*up), self.rng.randint(*life), self.rng.randrange(1 << 16), r[0], r[1], colours)

    # ---- simulation
    def step(self) -> None:
        alive = []
        for p in self.items:
            p.age += 1
            k = p.kind
            if k in ("spark", "fspark"):
                p.x += p.vx
                p.gy += p.vgy
                p.z += p.vz
                p.vx *= 0.9
                p.vgy *= 0.9
                p.vz = p.vz * 0.92 - self.GRAVITY[k]
                if p.z < 0:
                    p.z, p.vz = 0, 0
            elif k in ("mote", "ember"):
                p.x += p.vx + math.sin(p.age * 0.35 + p.seed) * (0.25 if k == "mote" else 0.35)
                p.gy += p.vgy
                p.z += p.vz
                p.vx *= 0.95
                p.vgy *= 0.95
                p.vz *= 0.985 if k == "mote" else 0.97
            elif k in ("rock", "shard"):
                p.vz -= self.GRAVITY[k]
                p.z += p.vz
                p.x += p.vx
                p.gy += p.vgy
                if p.z <= 0:
                    p.z = 0
                    if p.vz < -0.8 and p.bounces < 2:
                        p.vz = -p.vz * 0.32
                        p.vx *= 0.55
                        p.vgy *= 0.55
                        p.bounces += 1
                    else:
                        p.vz = 0
                        p.vx *= 0.7
                        p.vgy *= 0.7
            elif k in ("smoke", "wisp", "dust"):
                p.x += p.vx + math.sin(p.age * (0.12 if k != "wisp" else 0.3) + p.seed) * (0.18 if k != "wisp" else 0.35)
                p.gy += p.vgy
                p.z += p.vz
                p.vx *= 0.93
                p.vgy *= 0.93
                p.vz *= {"smoke": 0.99, "wisp": 0.97, "dust": 0.9}[k]  # smoke keeps climbing; dust stays low
            elif k == "lift":  # a rock floating up off the ground (the circle forming), bobbing
                p.z = p.tz * ease_out(p.age / 30) + math.sin(p.age * 0.18 + p.seed) * 0.8
            elif k == "seek":  # flies from where it started to its target (the blink's re-forming motes)
                f = ease_out(p.age / p.life)
                p.x = p.sx + (p.tx - p.sx) * f
                p.gy = p.sgy + (p.tgy - p.sgy) * f
                p.z = p.sz + (p.tz - p.sz) * f + math.sin(f * math.pi) * 4
            elif k == "streak":  # a fast mote with a motion smear (the blink's dissolving body)
                p.x += p.vx
                p.gy += p.vgy
                p.z += p.vz
                p.vx *= 0.88
                p.vgy *= 0.88
                p.vz *= 0.9
            if p.age < p.life:
                alive.append(p)
        self.items = alive

    def release_lifts(self, cx: float, cgy: float, power: float) -> None:
        """The floating rocks are blasted out from (cx, cgy) when the meteor lands."""
        for p in self.items:
            if p.kind != "lift":
                continue
            a = math.atan2((p.gy - cgy) * 2.5, p.x - cx)
            p.kind = "rock"
            p.vx, p.vgy = math.cos(a) * power * self.rng.uniform(0.7, 1.2), math.sin(a) * power * 0.4 * self.rng.uniform(0.7, 1.2)
            p.vz = self.rng.uniform(2.0, 3.6)
            p.life, p.age = self.rng.randint(45, 70), 0

    # ---- drawing
    def draw(self, air: Canvas, depth: list, soft: Canvas | None = None) -> None:
        """Sparks, motes and embers onto the air canvas (view coordinates), smoke and wisps onto `soft` (they are lit by the scene,
        not glowing; the air canvas if none); rocks, shards and dust into the depth list as (gy, Sprite, x, y, emissive) so they
        sort with the characters."""
        soft = soft or air
        for p in self.items:
            f = p.age / max(1, p.life)
            x, y = p.x, p.gy - p.z
            k = p.kind
            if k in ("spark", "fspark"):
                sym = ramp(p.colours, f)
                if p.age < 3:
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        air.put(x + dx, y + dy, ramp(p.colours, f + 0.25))
                air.put(x, y, sym)
            elif k == "mote":
                sym = ramp(p.colours, f)
                alpha = clamp01((1 - f) / 0.3)
                if (p.age // 4 + p.seed) % 3 == 0 and f < 0.7:
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        air.put(x + dx, y + dy, ramp(p.colours, f + 0.3), alpha)
                air.put(x, y, sym, alpha)
            elif k == "ember":
                if (p.age + p.seed) % 6 != 0:
                    air.put(x, y, ramp(p.colours, f), clamp01((1 - f) / 0.35))
            elif k in ("smoke", "dust"):
                # solid while young (pixel-art smoke is solid shapes), dithering away only at the end of its life
                r = p.r0 + (p.r1 - p.r0) * ease_out(f)
                alpha = clamp01((1 - f) / 0.3) if k == "smoke" else clamp01((1 - f) / 0.5) * 0.85
                depth.append((p.gy + 0.1, _puff(r, p.colours, alpha, p.seed), x, y, False))
            elif k == "wisp":
                alpha = clamp01((1 - f) / 0.5)
                for s in range(5):
                    a = p.age * 0.25 + s * 0.5 + p.seed
                    soft.put(x + math.cos(a) * (1.5 + s * 0.4), y - s * 0.8 + math.sin(a) * 1.2, ramp(p.colours, f + s * 0.08), alpha)
            elif k == "twinkle":  # a sparkle that swells and shrinks where it is
                size = int(round(math.sin(f * math.pi) * 2.4))
                if size > 0:
                    air.paste(twinkle(min(2, size - 1)), x, y)
                else:
                    air.put(x, y, "o")
            elif k == "streak":
                sym = ramp(p.colours, f)
                air.put(x, y, sym)
                sp = math.hypot(p.vx, p.vgy - p.vz)
                if sp > 0.6:
                    air.put(x - p.vx / sp * 1.2, y - (p.vgy - p.vz) / sp * 1.2, ramp(p.colours, f + 0.3), 0.7)
                    if sp > 1.6:
                        air.put(x - p.vx / sp * 2.4, y - (p.vgy - p.vz) / sp * 2.4, ramp(p.colours, f + 0.5), 0.5)
            elif k in ("rock", "lift"):
                fade = 1.0 if k == "lift" else clamp01((1 - f) / 0.25)
                spr = rock_sprite(p.shape, (p.age // 3) if p.z > 0.5 else 0)
                if fade < 1.0:
                    spr = Sprite(_dither(spr.img, fade), spr.ax, spr.ay)
                if k == "lift" or p.z > 0.5:  # its shadow on the ground
                    depth.append((p.gy - 0.05, _shadow(len(ROCKS[p.shape][0])), p.x, p.gy, False))
                depth.append((p.gy, spr, x, y, False))
            elif k == "shard":
                c = Canvas(3, 4, 1, 3)
                spin = (p.age // 2 + p.seed) % 2
                for yy, row in enumerate(([".p.", "pop", ".o.", ".u."] if spin else ["...", "pou", "...", "..."])):
                    for xx, ch in enumerate(row):
                        if ch != ".":
                            c.put(xx, yy, ch, clamp01((1 - f) / 0.3))
                depth.append((p.gy, c.sprite(), x, y, True))
            elif k == "seek":
                sym = ramp(p.colours, 0.2 + 0.5 * (1 - f))
                air.put(x, y, sym)
                if p.age < 2:
                    air.put(x + 1, y, ramp(p.colours, 0.5))


def _puff(r: float, colours: list[str], alpha: float, seed: int) -> Sprite:
    """A smoke or dust puff: a lumpy cloud (a main blob and two smaller ones at fixed offsets per puff), solid colour."""
    rr = max(1.0, r)
    c = Canvas(2 * rr + 5, 2 * rr + 5, rr + 2, rr + 2)
    rng = random.Random(seed)
    c.disc(rr + 2, rr + 2.5, rr * 0.9, rr * 0.75, colours[0], alpha)
    if rr >= 2.5:
        for _ in range(2):
            a = rng.uniform(math.pi * 0.9, math.pi * 2.1)
            c.disc(rr + 2 + math.cos(a) * rr * 0.45, rr + 2.5 + math.sin(a) * rr * 0.4, rr * 0.55, rr * 0.5, colours[0], alpha)
    if rr >= 2:  # the lower edge darker and the top lighter (it reads as a round puff)
        edge = []
        for x in range(c.w):
            for y in range(c.h):
                if c.filled(x, y) and not c.filled(x, y + 1):
                    edge.append((x, y, colours[min(1, len(colours) - 1)]))
                elif len(colours) > 2 and rr >= 3 and c.filled(x, y) and not c.filled(x, y - 1) and x < rr + 2:
                    edge.append((x, y, colours[2]))
        for x, y, sym in edge:
            c.put(x, y, sym)
    return c.sprite()


def _shadow(w: int) -> Sprite:
    c = Canvas(w + 2, 3, (w + 2) // 2, 1)
    c.disc((w + 2) / 2 - 0.5, 1, w / 2, 0.8, "0", 0.5)
    return c.sprite()


def _dither(img: Image.Image, alpha: float) -> Image.Image:
    out = img.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            if px[x, y][3] and not keep(x, y, alpha):
                px[x, y] = (0, 0, 0, 0)
    return out
