"""Preview GIFs of the mage staff at game scale (review stage, nothing here is in the game).

The hero's poses are the 8 key poses cut from the staff concept (tools/art/import_staff_concept.py); every effect and particle is
drawn in code by tools/art/staff_fx.py, so each frame has the same size and anchor. The Warden's in-game frames are the target, on
a piece of the Hollow Trial floor, shown 4x. Layers work like the game will: circles, rings and the crater lie on the ground under
the characters; rocks, shards and dust sort in depth with them; bursts, fire, the meteor, sparks and smoke are drawn over them.
Presentation-side touches the game can do too: light from the fire and the magic on the ground, the scene darkening while the
ultimate is cast, camera shake, a hit flash, and the Hollow Trial's scene look (glow, colour grade, vignette:
presentation/effects/looks/hollow_trial_layered.tres) applied the way scene_post.gdshader does it.

    staff_attack.gif     the basic attack: two Arcane Bursts (cast, bolt, burst), then the Great Burst finisher (a small circle
                         under the target, then a pillar of light)
    staff_blink.gif      the blink dash: he breaks into light, streaks forward and re-forms
    staff_ultimate.gif   Disintegration, after the owner's reference: the circle forms with rocks lifting off the ground, it
                         charges, he calls the meteor, it falls straight down, the blast, smoke, the cracked crater cooling

Output: art/reference/staff_v1/preview/. Run from the project root:
    python tools/art/preview_staff.py [attack|blink|ultimate ...]
"""
from __future__ import annotations

import json
import math
import random
import sys
from functools import lru_cache
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import staff_fx as F  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
IMPORTED = ROOT / "art/reference/staff_v1/imported"
OUT = ROOT / "art/reference/staff_v1/preview"
FLOOR = ROOT / "presentation/forest/hollow_trial_layered_ground.png"
ZOOM = 4
VIEW = (136, 98, 376, 233)  # the floor piece (game px), 240x135
VW, VH = VIEW[2] - VIEW[0], VIEW[3] - VIEW[1]
FPS = 30
HERO = (50, 100)    # the hero's feet (view px)
TARGET = (162, 104)  # the Warden's feet
# where the staff's crystal is in each pose, from the feet (measured on the imported frames)
CRYSTAL = {1: (10, -30), 3: (23, -24), 4: (7, -40), 5: (6, -31), 6: (12, -29), 8: (5, -38)}
WARM = (1.0, 0.62, 0.28)
TEAL = (0.45, 0.95, 0.9)
# the Hollow Trial's scene look (scene_look.gd defaults with the trial's overrides)
LOOK = {"exposure": 1.04, "contrast": 1.08, "saturation": 1.06, "shadow": (0.9, 0.95, 1.1), "highlight": (1.06, 1.0, 0.92),
        "vig_strength": 0.48, "vig_radius": 0.95, "vig_soft": 0.6, "vig_colour": (0.03, 0.03, 0.07),
        "glow_strength": 0.7, "glow_threshold": 0.62, "glow_radius": 5.0}

SETS = json.loads((IMPORTED / "imported.json").read_text(encoding="utf-8"))["sets"]
SPRITES = json.loads((ROOT / "art/build/sprites.json").read_text(encoding="utf-8"))["frames"]
FLOOR_IMG = Image.open(FLOOR).convert("RGBA")


@lru_cache(maxsize=None)
def hero(pose: int) -> F.Sprite:
    m = SETS["hero"][pose - 1]
    return F.Sprite(Image.open(IMPORTED / m["file"]).convert("RGBA"), m["ax"], m["ay"])


@lru_cache(maxsize=None)
def warden(name: str) -> F.Sprite:
    """The Warden facing left (toward the hero): its right-facing frame mirrored around the anchor."""
    m = SPRITES[name]
    img = Image.open(ROOT / "art/build/sprites" / f"{name}.png").convert("RGBA").transpose(Image.FLIP_LEFT_RIGHT)
    return F.Sprite(img, img.width - 1 - m["ax"], m["ay"])


def warden_frame(k: int, hurt: bool) -> F.Sprite:
    if hurt:
        return warden(f"warden_hurt_right_{1 + (k // 4) % 2}")
    return warden(f"warden_idle_right_{1 + (k // 5) % 6}")


cached_explosion = lru_cache(maxsize=None)(F.explosion)
cached_meteor = lru_cache(maxsize=None)(lambda t: F.meteor(t, r=13, flame=74))
cached_burst = lru_cache(maxsize=None)(F.arcane_burst)
cached_column = lru_cache(maxsize=None)(F.light_column)
cached_fire_ring = lru_cache(maxsize=None)(F.fire_ring)


