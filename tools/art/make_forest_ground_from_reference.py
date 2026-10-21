"""Turn the owner's paintings of the forest route and the Stag glade into the ground art of chapter 1 scenes S2/S3 and S4.

Sources (clean targets the human supplied on 2026-10-21, both about 835x485 with a thin flat screenshot frame):
- art/reference/forest_route_target.png: the merged S2+S3 forest route. A dirt trail comes in at the left edge (the
  village side) and runs in an S-bend through two clearings: signpost, mossy stone, fallen logs, a lantern post, two
  stone lantern pedestals, a root-tangle gate at the top right (the lantern puzzle gate), a chest in the bottom-right
  nook, big trees all round.
- art/reference/stag_glade_target.png: the S4 mini-boss glade. A round clearing with a ring of rune standing stones
  around a glowing spring, thorn vines, antler bones, a root arch at the top right (the exit) and the trail entrance at
  the bottom left.

Both become 800x480 hard pixel art in the Totoy 36 palette with the same steps as the arena
(tools/art/make_arena_ground_from_reference.py) and the village (tools/art/make_village_ground_from_reference.py):

1. trim the screenshot frame and apply the FUNCTIONAL EDITS below at the painting's own resolution (before any
   resize, so the edit goes through the same filter, grade and snap as the painting around it and leaves no seam);
2. a Lanczos resize to 800x480 (a horizontal squeeze of about 4 %, no crop: the entrances sit on the edges);
3. a grade: the paintings are dark, so a midtone lift that leaves the deep shadows alone (the canopy and the forest
   floor under it stay dark, the trail and the clearings come up), a little more contrast and a little less saturation;
4. the village's nearest-colour snap in Lab (lightness weighted) to the palette WITHOUT the reserved combat colours
   (x, y, z, A), with the same hue guards (greens stay in the grass / stone / teal ramps, browns stay brown, warm light
   lands on cream / skin / dirt_6), plus a cyan guard (the rune glow and the spring stay teal / water instead of
   turning grey) and a green guard (a clearly green pixel, such as the spring's glow on the grass, does not turn into
   grey stone);
5. the village's lone-pixel cleanup (light colours, the rune teal and the spring blues are kept);
6. a palette check.

Functional edits (painting coordinates of the untrimmed source; see FOREST_EDITS / GLADE_EDITS):
- forest: a short DEAD-END trail branches EAST past the second lantern pedestal to the chest (the exit is the painted
  path behind the root gate, so the lantern puzzle gates it; decided by the human on 2026-10-22). The new stretch is a
  copy of the painted trail at the left edge (dirt, pebbles and the grass fringe), bent to follow the new centre line
  and squeezed to the trail width; it cuts through the big fallen root (the root ends dip under the trail), runs just
  above the chest (which stays as painted, so the chest nook opens onto the trail) and under the mossy rock, then
  narrows to a point and darkens into the undergrowth well before the right edge (it does not lead off-screen). The two pedestals are made UNLIT (their warm windows become dark stone): the
  lantern puzzle lights them at runtime, so the painting must show the unlit state. The left entrance, the root gate
  and the chest are left as painted.
- glade: the bottom-left entrance trail and the root arch are already clear in the painting; nothing is painted.

Writes presentation/forest/forest_route_ground.png and presentation/forest/stag_glade_ground.png (800x480, opaque,
palette colours only). Deterministic: the only randomness is a hash of (SEED, x, y) for the ragged trail fringe.
--scale S (default 1.0, the approved 800x480 files) converts the paintings at round(800*S) x round(480*S) with the same
pipeline and edits, so trees, stones and props shrink relative to the characters (who keep their pixel size; the human's
review on 2026-10-22: at 1.0 the hero looks tiny, as in the village, which moved to 0.7). Any other scale writes
presentation/forest/<name>_sNNN.png (forest_route_ground_s060.png ...) beside the game's files; the matching colliders
are core/forest_layout.gd / core/glade_layout.gd build_scaled(S). Options compared on docs/previews/forest_scale_options.png
and glade_scale_options.png.
Run from the project root:
  python tools/art/make_forest_ground_from_reference.py --scene forest|glade|all [--scale S] [--preview DIR]
"""
from __future__ import annotations

import argparse
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Callable

from PIL import Image, ImageEnhance

sys.path.insert(0, str(Path(__file__).resolve().parent))
import artlib  # noqa: E402
from import_reference import srgb_to_lab  # noqa: E402

