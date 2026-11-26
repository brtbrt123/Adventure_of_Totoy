"""Rootcrown v2: preview pictures for the owner, nothing is wired into the game.

The first Rootcrown map was rejected in the owner's playtest (2026-11-09): the look "doesnt match our other scene" and
"the stage is too small". This proposal is built only from the existing forest scenes' own art:
  - the floor is stitched from the Root Hollow, Woodland Approach and Hollow Trial floor pixels (tools/art/quilt_ground.py);
  - every prop is an existing forest prop (Stag Glade, Root Hollow, Woodland, Hollow Trial, Forest Route);
  - only the beacon tower is new art: art/reference/rootcrown_v2/tower_dark.png and tower_lit.png, made by
    tools/art/make_rootcrown_tower.py from two Higgsfield pictures (a marked placeholder is drawn if they are missing).

Outputs (docs/previews/rootcrown_v2/):
  floor.png                  the stitched floor, 960x640 game pixels
  rootcrown_v2_map_2x.png    floor and props at 2x, plain (no night light), like the other scenes' plain composites
  rootcrown_v2_size.png      the same map with the sizes: the fight floor, the screen, the first build's floor, the old
                             arena, the Colossus at its new size with Totoy
  rootcrown_v2_compare.png   one game screen (384x216) of the Stag Glade, Root Hollow and the new map side by side, 2x
  rootcrown_v2_tower_end.png the tower end as the game camera shows it, hero at three spots, dark and lit, 2x
  layout.json                the numbers above, for the build step

Run: python tools/art/make_rootcrown_v2_preview.py [--seed N]
"""
from __future__ import annotations

import argparse
import json
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, str(Path(__file__).resolve().parent))
from quilt_ground import load_sources, quilt  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "docs" / "previews" / "rootcrown_v2"
SPRITES = ROOT / "art" / "build" / "sprites"
DEF_FILES = ["prop_defs.json", "prop_defs_root_hollow.json", "prop_defs_woodland.json", "prop_defs_hollow_trial.json"]

W, H = 1024, 720                       # 64 x 45 tiles; the first build was 640x360
VIEW = (384, 216)
# The dirt clearing: a superellipse round the fight floor, its edge wobbled so it reads as trodden earth, not a shape.
# Its walkable area is about the old arena's (744x424 walkable); all of it is open ground.
CLEAR_C = (512, 410)
CLEAR_R = (392, 228)
CLEAR_N = 3.0
FIGHT = (200, 238, 624, 344)          # x, y, w, h: kept free of every prop
# The tower stands on the dirt at the clearing's top, with room above it for the trees' crowns (2026-11-25: on the
# owner's "this looks off" the slab ring under it was dropped and the map grew 48 px at the top).
TOWER = (512, 204)                     # the tower's feet
TOWER_BOX = (128, 144)                 # placeholder footprint, w x h above the feet (only if the tower art is missing)
FORECOURT = (512, 226, 118, 30)        # centre and radii of the dirt in front of the tower's foot
TOWER_MOUND = (512, 200, 60, 20)       # grass round the tower's foot, so its roots sit in grass that frays onto the dirt
# Props that stand in a patch of grass at the clearing's edge instead of on bare dirt (owner 2026-11-26: the stones and bushes
# "look like it just got put in there"): a grass seat of about their base's width under each of them.
SEATED = ("forest_standing_stone", "glade_stone_", "root_hollow_rune_stones", "hollow_trial_rune_rock_", "glade_thorns",
          "forest_thorns_", "forest_rock_root", "glade_rock", "root_hollow_boulder", "forest_rocks", "woodland_rocks",
          "forest_flowers", "root_hollow_mushrooms", "glade_mushrooms", "glade_antler", "hollow_trial_roots_",
          "root_hollow_roots", "root_hollow_branches", "forest_pedestal")
PATH_X = 512                           # the climb from the glade enters at the bottom edge
ENTRY = (512, 698)
CHECKPOINT = (512, 656)
COLOSSUS_START = (512, 378)
# The prop list below was drawn on a 960x640 sketch round a clearing at (480, 344) with radii (360, 210); fit() moves
# each placement to the same spot of the real clearing.
SKETCH_C = (480, 344)
SKETCH_R = (360, 210)
# For the size picture: the old numbers (core/tuning.gd) and a guess at the redesigned boss (step 3 decides them).
OLD = {"body": 20, "stomp_outer": 100, "charge": 170, "arena_walkable": (744, 424)}
NEW = {"body": 46, "reach_scale": 1.5}
V1 = {"fight": (264, 120), "plateau": (456, 192)}


# ------------------------------------------------------------------ floor

ISLANDS = 62          # small patches of grass stitched into the earth (owner 2026-11-26: "our dirt ground looks empty")


