"""Effects for the Colossus from PixelFX (patch-gg/pixelfx, MIT, the owner's clone at C:\\Users\\Admin\\Desktop\\Projects\\pixelfx).

Renders chosen PixelFX effects with Totoy 36 ramps (never gold or red: those are combat cues), then snaps every frame to the
palette with hard alpha (a pixel is opaque when its alpha is at least ALPHA_CUT, else clear): PixelFX's glow and translucent smoke
drop out, the game's own lights glow instead. Writes, per effect, art/reference/pixelfx_colossus_v1/<name>/:
  raw/<pixelfx sheet>.png + .json   PixelFX's own output (the original, kept for provenance)
  <name>_<n>.png                     the snapped frames (review material until the owner approves them for art/src)
  frames.json                        fps, frame size and pivot (PixelFX's origin: where the effect stands)
and art/reference/pixelfx_colossus_v1/sources.json. Proposals for part 3b (docs/PLAN_colossus_step3.md); nothing is wired.

    python tools/art/import_pixelfx.py
"""
from __future__ import annotations

import json
import math
import subprocess
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
PIXELFX = Path(r"C:\Users\Admin\Desktop\Projects\pixelfx")
OUT = ROOT / "art" / "reference" / "pixelfx_colossus_v1"
ALPHA_CUT = 128
COMMIT = "5294518"

INK, CREAM = "#1c1824", "#f4ecd6"
DIRT = ["#2e211e", "#4d3a30", "#62453d", "#765f47", "#987959", "#bc9c72"]
STONE = ["#2f3231", "#444b49", "#5a625e", "#737769", "#9a9886", "#c6bfaa"]
WATER = ["#24365c", "#33508a", "#4a72ae", "#6f9bc8", "#a7cde0", "#e0f0ec"]
TEAL = ["#3f7f7a", "#6aa89a"]
GRASS = ["#26301c", "#3f5226", "#5a7a3a", "#7f9348", "#a0b159", "#c2cb7c"]

WOOD8 = [INK, *DIRT, CREAM]  # a root, dark to bright
SOIL8 = [INK, *DIRT, STONE[5]]
SONG4 = [WATER[0], TEAL[0], TEAL[1], WATER[4]]  # the stolen song's blue light, dark to bright
STONE8 = [INK, *STONE, CREAM]

# name: (PixelFX id, options, extra render flags, what it is for)
EFFECTS: dict[str, tuple[str, dict, list[str], str]] = {
    "root_thorn": ("nature/thorns", {"count": 1, "palette": WOOD8, "glow": SONG4, "soil": SOIL8, "seed": 8}, [],
                   "Root Snare: one root thorn bursting up, placed again and again along the real lane"),
    "boulder": ("nature/boulder", {"palette": STONE8, "sparks": [CREAM, STONE[5], STONE[4], STONE[3]], "size": 11, "seed": 11}, [],
                "Boulder Toss: the spinning stone (its flight is drawn along the real arc) and its landing burst"),
    "grab_vine": ("nature/vine-whip", {"palette": [INK, DIRT[0], DIRT[1], DIRT[2], GRASS[1], GRASS[2], GRASS[3], GRASS[5]],
                                       "thorn": [DIRT[0], DIRT[2], DIRT[4], DIRT[5]], "soil": SOIL8, "seed": 3, "angle": 0.24}, [],
                  "Heartroot Grab: a mossy root-arm lashing out along the lane (turned to the lane's angle)"),
    "shock_ring": ("impacts/heavy-landing", {"palette": [INK, *STONE], "stone": STONE[1], "seed": 14}, ["--no-actor"],
                   "the Boulder Toss's ring of shock: dust rings rolling out over the floor"),
}


def palette() -> list[tuple[int, int, int]]:
    data = json.loads((ROOT / "art" / "palette.json").read_text(encoding="utf-8"))
    reserved = set(data["reserved"])
    return [tuple(int(c["hex"][i:i + 2], 16) for i in (1, 3, 5)) for c in data["colors"] if c["symbol"] not in reserved]


def snap(frame: Image.Image, colours: list[tuple[int, int, int]]) -> Image.Image:
    out = Image.new("RGBA", frame.size, (0, 0, 0, 0))
    src, dst = frame.load(), out.load()
    cache: dict[tuple[int, int, int], tuple[int, int, int]] = {}
    for y in range(frame.height):
        for x in range(frame.width):
            r, g, b, a = src[x, y]
            if a < ALPHA_CUT:
                continue
            key = (r, g, b)
            if key not in cache:
                cache[key] = min(colours, key=lambda c: 2 * (c[0] - r) ** 2 + 4 * (c[1] - g) ** 2 + 3 * (c[2] - b) ** 2)
            dst[x, y] = (*cache[key], 255)
    return out


