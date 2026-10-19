"""Export the Black Form cut-in art for the game (presentation/cutin/).

Reads Codex's concept art (art/reference/black_katana_form/concept_v1.png: six black-form poses) and the black
aura wisps (aura_layers_v1.png) and writes clean, game-ready PNGs:
  black_form_pose_<name>.png      the isolated pose with a violet rim glow (name: crouch, ready, burst)
  black_form_pose_<name>_sil.png  the same pose as an ink silhouette with a violet outline (the impact frame)
  black_form_aura.png             the 12 aura wisp frames (6x2 atlas) with a violet glow
  black_form_cutin.json           sizes and anchors used by presentation/arena/black_form_cutin.gd
The poses overlap their neighbours on the sheet, so each is isolated by connected blobs (the six biggest are the
figures; small flecks join the nearest figure). Pillow only. Run from the project root:
  python tools/art/export_black_form_cutin.py
"""
import json
import math
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "presentation" / "cutin"
REF = ROOT / "art" / "reference" / "black_katana_form"
VIOLET = (154, 100, 255)
INK = (14, 6, 30)
POSE_DEF = {"crouch": 0, "ready": 1, "burst": 4}  # sheet cell index (3x2 grid, left to right, top to bottom)
FEET_X = {"crouch": 0.47, "ready": 0.47, "burst": 0.42}  # feet x as a fraction of the un-padded cut-out

concept = Image.open(REF / "concept_v1.png").convert("RGBA")
aura_sheet = Image.open(REF / "aura_layers_v1.png").convert("RGBA")