ROOT = artlib.ROOT
OUT_DIR = ROOT / "presentation" / "forest"
W, H = 800, 480
# the approved scale of the files the game loads (1.0 = 800x480); --scale writes options beside them (see the docstring)
DEFAULT_SCALE = 1.0
SEED = 20261021
LIGHTNESS_WEIGHT = 2.0
# the village's hue guards (extra cost, Lab distance squared, for leaving the pixel's hue family)
GREEN_PENALTY = 140.0
BROWN_PENALTY = 140.0
WARM_LIGHT_PENALTY = 10000.0
GREEN_OK = set("234567efghij" + "tu" + "0")
WATER = set("klmnop")
BROWN_BAD = set("234567" + "tu" + "klmnop" + "v")
# cyan glow (the runes, the spring, the root gate's sparks) must stay teal / water: the grey stones cost extra
CYAN_OK = set("tu" + "klmnop" + "1")
CYAN_PENALTY = 400.0
# a clearly green pixel (the spring's glow on the grass, sunlit moss) stays in the grass ramp: the grey stones cost extra
STONE = set("efghij")
# colours the cleanup never removes (warm light, the brightest highlight, the rune glow and the spring)
KEEP = {"1", "s", "r", "u", "o", "p", "n"}
# the grade: v -> blend(v, v ** GAMMA) with the weight rising from SHADOW_LO to SHADOW_HI (0..1 channel values), so
# the deep shadows keep their value and the lit ground is lifted
GAMMA = 0.72
SHADOW_LO = 0.05
SHADOW_HI = 0.22

palette = artlib.load_palette()

Box = tuple[int, int, int, int]
Point = tuple[float, float]


@dataclass
class Scene:
    name: str
    source: Path
    out: Path
    # the painting inside the screenshot frame (left, top, right, bottom), measured on the source
    trim: Box
    edits: Callable[[Image.Image, "Scene"], Image.Image] | None = None
    contrast: float = 1.08
    color: float = 0.94
    extra: dict = field(default_factory=dict)

    def local(self, x: float, y: float) -> Point:
        """Source (untrimmed) painting coordinates -> trimmed painting coordinates."""
        return x - self.trim[0], y - self.trim[1]


# --- helpers for the painted edits -------------------------------------------------------------------------------

def _hash01(x: int, y: int, salt: int = 0) -> float:
    """Deterministic value noise in 0..1 for (SEED, x, y, salt)."""
    h = (x * 374761393 + y * 668265263 + (SEED + salt) * 2147483647) & 0xFFFFFFFF
    h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
    return ((h ^ (h >> 16)) & 0xFFFF) / 65535.0