def grass_islands(lab: np.ndarray, seed: int) -> np.ndarray:
    """Where small grass islands grow in the earth: ISLANDS patches 12..30 px across (a few up to 48 near the edge), more of
    them towards the clearing's edge and fewer in the middle, never crowding each other or the climb. Flat ground: walked over
    like the dirt."""
    rng = np.random.default_rng(seed + 101)
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float64)
    out = np.zeros_like(lab)
    placed: list[tuple[float, float]] = []
    tries = 0
    while len(placed) < ISLANDS and tries < 20000:
        tries += 1
        x, y = rng.uniform(CLEAR_C[0] - CLEAR_R[0], CLEAR_C[0] + CLEAR_R[0]), rng.uniform(CLEAR_C[1] - CLEAR_R[1], CLEAR_C[1] + CLEAR_R[1])
        if not lab[int(y), int(x)] or y > CLEAR_C[1] + CLEAR_R[1] * 0.85:
            continue
        edge = (abs((x - CLEAR_C[0]) / CLEAR_R[0]) ** CLEAR_N + abs((y - CLEAR_C[1]) / CLEAR_R[1]) ** CLEAR_N) ** (1.0 / CLEAR_N)
        if rng.uniform() > 0.3 + 0.7 * edge ** 2:
            continue
        if any((x - px) ** 2 + (y - py) ** 2 < 38.0 ** 2 for px, py in placed):
            continue
        r = rng.uniform(11.0, 16.0) if edge > 0.6 and rng.uniform() < 0.3 else rng.uniform(4.0, 10.0)
        out |= ((xx - x) / (r * 1.5)) ** 2 + ((yy - y) / (r * 0.8)) ** 2 < 1.0
        placed.append((x, y))
    return out


def clearing_label(seed: int, props: list[dict] | None = None, islands: bool = True) -> np.ndarray:
    rng = np.random.default_rng(seed)
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float64)
    dx, dy = (xx - CLEAR_C[0]) / CLEAR_R[0], (yy - CLEAR_C[1]) / CLEAR_R[1]
    ang = np.arctan2(dy, dx)
    wob = 1.0
    for k, amp in ((3, 0.035), (5, 0.03), (8, 0.02), (13, 0.012)):
        wob = wob + amp * np.sin(k * ang + rng.uniform(0, 2 * math.pi))
    lab = (np.abs(dx) ** CLEAR_N + np.abs(dy) ** CLEAR_N) ** (1.0 / CLEAR_N) < wob
    # the climb: a path from the clearing's bottom to the map's bottom edge, gently curving
    for y in range(int(CLEAR_C[1] + CLEAR_R[1] * 0.8), H):
        t = (y - 588) / 140.0
        cx = PATH_X + 10 * math.sin(t * 2.4)
        half = 46 + 6 * math.sin(y * 0.11) + 4 * math.sin(y * 0.31)
        lab[y, max(0, int(cx - half)):min(W, int(cx + half))] = True
    # the tower's forecourt: earth round its foot
    fx, fy = (xx - FORECOURT[0]) / FORECOURT[2], (yy - FORECOURT[1]) / FORECOURT[3]
    lab |= (fx * fx + fy * fy) < 1.0
    fx, fy = (xx - TOWER_MOUND[0]) / TOWER_MOUND[2], (yy - TOWER_MOUND[1]) / TOWER_MOUND[3]
    lab &= ~((fx * fx + fy * fy) < 1.0)
    for q in props or []:
        if not q["type"].startswith(SEATED):
            continue
        w = sprite(q["type"]).width
        rx, ry = max(14.0, w * 0.55), 11.0
        fx, fy = (xx - q["x"]) / rx, (yy - (q["y"] - 3)) / ry
        lab &= ~((fx * fx + fy * fy) < 1.0)
    fx, fy = (xx - FIGHT[0] - FIGHT[2] / 2) / (FIGHT[2] / 2), (yy - FIGHT[1] - FIGHT[3] / 2) / (FIGHT[3] / 2)
    lab |= (np.abs(fx) <= 1.0) & (np.abs(fy) <= 1.0)     # never let the wobble bite into the fight floor
    if islands:
        lab &= ~grass_islands(lab, seed)
    return lab


def shade_map(lab: np.ndarray) -> np.ndarray:
    """Wished grass brightness (0 darkest .. 1 lightest of the source floors' grass; NaN on dirt): light at the clearing's
    edge where the sky is open, darker the deeper under the trees, darkest behind the tower and at the map's rim."""
    cell = 8
    gh, gw = H // cell, W // cell
    small = lab[: gh * cell, : gw * cell].reshape(gh, cell, gw, cell).any((1, 3))
    dist = np.where(small, 0.0, np.inf)
    for _ in range(gh + gw):                              # city-block distance to the nearest dirt, in cells
        nxt = dist.copy()
        nxt[1:] = np.minimum(nxt[1:], dist[:-1] + 1)
        nxt[:-1] = np.minimum(nxt[:-1], dist[1:] + 1)
        nxt[:, 1:] = np.minimum(nxt[:, 1:], dist[:, :-1] + 1)
        nxt[:, :-1] = np.minimum(nxt[:, :-1], dist[:, 1:] + 1)
        if np.array_equal(nxt, dist):
            break
        dist = nxt
    d = np.zeros((H, W))
    d[: gh * cell, : gw * cell] = np.kron(dist, np.ones((cell, cell))) * cell
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float64)
    want = np.clip(0.78 - d / 150.0, 0.12, 0.78)
    behind = np.exp(-(((xx - TOWER[0]) / 120.0) ** 2 + ((yy - (TOWER[1] - 80)) / 70.0) ** 2))
    want *= 1.0 - 0.65 * behind
    rim = np.clip(np.minimum.reduce([xx, yy, W - 1 - xx, H - 1 - yy]) / 70.0, 0.0, 1.0)
    want *= 0.55 + 0.45 * rim
    want[lab] = np.nan
    return want


