"""The mobile blueprint: how Adventure of Totoy would look and play on a phone (owner 2026-11-02: "make a blueprint for how it is
gonna look if we do a mobile"). A proposal for the owner, not game code.

Built from the real game (presentation/review/mobile/capture_mobile_view.gd captures both):
    art/reference/mobile_v1/source/wide_view.png    the game in a 20:9 window with the expand aspect: a 480x216 view at 3x, the
                                                     desktop HUD hidden
    art/reference/mobile_v1/source/hud_magenta.png  the desktop HUD alone in the normal 16:9 window over magenta; its pieces are
                                                     cut out (magenta keyed away) and moved to their touch positions
The touch controls are drawn here as pixel art at game scale (1 game px = 3 px here, like the captures) in the HUD's colours.
Sizes are in game px and in millimetres on a 6.5 inch 20:9 phone (216 game px tall = 68 mm, so 1 game px = 0.31 mm); a touch
target should be at least 7 mm (about 22 game px).

    python tools/art/mobile_blueprint.py      # writes art/reference/mobile_v1/mobile_blueprint.png and mobile_screen.png
                                              # (the phone's screen alone, 1440x648, no notes: a reference for other tools)
"""
from __future__ import annotations

import json
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "art/reference/mobile_v1/source"
OUT = ROOT / "art/reference/mobile_v1/mobile_blueprint.png"
PAL = {c["symbol"]: tuple(bytes.fromhex(c["hex"][1:])) for c in json.loads((ROOT / "art/palette.json").read_text(encoding="utf-8"))["colors"]}
S = 3  # px per game px (the captures' scale)
VIEW = (480, 216)  # the phone's view in game px (20:9; on a 2400x1080 screen at 5x)
NARROW = 384  # the view's width on a 16:9 screen (as on PC)
MM = 68.0 / 216.0  # mm per game px on a 6.5 inch 20:9 phone

PAPER = (14, 30, 56)
GRID = (22, 43, 76)
GRID_BOLD = (30, 57, 98)
LINE = (150, 205, 240)
INK = (232, 242, 250)
DIM = (160, 188, 216)
ACCENT = (255, 214, 102)

# the desktop HUD's pieces in hud_magenta.png (px at 3x; the opaque bounds)
HUD = {
    "wave": (12, 12, 372, 54),
    "level": (12, 108, 75, 175),
    "medallion": (12, 478, 156, 642),
    "health": (174, 519, 582, 588),
    "edge": (174, 593, 426, 636),
    "dash": (468, 593, 582, 636),
    "items": (618, 552, 792, 636),
    "aspect_z": (804, 516, 915, 636),
    "aspect_x": (918, 516, 1029, 636),
    "aspect_c": (1032, 516, 1143, 636),
}

# ------------------------------------------------------------------------------------------------------------ the layout
# game px on the 480x216 view, origin top-left. The right thumb rests on Attack; the rest sits on two rings around it.
ATTACK = (428, 166)
RING1, RING2 = 50, 96


def _on_ring(r: float, degrees: float) -> tuple[float, float]:
    return ATTACK[0] + r * math.cos(math.radians(degrees)), ATTACK[1] + r * math.sin(math.radians(degrees))


PARRY = _on_ring(RING1, 160)
DASH = _on_ring(RING1, 215)
SKILL = _on_ring(RING1, 265)
ASPECTS = [_on_ring(RING2, a) for a in (170, 200, 230)]
STICK = (64, 160)
STICK_R, KNOB_R = 28, 11
PAUSE = (462, 15)
INTERACT = (227, 32)  # over the altar
SIZES = {"attack": 46, "parry": 32, "dash": 28, "skill": 30, "aspect": 37, "stick": 2 * STICK_R, "pause": 22, "items": 26}


def mm(game_px: float) -> str:
    return f"{game_px * MM:.0f} mm"