@lru_cache(maxsize=None)
def cached_crater(heat: float, fade: float) -> F.Sprite:
    return F.crater(heat, fade)


def tint(img: Image.Image, dim: float = 0.0, flash: float = 0.0) -> Image.Image:
    """Darken (the ultimate's night) or flash toward cream (a hit); alpha stays hard."""
    if dim <= 0 and flash <= 0:
        return img
    a = np.asarray(img).astype(np.float32)
    rgb = a[..., :3]
    if dim > 0:
        rgb = rgb * (1 - dim) + dim * np.array([8, 10, 26], np.float32)
    if flash > 0:
        rgb = rgb * (1 - flash) + flash * np.array(F.PAL["1"], np.float32)
    a[..., :3] = rgb
    return Image.fromarray(a.clip(0, 255).astype(np.uint8))


class Shot:
    """One frame: the floor, ground effects, characters and rocks in depth order, smoke, then effects and particles on top."""

    def __init__(self, cam: tuple[int, int] = (0, 0), dim: float = 0.0, flash: float = 0.0) -> None:
        self.cam, self.dim, self.flash = cam, dim, flash
        self.ground: list = []
        self.depth: list = []
        self.air: list = []
        self.lights: list = []
        self.air_px = F.Canvas(VW, VH)
        self.soft_px = F.Canvas(VW, VH)

    def on_ground(self, s: F.Sprite, x: float, y: float, emissive: bool = True) -> None:
        self.ground.append((s, x, y, emissive))

    def actor(self, s: F.Sprite, x: float, gy: float, hit: float = 0.0, shadow: float = 0.0) -> None:
        self.depth.append((gy, s, x, gy, False, hit, shadow))

    def over(self, s: F.Sprite, x: float, y: float, emissive: bool = True) -> None:
        self.air.append((s, x, y, emissive))

    def light(self, x: float, y: float, radius: float, colour: tuple[float, float, float], strength: float) -> None:
        if strength > 0.01:
            self.lights.append((x, y, radius, colour, strength))

    def particles(self, p: F.Particles) -> None:
        extra: list = []
        p.draw(self.air_px, extra, self.soft_px)
        for gy, s, x, y, em in extra:
            self.depth.append((gy, s, x, y, em, 0.0, 0.0))

    def _place(self, dst: Image.Image, s: F.Sprite, x: float, y: float, dim: float = 0.0, flash: float = 0.0) -> None:
        img = tint(s.img, dim, flash)
        F._paste_clipped(dst, F.Sprite(img, s.ax, s.ay), x - self.cam[0], y - self.cam[1])

    def render(self) -> Image.Image:
        cx, cy = self.cam
        img = tint(FLOOR_IMG.crop((VIEW[0] + cx, VIEW[1] + cy, VIEW[2] + cx, VIEW[3] + cy)), self.dim)
        for s, x, y, em in self.ground:
            self._place(img, s, x, y, 0.0 if em else self.dim)
        shadows = Image.new("RGBA", img.size, (0, 0, 0, 0))
        sh = shadows.load()
        for gy, s, x, y, em, hit, shadow in self.depth:  # soft presentation shadows under the characters
            if shadow > 0:
                rx, ry = shadow, shadow * 0.32
                for yy in range(int(gy - ry - 1), int(gy + ry + 2)):
                    for xx in range(int(x - rx - 1), int(x + rx + 2)):
                        d = ((xx - x) / rx) ** 2 + ((yy - gy) / ry) ** 2
                        px_, py_ = int(xx - cx), int(yy - cy)
                        if d < 1 and 0 <= px_ < VW and 0 <= py_ < VH:
                            sh[px_, py_] = (16, 12, 24, 120 if d < 0.55 else 70)
        img.alpha_composite(shadows)
        for gy, s, x, y, em, hit, shadow in sorted(self.depth, key=lambda d: d[0]):
            self._place(img, s, x, y, 0.0 if em else self.dim, hit)
        if self.lights:  # light from the fire and the magic on everything below the effects
            ys, xs = np.mgrid[0:VH, 0:VW].astype(np.float32)
            lmap = np.zeros((VH, VW, 3), np.float32)
            for lx, ly, r, col, st in self.lights:
                d = np.sqrt(((xs - (lx - cx)) / r) ** 2 + ((ys - (ly - cy)) / (r * 0.55)) ** 2)
                lmap += (np.clip(1 - d, 0, 1) ** 2)[..., None] * np.array(col, np.float32) * st
            a = np.asarray(img).astype(np.float32)
            a[..., :3] = a[..., :3] * (1 + lmap * 0.9) + lmap * 38
            img = Image.fromarray(a.clip(0, 255).astype(np.uint8))
        soft = tint(self.soft_px.img, self.dim * 0.6)
        img.alpha_composite(soft, (0, 0))
        for s, x, y, em in self.air:
            self._place(img, s, x, y, 0.0 if em else self.dim)
        img.alpha_composite(self.air_px.img)
        out = scene_look(img.convert("RGB").resize((VW * ZOOM, VH * ZOOM), Image.NEAREST))
        if self.flash > 0:  # a screen flash sits over the scene look (like a flash on the HUD layer), so it does not bloom
            out = Image.blend(out, Image.new("RGB", out.size, F.PAL["1"]), self.flash)
        return out