def make_floor(seed: int, props: list[dict] | None = None) -> Image.Image:
    lab = clearing_label(seed, props)
    rgb = quilt(lab, load_sources(), seed=seed, shade=shade_map(lab))
    return Image.fromarray(rgb, "RGB").convert("RGBA")


# ------------------------------------------------------------------ props

def load_defs() -> dict:
    defs = {}
    for f in DEF_FILES:
        defs.update(json.loads((ROOT / "data" / "props" / f).read_text(encoding="utf-8"))["props"])
    return defs


def P(t: str, x: float, y: float, flip: bool = False) -> dict:
    return {"type": t, "x": round(x), "y": round(y), "flip": flip}


def fit(q: dict) -> dict:
    x = CLEAR_C[0] + (q["x"] - SKETCH_C[0]) * CLEAR_R[0] / SKETCH_R[0]
    y = CLEAR_C[1] + (q["y"] - SKETCH_C[1]) * CLEAR_R[1] / SKETCH_R[1]
    return P(q["type"], x, min(y, H), q["flip"])


def rootcrown_props() -> list[dict]:
    """Every placement, from the existing forest props only. The fight floor FIGHT stays empty."""
    p: list[dict] = []
    # --- the tree wall round the hilltop (Root Hollow and Woodland trees, as Root Hollow mixes them)
    p += [P("root_hollow_tree_ancient", 96, 150), P("root_hollow_tree_ancient", 866, 146, True),
          P("root_hollow_tree_rootwall", 300, 96), P("root_hollow_tree_rootwall", 660, 98, True),
          P("woodland_tree_broad", 200, 70), P("woodland_tree_broad", 770, 66, True),
          P("hollow_trial_tree_2", 380, 52), P("hollow_trial_tree_1", 586, 50, True),
          P("hollow_trial_tree_1", 56, 300), P("hollow_trial_tree_2", 912, 300, True),
          P("root_hollow_tree_rootwall", 60, 440), P("root_hollow_tree_rootwall", 904, 446, True),
          P("woodland_tree_broad", 120, 600), P("woodland_tree_broad", 846, 604, True),
          P("hollow_trial_tree_1", 270, 640), P("hollow_trial_tree_2", 700, 640, True),
          P("woodland_tree_slender", 30, 200), P("woodland_tree_slender", 936, 214, True),
          P("woodland_tree_slender", 360, 640), P("woodland_tree_slender", 610, 636, True)]
    # --- undergrowth between the trunks
    p += [P("woodland_bush", 150, 236), P("woodland_bush", 820, 232, True), P("glade_bush_1", 104, 372),
          P("glade_bush_1", 862, 370, True), P("hollow_trial_bush_1", 170, 512), P("hollow_trial_bush_3", 800, 516),
          P("woodland_bush", 230, 590), P("woodland_bush", 744, 588, True), P("glade_bush_2", 250, 130),
          P("glade_bush_2", 716, 128, True), P("hollow_trial_bush_2", 40, 520), P("hollow_trial_bush_4", 930, 530),
          P("forest_fern_1", 330, 600), P("forest_fern_2", 640, 600, True), P("glade_fern_1", 18, 380),
          P("glade_fern_2", 944, 400, True)]
    # --- the ring's edge: rune stones and standing stones (the song's wardens), briars, roots and rubble
    p += [P("forest_standing_stone", 168, 300), P("forest_standing_stone", 794, 302, True),
          P("glade_stone_2", 392, 150), P("glade_stone_4", 568, 150, True),
          P("root_hollow_rune_stones", 160, 470), P("root_hollow_rune_stones", 800, 468, True),
          P("hollow_trial_rune_rock_5", 250, 178), P("hollow_trial_rune_rock_1", 714, 176, True),
          P("hollow_trial_rune_rock_3", 128, 404), P("hollow_trial_rune_rock_4", 834, 410, True),
          P("hollow_trial_rune_rock_2", 300, 540), P("hollow_trial_rune_rock_6", 662, 542)]
    p += [P("glade_thorns", 140, 210), P("forest_thorns_1", 826, 196, True), P("forest_thorns_2", 230, 536),
          P("glade_thorns", 734, 540, True), P("forest_thorns_2", 108, 486, True), P("forest_thorns_1", 860, 488)]
    p += [P("root_hollow_roots", 320, 150), P("root_hollow_roots", 640, 152, True), P("forest_rock_root", 164, 250),
          P("forest_rock_root", 796, 252, True), P("hollow_trial_roots_1", 150, 340), P("hollow_trial_roots_2", 820, 342)]
    p += [P("glade_rocks_small", 280, 172), P("glade_rock_2", 690, 172, True), P("root_hollow_boulder", 136, 260),
          P("root_hollow_boulder", 830, 266, True), P("glade_rock_1", 248, 520), P("glade_rock_3", 714, 518, True),
          P("forest_rocks", 380, 548), P("woodland_rocks", 588, 552, True)]
    # --- the climb: only the two dark stone lanterns at its foot (placed below, from the path); the lamp posts were removed on
    # the owner's word (2026-11-26: "remove the post light")
    # --- small ground life
    p += [P("root_hollow_mushrooms", 150, 400), P("glade_mushrooms", 812, 398, True), P("forest_flowers", 300, 176),
          P("root_hollow_branches", 610, 174), P("glade_antler", 846, 560)]
    # --- tufts at the feet of the stones and rocks, so they grow out of the ground instead of standing on it
    p += [P("hollow_trial_fern_1", 186, 306), P("hollow_trial_fern_2", 776, 308), P("glade_fern_2", 410, 156),
          P("hollow_trial_fern_2", 552, 156), P("hollow_trial_fern_1", 178, 474), P("hollow_trial_fern_2", 784, 472),
          P("forest_fern_small", 266, 182), P("forest_fern_small", 700, 182), P("hollow_trial_fern_1", 262, 524),
          P("hollow_trial_fern_2", 702, 522), P("hollow_trial_bush_4", 396, 552), P("hollow_trial_bush_4", 572, 556)]
    out = [fit(q) for q in p]
    # --- the tower's foot (placed from the tower, not the sketch): its roots run on into the ground, stones it shed lie
    # in the grass and the dirt, ferns and mushrooms grow in its shade
    # the stone lanterns at the head of the climb stand on the grass either side of it, not on its dirt (owner 2026-11-26)
    out += [P("forest_pedestal", PATH_X - 100, 690), P("forest_pedestal", PATH_X + 108, 692)]  # lower down the climb (owner: "more down")
    tx, ty = TOWER
    out += [P("hollow_trial_roots_1", tx - 46, ty + 12), P("hollow_trial_roots_2", tx + 48, ty + 13),
            P("root_hollow_branches", tx - 88, ty + 18), P("glade_rocks_small", tx + 70, ty + 10),
            P("forest_rocks", tx - 74, ty + 6), P("hollow_trial_fern_1", tx - 36, ty + 4), P("hollow_trial_fern_2", tx + 30, ty + 5),
            P("forest_fern_small", tx - 100, ty + 2), P("glade_fern_2", tx + 100, ty + 4, True),
            P("root_hollow_mushrooms", tx + 40, ty + 20)]
    return out