def font(size: int, bold: bool = True) -> ImageFont.FreeTypeFont:
    for name in (("segoeuib.ttf", "arialbd.ttf") if bold else ("segoeui.ttf", "arial.ttf")):
        try:
            return ImageFont.truetype(f"C:/Windows/Fonts/{name}", size)
        except OSError:
            continue
    return ImageFont.load_default()


def keyed(path: Path) -> Image.Image:
    """The HUD capture with its magenta background keyed away (anti-aliased text edges un-blended from the magenta)."""
    a = np.asarray(Image.open(path).convert("RGB")).astype(np.float32)
    m = np.clip((np.minimum(a[..., 0], a[..., 2]) - a[..., 1]) / 255.0, 0.0, 1.0)  # how much magenta a pixel holds
    alpha = 1.0 - m
    fg = (a - m[..., None] * np.array([255.0, 0.0, 255.0])) / np.maximum(alpha, 1e-3)[..., None]
    alpha[alpha < 0.15] = 0.0
    out = np.dstack([np.clip(fg, 0, 255), alpha * 255.0]).astype(np.uint8)
    return Image.fromarray(out, "RGBA")


# ------------------------------------------------------------------------------------------------- pixel-art touch controls
class Px:
    """A layer at game scale: pixel art in the palette; translucent fills are allowed (touch controls are runtime UI)."""

    def __init__(self, w: int, h: int) -> None:
        self.img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        self.px = self.img.load()

    def put(self, x: float, y: float, sym: str, alpha: int = 255) -> None:
        x, y = int(round(x)), int(round(y))
        if 0 <= x < self.img.width and 0 <= y < self.img.height:
            self.px[x, y] = PAL[sym] + (alpha,)

    def disc(self, cx: float, cy: float, r: float, sym: str, alpha: int = 255) -> None:
        for y in range(int(cy - r) - 1, int(cy + r) + 2):
            for x in range(int(cx - r) - 1, int(cx + r) + 2):
                if (x - cx) ** 2 + (y - cy) ** 2 <= r * r:
                    self.put(x, y, sym, alpha)

    def ring(self, cx: float, cy: float, r: float, sym: str, alpha: int = 255) -> None:
        for y in range(int(cy - r) - 2, int(cy + r) + 3):
            for x in range(int(cx - r) - 2, int(cx + r) + 3):
                if r - 0.5 <= math.hypot(x - cx, y - cy) < r + 0.5:
                    self.put(x, y, sym, alpha)

    def line(self, x0: float, y0: float, x1: float, y1: float, sym: str, alpha: int = 255) -> None:
        n = int(max(abs(x1 - x0), abs(y1 - y0))) + 1
        for i in range(n + 1):
            self.put(x0 + (x1 - x0) * i / n, y0 + (y1 - y0) * i / n, sym, alpha)

    def arc(self, cx: float, cy: float, r: float, a0: float, a1: float, sym: str, alpha: int = 255) -> None:
        steps = max(8, int(abs(a1 - a0) * r * 1.5))
        for i in range(steps + 1):
            a = a0 + (a1 - a0) * i / steps
            self.put(cx + math.cos(a) * r, cy + math.sin(a) * r, sym, alpha)


def button(p: Px, at: tuple[float, float], size: int, rim: str = "c", inner: str = "9") -> None:
    """A round touch button in the HUD's style: a dark translucent face, a copper rim with a darker inner line, teal studs."""
    cx, cy = at
    r = size / 2
    p.disc(cx, cy, r, "0", 175)
    p.ring(cx, cy, r, rim)
    p.ring(cx, cy, r - 1, inner)
    for a in (math.pi * 0.75, math.pi * 0.25):
        p.put(cx + math.cos(a) * r, cy + math.sin(a) * r, "u")


def icon_parry(p: Px, at: tuple[float, float], r: int) -> None:
    cx, cy = at
    for k in range(r + 1):  # the gold parry diamond, as the game draws a parry
        for sx, sy in ((1, 1), (1, -1), (-1, 1), (-1, -1)):
            p.put(cx + sx * k, cy + sy * (r - k), "x")
            p.put(cx + sx * k * 0.55, cy + sy * (r - k) * 0.55, "y")
    p.disc(cx, cy, 1.6, "1")


