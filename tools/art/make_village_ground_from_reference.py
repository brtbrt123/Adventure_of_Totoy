"""Turn the owner's painting of Lanternfen village into the village's ground art (scene S1).

Reads art/reference/lanternfen_village_target.png (837x496, the clean target the human supplied on 2026-10-21: a forest
village clearing in a 3/4 view with the rune gate on the left, a dirt crossroads, the smithy with forge, anvil, workbench
and training dummy at the top, a thatched house at the top right, barrels and crates, lanterns, a stone shrine, rubble,
trees along the edges and a mountain view at the top left), trims the flat screenshot frame, resizes it to the village
(571x336 = 0.7 of the 816x480 measuring size, core/village_layout.gd SCALE / VILLAGE_SIZE) and turns it into hard
pixel art in the Totoy 36 palette, the same way tools/art/make_arena_ground_from_reference.py did the arena:

1. the frame's rounded corners are filled from the painting next to them (they would snap to a grey blob otherwise);
2. a Lanczos resize and a mild grade (a little brighter, a little more contrast, a little less saturation);
3. a nearest-colour snap in Lab (lightness weighted) to the palette WITHOUT the reserved combat colours (x, y, z, A),
   with hue guards: a green pixel pays extra for leaving the grass / stone / teal ramps (the canopy stays green, not
   violet ink or brown), a warm brown pixel pays extra for the grass, teal, water and lilac colours (the dirt and the
   timber stay brown). Warm light (lantern windows, the forge fire) has no gold to go to (gold is reserved): it lands
   on cream / skin_3 / skin_2 / dirt_6, which still reads as warm light against the dark greens;
4. a cleanup pass: lone pixels whose 8 neighbours mostly agree on one colour take that colour; the light colours
   (cream, skin_3, skin_2, the rune teal) are kept so the small lantern and window glows survive.

Writes presentation/village/village_ground.png (571x336, opaque, palette colours only) and checks the palette at the
end. Deterministic: no randomness (SEED is recorded for the art tools' convention; nothing random runs).

--scale S (default 0.7, the human's choice on 2026-10-22: at 1.0 the characters looked tiny next to the painted
buildings, see docs/previews/village_scale_options.png) converts the painting at round(816*S) x round(480*S) with the
same pipeline, so buildings and props shrink relative to the characters (who keep their pixel size). Any scale other
than 0.7 writes presentation/village/village_ground_sNNN.png (NNN = S*100, e.g. _s100 for the first 816x480 version)
instead of the game's file; the matching colliders are core/village_layout.gd build_scaled(S).
Run from the project root:  python tools/art/make_village_ground_from_reference.py [--scale S] [--out PATH] [--preview DIR]
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

from PIL import Image, ImageEnhance

sys.path.insert(0, str(Path(__file__).resolve().parent))
import artlib  # noqa: E402
from import_reference import srgb_to_lab  # noqa: E402

ROOT = artlib.ROOT
SOURCE = ROOT / "art" / "reference" / "lanternfen_village_target.png"
OUT = ROOT / "presentation" / "village" / "village_ground.png"
BASE_W, BASE_H = 816, 480
# the game's scale (core/village_layout.gd SCALE)
DEFAULT_SCALE = 0.7
SEED = 20261021
# the screenshot's flat grey frame: 5 columns at the left, 5 rows at the top, 8 columns at the right, 7 rows at the
# bottom (measured: the painting is x 5..827, y 5..487)
TRIM = (5, 5, 828, 488)
# the frame's rounded corners reach this far into the trimmed painting
CORNER = 14
LIGHTNESS_WEIGHT = 2.0
# a little brighter before the snap: the painting's dusk path (mean Lab L 30, yellow-brown) otherwise lands almost all on
# the reddish dirt_3; at 1.08 it mixes dirt_3 with dirt_4 and reads brown like the painting (1.15 tried: the sky turns
# teal and the path pink)
BRIGHTNESS = 1.08
# extra cost (Lab distance squared) for leaving the pixel's hue family (see the module docstring)
GREEN_PENALTY = 140.0
BROWN_PENALTY = 140.0
# yellow light would snap to grass_6 (the nearest Lab colour): it must take a warm colour instead
WARM_LIGHT_PENALTY = 10000.0
GREEN_OK = set("234567efghij" + "tu" + "0")
WATER = set("klmnop")
BROWN_BAD = set("234567" + "tu" + "klmnop" + "v")
# colours the cleanup never removes (warm light, the brightest highlight, the rune glow)
KEEP = {"1", "s", "r", "u"}

palette = artlib.load_palette()


def _is_frame(c: tuple[int, int, int]) -> bool:
    return max(c) - min(c) <= 7 and 26 <= sum(c) / 3 <= 40


def fill_corners(img: Image.Image) -> Image.Image:
    """Replace the grey frame pixels left in the rounded corners by the nearest painting pixel along the diagonal."""
    img = img.copy()
    px = img.load()
    w, h = img.size
    for cx, cy, sx, sy in ((0, 0, 1, 1), (w - 1, 0, -1, 1), (0, h - 1, 1, -1), (w - 1, h - 1, -1, -1)):
        for dy in range(CORNER):
            for dx in range(CORNER):
                x, y = cx + sx * dx, cy + sy * dy
                if not _is_frame(px[x, y]):
                    continue
                # walk inward along the diagonal until the painting starts
                k = 1
                while k < CORNER * 2:
                    nx, ny = x + sx * k, y + sy * k
                    if not _is_frame(px[nx, ny]):
                        px[x, y] = px[nx, ny]
                        break
                    k += 1
    return img


def size_for(scale: float = DEFAULT_SCALE) -> tuple[int, int]:
    """The village size in px at `scale` (1.0 = 816x480, 0.7 = 571x336)."""
    return round(BASE_W * scale), round(BASE_H * scale)


def default_out(scale: float) -> Path:
    if abs(scale - DEFAULT_SCALE) < 1e-9:
        return OUT
    return OUT.with_name(f"village_ground_s{round(scale * 100):03d}.png")


def prepare(src: Image.Image, size: tuple[int, int] | None = None) -> Image.Image:
    size = size or size_for()
    img = fill_corners(src.convert("RGB").crop(TRIM)).resize(size, Image.LANCZOS)
    img = ImageEnhance.Brightness(img).enhance(BRIGHTNESS)
    img = ImageEnhance.Contrast(img).enhance(1.05)
    return ImageEnhance.Color(img).enhance(0.95)


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
            # lantern light, the window glow and the forge fire: yellow to orange, never green
            warm_light = r >= g and g - b > 30 and r > 110
            # the dusk sky is a grey slate, only a little blue: without this a few cloud pixels jump to the saturated
            # water blues and read as stray blue specks
            slate = b < r + 50

            def cost(c: tuple[str, tuple[float, float, float], tuple[int, int, int]]) -> float:
                d = (c[1][0] - lab[0]) ** 2 * LIGHTNESS_WEIGHT + (c[1][1] - lab[1]) ** 2 + (c[1][2] - lab[2]) ** 2
                if greenish and c[0] not in GREEN_OK:
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
    W, H = img.size
    grid: list[list[str]] = []
    for y in range(H):
        row: list[str] = []
        for x in range(W):
            r, g, b = px[x, y]
            row.append(snapper.snap((r // 2 * 2, g // 2 * 2, b // 2 * 2)))
        grid.append(row)
    return grid


def cleanup(grid: list[list[str]], passes: int = 1) -> list[list[str]]:
    H, W = len(grid), len(grid[0])
    for _ in range(passes):
        out = [row[:] for row in grid]
        for y in range(H):
            for x in range(W):
                sym = grid[y][x]
                if sym in KEEP:
                    continue
                counts: dict[str, int] = {}
                same = 0
                for dy in (-1, 0, 1):
                    for dx in (-1, 0, 1):
                        if dx == 0 and dy == 0:
                            continue
                        n = grid[min(H - 1, max(0, y + dy))][min(W - 1, max(0, x + dx))]
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
    H, W = len(grid), len(grid[0])
    out = Image.new("RGB", (W, H))
    po = out.load()
    for y in range(H):
        for x in range(W):
            po[x, y] = palette.by_symbol[grid[y][x]]
    return out


# The painted training post of the first layout (feet 468,212 on the 816x480 painting): its body, arms and ground shadow
# fit this rectangle (x0, y0, x1, y1 at scale 1.0). The post moved on 2026-10-27 (core/village_layout.gd TRAINING_DUMMY),
# so the opt-in --erase-old-dummy replaces these pixels with the dirt around them.
OLD_DUMMY_1X = (446, 161, 493, 226)
ERASE_SEED = 20261027
# the three dirt browns of the forge yard (the base, the pinker patches and the darker mottling)
YARD_DIRT_RGB = {(118, 95, 71), (143, 95, 76), (98, 69, 61)}


def erase_old_dummy(grid: list[list[str]], scale: float) -> list[list[str]]:
    """Fills OLD_DUMMY_1X (scaled) with forge-yard dirt: 2x2 blocks that take the dirt symbols (the three dirt browns of the
    yard, never the shadow, grass or anvil next to it) of the pixels within 4 px outside the rectangle, nearer ones likelier.
    A fixed seed keeps the speckle natural and the result identical every run."""
    import random

    rng = random.Random(ERASE_SEED)
    x0, y0, x1, y1 = (round(v * scale) for v in OLD_DUMMY_1X)
    dirt = {sym for sym, rgb in palette.by_symbol.items() if rgb in YARD_DIRT_RGB}
    out = [row[:] for row in grid]
    for by in range(y0, y1, 2):
        for bx in range(x0, x1, 2):
            picks: list[tuple[str, float]] = []
            for k in range(1, 5):
                for sym, d in ((grid[by][x0 - k], bx - (x0 - k)), (grid[by][x1 + k - 1], (x1 + k - 1) - bx),
                               (grid[y0 - k][bx], by - (y0 - k)), (grid[y1 + k - 1][bx], (y1 + k - 1) - by)):
                    if sym in dirt:
                        picks.append((sym, 1.0 / max(d, 1) ** 2))
            sym = rng.choices([c for c, _w in picks], weights=[w for _c, w in picks])[0] if picks else "m"
            for y in range(by, min(by + 2, y1)):
                for x in range(bx, min(bx + 2, x1)):
                    out[y][x] = sym
    return out


def build(scale: float = DEFAULT_SCALE, erase_dummy: bool = False) -> Image.Image:
    grid = cleanup(snap_image(prepare(Image.open(SOURCE), size_for(scale))))
    if erase_dummy:
        grid = erase_old_dummy(grid, scale)
    return to_image(grid)


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


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--preview", help="also write a 2x preview and the prepared (unsnapped) image into this folder")
    parser.add_argument("--out", help="output path (default: presentation/village/village_ground.png at scale 0.7, "
                        "village_ground_sNNN.png next to it otherwise)")
    parser.add_argument("--scale", type=float, default=DEFAULT_SCALE,
                        help="village scale relative to 816x480 (default 0.7 = 571x336)")
    parser.add_argument("--erase-old-dummy", action="store_true",
                        help="paint the old training post out of the ground (it moved, see OLD_DUMMY_1X); the default output stays reproducible without it")
    args = parser.parse_args()
    if not SOURCE.exists():
        print("missing", SOURCE)
        return 1
    if not 0.25 <= args.scale <= 2.0:
        print("--scale must be between 0.25 and 2.0")
        return 1
    out = build(args.scale, args.erase_old_dummy)
    problems = check(out, args.scale)
    if problems:
        for p in problems:
            print("ERROR:", p)
        return 1
    path = Path(args.out) if args.out else default_out(args.scale)
    path.parent.mkdir(parents=True, exist_ok=True)
    out.save(path)
    if args.preview:
        folder = Path(args.preview)
        folder.mkdir(parents=True, exist_ok=True)
        out.resize((out.width * 2, out.height * 2), Image.NEAREST).save(folder / "village_ground_2x.png")
        prepare(Image.open(SOURCE), size_for(args.scale)).save(folder / "village_ground_prepared.png")
    print("wrote", path, out.size, "palette check OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