def _smooth_noise(x: float, salt: int, period: float = 6.0) -> float:
    """1D smooth noise in -1..1 along x (linear interpolation between hashed knots)."""
    k = int(x // period)
    t = (x - k * period) / period
    a = _hash01(k, 0, salt) * 2.0 - 1.0
    b = _hash01(k + 1, 0, salt) * 2.0 - 1.0
    return a + (b - a) * t


def _polyline_y(points: list[Point], x: float) -> float:
    """y of a left-to-right polyline at x (clamped at the ends)."""
    if x <= points[0][0]:
        return points[0][1]
    for (x0, y0), (x1, y1) in zip(points, points[1:]):
        if x <= x1:
            return y0 + (y1 - y0) * (x - x0) / (x1 - x0)
    return points[-1][1]


def _inside_ellipse(x: float, y: float, e: tuple[float, float, float, float]) -> bool:
    cx, cy, rx, ry = e
    return ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0


def clone_trail(img: Image.Image, scene: Scene, spec: dict) -> Image.Image:
    """Paint a trail along spec['centre'] by copying a straight stretch of the painted trail (spec['source_*']).

    For every target column x the source column is x + source_dx; target offsets v from the new centre line map to
    source offsets v * source_half / half around the source centre line, so the copy keeps the painted dirt, pebbles
    and grass fringe but follows the new bend at the new width. Pixels within half + fringe are copied; the outer
    `ragged` px blend into the painting per pixel by hashed noise (an irregular edge, not a straight cut). `protect`
    ellipses (props the trail passes) are never painted. Over the last `taper` columns the trail narrows to nothing
    and darkens to `fade` (it ends in the undergrowth).
    """
    out = img.copy()
    src = img.load()
    dst = out.load()
    w, h = img.size
    centre = [scene.local(x, y) for x, y in spec["centre"]]
    src_centre = [scene.local(x, y) for x, y in spec["source_centre"]]
    half = spec["half"]
    src_half = spec["source_half"]
    fringe = spec["fringe"]
    ragged = spec["ragged"]
    protect = [(*scene.local(e[0], e[1]), e[2], e[3]) for e in spec.get("protect", [])]
    x_from = int(max(0, centre[0][0]))
    x_to = int(min(w, centre[-1][0]))
    dx = spec["source_dx"]
    taper = spec["taper"]
    fade = spec["fade"]
    for x in range(x_from, x_to):
        cy = _polyline_y(centre, x) + _smooth_noise(x, 1, 9.0) * 1.5
        sx = min(w - 1, max(0, x + dx))
        scy = _polyline_y(src_centre, sx)
        # the start of the new stretch lies over the painted trail: its dirt fades in over `lead_in` columns and its
        # grass fringe only grows in after `fringe_in` columns (no grass line across the old dirt)
        lead = min(1.0, (x - x_from) / spec["lead_in"])
        reach = half + fringe * min(1.0, max(0.0, (x - x_from - spec["lead_in"]) / spec["fringe_in"]))
        # the dead end: the trail narrows to nothing and darkens over the last `taper` columns
        end = min(1.0, (x_to - x) / taper)
        reach *= end ** 0.6
        k = fade + (1.0 - fade) * end
        for y in range(int(cy - reach - 1), int(cy + reach + 2)):
            if y < 0 or y >= h:
                continue
            if any(_inside_ellipse(x, y, e) for e in protect):
                continue
            v = y - cy
            edge = reach - abs(v) + _smooth_noise(x + (0 if v < 0 else 500), 2 if v < 0 else 3, 5.0) * 2.0
            if edge <= 0:
                continue
            if edge < ragged and _hash01(x, y, 7) > edge / ragged:
                continue
            if lead < 1.0 and _hash01(x, y, 9) > lead:
                continue
            sy = int(round(scy + v * src_half / half))
            sy = min(h - 1, max(0, sy))
            r, g, b = src[sx, sy]
            r, g, b = int(r * k), int(g * k), int(b * k)
            dst[x, y] = (r, g, b)
    return out


def unlight(img: Image.Image, scene: Scene, boxes: list[Box]) -> Image.Image:
    """Turn warm lantern light inside the boxes into dark stone (the pedestal's window, unlit)."""
    out = img.copy()
    px = out.load()
    for box in boxes:
        x0, y0 = scene.local(box[0], box[1])
        x1, y1 = scene.local(box[2], box[3])
        for y in range(int(y0), int(y1)):
            for x in range(int(x0), int(x1)):
                r, g, b = px[x, y]
                warm = r > b + 18 and r >= g - 4 and r > 70
                if warm:
                    # the unlit window: a deep stone recess, darker toward the brightest (centre) pixels
                    lum = (r + g + b) / 3.0
                    px[x, y] = (34, 38, 34) if lum > 150 else (46, 51, 45)
    return out


# --- the scenes ----------------------------------------------------------------------------------------------------

# Forest: the dead-end trail east from the second pedestal to the chest (see the module docstring). The source is the
# painted trail at the left edge (x 0..200, centre line y about 268, dirt half width about 23).
FOREST_TRAIL = {
    "centre": [(546.0, 286.0), (578.0, 294.0), (610.0, 300.0), (650.0, 308.0), (690.0, 318.0), (735.0, 326.0),
               (780.0, 331.0), (805.0, 333.0)],
    # it starts on the painted dirt below the first pedestal: the copy fades in, the fringe grows in past the old edge
    "lead_in": 14.0,
    "fringe_in": 40.0,
    "half": 17.0,
    "fringe": 10.0,
    "ragged": 8.0,
    "source_centre": [(0.0, 270.0), (60.0, 268.0), (120.0, 266.0), (200.0, 262.0), (260.0, 262.0)],
    "source_half": 21.0,
    "source_dx": -543,
    # props the trail passes: the second pedestal, the chest, the mossy rock (cx, cy, rx, ry in source coordinates)
    "protect": [(662.0, 252.0, 26.0, 42.0), (717.0, 376.0, 30.0, 28.0), (772.0, 288.0, 19.0, 33.0)],
    # the dead end: it narrows to a point and darkens from x 745 to 805 (world about 716..774), short of the edge
    "taper": 60.0,
    "fade": 0.6,
}
# the pedestal windows (source coordinates): warm pixels in here become dark stone
FOREST_PEDESTAL_WINDOWS: list[Box] = [(520, 180, 548, 206), (646, 218, 676, 246)]


def forest_edits(img: Image.Image, scene: Scene) -> Image.Image:
    img = clone_trail(img, scene, FOREST_TRAIL)
    return unlight(img, scene, FOREST_PEDESTAL_WINDOWS)


SCENES: dict[str, Scene] = {
    "forest": Scene(
        "forest",
        ROOT / "art" / "reference" / "forest_route_target.png",
        OUT_DIR / "forest_route_ground.png",
        # 2 grey columns at the left, 3 at the right, no rows (measured)
        (2, 0, 832, 481),
        forest_edits,
    ),
    "glade": Scene(
        "glade",
        ROOT / "art" / "reference" / "stag_glade_target.png",
        OUT_DIR / "stag_glade_ground.png",
        # 1 grey column at the left, 3 at the right, 5 rows at the top (measured)
        (1, 5, 832, 489),
        None,
    ),
}


# --- the conversion (the village pipeline, size-independent) -------------------------------------------------------

def _lift_lut() -> list[int]:
    lut: list[int] = []
    for i in range(256):
        v = i / 255.0
        t = min(1.0, max(0.0, (v - SHADOW_LO) / (SHADOW_HI - SHADOW_LO)))
        wgt = t * t * (3.0 - 2.0 * t)
        out = v * (1.0 - wgt) + (v ** GAMMA) * wgt
        lut.append(int(round(min(1.0, out) * 255.0)))
    return lut


def edited(scene: Scene) -> Image.Image:
    img = Image.open(scene.source).convert("RGB").crop(scene.trim)
    if scene.edits is not None:
        img = scene.edits(img, scene)
    return img


def prepare(scene: Scene, size: tuple[int, int] = (W, H)) -> Image.Image:
    img = edited(scene).resize(size, Image.LANCZOS)
    img = img.point(_lift_lut() * 3)
    img = ImageEnhance.Contrast(img).enhance(scene.contrast)
    return ImageEnhance.Color(img).enhance(scene.color)


class Snapper:
    def __init__(self) -> None:
        reserved = set(palette.reserved)
        self.choices = [(sym, srgb_to_lab(rgb), rgb) for sym, rgb in palette.by_symbol.items() if sym not in reserved]
        self.cache: dict[tuple[int, int, int], str] = {}

    def snap(self, rgb: tuple[int, int, int]) -> str:
        hit = self.cache.get(rgb)
        if hit is None:
            lab = srgb_to_lab(rgb)
            r, g, b = rgb
            greenish = g > r + 2 and g > b + 2
            brownish = r > g + 4 and g >= b and r > b + 10
            warm_light = r >= g and g - b > 30 and r > 110
            # the rune glow and the spring: clearly blue-green and bright enough to be light, not shadow
            # (the pale blue-green haze around the spring is NOT: it stays grass, so the pool keeps its painted size)
            cyan = b > r + 50 and g > r + 60 and g + b > 200
            slate = b < r + 50
            clearly_green = g > r + 10 and g > b + 20
            # ... and a yellow-green one (the glow on the grass) is not teal or water either: those are for the pool
            yellow_green = clearly_green and b < g - 30

            def cost(c: tuple[str, tuple[float, float, float], tuple[int, int, int]]) -> float:
                d = (c[1][0] - lab[0]) ** 2 * LIGHTNESS_WEIGHT + (c[1][1] - lab[1]) ** 2 + (c[1][2] - lab[2]) ** 2
                if cyan:
                    if c[0] not in CYAN_OK:
                        d += CYAN_PENALTY
                    return d
                if greenish and c[0] not in GREEN_OK:
                    d += GREEN_PENALTY
                if clearly_green and c[0] in STONE:
                    d += GREEN_PENALTY
                if yellow_green and (c[0] in WATER or c[0] in "tu"):
                    d += GREEN_PENALTY
                if greenish and c[0] == "0":
                    d += GREEN_PENALTY  # the violet ink only for real black
                if brownish and c[0] in BROWN_BAD:
                    d += BROWN_PENALTY
                if slate and c[0] in WATER:
                    d += GREEN_PENALTY
                if warm_light and c[0] in BROWN_BAD:
                    d += WARM_LIGHT_PENALTY
                return d

            hit = min(self.choices, key=cost)[0]
            self.cache[rgb] = hit
        return hit


def snap_image(img: Image.Image) -> list[list[str]]:
    snapper = Snapper()
    px = img.load()
    w, h = img.size
    grid: list[list[str]] = []
    for y in range(h):
        row: list[str] = []
        for x in range(w):
            r, g, b = px[x, y]
            row.append(snapper.snap((r // 2 * 2, g // 2 * 2, b // 2 * 2)))
        grid.append(row)
    return grid


def cleanup(grid: list[list[str]], passes: int = 1) -> list[list[str]]:
    h, w = len(grid), len(grid[0])
    for _ in range(passes):
        out = [row[:] for row in grid]
        for y in range(h):
            for x in range(w):
                sym = grid[y][x]
                if sym in KEEP:
                    continue
                counts: dict[str, int] = {}
                same = 0
                for dy in (-1, 0, 1):
                    for dx in (-1, 0, 1):
                        if dx == 0 and dy == 0:
                            continue
                        n = grid[min(h - 1, max(0, y + dy))][min(w - 1, max(0, x + dx))]
                        counts[n] = counts.get(n, 0) + 1
                        if n == sym:
                            same += 1
                if same <= 1:
                    best, count = max(counts.items(), key=lambda kv: kv[1])
                    if count >= 5:
                        out[y][x] = best
        grid = out
    return grid


def to_image(grid: list[list[str]]) -> Image.Image:
    h, w = len(grid), len(grid[0])
    out = Image.new("RGB", (w, h))
    po = out.load()
    for y in range(h):
        for x in range(w):
            po[x, y] = palette.by_symbol[grid[y][x]]
    return out


def size_for(scale: float = DEFAULT_SCALE) -> tuple[int, int]:
    """The scene size in px at `scale` (1.0 = 800x480, the approved size; 0.7 = 560x336, 0.6 = 480x288, 0.5 = 400x240)."""
    return round(W * scale), round(H * scale)


def out_for(scene: Scene, scale: float) -> Path:
    """The game's file at the default scale; presentation/forest/<name>_sNNN.png for any other scale (an option)."""
    if abs(scale - DEFAULT_SCALE) < 1e-9:
        return scene.out
    return scene.out.with_name(f"{scene.out.stem}_s{round(scale * 100):03d}.png")


def build(scene: Scene, scale: float = DEFAULT_SCALE) -> Image.Image:
    return to_image(cleanup(snap_image(prepare(scene, size_for(scale)))))


def check(img: Image.Image, scale: float = DEFAULT_SCALE) -> list[str]:
    allowed = {rgb for sym, rgb in palette.by_symbol.items() if sym not in palette.reserved}
    problems: list[str] = []
    if img.size != size_for(scale):
        problems.append(f"size {img.size} is not {size_for(scale)}")
    if img.mode != "RGB":
        problems.append(f"mode {img.mode} is not opaque RGB")
    stray = {c for c in img.convert("RGB").get_flattened_data() if c not in allowed}
    if stray:
        problems.append(f"colours outside the palette (or reserved): {sorted(stray)[:5]}")
    return problems


def run(scene: Scene, preview: Path | None, scale: float = DEFAULT_SCALE) -> int:
    if not scene.source.exists():
        print("missing", scene.source)
        return 1
    out = build(scene, scale)
    problems = check(out, scale)
    if problems:
        for p in problems:
            print(f"ERROR ({scene.name}):", p)
        return 1
    path = out_for(scene, scale)
    path.parent.mkdir(parents=True, exist_ok=True)
    out.save(path)
    if preview is not None:
        preview.mkdir(parents=True, exist_ok=True)
        out.resize((out.width * 2, out.height * 2), Image.NEAREST).save(preview / f"{path.stem}_2x.png")
        prepare(scene, size_for(scale)).save(preview / f"{path.stem}_prepared.png")
        edited(scene).save(preview / f"{scene.out.stem}_edited.png")
    print("wrote", path, out.size, "palette check OK")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--scene", choices=["forest", "glade", "all"], default="all")
    parser.add_argument("--scale", type=float, default=DEFAULT_SCALE,
                        help="scene scale relative to 800x480 (default 1.0, the approved files; others write *_sNNN.png)")
    parser.add_argument("--preview", help="also write a 2x preview, the edited painting and the prepared (unsnapped) image")
    args = parser.parse_args()
    if not 0.25 <= args.scale <= 2.0:
        print("--scale must be between 0.25 and 2.0")
        return 1
    names = ["forest", "glade"] if args.scene == "all" else [args.scene]
    preview = Path(args.preview) if args.preview else None
    code = 0
    for name in names:
        code = max(code, run(SCENES[name], preview, args.scale))
    return code


if __name__ == "__main__":
    sys.exit(main())