def icon_dash(p: Px, at: tuple[float, float]) -> None:
    cx, cy = at
    for dy, ln in ((-4, 7), (0, 10), (4, 7)):
        p.line(cx - 6, cy + dy, cx - 6 + ln, cy + dy, "o")
    p.line(cx + 4, cy - 5, cx + 8, cy, "1")
    p.line(cx + 8, cy, cx + 4, cy + 5, "1")


def icon_skill(p: Px, at: tuple[float, float]) -> None:
    cx, cy = at
    for a in range(8):  # a lilac burst: the weapon's own skill
        ang = a * math.pi / 4 + math.pi / 8
        ln = 8 if a % 2 == 0 else 5
        p.line(cx, cy, cx + math.cos(ang) * ln, cy + math.sin(ang) * ln, "p" if a % 2 == 0 else "v")
    p.disc(cx, cy, 2.2, "1")


def icon_pause(p: Px, at: tuple[float, float]) -> None:
    cx, cy = at
    for dy in (-4, 0, 4):
        p.line(cx - 5, cy + dy, cx + 5, cy + dy, "1")


def icon_tap(p: Px, at: tuple[float, float]) -> None:
    """The interact bubble: a tap mark (a ring and a dot) on a cream bubble with a tail toward what it is over."""
    cx, cy = at
    p.disc(cx, cy, 8, "1", 240)
    p.ring(cx, cy, 8, "9")
    for k in range(1, 5):
        p.line(cx - 4 + k, cy + 7 + k, cx + 4 - k, cy + 7 + k, "1", 240)
        p.put(cx - 4 + k, cy + 7 + k, "9")
        p.put(cx + 4 - k, cy + 7 + k, "9")
    p.ring(cx, cy, 4.5, "9")
    p.disc(cx, cy, 1.6, "9")


def stick(p: Px) -> None:
    p.disc(*STICK, STICK_R, "0", 110)
    p.ring(*STICK, STICK_R, "j", 210)
    p.ring(*STICK, STICK_R - 1, "h", 160)
    for a in range(4):  # direction ticks
        ang = a * math.pi / 2
        p.line(STICK[0] + math.cos(ang) * (STICK_R - 6), STICK[1] + math.sin(ang) * (STICK_R - 6),
               STICK[0] + math.cos(ang) * (STICK_R - 3), STICK[1] + math.sin(ang) * (STICK_R - 3), "i", 210)
    knob = (STICK[0] + 12, STICK[1] - 5)  # pushed toward the Warden
    p.disc(*knob, KNOB_R, "h", 235)
    p.disc(knob[0] - 2, knob[1] - 2, KNOB_R - 4, "j", 235)
    p.ring(*knob, KNOB_R, "9")