def check_fight_floor(props: list[dict], defs: dict) -> list[str]:
    """Names of props whose body (sprite bottom 12 px or a collider) reaches into the fight floor."""
    fx, fy, fw, fh = FIGHT
    bad = []
    for q in props:
        d = defs[q["type"]]
        cols = d["colliders"] or [[0, 0, 4]]
        for cx, cy, r in cols:
            x = q["x"] + (-cx if q["flip"] else cx)
            y = q["y"] + cy
            if fx - r < x < fx + fw + r and fy - r < y < fy + fh + r:
                bad.append(q["type"])
                break
    return bad


def sprite(t: str) -> Image.Image:
    return Image.open(SPRITES / f"{t}.png").convert("RGBA")


PROP_ART = json.loads((ROOT / "presentation" / "common" / "prop_art.json").read_text(encoding="utf-8"))["props"]
FRAMES = json.loads((ROOT / "art" / "build" / "sprites.json").read_text(encoding="utf-8"))["frames"]
INK = (28, 24, 36)              # presentation/common/actor_shadow.gd INK, palette "0"
CAST_ALPHA = 0.30               # presentation/common/environment_light.gd PROP_SHADOW_ALPHA
CONTACT_CORE, CONTACT_EDGE = 0.24, 0.10   # props_layer.draw_shadow at the default strength 0.25
ACTOR_ALPHA = 0.25


def _shadow_rows(core: list, edge: list, origin: tuple[int, int], flip: bool, width: int, layer: np.ndarray):
    for rows, a in ((edge, CONTACT_EDGE), (core, CONTACT_CORE)):
        for x0, y, n in rows:
            x = width - x0 - n if flip else x0
            X, Y = origin[0] + x, origin[1] + y
            if 0 <= Y < layer.shape[0]:
                lo, hi = max(0, X), min(layer.shape[1], X + n)
                if lo < hi:
                    layer[Y, lo:hi] = np.maximum(layer[Y, lo:hi], a)


def _actor_rows(feet: tuple[int, int], radius: float, layer: np.ndarray):
    """presentation/common/actor_shadow.gd plan(): a hard-pixel ellipse of row spans under the feet."""
    rx = max(2.0, radius * 0.65)
    ry = max(2.0, rx * 0.25)
    cx, cy = round(feet[0]), round(feet[1]) + 1
    for dy in range(-round(ry), round(ry) + 1):
        t = dy / (ry + 0.5)
        half = int(math.floor(rx * math.sqrt(max(0.0, 1.0 - t * t)) + 0.5))
        if half > 0 and 0 <= cy + dy < layer.shape[0]:
            lo, hi = max(0, cx - half), min(layer.shape[1], cx + half)
            layer[cy + dy, lo:hi] = np.maximum(layer[cy + dy, lo:hi], ACTOR_ALPHA)