def render(name: str, effect: str, options: dict, flags: list[str]) -> tuple[Image.Image, dict]:
    raw = OUT / name / "raw"
    raw.mkdir(parents=True, exist_ok=True)
    cmd = ["node", "tools/render.mjs", effect, "--sheet", "--bg", "none", "--opts", json.dumps(options), "--out", str(raw), *flags]
    result = subprocess.run(cmd, cwd=PIXELFX, capture_output=True, text=True)
    if result.returncode != 0:
        raise SystemExit(f"{effect}: {result.stderr or result.stdout}")
    stem = effect.split("/")[1]
    folder = raw / effect
    sheet = Image.open(folder / f"{stem}.png").convert("RGBA")
    meta = json.loads((folder / f"{stem}.json").read_text(encoding="utf-8"))
    return sheet, meta


def blobs(img: Image.Image) -> list[tuple[int, tuple[int, int, int, int]]]:
    """Connected groups of opaque pixels (8 neighbours): [(pixel count, bbox x0, y0, x1, y1)], biggest first."""
    w, h = img.size
    alpha = img.getchannel("A").load()
    seen = bytearray(w * h)
    out = []
    for y in range(h):
        for x in range(w):
            if not alpha[x, y] or seen[y * w + x]:
                continue
            stack, count, box = [(x, y)], 0, [x, y, x, y]
            seen[y * w + x] = 1
            while stack:
                cx, cy = stack.pop()
                count += 1
                box = [min(box[0], cx), min(box[1], cy), max(box[2], cx), max(box[3], cy)]
                for nx in (cx - 1, cx, cx + 1):
                    for ny in (cy - 1, cy, cy + 1):
                        if 0 <= nx < w and 0 <= ny < h and alpha[nx, ny] and not seen[ny * w + nx]:
                            seen[ny * w + nx] = 1
                            stack.append((nx, ny))
            out.append((count, (box[0], box[1], box[2] + 1, box[3] + 1)))
    return sorted(out, reverse=True)


def anchors(name: str, folder: Path, meta: dict) -> dict:
    """Where the pieces stand, so a review script can place them on the real lanes. root_thorn: the thorn's foot. boulder: the
    stone's spin frames cut out (rock_<n>.png, centred) and the landing frames cut round the landing (land_<n>.png)."""
    frames = [Image.open(folder / f) for f in meta["frames"]]
    floor = meta["pivot"][1]
    if name == "root_thorn":
        tops = [(b[1][1], (b[1][0] + b[1][2]) // 2) for f in frames for b in blobs(f)[:1] if b[0] > 20]
        return {"anchor": [min(tops)[1], floor]}
    if name == "boulder":
        rock = blobs(frames[2])[0][0]
        impact = next(i for i, f in enumerate(frames) if i > 2 and blobs(f) and blobs(f)[0][0] > rock * 2.5)
        land = blobs(frames[impact])[0][1]
        land_x = (land[0] + land[2]) // 2
        spin = []
        for i in range(impact):
            b = blobs(frames[i])[0][1]
            cut = frames[i].crop((b[0] - 1, b[1] - 1, b[2] + 1, b[3] + 1))
            cut.save(folder / f"rock_{i + 1}.png")
            spin.append(f"rock_{i + 1}.png")
        landing = []
        for i in range(impact, len(frames)):
            cut = frames[i].crop((land_x - 64, 0, land_x + 64, frames[i].height))
            cut.save(folder / f"land_{i - impact + 1}.png")
            landing.append(f"land_{i - impact + 1}.png")
        return {"spin": spin, "landing": landing, "land_anchor": [64, floor]}
    return {}


def main() -> int:
    colours = palette()
    sources = {"what": "Effect proposals for the road Colossus, part 3b (docs/PLAN_colossus_step3.md), rendered with PixelFX and snapped "
                       "to Totoy 36 with hard alpha by tools/art/import_pixelfx.py. Review material; nothing is in the game.",
               "library": "https://github.com/patch-gg/pixelfx (MIT), the owner's clone outside this repo, commit " + COMMIT,
               "alpha_cut": ALPHA_CUT, "effects": {}}
    for name, (effect, options, flags, purpose) in EFFECTS.items():
        sheet, meta = render(name, effect, options, flags)
        info = meta["meta"]["pixelfx"]
        frames = []
        for i, row in enumerate(meta["frames"]):
            f = row["frame"]
            cut = snap(sheet.crop((f["x"], f["y"], f["x"] + f["w"], f["y"] + f["h"])), colours)
            file = f"{name}_{i + 1}.png"
            cut.save(OUT / name / file)
            frames.append(file)
        record = {"fps": info["fps"], "size": info["frameSize"], "pivot": info["pivot"], "frames": frames}
        record.update(anchors(name, OUT / name, record))
        (OUT / name / "frames.json").write_text(json.dumps(record, indent=1) + "\n", encoding="utf-8")
        sources["effects"][name] = {"pixelfx": effect, "options": options, "flags": flags, "for": purpose, "frames": len(frames),
                                    "fps": info["fps"], "pivot": info["pivot"]}
        print(f"{name}: {effect} {len(frames)} frames {info['frameSize']} pivot {info['pivot']}")
    (OUT / "sources.json").write_text(json.dumps(sources, indent=1) + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    sys.exit(main())
