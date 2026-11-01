"""Preview GIFs of the mage staff at game scale (review stage, nothing here is in the game).

Built from the cut-down concept frames (tools/art/import_staff_concept.py, art/reference/staff_v1/imported/), the Warden's in-game
idle frames (art/build/sprites) as the target and a piece of the Hollow Trial floor, shown 4x. The hero only has the 8 key poses of
the concept so far, so his moves swap between poses; the full animation sheets come after the owner approves the look.

    staff_attack.gif          the basic attack: two Arcane Bursts on the target, then the Great Burst finisher
    staff_blink.gif           the blink dash: depart (dissolve) and arrive a short way ahead
    staff_disintegration.gif  the right click: the circle draws under the target, the star is called and falls, impact, scorch

Output: art/reference/staff_v1/preview/. Run from the project root:
    python tools/art/preview_staff.py
"""
from __future__ import annotations

import json
import math
import random
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
IMPORTED = ROOT / "art/reference/staff_v1/imported"
OUT = ROOT / "art/reference/staff_v1/preview"
FLOOR = ROOT / "presentation/forest/hollow_trial_layered_ground.png"
ZOOM = 4
VIEW = (176, 120, 368, 228)  # the floor piece (game px), 192x108: half the game screen
FPS = 20

SETS = json.loads((IMPORTED / "imported.json").read_text(encoding="utf-8"))["sets"]
SPRITES = json.loads((ROOT / "art/build/sprites.json").read_text(encoding="utf-8"))["frames"]


class Frame:
    def __init__(self, img: Image.Image, ax: int, ay: int) -> None:
        self.img, self.ax, self.ay = img, ax, ay


def staff(name: str, n: int) -> Frame:
    m = SETS[name][n - 1]
    return Frame(Image.open(IMPORTED / m["file"]).convert("RGBA"), m["ax"], m["ay"])


def sprite(name: str) -> Frame:
    m = SPRITES[name]
    return Frame(Image.open(ROOT / "art/build/sprites" / f"{name}.png").convert("RGBA"), m["ax"], m["ay"])


WARDEN = [sprite(f"warden_idle_right_{i}") for i in range(1, 7)]