def _stamp(cast: Image.Image, pos: tuple[int, int], layer: np.ndarray):
    a = np.asarray(cast)[..., 3] > 0
    x, y = pos
    h, w = a.shape
    y0, x0 = max(0, y), max(0, x)
    y1, x1 = min(layer.shape[0], y + h), min(layer.shape[1], x + w)
    if y0 < y1 and x0 < x1:
        sub = a[y0 - y:y1 - y, x0 - x:x1 - x]
        region = layer[y0:y1, x0:x1]
        region[sub] = np.maximum(region[sub], CAST_ALPHA)


def draw_shadows(board: Image.Image, props: list[dict], defs: dict, tower_feet: tuple[int, int] | None = None,
                 actors: list[tuple[int, int]] = ()):
    """The shadows the game draws before the props (presentation/common/props_layer.gd draw_shadow): each prop's moonlight
    cast shadow (fx_shadow_* at PROP_SHADOW_ALPHA) and its contact shadow rows from presentation/common/prop_art.json; a prop
    without that data gets the actor ellipse, as in the game. The tower's come from art/reference/rootcrown_v2/tower_cut.json."""
    cast = np.zeros((board.height, board.width))
    contact = np.zeros_like(cast)
    for q in props:
        d = defs[q["type"]]
        ax, ay = d["anchor"]
        fw = FRAMES.get(q["type"], {}).get("w", sprite(q["type"]).width)
        flip = bool(q.get("flip"))
        origin = (round(q["x"] - (fw - ax) if flip else q["x"] - ax), round(q["y"] - ay))
        art = PROP_ART.get(q["type"], {})
        name = art.get("cast_shadow", {}).get("flipped" if flip else "normal", "")
        if name and name in FRAMES:
            f = FRAMES[name]
            _stamp(sprite(name), (round(q["x"] - f["ax"]), round(q["y"] - f["ay"])), cast)
        plan = art.get("contact_shadow", {})
        if plan:
            _shadow_rows(plan["core"], plan["edge"], origin, flip, plan["size"][0], contact)
        else:
            _actor_rows((q["x"], q["y"]), min(22.0, fw * 0.2), contact)
    meta_path = TOWER_ART / "tower_cut.json"
    if tower_feet is not None and meta_path.exists():
        meta = json.loads(meta_path.read_text(encoding="utf-8"))
        c = meta["cast_shadow"]["normal"]
        img = Image.open(TOWER_ART / c["image"]).convert("RGBA")
        _stamp(img, (tower_feet[0] - c["feet"][0], tower_feet[1] - c["feet"][1]), cast)
        ax, ay = meta["anchor"]
        plan = meta["contact_shadow"]
        _shadow_rows(plan["core"], plan["edge"], (round(tower_feet[0] - ax), round(tower_feet[1] - ay)), False,
                     plan["size"][0], contact)
    for a in actors:
        _actor_rows(a, 10.0, contact)
    rgb = np.asarray(board.convert("RGB")).astype(np.float64)
    rgb *= (1.0 - cast)[..., None]
    rgb = rgb * (1.0 - contact)[..., None] + np.array(INK, dtype=np.float64) * contact[..., None]
    board.paste(Image.fromarray(rgb.round().astype(np.uint8), "RGB").convert("RGBA"))


def draw_props(board: Image.Image, props: list[dict], defs: dict, extra: list[tuple[int, Image.Image, tuple[int, int]]] = ()):
    items = []
    for q in props:
        d = defs[q["type"]]
        img = sprite(q["type"])
        ax, ay = d["anchor"]
        if q.get("flip"):
            img = img.transpose(Image.FLIP_LEFT_RIGHT)
            ax = img.width - ax
        items.append((q["y"], img, (round(q["x"] - ax), round(q["y"] - ay))))
    items += list(extra)
    for _, img, pos in sorted(items, key=lambda it: it[0]):
        board.alpha_composite(img, pos)


def hero() -> tuple[Image.Image, tuple[int, int]]:
    return sprite("hero2_idle_right_1"), (12, 35)


def tower_placeholder() -> Image.Image:
    w, h = TOWER_BOX
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    for i in range(0, w, 6):
        d.line([(i, 0), (min(w - 1, i + 3), 0)], fill=(235, 235, 235, 255))
        d.line([(i, h - 1), (min(w - 1, i + 3), h - 1)], fill=(235, 235, 235, 255))
    for j in range(0, h, 6):
        d.line([(0, j), (0, min(h - 1, j + 3))], fill=(235, 235, 235, 255))
        d.line([(w - 1, j), (w - 1, min(h - 1, j + 3))], fill=(235, 235, 235, 255))
    d.rectangle([1, 1, w - 2, h - 2], fill=(20, 24, 30, 120))
    for k, line in enumerate(["BEACON TOWER", "new art,", "made from these", "props (picture", "comes next)"]):
        tw = d.textlength(line)
        d.text(((w - tw) / 2, 40 + k * 13), line, fill=(255, 255, 255, 255))
    return im