_VIG = None


def scene_look(img: Image.Image) -> Image.Image:
    """The scene look the way scene_post.gdshader draws it: glow from bright pixels (three rings of eight taps), colour grade,
    vignette."""
    global _VIG
    c = np.asarray(img).astype(np.float32) / 255.0
    h, w, _ = c.shape
    reach_max = int(LOOK["glow_radius"] * ZOOM) + 2
    pad = np.pad(c, ((reach_max, reach_max), (reach_max, reach_max), (0, 0)), mode="edge")
    b = pad.max(axis=2)
    wgt = np.clip((b - LOOK["glow_threshold"]) / 0.22, 0, 1)
    wgt = wgt * wgt * (3 - 2 * wgt)
    bright = pad * wgt[..., None]
    spill = np.zeros_like(c)
    total = 0.0
    for ring in (1, 2, 3):
        reach = LOOK["glow_radius"] * ZOOM * ring / 3
        for k in range(8):
            ang = k * 0.7853982 + ring * 0.39
            dx, dy = int(round(math.cos(ang) * reach)), int(round(math.sin(ang) * reach))
            spill += bright[reach_max + dy:reach_max + dy + h, reach_max + dx:reach_max + dx + w] / ring
            total += 1 / ring
    c = c + spill / total * LOOK["glow_strength"]
    c = c * LOOK["exposure"]
    luma = (c * np.array([0.299, 0.587, 0.114], np.float32)).sum(axis=2, keepdims=True)
    c = luma + (c - luma) * LOOK["saturation"]
    c = (c - 0.5) * LOOK["contrast"] + 0.5
    t = np.clip((luma - 0.05) / 0.8, 0, 1)
    t = t * t * (3 - 2 * t)
    c = c * (np.array(LOOK["shadow"], np.float32) * (1 - t) + np.array(LOOK["highlight"], np.float32) * t)
    if _VIG is None or _VIG.shape[:2] != (h, w):
        ys, xs = np.mgrid[0:h, 0:w].astype(np.float32)
        d = np.sqrt((xs / w - 0.5) ** 2 + (ys / h - 0.5) ** 2) * 1.414
        e = np.clip((d - (LOOK["vig_radius"] - LOOK["vig_soft"])) / LOOK["vig_soft"], 0, 1)
        _VIG = (e * e * (3 - 2 * e) * LOOK["vig_strength"])[..., None]
    c = c * (1 - _VIG) + np.array(LOOK["vig_colour"], np.float32) * _VIG
    return Image.fromarray((c.clip(0, 1) * 255).astype(np.uint8))