def isolate_poses():
    S = 2
    small = concept.getchannel("A").resize((concept.width // S, concept.height // S), Image.BOX)
    m = small.point(lambda v: 255 if v > 12 else 0)
    w, h = m.size
    px = list(m.getdata())
    lab = [0] * (w * h)
    comps = []  # (count, bbox)
    for start in range(w * h):
        if px[start] and not lab[start]:
            n = len(comps) + 1
            lab[start] = n
            st = [start]
            cnt = 0
            x0 = y0 = 10 ** 9
            x1 = y1 = -1
            while st:
                i = st.pop()
                cnt += 1
                y, x = divmod(i, w)
                if x < x0: x0 = x
                if x > x1: x1 = x
                if y < y0: y0 = y
                if y > y1: y1 = y
                for j in ((i + 1) if x + 1 < w else -1, (i - 1) if x > 0 else -1, (i + w) if y + 1 < h else -1, (i - w) if y > 0 else -1):
                    if j >= 0 and px[j] and not lab[j]:
                        lab[j] = n
                        st.append(j)
            comps.append((cnt, (x0, y0, x1, y1)))
    order = sorted(range(len(comps)), key=lambda c: -comps[c][0])
    cores = order[:6]

    def cell_of(c):
        x0, y0, x1, y1 = comps[c][1]
        cx, cy = (x0 + x1) / 2 * S, (y0 + y1) / 2 * S
        return int(cy // (concept.height / 2)) * 3 + int(cx // (concept.width / 3))

    core_by_cell = {cell_of(c): c for c in cores}

    def box_dist(a, b):
        dx = max(0, max(a[0], b[0]) - min(a[2], b[2]))
        dy = max(0, max(a[1], b[1]) - min(a[3], b[3]))
        return math.hypot(dx, dy)

    owner = {}
    for c in range(len(comps)):
        if c in cores:
            owner[c + 1] = c
            continue
        best, bd = None, 1e9
        for k in cores:
            dd = box_dist(comps[c][1], comps[k][1])
            if dd < bd:
                best, bd = k, dd
        if bd <= 24:  # 48 px at full size
            owner[c + 1] = best
    poses = {}
    for cell, core in core_by_cell.items():
        keep = bytes(255 if (l and owner.get(l) == core) else 0 for l in lab)
        mask = Image.frombytes("L", (w, h), keep).resize(concept.size, Image.NEAREST)
        mask = mask.filter(ImageFilter.MaxFilter(3))
        x0, y0, x1, y1 = comps[core][1]
        # bbox of everything owned
        bb = mask.getbbox()
        img = concept.copy()
        img.putalpha(ImageChops.multiply(concept.getchannel("A"), mask))
        poses[cell] = img.crop(bb)
    return poses


def rim_light(img, color, radius=6, strength=1.6):
    a = img.getchannel("A")
    pad = radius * 3
    big = Image.new("RGBA", (img.width + 2 * pad, img.height + 2 * pad), (0, 0, 0, 0))
    big.alpha_composite(img, (pad, pad))
    ab = big.getchannel("A")
    glow = Image.new("RGBA", big.size, color + (0,))
    glow.putalpha(ab.filter(ImageFilter.GaussianBlur(radius)).point(lambda v: int(min(255, v * strength))))
    out = Image.alpha_composite(glow, big)
    return out, pad, big

def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    all_poses = isolate_poses()
    meta = {"poses": {}, "aura": {}}
    for name, idx in POSE_DEF.items():
        lit, pad, raw = rim_light(all_poses[idx], VIOLET)
        lit.save(OUT / f"black_form_pose_{name}.png")
        # impact silhouette: the figure's body without the small aura flecks, ink fill + violet outline
        alpha = raw.getchannel("A").point(lambda v: 255 if v > 128 else 0)
        alpha = alpha.filter(ImageFilter.MinFilter(5)).filter(ImageFilter.MaxFilter(5))
        sil = Image.new("RGBA", raw.size, VIOLET + (0,))
        sil.putalpha(alpha.filter(ImageFilter.MaxFilter(5)))
        ink = Image.new("RGBA", raw.size, INK + (0,))
        ink.putalpha(alpha)
        sil = Image.alpha_composite(sil, ink)
        sil.save(OUT / f"black_form_pose_{name}_sil.png")
        meta["poses"][name] = {"w": lit.width, "h": lit.height, "pad": pad, "inner_w": lit.width - 2 * pad, "inner_h": lit.height - 2 * pad, "feet_x": FEET_X[name]}
    # aura wisps: crop each to its content, add a violet glow, bottom-centre them in equal cells of a 6x2 atlas
    wisps = []
    cw, ch = aura_sheet.width // 6, aura_sheet.height // 2
    for row in range(2):
        for col in range(6):
            cell = aura_sheet.crop((col * cw, row * ch, (col + 1) * cw, (row + 1) * ch))
            cell = cell.crop(cell.getchannel("A").getbbox())
            pad = 12
            big = Image.new("RGBA", (cell.width + 2 * pad, cell.height + 2 * pad), (0, 0, 0, 0))
            big.alpha_composite(cell, (pad, pad))
            glow = Image.new("RGBA", big.size, (150, 95, 235, 0))
            glow.putalpha(big.getchannel("A").filter(ImageFilter.GaussianBlur(7)).point(lambda v: min(255, int(v * 1.3))))
            wisps.append(Image.alpha_composite(glow, big))
    cell_w = max(w.width for w in wisps)
    cell_h = max(w.height for w in wisps)
    atlas = Image.new("RGBA", (cell_w * 6, cell_h * 2), (0, 0, 0, 0))
    frames = []
    for i, w in enumerate(wisps):
        x0 = (i % 6) * cell_w + (cell_w - w.width) // 2
        y0 = (i // 6) * cell_h + (cell_h - w.height)
        atlas.alpha_composite(w, (x0, y0))
        frames.append({"x": x0, "y": y0, "w": w.width, "h": w.height})
    atlas.save(OUT / "black_form_aura.png")
    meta["aura"] = {"cell_w": cell_w, "cell_h": cell_h, "frames": frames}
    (OUT / "black_form_cutin.json").write_text(json.dumps(meta, indent=1) + "\n", encoding="utf-8", newline="\n")
    print("wrote", len(POSE_DEF) * 2 + 1, "images and the json to", OUT)
    return 0


if __name__ == "__main__":
    sys.exit(main())