def touch_screen(wide: Image.Image, hud: Image.Image, width: int = VIEW[0]) -> Image.Image:
    """The view with the moved HUD and the touch controls. `width` < 480 is a narrower screen (16:9): the left pieces stay at
    the left edge and the right ones at the right edge, so every control keeps its distance from its edge."""
    shift = width - VIEW[0]  # the right-hand pieces move with the right edge
    left_px = (VIEW[0] - width) // 2
    screen = wide.crop((left_px * S, 0, (left_px + width) * S, VIEW[1] * S)).convert("RGBA")
    p = Px(width, VIEW[1])
    stick(p)
    r = lambda at: (at[0] + shift, at[1])  # noqa: E731  (a right-hand position on this screen)
    button(p, r(PARRY), SIZES["parry"], rim="y", inner="9")
    icon_parry(p, r(PARRY), 8)
    button(p, r(DASH), SIZES["dash"])
    icon_dash(p, r(DASH))
    button(p, r(SKILL), SIZES["skill"], rim="v", inner="l")
    icon_skill(p, r(SKILL))
    p.arc(*r(SKILL), SIZES["skill"] / 2 + 2, -math.pi / 2, -math.pi / 2 + math.tau * 0.7, "u")  # its Edge ring, 70 % full
    pause = r(PAUSE)
    p.disc(*pause, SIZES["pause"] / 2, "0", 190)
    p.ring(*pause, SIZES["pause"] / 2, "c")
    icon_pause(p, pause)
    icon_tap(p, (INTERACT[0] - left_px, INTERACT[1]))
    screen.alpha_composite(p.img.resize((width * S, VIEW[1] * S), Image.NEAREST))

    def place(name: str, at: tuple[float, float], centre: bool = False) -> None:
        img = hud.crop(HUD[name])
        x, y = int(round(at[0] * S)), int(round(at[1] * S))
        if centre:
            x, y = x - img.width // 2, y - img.height // 2
        screen.alpha_composite(img, (x, y))

    place("health", (10, 3))
    place("edge", (10, 27))
    place("dash", (99, 27))
    place("level", (150, 3))
    place("wave", (max(width / 2 - 60, 176), 3))  # centred, but never over the level shield
    place("items", (10, 66))
    place("medallion", r(ATTACK), True)
    for at, name in zip(ASPECTS, ("aspect_z", "aspect_x", "aspect_c")):
        place(name, r(at), True)
    return screen


# ------------------------------------------------------------------------------------------------------------ the sheet
def grid(canvas: Image.Image) -> None:
    d = ImageDraw.Draw(canvas)
    for x in range(0, canvas.width, 20):
        d.line([(x, 0), (x, canvas.height)], fill=GRID_BOLD if x % 100 == 0 else GRID, width=1)
    for y in range(0, canvas.height, 20):
        d.line([(0, y), (canvas.width, y)], fill=GRID_BOLD if y % 100 == 0 else GRID, width=1)