def save(frames: list[Image.Image], name: str, hold: int = 12) -> None:
    """GIF at 30 fps with one palette for every frame (so unchanged areas compress)."""
    OUT.mkdir(parents=True, exist_ok=True)
    frames = frames + [frames[-1]] * hold
    sample = frames[:: max(1, len(frames) // 20)]
    sw, sh = frames[0].width // 2, frames[0].height // 2
    mosaic = Image.new("RGB", (sw, sh * len(sample)))
    for i, f in enumerate(sample):
        mosaic.paste(f.resize((sw, sh), Image.NEAREST), (0, i * sh))
    pal = mosaic.quantize(colors=255, method=Image.Quantize.MEDIANCUT)
    q = [f.quantize(palette=pal, dither=Image.Dither.NONE) for f in frames]
    durations = [40 if i % 3 == 2 else 30 for i in range(len(q))]  # averages 33.3 ms: 30 fps
    q[0].save(OUT / name, save_all=True, append_images=q[1:], duration=durations, loop=0, disposal=1)
    print(name, len(frames), "frames", round((OUT / name).stat().st_size / 1e6, 1), "MB")


def shake_at(rng: random.Random, amp: float) -> tuple[int, int]:
    if amp < 0.5:
        return (0, 0)
    return (int(round(rng.uniform(-amp, amp))), int(round(rng.uniform(-amp, amp) * 0.6)))


def crystal(pose: int, at: tuple[float, float]) -> tuple[float, float]:
    dx, dy = CRYSTAL[pose]
    return (at[0] + dx, at[1] + dy)


def draw_trail(c: F.Canvas, x0: float, y0: float, x1: float, y1: float, colours: list[str]) -> None:
    """A tapering trail from the head (x1, y1) back toward (x0, y0)."""
    n = int(max(abs(x1 - x0), abs(y1 - y0))) + 1
    for i in range(n + 1):
        f = i / n
        c.put(x1 + (x0 - x1) * f, y1 + (y0 - y1) * f, F.ramp(colours, f), F.clamp01((1 - f) / 0.6))


# ------------------------------------------------------------------------------------------------- the attack
def attack() -> list[Image.Image]:
    P = F.Particles(7)
    rng = random.Random(70)
    frames = []
    hits = [(8, (TARGET[0] - 6, TARGET[1] + 1)), (38, (TARGET[0] + 2, TARGET[1] + 2))]
    BOLT = 4
    FIN, ERUPT, END = 66, 80, 126
    react = {"t": -99, "power": 0.0}
    for k in range(END):
        if FIN - 4 <= k < FIN + 4:
            pose = 4
        elif FIN + 4 <= k < ERUPT + 14:
            pose = 5
        else:
            pose = 1
            for t0, _ in hits:
                if t0 - 2 <= k < t0 + BOLT + 1:
                    pose = 3
        since = k - react["t"]
        amp = react["power"] * 2.2 * (0.7 ** since) if since >= 0 else 0
        shot = Shot(cam=shake_at(rng, amp))
        knock = react["power"] * 3 * max(0.0, 1 - since / 10) if since >= 0 else 0
        hurt = 0 <= since < 10
        shot.actor(warden_frame(k, hurt), TARGET[0] + knock, TARGET[1], hit=max(0.0, 0.85 - since * 0.22) if since >= 0 else 0,
                   shadow=22)
        shot.actor(hero(pose), *HERO, shadow=9)
        for t0, g in hits:  # cast, bolt, burst
            cx, cy = crystal(3, HERO)
            centre = (g[0], g[1] - 15)
            if t0 <= k < t0 + 4:
                shot.over(F.cast_flash(k - t0), cx, cy)
                shot.light(cx, cy + 20, 26, TEAL, 0.5)
            if t0 + 1 <= k < t0 + 1 + BOLT:
                f = (k - t0) / BOLT
                bx, by = cx + (centre[0] - cx) * f, cy + (centre[1] - cy) * f
                draw_trail(shot.air_px, cx, cy, bx, by, ["1", "p", "o", "u", "t"])
                shot.over(F.bolt(k), bx, by)
                P.add("mote", bx, by + 14, 14, rng.uniform(-0.3, 0.3), 0, rng.uniform(0.1, 0.3), rng.randint(8, 14), rng.randrange(999))
                shot.light(bx, by + 16, 24, TEAL, 0.45)
            if k == t0 + 1 + BOLT:
                P.burst("spark", g[0], g[1], 13, 18, (1.2, 2.8), (0.4, 2.2), (10, 18))
                P.burst("mote", g[0], g[1], 12, 6, (0.2, 0.6), (0.25, 0.5), (24, 40))
                P.burst("dust", g[0], g[1], 0, 6, (0.4, 1.0), (0.02, 0.06), (14, 22), ["d", "c"], spread=6, r=(1.0, 3.0))
                react.update(t=k, power=0.6)
            b = k - (t0 + 1 + BOLT)
            if 0 <= b < 12:
                shot.over(cached_burst(b // 2, 1.25), *centre)
                shot.on_ground(F.ground_ring(6 + 16 * F.ease_out(b / 11), 1 - b / 12), *g)
                shot.light(g[0], g[1], 46, TEAL, 0.9 * (1 - b / 12))
        # the finisher: wind up, slam, the circle forms under the target, the pillar erupts
        if FIN - 4 <= k < FIN + 4:
            cx, cy = crystal(4, HERO)
            if k % 2 == 0:
                for _ in range(3):
                    a = rng.uniform(0, math.tau)
                    p = P.add("seek", 0, 0, 0, life=rng.randint(5, 8), colours=["1", "p", "o", "u"])
                    p.sx, p.sgy, p.sz = cx + math.cos(a) * 14, HERO[1], HERO[1] - cy + math.sin(a) * 10
                    p.tx, p.tgy, p.tz = cx, HERO[1], HERO[1] - cy
            shot.over(F.cast_flash(min(2, (k - FIN + 4) // 3)), cx, cy)
            shot.light(cx, cy + 30, 30, TEAL, 0.5)
        if k == FIN + 4:
            P.burst("dust", HERO[0] + 6, HERO[1], 0, 6, (0.5, 1.1), (0.02, 0.05), (14, 20), ["d", "c"], spread=4, r=(1.0, 2.5))
        if FIN + 4 <= k < FIN + 12:
            shot.on_ground(F.ground_ring(4 + 10 * F.ease_out((k - FIN - 4) / 7), 1 - (k - FIN - 4) / 8), HERO[0] + 6, HERO[1])
        if FIN + 4 <= k < ERUPT + 16:
            draw = F.ease_out((k - FIN - 4) / 9)
            power = 0.6 + 0.4 * F.clamp01((k - FIN - 4) / 9) if k < ERUPT + 4 else max(0.0, 1 - (k - ERUPT - 4) / 12)
            if power > 0.05:
                g_, a_ = F.rune_circle(30, draw, power, rot=(k - FIN) * 3, spikes=0.6 if ERUPT - 3 <= k < ERUPT + 6 else 0, k=k, glyphs=10)
                shot.on_ground(g_, *TARGET)
                shot.over(a_, *TARGET)
                shot.light(TARGET[0], TARGET[1], 50, TEAL, 0.5 * power)
            if k % 2 == 0 and k < ERUPT:
                P.ring_emit("mote", TARGET[0], TARGET[1], 30, 1, (0.25, 0.5), (16, 26))
        if k == ERUPT:
            P.burst("shard", TARGET[0], TARGET[1], 6, 16, (0.8, 2.4), (2.0, 4.2), (30, 45))
            P.burst("spark", TARGET[0], TARGET[1], 18, 30, (1.5, 3.5), (0.5, 3.0), (12, 22))
            P.burst("mote", TARGET[0], TARGET[1], 10, 12, (0.2, 0.8), (0.3, 0.7), (30, 50))
            P.ring_emit("dust", TARGET[0], TARGET[1], 26, 14, (0.02, 0.06), (16, 26), ["d", "c"], out=0.8, r=(1.5, 4.0))
            react.update(t=k, power=1.4)
        e = k - ERUPT
        if 0 <= e < 12:
            shot.over(cached_column(e // 2, 6, 14, 64), *TARGET)
            shot.over(cached_burst(min(5, e // 2), 1.6), TARGET[0], TARGET[1] - 20)
        if 0 <= e < 16:
            shot.on_ground(F.ground_ring(20 + 50 * F.ease_out(e / 15), 1 - e / 16), *TARGET)
            shot.light(TARGET[0], TARGET[1] - 10, 90, TEAL, 1.4 * (1 - e / 16))
        P.step()
        shot.particles(P)
        frames.append(shot.render())
    return frames


# -------------------------------------------------------------------------------------------------- the blink
def blink() -> list[Image.Image]:
    P = F.Particles(11)
    rng = random.Random(110)
    a, b = HERO, (HERO[0] + 44, HERO[1] + 4)
    frames = []
    GATHER, GO, ARRIVE, FORM, END = 10, 12, 16, 22, 52
    for k in range(END):
        shot = Shot()
        shot.actor(warden_frame(k, False), *TARGET, shadow=22)
        if k < GATHER:
            shot.actor(hero(1), *a, shadow=9)
        elif k < GO:
            shot.actor(hero(6), *a, hit=0.35 + 0.25 * (k - GATHER), shadow=9)
            shot.light(a[0], a[1] - 10, 34, TEAL, 0.6)
        elif k < GO + 2:
            spr = hero(6)
            shot.actor(F.Sprite(F._dither(spr.img, 0.5 if k == GO else 0.2), spr.ax, spr.ay), *a, hit=0.8, shadow=9 if k == GO else 0)
        if k == GO:  # the body breaks into streaks of light flying forward
            spr = hero(6)
            px = spr.img.load()
            for yy in range(spr.img.height):
                for xx in range(spr.img.width):
                    if px[xx, yy][3] and rng.random() < 0.7:
                        x, z = a[0] - spr.ax + xx, spr.ay - yy
                        P.add("streak", x, a[1] + rng.uniform(-1, 1), z, rng.uniform(1.8, 4.2), rng.uniform(-0.2, 0.3),
                              rng.uniform(-0.15, 0.35), rng.randint(5, 10), rng.randrange(999), colours=["1", "p", "o", "u", "t"][rng.randint(0, 2):])
            P.burst("spark", a[0], a[1], 14, 10, (0.8, 2.0), (0.2, 1.2), (8, 14))
        if GO <= k < GO + 10:
            t = (k - GO) / 9
            shot.on_ground(F.ground_ring(8 + 9 * F.ease_out(t), 1 - t), *a)
        if GO <= k < ARRIVE + 2:  # the streak along the ground at hip height
            t = (k - GO) / (ARRIVE + 2 - GO)
            y0, y1 = a[1] - 14, b[1] - 14
            for x in range(int(a[0]), int(b[0]) + 1):
                f = (x - a[0]) / (b[0] - a[0])
                y = y0 + (y1 - y0) * f
                alpha = 1.0 if t < 0.4 else 1.4 - t * 1.4
                shot.air_px.put(x, y, "p", alpha)
                shot.air_px.put(x, y - 1, "o", alpha * 0.6)
                shot.air_px.put(x, y + 1, "o", alpha * 0.6)
            shot.light((a[0] + b[0]) / 2, b[1] - 6, 50, TEAL, 0.6 * (1 - t))
        if k == ARRIVE:  # motes fly back together into his shape at the arrival point
            spr = hero(1)
            px = spr.img.load()
            for yy in range(spr.img.height):
                for xx in range(spr.img.width):
                    if px[xx, yy][3] and rng.random() < 0.55:
                        p = P.add("seek", 0, 0, 0, life=rng.randint(4, 7), seed=rng.randrange(999), colours=["1", "p", "o", "u"])
                        p.sx, p.sgy, p.sz = rng.uniform(a[0] + 8, b[0] - 2), b[1] + rng.uniform(-2, 2), rng.uniform(6, 22)
                        p.tx, p.tgy, p.tz = b[0] - spr.ax + xx, b[1], spr.ay - yy
        if ARRIVE <= k < ARRIVE + 12:
            t = (k - ARRIVE) / 11
            shot.on_ground(F.ground_ring(5 + 10 * F.ease_out(t), 1 - t), *b)
            shot.over(cached_column(min(4, (k - ARRIVE) // 2), 5, 6, 36), *b)
            shot.light(b[0], b[1] - 8, 40, TEAL, 0.8 * (1 - t))
        if k >= FORM:
            shot.actor(hero(1), *b, hit=max(0.0, 0.9 - (k - FORM) * 0.25), shadow=9)
        if k == FORM:
            P.burst("mote", b[0], b[1], 16, 8, (0.2, 0.7), (0.2, 0.5), (20, 34))
            P.burst("spark", b[0], b[1], 16, 10, (0.8, 1.8), (0.3, 1.4), (8, 14))
            P.burst("dust", b[0], b[1], 0, 4, (0.4, 0.8), (0.02, 0.05), (12, 18), ["d", "c"], spread=4, r=(1.0, 2.5))
        P.step()
        shot.particles(P)
        frames.append(shot.render())
    return frames


# ------------------------------------------------------------------------------------------------ the ultimate
POINT, FORM, CHARGE, FALL, IMPACT, END = 8, 14, 44, 64, 86, 178


def ultimate_pose(k: int) -> int:
    for start, pose in ((96, 1), (70, 4), (46, 8), (20, 5), (8, 3)):
        if k >= start:
            return pose
    return 1


def ultimate() -> list[Image.Image]:
    P = F.Particles(23)
    rng = random.Random(230)
    frames = []
    rx = 58
    tx, ty = TARGET
    for k in range(END):
        if k < FORM:
            dim = 0.0
        elif k < CHARGE:
            dim = 0.45 * F.ease_out((k - FORM) / 26)
        elif k < FALL:
            dim = 0.45 + 0.1 * (k - CHARGE) / (FALL - CHARGE)
        elif k < IMPACT:
            dim = 0.55 - 0.2 * (k - FALL) / (IMPACT - FALL)
        else:
            dim = 0.0
        since = k - IMPACT
        flash = {0: 0.6, 1: 0.38, 2: 0.22, 3: 0.1, 4: 0.04}.get(since, 0.0)
        amp = 5.0 * (0.82 ** since) if since >= 0 else (0.6 if FALL + 12 <= k < IMPACT else 0)
        shot = Shot(cam=shake_at(rng, amp), dim=dim, flash=flash)
        pose = ultimate_pose(k)
        # the Warden: hurt and pushed back by the blast
        knock = 6 * max(0.0, 1 - since / 22) if since >= 0 else 0
        shot.actor(warden_frame(k, 0 <= since < 26), tx + knock, ty, hit=max(0.0, 1.0 - since * 0.14) if since >= 0 else 0, shadow=22)
        shot.actor(hero(pose), *HERO, shadow=9)
        cxr, cyr = crystal(pose, HERO)
        # 1. he points the staff: the crystal flares, a mote flies to the target and marks the spot
        if POINT <= k < POINT + 4:
            shot.over(F.cast_flash(k - POINT), cxr, cyr)
            shot.light(cxr, cyr + 24, 30, TEAL, 0.6)
        if POINT + 1 <= k < FORM:
            f = (k - POINT - 1) / (FORM - POINT - 1)
            bx, by = cxr + (tx - cxr) * f, cyr + (ty - 4 - cyr) * f - math.sin(f * math.pi) * 14
            draw_trail(shot.air_px, cxr, cyr, bx, by, ["1", "p", "o", "u", "t"])
            shot.over(F.bolt(k), bx, by)
        if FORM <= k < FORM + 8:
            shot.on_ground(F.ground_ring(4 + 12 * F.ease_out((k - FORM) / 7), 1 - (k - FORM) / 8), tx, ty)
        # 2. the circle forms (rocks lift, wisps curl up), then charges (rays, sparkles, the beam), until the meteor lands
        if FORM <= k < IMPACT + 2:
            draw = F.ease_out((k - FORM) / 26)
            power = 0.15 + 0.35 * F.clamp01((k - FORM) / 30) + 0.5 * F.clamp01((k - CHARGE) / 16)
            spikes = F.ease_out((k - CHARGE) / 14) if k >= CHARGE else 0.0
            beam = (F.ease_out((k - 52) / 8) if k < FALL else max(0.0, 1 - (k - FALL) / 6)) if k >= 52 else 0.0
            if k >= IMPACT:
                spikes, power = 1.6, 1.0
            rot = (k - FORM) * 1.2 + max(0, k - CHARGE) * 2.0
            g_, a_ = F.rune_circle(rx, draw, power, rot=rot, spikes=spikes, beam=beam, k=k)
            shot.on_ground(g_, tx, ty)
            shot.over(a_, tx, ty)
            shot.light(tx, ty, 110, TEAL, 0.25 + 0.75 * power)
        if k == FORM + 4:  # rocks lift off the ground around the rim
            for j in range(12):
                a = j * math.tau / 12 + rng.uniform(-0.2, 0.2)
                d = rng.uniform(0.92, 1.12)
                p = P.add("lift", tx + math.cos(a) * rx * d, ty + math.sin(a) * rx * 0.4 * d, 0, life=999, seed=rng.randrange(999))
                p.shape = rng.randrange(6, len(F.ROCKS))
                p.tz = rng.uniform(5, 14)
        if FORM + 4 <= k < CHARGE + 10 and rng.random() < 0.55:
            a = rng.uniform(0, math.tau)
            P.add("wisp", tx + math.cos(a) * rx * rng.uniform(0.85, 1.1), ty + math.sin(a) * rx * 0.4, 0, 0, 0, rng.uniform(0.3, 0.5),
                  rng.randint(18, 28), rng.randrange(999), colours=["g", "f", "t", "e"])
        if FORM + 6 <= k < IMPACT:
            P.ring_emit("mote", tx, ty, rx * rng.uniform(0.75, 1.0), 1, (0.25, 0.55), (20, 32))
        if CHARGE <= k < IMPACT - 2 and k % 2 == 0:
            p = P.add("twinkle", tx + rng.uniform(-rx, rx), ty + rng.uniform(-rx * 0.4, rx * 0.4), rng.uniform(14, 52),
                      life=rng.randint(10, 16), seed=rng.randrange(999))
        # 3. he raises the staff: a beam from the crystal into the sky calls the meteor
        if 48 <= k < FALL + 2:
            fade = 1.0 if k < FALL - 2 else 0.5
            for y in range(-2, int(cyr) - 3):
                flick = 0.75 + 0.25 * math.sin(k * 1.7 + y * 0.3)
                shot.air_px.put(cxr, y, "1", fade * flick)
                shot.air_px.put(cxr - 1, y, "p", 0.6 * fade)
                shot.air_px.put(cxr + 1, y, "p", 0.6 * fade)
                shot.air_px.put(cxr + 2, y, "o", 0.3 * fade)
            shot.over(F.cast_flash(1 + (k % 2)), cxr, cyr)
            shot.light(cxr, HERO[1], 50, TEAL, 0.7)
            if k % 2 == 0:
                P.add("mote", cxr + rng.uniform(-2, 2), HERO[1], HERO[1] - cyr + rng.uniform(0, 40), 0, 0, rng.uniform(0.4, 0.9),
                      rng.randint(12, 20), rng.randrange(999))
        # 4. the meteor falls straight down onto the circle; its shadow and light grow on the ground
        if FALL <= k < IMPACT:
            t = (k - FALL + 1) / (IMPACT - FALL)
            bottom = -10 + (ty + 10) * t ** 1.8
            shot.over(cached_meteor(k), tx, bottom)
            shot.on_ground(F.meteor_shadow(4 + 14 * t, t), tx, ty)
            shot.on_ground(F.ground_ring(7 + math.sin(k * 0.9), 1.0, ["1", "p", "o", "u"]), tx, ty)
            shot.light(tx, max(bottom, ty - 60), 70 + 50 * t, WARM, 0.4 + 1.0 * t)
            height = ty - bottom
            for _ in range(5):
                P.add("ember", tx + rng.uniform(-10, 10), ty + rng.uniform(-1, 1), height + rng.uniform(6, 22), rng.uniform(-0.3, 0.3), 0,
                      rng.uniform(0.2, 0.8), rng.randint(10, 18), rng.randrange(999), colours=F.FIRE)
            if k % 2 == 0:
                P.add("smoke", tx + rng.uniform(-5, 5), ty - 0.5, height + 44, rng.uniform(-0.2, 0.2), 0, 0.15, rng.randint(14, 20),
                      rng.randrange(999), 2.0, 4.5, ["f", "e", "g"])
        # 5. impact: flash, shake, the fire ring, the blast, rocks and sparks everywhere, then smoke and the crater cooling
        if since == 0:
            P.release_lifts(tx, ty, 2.6)
            P.burst("rock", tx, ty, 6, 26, (1.2, 3.4), (2.6, 5.5), (55, 75), spread=8)
            P.burst("fspark", tx, ty, 10, 46, (1.5, 4.2), (0.5, 4.0), (12, 26), F.FIRE, spread=6)
            P.ring_emit("shard", tx, ty, rx * 0.9, 16, (1.5, 3.5), (30, 45), out=1.2, z=2)
            P.burst("spark", tx, ty, 6, 20, (1.0, 3.0), (0.5, 2.5), (12, 20))
            P.ring_emit("dust", tx, ty, rx * 0.65, 24, (0.02, 0.08), (20, 32), ["d", "c"], out=1.3, r=(2.0, 6.0))
        if 0 <= since < 5:
            shot.over(cached_fire_ring(since), tx, ty)
        if 0 <= since < 24:
            shot.over(cached_explosion(since // 2), tx, ty)
        if 0 <= since < 40:
            shot.light(tx, ty - 20, 150, WARM, 2.0 * (1 - since / 40) ** 1.5)
        if since >= 6:
            heat = round(max(0.0, 1 - (since - 6) / 70), 2)
            fade = round(max(0.0, min(1.0, (END - 2 - k) / 6)), 2)
            shot.on_ground(cached_crater(heat, fade), tx, ty)
            if heat > 0:
                shot.light(tx, ty, 70, WARM, 0.5 * heat)
        if 0 <= since < 26:
            for _ in range(3):
                P.add("ember", tx + rng.uniform(-44, 44), ty + rng.uniform(-6, 6), rng.uniform(8, 60), rng.uniform(-0.3, 0.3), 0,
                      rng.uniform(0.5, 1.2), rng.randint(20, 34), rng.randrange(999), colours=F.FIRE)
        if 10 <= since < 26:  # the blast's smoke rolling up
            P.add("smoke", tx + rng.uniform(-36, 36), ty + rng.uniform(-8, 4), rng.uniform(10, 36), rng.uniform(-0.25, 0.25), 0,
                  rng.uniform(0.7, 1.1), rng.randint(30, 44), rng.randrange(999), 2.0, 7.0, ["f", "e", "g"])
        if 12 <= since < 74 and since % 2 == 0:  # then columns of smoke curling up from vents in the crater (the reference's frames 12-15)
            for vx_, vy_ in ((-26, -3), (4, -6), (28, 1)):
                P.add("smoke", tx + vx_ + rng.uniform(-2, 2), ty + vy_, rng.uniform(4, 8), rng.uniform(-0.1, 0.1), 0,
                      rng.uniform(1.1, 1.5), rng.randint(40, 52), rng.randrange(999), 1.5, 5.0 if since < 50 else 3.5, ["e", "0"])
        if 16 <= since < 70 and k % 2 == 0:
            P.add("mote", tx + rng.uniform(-30, 30), ty + rng.uniform(-8, 8), 0, 0, 0, rng.uniform(0.3, 0.6), rng.randint(24, 40),
                  rng.randrange(999))
        P.step()
        shot.particles(P)
        frames.append(shot.render())
    return frames


def main() -> int:
    which = sys.argv[1:] or ["attack", "blink", "ultimate"]
    if "attack" in which:
        save(attack(), "staff_attack.gif")
    if "blink" in which:
        save(blink(), "staff_blink.gif")
    if "ultimate" in which:
        save(ultimate(), "staff_ultimate.gif", hold=6)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