TOWER_ART = ROOT / "art" / "reference" / "rootcrown_v2"


def tower_image(lit: bool) -> tuple[Image.Image, tuple[float, float]] | None:
    """The cut beacon tower (tools/art/make_rootcrown_tower.py) and its anchor, or None before it exists."""
    path = TOWER_ART / ("tower_lit.png" if lit else "tower_dark.png")
    meta = TOWER_ART / "tower_cut.json"
    if not path.exists() or not meta.exists():
        return None
    ax, ay = json.loads(meta.read_text(encoding="utf-8"))["anchor"]
    return Image.open(path).convert("RGBA"), (ax, ay)


def render_rootcrown(floor: Image.Image, props: list[dict], defs: dict, with_hero: bool = True, lit: bool = False,
                     hero_at: tuple[int, int] = CHECKPOINT) -> Image.Image:
    board = floor.copy()
    tower = tower_image(lit)
    if tower is None:
        extra = [(TOWER[1], tower_placeholder(), (TOWER[0] - TOWER_BOX[0] // 2, TOWER[1] - TOWER_BOX[1]))]
    else:
        img, (ax, ay) = tower
        extra = [(TOWER[1], img, (round(TOWER[0] - ax), round(TOWER[1] - ay)))]
    if with_hero:
        img, (ax, ay) = hero()
        extra.append((hero_at[1], img, (hero_at[0] - ax, hero_at[1] - ay)))
    draw_shadows(board, props, defs, TOWER if tower is not None else None, [hero_at] if with_hero else [])
    draw_props(board, props, defs, extra)
    return board


def render_scene(scene_id: str, defs: dict) -> Image.Image:
    """The plain composite of an existing layered scene from its data, drawn the same way as the new map."""
    sc = json.loads((ROOT / "data" / "scenes" / f"{scene_id}_props.json").read_text(encoding="utf-8"))
    board = Image.open(ROOT / sc["ground"].replace("res://", "")).convert("RGBA")
    props = [P(q["type"], q["x"], q["y"], bool(q.get("flip"))) for q in sc["props"] if q["type"] in defs]
    img, (ax, ay) = hero()
    e = sc["entries"][sc["default_entry"]]
    draw_shadows(board, props, defs, None, [tuple(e)])
    draw_props(board, props, defs, [(e[1], img, (e[0] - ax, e[1] - ay))])
    return board


# ------------------------------------------------------------------ pictures

def font(size: int):
    for name in ("arialbd.ttf", "arial.ttf", "DejaVuSans-Bold.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            continue
    return ImageFont.load_default()


def colossus_cutout(height: int) -> Image.Image:
    """The approved Colossus concept with its flat background removed, scaled to `height` game pixels (no Totoy)."""
    c = Image.open(ROOT / "art" / "reference" / "rootcrown_v1" / "colossus_concept_1.png").convert("RGB")
    a = np.asarray(c).astype(np.int32)
    bg = np.array([51, 57, 47])
    keep = np.abs(a - bg).sum(2) > 24
    h, w = keep.shape
    keep[:, : int(w * 0.31)] = False                       # Totoy stands on the left of the sheet
    ys, xs = np.nonzero(keep)
    box = (xs.min(), ys.min(), xs.max() + 1, ys.max() + 1)
    rgba = np.dstack([a.astype(np.uint8), (keep * 255).astype(np.uint8)])
    im = Image.fromarray(rgba, "RGBA").crop(box)
    s = height / im.height
    return im.resize((max(1, round(im.width * s)), height), Image.LANCZOS)


def dashed_rect(d: ImageDraw.ImageDraw, box, color, width=2, dash=10):
    x0, y0, x1, y1 = box
    for x in range(int(x0), int(x1), dash * 2):
        d.line([(x, y0), (min(x + dash, x1), y0)], fill=color, width=width)
        d.line([(x, y1), (min(x + dash, x1), y1)], fill=color, width=width)
    for y in range(int(y0), int(y1), dash * 2):
        d.line([(x0, y), (x0, min(y + dash, y1))], fill=color, width=width)
        d.line([(x1, y), (x1, min(y + dash, y1))], fill=color, width=width)


def size_picture(map_img: Image.Image, seed: int) -> Image.Image:
    Z = 1.5
    base = map_img.resize((round(W * Z), round(H * Z)), Image.NEAREST).convert("RGBA")
    base.alpha_composite(Image.new("RGBA", base.size, (0, 0, 0, 110)))
    d = ImageDraw.Draw(base)
    f, fb = font(15), font(17)
    cx, cy = CLEAR_C

    def R(x, y, w, h):
        return (x * Z, y * Z, (x + w) * Z, (y + h) * Z)

    # the walkable clearing's edge (cyan), from the floor's own dirt label
    lab = clearing_label(seed)
    edge = lab & ~(np.roll(lab, 1, 0) & np.roll(lab, -1, 0) & np.roll(lab, 1, 1) & np.roll(lab, -1, 1))
    ys, xs = np.nonzero(edge)
    for x, y in zip(xs[::2], ys[::2]):
        d.rectangle((x * Z, y * Z, x * Z + 2, y * Z + 2), fill=(90, 220, 235))
    walk = int(lab.sum())
    # the old arena's walkable floor, centred on the clearing
    aw, ah = OLD["arena_walkable"]
    dashed_rect(d, R(cx - aw / 2, cy - ah / 2, aw, ah), (240, 200, 70), 2)
    d.text(((cx - aw / 2) * Z + 6, (cy - ah / 2) * Z - 20), f"old arena walkable {aw}x{ah}", font=f, fill=(240, 200, 70))
    # the new open fight floor, one game screen, the first build's open floor
    d.rectangle(R(*FIGHT), outline=(90, 230, 120), width=4)
    d.text((FIGHT[0] * Z + 4, (FIGHT[1] + FIGHT[3]) * Z + 6), f"new open fight floor {FIGHT[2]}x{FIGHT[3]}, no props inside",
           font=fb, fill=(90, 230, 120))
    vw, vh = VIEW
    d.rectangle(R(FIGHT[0] + 10, FIGHT[1] + 10, vw, vh), outline=(255, 255, 255), width=2)
    d.text(((FIGHT[0] + 16) * Z, (FIGHT[1] + 14) * Z), f"one game screen {vw}x{vh}", font=f, fill=(255, 255, 255))
    v1w, v1h = V1["fight"]
    v1x, v1y = FIGHT[0] + 10, FIGHT[1] + FIGHT[3] - v1h - 10
    d.rectangle(R(v1x, v1y, v1w, v1h), outline=(235, 80, 80), width=3)
    d.text(((v1x + 6) * Z, (v1y + v1h) * Z - 24), f"first build's open floor {v1w}x{v1h}", font=f, fill=(235, 80, 80))
    # the Colossus at its new size, its body circle, the stomp ring and the charge if the reaches grow 1.5x
    bx, by = FIGHT[0] + FIGHT[2] - 170, cy - 10
    body = NEW["body"]
    ring = OLD["stomp_outer"] * NEW["reach_scale"]
    d.ellipse(((bx - ring) * Z, (by - ring) * Z, (bx + ring) * Z, (by + ring) * Z), outline=(235, 80, 80), width=2)
    d.text(((bx + ring * 0.6) * Z, (by - ring * 0.86) * Z - 18), f"stomp ring r{int(ring)}", font=f, fill=(235, 80, 80))
    d.ellipse(((bx - body) * Z, (by - body * 0.5) * Z, (bx + body) * Z, (by + body * 0.5) * Z), outline=(120, 200, 255), width=2)
    col = colossus_cutout(130)
    col = col.resize((round(col.width * Z), round(col.height * Z)), Image.NEAREST)
    base.alpha_composite(col, (round(bx * Z - col.width / 2), round(by * Z - col.height + 6 * Z)))
    d.text(((bx - 64) * Z, (by + 28) * Z), f"Colossus about 130 px tall, body r{body}", font=f, fill=(120, 200, 255))
    hi, (hax, hay) = hero()
    hi = hi.resize((round(hi.width * Z), round(hi.height * Z)), Image.NEAREST)
    hx, hy = bx - 100, by + 4
    base.alpha_composite(hi, (round((hx - hax) * Z), round((hy - hay) * Z)))
    d.text(((hx - 16) * Z, (hy + 4) * Z), "Totoy", font=f, fill=(255, 255, 255))
    ch = OLD["charge"] * NEW["reach_scale"]
    ly = FIGHT[1] + FIGHT[3] - 18
    lx = FIGHT[0] + FIGHT[2] - 14 - ch
    d.line([(lx * Z, ly * Z), ((lx + ch) * Z, ly * Z)], fill=(235, 80, 80), width=6)
    d.text((lx * Z, (ly - 14) * Z - 6), f"charge {int(ch)} px", font=f, fill=(235, 80, 80))
    pad = 92
    out = Image.new("RGBA", (base.width, base.height + pad), (24, 26, 32, 255))
    out.alpha_composite(base, (0, pad))
    d2 = ImageDraw.Draw(out)
    d2.text((12, 8), f"ROOTCROWN v2: map {W}x{H} (first build 640x360), drawn at 1.5x", font=font(20), fill=(255, 255, 255))
    d2.text((12, 38), f"Walkable ground (cyan edge): about {walk // 1000}k square px. Old arena {aw * ah // 1000}k (with "
            f"pillars), first build about {int(math.pi / 4 * V1['plateau'][0] * V1['plateau'][1]) // 1000}k.",
            font=f, fill=(200, 200, 200))
    d2.text((12, 62), "Red sizes assume the boss's reach grows 1.5x; step 3 sets the real numbers.", font=f, fill=(200, 200, 200))
    return out


def game_view(img: Image.Image, hero_x: int, hero_y: int) -> Image.Image:
    """What the game camera shows with the hero here: centred on him, clamped to the map (explore_scene._update_camera)."""
    vw, vh = VIEW
    x = min(max(0, hero_x - vw // 2), W - vw)
    y = min(max(0, hero_y - vh // 2), H - vh)
    return img.crop((x, y, x + vw, y + vh))


def screen_crop(img: Image.Image, cx: int, cy: int) -> Image.Image:
    vw, vh = VIEW
    x = min(max(0, cx - vw // 2), img.width - vw)
    y = min(max(0, cy - vh // 2), img.height - vh)
    return img.crop((x, y, x + vw, y + vh))


def compare_picture(rootcrown: Image.Image, defs: dict) -> Image.Image:
    glade = render_scene("glade_layered", defs)
    hollow = render_scene("root_hollow_layered", defs)
    trial = render_scene("hollow_trial_layered", defs)
    tiles = [("STAG GLADE (now)", screen_crop(glade, 280, 168)),
             ("ROOT HOLLOW (now)", screen_crop(hollow, 330, 210)),
             ("HOLLOW TRIAL (now)", screen_crop(trial, 256, 176)),
             ("ROOTCROWN v2: the tower end", screen_crop(rootcrown, TOWER[0], 236)),
             ("ROOTCROWN v2: the ring's west edge", screen_crop(rootcrown, 230, CLEAR_C[1] + 60)),
             ("ROOTCROWN v2: the climb in", screen_crop(rootcrown, PATH_X, CHECKPOINT[1] - 50))]
    Z, gap, lab = 2, 14, 26
    tw, th = VIEW[0] * Z, VIEW[1] * Z
    out = Image.new("RGBA", (tw * 3 + gap * 4, (th + lab) * 2 + gap * 3 + 40), (24, 26, 32, 255))
    d = ImageDraw.Draw(out)
    d.text((gap, 10), "One game screen each, 2x, with the game's prop shadows, no night light, for all six. Top: the scenes now. Bottom: the "
           "new map.", font=font(17), fill=(255, 255, 255))
    for i, (name, im) in enumerate(tiles):
        r, c = divmod(i, 3)
        x = gap + c * (tw + gap)
        y = 40 + gap + r * (th + lab + gap)
        d.text((x, y), name, font=font(17), fill=(255, 255, 255))
        out.alpha_composite(im.resize((tw, th), Image.NEAREST), (x, y + lab))
    return out


TOWER_VIEWS = [("hero beside the tower", (444, 176)), ("hero just in front of it", (512, 236)),
               ("hero at the top of the fight floor", (512, 290))]


def tower_end_picture(floor: Image.Image, props: list[dict], defs: dict) -> Image.Image:
    """The tower end as the game camera shows it with the hero at three spots, beacon dark (top) and lit (bottom), 2x."""
    Z, gap, lab = 2, 14, 26
    tw, th = VIEW[0] * Z, VIEW[1] * Z
    out = Image.new("RGBA", (tw * 3 + gap * 4, (th + lab + gap) * 2 + 40), (24, 26, 32, 255))
    d = ImageDraw.Draw(out)
    d.text((gap, 8), "The tower end as the game camera shows it (it follows the hero and stops at the map's edge), 2x, with the game's prop "
           "shadows; no night light, glow or mist.", font=font(17), fill=(255, 255, 255))
    for r, lit in enumerate((False, True)):
        for c, (name, at) in enumerate(TOWER_VIEWS):
            im = render_rootcrown(floor, props, defs, lit=lit, hero_at=at)
            x = gap + c * (tw + gap)
            y = 40 + r * (th + lab + gap)
            d.text((x, y), f"{'LIT' if lit else 'DARK'}: {name}", font=font(17), fill=(255, 255, 255))
            out.alpha_composite(game_view(im, *at).resize((tw, th), Image.NEAREST), (x, y + lab))
    return out


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--seed", type=int, default=7)
    a = ap.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    defs = load_defs()
    props = rootcrown_props()
    bad = check_fight_floor(props, defs)
    if bad:
        raise SystemExit(f"props inside the fight floor: {bad}")
    floor = make_floor(a.seed, props)
    floor.convert("RGB").save(OUT / "floor.png")
    m = render_rootcrown(floor, props, defs)
    m.resize((W * 2, H * 2), Image.NEAREST).save(OUT / "rootcrown_v2_map_2x.png")
    if tower_image(True) is not None:
        tower_end_picture(floor, props, defs).save(OUT / "rootcrown_v2_tower_end.png")
    size_picture(m, a.seed).save(OUT / "rootcrown_v2_size.png")
    compare_picture(m, defs).save(OUT / "rootcrown_v2_compare.png")
    layout = {"size": [W, H], "fight_floor": list(FIGHT), "clearing_centre": list(CLEAR_C), "clearing_radii": list(CLEAR_R),
              "tower_feet": list(TOWER), "forecourt": list(FORECOURT), "entry": list(ENTRY), "checkpoint": list(CHECKPOINT),
              "colossus_start": list(COLOSSUS_START), "seed": a.seed, "props": props}
    (OUT / "layout.json").write_text(json.dumps(layout, indent=1), encoding="utf-8")
    tower = "the beacon tower cut-outs" if tower_image(False) is not None else "a placeholder box for the tower"
    print(f"Rootcrown v2 previews in {OUT} ({len(props)} props, all existing forest art, plus {tower})")


if __name__ == "__main__":
    main()