def phone(canvas: Image.Image, screen: Image.Image, x: int, y: int, bezel: int = 26) -> tuple[int, int]:
    """A landscape phone around `screen` with its top-left at (x, y); returns the screen's top-left."""
    w, h = screen.size
    d = ImageDraw.Draw(canvas)
    d.rounded_rectangle([x, y, x + w + 2 * bezel, y + h + 2 * bezel], radius=bezel + 22, fill=(10, 12, 18), outline=LINE, width=3)
    sx, sy = x + bezel, y + bezel
    mask = Image.new("L", screen.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, w - 1, h - 1], radius=26, fill=255)
    canvas.paste(screen.convert("RGB"), (sx, sy), mask)
    cam = (sx + 18, sy + h // 2)  # the punch-hole camera, on the left in landscape
    d.ellipse([cam[0] - 9, cam[1] - 9, cam[0] + 9, cam[1] + 9], fill=(4, 4, 6), outline=(40, 44, 56), width=2)
    return sx, sy


def callout(d: ImageDraw.ImageDraw, target: tuple[int, int], label_at: tuple[int, int], bend_x: int, title: str,
            notes: list[str], right: bool) -> None:
    """A blueprint callout: a ring on the target, a line out to `bend_x`, then level to the label."""
    tx, ty = target
    lx, ly = label_at
    d.ellipse([tx - 6, ty - 6, tx + 6, ty + 6], outline=ACCENT, width=3)
    mid = ly + 14
    d.line([(tx, ty), (bend_x, mid), (lx - 10 if right else lx + 10, mid)], fill=ACCENT, width=2)
    x0 = lx if right else lx - max(d.textlength(t, font=font(19, False)) for t in [title] + notes)
    d.text((x0, ly), title, font=font(23), fill=INK)
    for k, t in enumerate(notes):
        d.text((x0, ly + 31 + k * 24), t, font=font(19, False), fill=DIM)


def zones(screen: Image.Image) -> Image.Image:
    """The thumb zones over a dimmed view: where each thumb rests and reaches, the HUD band, the fight, the safe area."""
    out = Image.blend(screen.convert("RGB"), Image.new("RGB", screen.size, (6, 10, 20)), 0.5).convert("RGBA")
    layer = Image.new("RGBA", out.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    w, h = out.size
    d.rectangle([0, 0, w, 48 * S], fill=(120, 170, 255, 60), outline=(150, 200, 255, 230), width=4)
    d.rectangle([0, 48 * S, 200 * S, h], fill=(110, 220, 140, 50), outline=(130, 230, 150, 240), width=4)
    reach = 125 * S
    d.pieslice([ATTACK[0] * S - reach, ATTACK[1] * S - reach, ATTACK[0] * S + reach, ATTACK[1] * S + reach], 150, 290,
               fill=(255, 170, 90, 70), outline=(255, 190, 110, 240), width=4)
    d.rectangle([160 * S, 60 * S, 330 * S, 180 * S], outline=(255, 255, 255, 230), width=4)
    for k in range(0, h, 30):
        d.line([(12 * S, k), (12 * S, k + 15)], fill=(255, 255, 255, 230), width=4)
    out.alpha_composite(layer)
    return out


def main() -> int:
    wide = Image.open(SRC / "wide_view.png").convert("RGBA")
    assert wide.size == (VIEW[0] * S, VIEW[1] * S), wide.size
    hud = keyed(SRC / "hud_magenta.png")
    screen = touch_screen(wide, hud)

    W, H = 2560, 1470
    canvas = Image.new("RGB", (W, H), PAPER)
    grid(canvas)
    d = ImageDraw.Draw(canvas)
    d.text((60, 34), "Adventure of Totoy on a phone: blueprint", font=font(46), fill=INK)
    d.text((62, 96), "Landscape, 20:9 (e.g. 2400x1080 at 5x). The picture is the real game, captured in a phone-shaped window: the "
                     "desktop HUD moves to the top, touch controls are added. A proposal for review.", font=font(21, False), fill=DIM)
    pw = VIEW[0] * S + 52
    px0 = (W - pw) // 2
    py0 = 170
    sx, sy = phone(canvas, screen, px0, py0)
    sw, sh = VIEW[0] * S, VIEW[1] * S

    def at(g: tuple[float, float]) -> tuple[int, int]:
        return int(sx + g[0] * S), int(sy + g[1] * S)

    lx, rx = px0 - 50, px0 + pw + 50  # label columns: right-aligned on the left, left-aligned on the right
    lb, rb = px0 - 18, px0 + pw + 18  # where the lines bend
    callout(d, at((70, 12)), (lx, 180), lb, "Health, Edge, Dash", ["The desktop bars, moved to the top:", "thumbs cover the bottom corners."], False)
    callout(d, at((160, 15)), (lx, 320), lb, "Level", ["The EXP pillar shrinks to its shield;", "the full bar is in the menu."], False)
    callout(d, at((38, 80)), (lx, 460), lb, "Items 1 and 2 (herb)", ["Tap to use; above the stick.", f"{SIZES['items']} game px = {mm(SIZES['items'])}."], False)
    callout(d, at(STICK), (lx, 610), lb, "Move: floating stick", ["It appears where the left thumb lands", "(green zone below). Attacks and skills",
                                                                  "already go where he moves.", f"Base {mm(SIZES['stick'])}."], False)
    callout(d, at((240, 10)), (rx, 180), rb, "Wave / objective", ["Top centre, as on PC."], True)
    callout(d, at(INTERACT), (rx, 270), rb, "Interact: tap the bubble", ["Over people and objects (was E).", "Dialogue: tap anywhere to go on."], True)
    callout(d, at(PAUSE), (rx, 385), rb, "Pause and character menu", ["Replaces Tab. Rewards pop in", "under it, as on PC's right side."], True)
    callout(d, at(ASPECTS[2]), (rx, 500), rb, "Aspects Z, X, C", ["The real slots become buttons on", "the outer ring; cooldowns as on PC."], True)
    callout(d, at(SKILL), (rx, 615), rb, "Weapon skill (right click on PC)", ["Black Katana, Lightning Form, Reaper's", "Coil, Disintegration; the ring is Edge."], True)
    callout(d, at(DASH), (rx, 730), rb, "Dash", [f"{SIZES['dash']} game px = {mm(SIZES['dash'])}."], True)
    callout(d, at(PARRY), (rx, 815), rb, "Parry: the gold diamond", ["The thumb rolls left onto it from", f"Attack: the timing button, {mm(SIZES['parry'])}."], True)
    callout(d, at(ATTACK), (rx, 925), rb, "Attack: the weapon medallion", ["Tap to swing, hold to keep the combo going.", f"The biggest button: {mm(SIZES['attack'])}."], True)

    # the lower row: thumb zones, the 16:9 screen, what it takes
    ly = sy + sh + 120
    small = 0.4
    zone_img = zones(screen)
    zw, zh = int(zone_img.width * small), int(zone_img.height * small)
    x1 = 60
    d.text((x1, ly), "Thumb zones and safe area", font=font(30), fill=INK)
    canvas.paste(zone_img.resize((zw, zh), Image.LANCZOS).convert("RGB"), (x1, ly + 48))
    d.rectangle([x1, ly + 48, x1 + zw, ly + 48 + zh], outline=LINE, width=2)
    for k, (col, t) in enumerate([((110, 220, 140), "Left thumb: move (the stick floats anywhere in the green box)"),
                                  ((255, 180, 100), "Right thumb: attack, parry, dash, skills (orange: its reach)"),
                                  ((140, 190, 255), "HUD band at the top: bars, wave, pause"),
                                  ((255, 255, 255), "White box: the fight stays clear. Dashed: the camera's inset")]):
        yy = ly + 62 + zh + k * 30
        d.rectangle([x1, yy + 5, x1 + 18, yy + 21], fill=col)
        d.text((x1 + 30, yy), t, font=font(19, False), fill=DIM)

    narrow = touch_screen(wide, hud, NARROW)
    x2 = x1 + zw + 80
    nw, nh = int(narrow.width * small), int(narrow.height * small)
    d.text((x2, ly), "16:9 phones and tablets", font=font(30), fill=INK)
    canvas.paste(narrow.resize((nw, nh), Image.LANCZOS).convert("RGB"), (x2, ly + 48))
    d.rectangle([x2, ly + 48, x2 + nw, ly + 48 + nh], outline=LINE, width=2)
    for k, t in enumerate([f"The same controls, the same distance from each edge.",
                           f"The view is {NARROW} x 216 game px, as on PC; a 20:9 phone",
                           f"sees {VIEW[0]} x 216 (more world to the sides).",
                           "Tablets: the same at a bigger whole scale."]):
        d.text((x2, ly + 62 + nh + k * 28), t, font=font(19, False), fill=DIM)

    x3 = x2 + nw + 80
    d.text((x3, ly), "What it takes", font=font(30), fill=INK)
    notes = [
        ("The same game: the core already takes one input", DIM),
        ("frame (move, attack, parry, dash, weapon skill,", DIM),
        ("aspects 1-3, interact, items). A touch layer fills", DIM),
        ("it; no rule changes. Aiming follows movement.", DIM),
        ("", DIM),
        ("Screen: stretch aspect 'expand' with whole scaling;", DIM),
        ("the HUD anchored to the corners, inside the safe", DIM),
        ("area (notches, rounded corners).", DIM),
        ("", DIM),
        ("Your call: a wider parry window on touch?", ACCENT),
        ("(no key to feel; now 14 ticks, perfect within 6)", DIM),
        ("Also: haptics on parries and hits, and a quality", DIM),
        ("switch for lighting and particles on older phones.", DIM),
    ]
    for k, (t, col) in enumerate(notes):
        d.text((x3, ly + 52 + k * 27), t, font=font(19, False), fill=col)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(OUT)
    screen.convert("RGB").save(OUT.with_name("mobile_screen.png"))
    print("wrote", OUT, canvas.size, "and", OUT.with_name("mobile_screen.png").name)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