class Scene:
    """One GIF frame: ground layer, sprites sorted by feet, overhead effects."""

    def __init__(self, floor: Image.Image, shake: tuple[int, int] = (0, 0)) -> None:
        self.floor, self.shake = floor, shake
        self.ground: list = []
        self.actors: list = []
        self.over: list = []

    def put(self, layer: list, f: Frame, x: float, y: float, flip: bool = False, white: bool = False) -> None:
        layer.append((f, x, y, flip, white))

    def render(self) -> Image.Image:
        img = self.floor.copy()
        sh = Image.new("RGBA", img.size, (0, 0, 0, 0))
        d = ImageDraw.Draw(sh)
        for f, x, y, _, _ in self.actors:  # soft shadows under the actors
            r = max(6, f.img.width // 4)
            d.ellipse((x - r, y - r // 3, x + r, y + r // 3), fill=(20, 16, 28, 110))
        img.alpha_composite(sh)
        for layer in (self.ground, sorted(self.actors, key=lambda a: a[2]), self.over):
            for f, x, y, flip, white in layer:
                pic, ax = f.img, f.ax
                if flip:
                    pic, ax = pic.transpose(Image.FLIP_LEFT_RIGHT), pic.width - 1 - f.ax
                if white:  # the hit flash: halfway to cream (preview only; the game has its own hit flash)
                    flash = Image.blend(pic, Image.new("RGBA", pic.size, (244, 236, 214, 255)), 0.55)
                    flash.putalpha(pic.getchannel("A"))
                    pic = flash
                img.alpha_composite(pic, (round(x - ax + self.shake[0]), round(y - f.ay + self.shake[1])))
        return img.resize((img.width * ZOOM, img.height * ZOOM), Image.NEAREST).convert("RGB")


def floor() -> Image.Image:
    return Image.open(FLOOR).convert("RGBA").crop(VIEW)


def save(frames: list[Image.Image], name: str, hold_last: int = 10) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    frames = frames + [frames[-1]] * hold_last
    pal = [f.convert("P", palette=Image.ADAPTIVE, colors=255) for f in frames]
    pal[0].save(OUT / name, save_all=True, append_images=pal[1:], duration=1000 // FPS, loop=0, disposal=1)
    print(name, len(frames), "frames")


HERO_AT = (52, 78)
TARGET = (140, 80)


def warden(k: int) -> Frame:
    return WARDEN[(k // 3) % len(WARDEN)]


def attack() -> list[Image.Image]:
    """Cast, burst on the target; cast, burst; swing, Great Burst at its feet."""
    base = floor()
    plan = []  # (hero pose, effect set or None, effect frame, effect point, hit)
    for cast, (fx, fy) in enumerate([(TARGET[0] - 4, TARGET[1] - 26), (TARGET[0] + 4, TARGET[1] - 18)]):
        plan += [(1, None, 0, None, False)] * 3 + [(3, None, 0, None, False)] * 2
        for n in range(1, 7):
            plan += [(3 if n < 4 else 1, "burst", n, (fx, fy), n == 2)] * 2
    plan += [(1, None, 0, None, False)] * 3 + [(4, None, 0, None, False)] * 3
    for n in range(1, 7):
        plan += [(4 if n < 4 else 8, "burst_big", n, (TARGET[0], TARGET[1] - 6), n == 2)] * 3
    frames = []
    for k, (pose, fx_set, n, at, hit) in enumerate(plan):
        sc = Scene(base, (random.Random(k).randint(-1, 1), 0) if hit else (0, 0))
        sc.put(sc.actors, staff("hero", pose), *HERO_AT)
        sc.put(sc.actors, warden(k), *TARGET, flip=True, white=hit)
        if fx_set:
            sc.put(sc.over, staff(fx_set, n), *at)
        frames.append(sc.render())
    return frames


def blink() -> list[Image.Image]:
    """Idle, dissolve with the depart ring, gone, the arrive pillar a short way ahead, standing again."""
    base = floor()
    a, b = HERO_AT, (HERO_AT[0] + 34, HERO_AT[1] + 6)
    frames = []
    for k in range(8):
        sc = Scene(base)
        sc.put(sc.actors, staff("hero", 1), *a)
        sc.put(sc.actors, warden(k), *TARGET, flip=True)
        frames.append(sc.render())
    step = 0
    for n in range(1, 5):  # depart
        for _ in range(2):
            sc = Scene(base)
            if n <= 2:
                sc.put(sc.actors, staff("hero", 6), *a)
            sc.put(sc.ground, staff("blink", n), *a)
            sc.put(sc.actors, warden(8 + step), *TARGET, flip=True)
            frames.append(sc.render())
            step += 1
    for n in range(5, 9):  # arrive
        for _ in range(2):
            sc = Scene(base)
            if n >= 7:
                sc.put(sc.actors, staff("hero", 1), *b)
            sc.put(sc.ground, staff("blink", n), *b)
            sc.put(sc.actors, warden(8 + step), *TARGET, flip=True)
            frames.append(sc.render())
            step += 1
    for k in range(10):
        sc = Scene(base)
        sc.put(sc.actors, staff("hero", 1), *b)
        sc.put(sc.actors, warden(8 + step + k), *TARGET, flip=True)
        frames.append(sc.render())
    return frames


def disintegration() -> list[Image.Image]:
    """Plant the staff: the circle draws in under the target and loops; call the star; it falls; impact; the scorch stays."""
    base = floor()
    frames = []
    k = 0

    def scene(pose: int, shake=(0, 0), white=False) -> Scene:
        sc = Scene(base, shake)
        sc.put(sc.actors, staff("hero", pose), *HERO_AT)
        sc.put(sc.actors, warden(k), *TARGET, flip=True, white=white)
        return sc

    for _ in range(4):
        frames.append(scene(1).render())
        k += 1
    for n in range(1, 5):  # the circle draws in
        for _ in range(2):
            sc = scene(5)
            sc.put(sc.ground, staff("circle", n), *TARGET)
            frames.append(sc.render())
            k += 1
    sky = (TARGET[0] + 70, TARGET[1] - 110)
    fall = 12
    for i in range(10 + fall):  # the loop while he calls the star; then it falls
        sc = scene(8 if i < 10 else 4)
        sc.put(sc.ground, staff("circle", 5 + (i // 2) % 4), *TARGET)
        if i >= 10:
            s = (i - 10 + 1) / fall
            s = s * s  # it speeds up
            head = (sky[0] + (TARGET[0] - sky[0]) * s, sky[1] + (TARGET[1] - sky[1]) * s)
            sc.put(sc.over, staff("star", 1 if s < 0.25 else 2 if s < 0.6 else 3), *head)
        frames.append(sc.render())
        k += 1
    for n in range(4, 9):  # the impact
        for j in range(2):
            hit = n == 4
            sc = scene(4 if n < 6 else 1, (random.Random(k).randint(-2, 2), random.Random(k + 7).randint(-1, 1)) if n < 6 else (0, 0), hit)
            sc.put(sc.ground, staff("scorch", 1), *TARGET)
            sc.put(sc.over, staff("star", n), *TARGET)
            frames.append(sc.render())
            k += 1
    for n in range(1, 5):  # the scorch cools
        for _ in range(4):
            sc = scene(1)
            sc.put(sc.ground, staff("scorch", n), *TARGET)
            frames.append(sc.render())
            k += 1
    return frames


def main() -> int:
    save(attack(), "staff_attack.gif")
    save(blink(), "staff_blink.gif")
    save(disintegration(), "staff_disintegration.gif")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
