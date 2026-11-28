"""Effects for the Colossus from PixelFX (patch-gg/pixelfx, MIT, the owner's clone at C:\\Users\\Admin\\Desktop\\Projects\\pixelfx).

Renders chosen PixelFX effects with Totoy 36 ramps (never gold or red: those are combat cues), then snaps every frame to the
palette with hard alpha (a pixel is opaque when its alpha is at least ALPHA_CUT, else clear): PixelFX's glow and translucent smoke
drop out, the game's own lights glow instead. Writes, per effect, art/reference/pixelfx_colossus_v1/<name>/:
  raw/<pixelfx sheet>.png + .json   PixelFX's own output (the original, kept for provenance)
  <name>_<n>.png                     the snapped frames (review material until the owner approves them for art/src)
  frames.json                        fps, frame size and pivot (PixelFX's origin: where the effect stands)
and art/reference/pixelfx_colossus_v1/sources.json. Proposals for part 3b (docs/PLAN_colossus_step3.md); nothing is wired.

    python tools/art/import_pixelfx.py             # render, snap and cut the proposals
    python tools/art/import_pixelfx.py --install   # then write the APPROVED ones into art/src (validate, build, preview after)

Approved by the owner on 2026-11-27 ("Yes, do that"): the Root Snare's thorn and the Boulder Toss's stone; on 2026-11-28
("Option B") the stone shard for the ring of shock, ("Yes, wire it") the reworked root-arm, and ("Yes, wire them") the 3c
effects: fx_colossus_song_shard (the thorn burst in the song's blue, round the Song Flare's rings) and fx_colossus_song_burst
(arcane/mana-burst in the song's blue, its gold blow); the Briar Ring's wall reuses fx_colossus_thorn. --install writes art/src/fx_colossus_thorn_<n>.txt (one thorn bursting up
and sinking), fx_colossus_shard_<n>.txt (the same in stone, set round the ring), fx_colossus_stone_spin_<n>.txt (the stone in
flight) and fx_colossus_stone_land_<n>.txt (its landing); generated, do not hand-edit. presentation/explore/colossus_view.gd
plays them. The root-arm is rendered at ARM_ANGLES (every 15 degrees, right half; the left half is drawn mirrored) through
tools/art/pixelfx_render.mjs (a margin, so the turned vine is not cut off) into fx_colossus_arm_<angle index>_<n>.
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
# per effect: the boulder's dust is alpha 128..223 and would become dark solid blobs; only its opaque rock and sparks are kept
CUTS = {"boulder": 240}
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
    # rework 2026-11-27 (the first mossy vine was thin and dark at night; heavy-landing's dust rings vanished with hard alpha)
    "grab_vine": ("nature/vine-whip", {"palette": [DIRT[1], DIRT[2], DIRT[3], DIRT[4], DIRT[5], STONE[5], CREAM, WATER[5]],
                                       "thorn": SONG4, "soil": SOIL8, "seed": 3, "angle": 0.24}, [],
                  "Heartroot Grab: a pale root-arm with the song's blue thorns lashing out along the lane (turned to its angle)"),
    "shock_ring": ("ice/frost-nova", {"palette": STONE8, "reach": 72, "seed": 4}, ["--no-actor"],
                   "the Boulder Toss's ring of shock, option A: PixelFX's ring of shards, set to the ring's real reach (72 px)"),
    "stone_thorn": ("nature/thorns", {"count": 1, "palette": STONE8, "glow": SONG4, "soil": SOIL8, "seed": 8}, [],
                    "the Boulder Toss's ring of shock, option B: one stone shard bursting up, placed round the real ring"),
    # part 3c proposals (2026-11-28)
    "song_shard": ("nature/thorns", {"count": 1, "palette": [INK, WATER[0], WATER[1], WATER[2], TEAL[0], WATER[3], WATER[4], WATER[5]],
                                     "glow": SONG4, "soil": SOIL8, "seed": 8}, [],
                   "Song Flare: a shard of the song's blue light bursting up, placed round each of its three real rings"),
    "song_burst": ("arcane/mana-burst", {"palette": [INK, WATER[0], WATER[1], WATER[2], TEAL[0], WATER[3], WATER[4], WATER[5], CREAM], "seed": 9}, [],
                   "Song Flare's last blow: the song's light rushing into its chest and blowing out"),
}


def palette() -> list[tuple[int, int, int]]:
    data = json.loads((ROOT / "art" / "palette.json").read_text(encoding="utf-8"))
    reserved = set(data["reserved"])
    return [tuple(int(c["hex"][i:i + 2], 16) for i in (1, 3, 5)) for c in data["colors"] if c["symbol"] not in reserved]


def snap(frame: Image.Image, colours: list[tuple[int, int, int]], cut: int = ALPHA_CUT) -> Image.Image:
    out = Image.new("RGBA", frame.size, (0, 0, 0, 0))
    src, dst = frame.load(), out.load()
    cache: dict[tuple[int, int, int], tuple[int, int, int]] = {}
    for y in range(frame.height):
        for x in range(frame.width):
            r, g, b, a = src[x, y]
            if a < cut:
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


def anchors(name: str, folder: Path, meta: dict, detect: list[Image.Image]) -> dict:
    """Where the pieces stand, so a review script can place them on the real lanes. root_thorn: the thorn's foot. boulder: the
    stone's spin frames cut out (rock_<n>.png, centred) and the landing frames cut round the landing (land_<n>.png). `detect` are
    the frames snapped at the normal cut (the landing's flash is found in them even when the saved frames keep less)."""
    frames = [Image.open(folder / f) for f in meta["frames"]]
    floor = meta["pivot"][1]
    if name in ("root_thorn", "stone_thorn", "song_shard"):
        tops = [(b[1][1], (b[1][0] + b[1][2]) // 2) for f in frames for b in blobs(f)[:1] if b[0] > 20]
        return {"anchor": [min(tops)[1], floor]}
    if name == "boulder":
        rock = blobs(detect[2])[0][0]
        impact = next(i for i, f in enumerate(detect) if i > 2 and blobs(f) and blobs(f)[0][0] > rock * 2.5)
        land = blobs(detect[impact])[0][1]
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


# What --install takes: the frames kept (PixelFX runs at 30 fps; every second frame is kept, so each lasts 4 game ticks).
# the crack and the burst, a short hold, the sink (PixelFX's long hold would leave the lane looking dangerous after its blow)
THORN_FRAMES = [6, 8, 10, 12, 14, 18, 24, 46, 50, 54, 58]
THORN_WINDOW = (16, 70, 32, 80)  # left of and above the thorn's foot, width, height
LAND_FRAMES = range(0, 42, 2)  # from the impact until the dust has settled
# the root-arm: PixelFX frames kept (30 fps; frame 15 is the lash, which meets the Grab's blow; see colossus_view.gd ARM_SOURCES)
ARM_SOURCES = [1, 3, 5, 7, 9, 11, 13, 14, 15, 16, 18, 21, 24, 28, 32]
ARM_ANGLES = [i * 15 - 90 for i in range(13)]  # degrees, -90 (up the screen) to 90 (down); index 0..12
ARM_MARGIN = 150
# the Song Flare's gold blow (PixelFX arcane/mana-burst): frames kept; frame 16 is the blow-out, which meets the blow (colossus_view.gd)
BURST_FRAMES = range(10, 56, 2)
ARM_RAW = Path(__file__).resolve().parents[2] / ".godot" / "pixelfx_arm_renders"  # scratch for the turned renders (ignored by git; big, remade on demand)


def grid(img: Image.Image, symbols: dict[tuple[int, int, int], str]) -> list[str]:
    px = img.load()
    return ["".join(symbols[px[x, y][:3]] if px[x, y][3] else "." for x in range(img.width)) for y in range(img.height)]


def write_sprite(name: str, img: Image.Image, anchor: tuple[int, int], symbols: dict, note: str) -> None:
    assert img.width % 8 == 0 and img.height % 8 == 0, (name, img.size)
    lines = ["# kind: sprite", f"# anchor: {anchor[0]},{anchor[1]}", f"# {note}"] + grid(img, symbols)
    (ROOT / "art" / "src" / f"{name}.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")


def pad8(n: int) -> int:
    return (n + 7) // 8 * 8


def install_arm(symbols: dict, note: str) -> int:
    effect, options, _, _ = EFFECTS["grab_vine"]
    colours = palette()
    count = 0
    for index, degrees in enumerate(ARM_ANGLES):
        out = ARM_RAW / str(index)
        opts = dict(options, angle=math.radians(degrees))
        run = subprocess.run(["node", str(Path(__file__).resolve().parent / "pixelfx_render.mjs"), str(PIXELFX), effect, str(out), str(ARM_MARGIN),
                              json.dumps(opts)], capture_output=True, text=True)
        if run.returncode != 0:
            raise SystemExit(f"arm {degrees}: {run.stderr or run.stdout}")
        stem = effect.split("/")[1]
        meta = json.loads((out / f"{stem}.json").read_text(encoding="utf-8"))
        sheet = Image.open(out / f"{stem}.png").convert("RGBA")
        px, py = meta["meta"]["pixelfx"]["pivot"]
        for n, source in enumerate(ARM_SOURCES, start=1):
            f = meta["frames"][source]["frame"]
            frame = snap(sheet.crop((f["x"], f["y"], f["x"] + f["w"], f["y"] + f["h"])), colours)
            box = frame.getbbox() or (px - 4, py - 8, px + 4, py)
            x0, y0 = box[0], box[1]
            x1, y1 = x0 + pad8(box[2] - x0), y0 + pad8(box[3] - y0)
            canvas = Image.new("RGBA", (x1 - x0, y1 - y0), (0, 0, 0, 0))
            canvas.alpha_composite(frame.crop((x0, y0, min(x1, frame.width), min(y1, frame.height))), (0, 0))
            write_sprite(f"fx_colossus_arm_{index}_{n}", canvas, (px - x0, py - y0), symbols, note.format(f"nature/vine-whip at {degrees} degrees"))
            count += 1
    return count


def install() -> int:
    data = json.loads((ROOT / "art" / "palette.json").read_text(encoding="utf-8"))
    symbols = {tuple(int(c["hex"][i:i + 2], 16) for i in (1, 3, 5)): c["symbol"] for c in data["colors"]}
    note = "PixelFX {} in Totoy 36, cut by tools/art/import_pixelfx.py --install (generated, do not hand-edit)"
    old = list((ROOT / "art" / "src").glob("fx_colossus_*.txt"))
    for path in old:
        path.unlink()
    # the thorn and the stone shard: a window round the foot
    for source, sprite in (("root_thorn", "fx_colossus_thorn"), ("stone_thorn", "fx_colossus_shard"), ("song_shard", "fx_colossus_song_shard")):
        thorn = json.loads((OUT / source / "frames.json").read_text(encoding="utf-8"))
        ax, ay = thorn["anchor"]
        left, up, w, h = THORN_WINDOW
        for n, i in enumerate(THORN_FRAMES, start=1):
            frame = Image.open(OUT / source / thorn["frames"][i]).convert("RGBA").crop((ax - left, ay - up, ax - left + w, ay - up + h))
            write_sprite(f"{sprite}_{n}", frame, (left, up), symbols, note.format("nature/thorns" + {"stone_thorn": " in stone", "song_shard": " in the song's blue"}.get(source, "")))
    # the Song Flare's gold blow: the song's light blowing out of its chest, every kept frame cut to their common box
    burst = json.loads((OUT / "song_burst" / "frames.json").read_text(encoding="utf-8"))
    blows = [Image.open(OUT / "song_burst" / burst["frames"][i]).convert("RGBA") for i in BURST_FRAMES]
    boxes = [b.getbbox() for b in blows if b.getbbox()]
    bx0, by0 = min(b[0] for b in boxes), min(b[1] for b in boxes)
    bx1, by1 = max(b[2] for b in boxes), max(b[3] for b in boxes)
    bx1, by1 = bx0 + pad8(bx1 - bx0), by0 + pad8(by1 - by0)
    for n, b in enumerate(blows, start=1):
        cut = Image.new("RGBA", (bx1 - bx0, by1 - by0), (0, 0, 0, 0))
        cut.alpha_composite(b.crop((bx0, by0, min(bx1, b.width), min(by1, b.height))), (0, 0))
        write_sprite(f"fx_colossus_song_burst_{n}", cut, (burst["pivot"][0] - bx0, burst["pivot"][1] - by0), symbols, note.format("arcane/mana-burst in the song's blue"))
    # the stone in flight: each spin frame centred on one canvas
    stone = json.loads((OUT / "boulder" / "frames.json").read_text(encoding="utf-8"))
    spins = [Image.open(OUT / "boulder" / f).convert("RGBA") for f in stone["spin"]]
    side = pad8(max(max(s.width, s.height) for s in spins))
    for n, s in enumerate(spins, start=1):
        canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
        canvas.alpha_composite(s, ((side - s.width) // 2, (side - s.height) // 2))
        write_sprite(f"fx_colossus_stone_spin_{n}", canvas, (side // 2, side // 2), symbols, note.format("nature/boulder (flight)"))
    # the landing: every kept frame cut to their common box, the anchor on the landing point
    lands = [Image.open(OUT / "boulder" / stone["landing"][i]).convert("RGBA") for i in LAND_FRAMES if i < len(stone["landing"])]
    boxes = [f.getbbox() for f in lands if f.getbbox()]
    x0, y0 = min(b[0] for b in boxes), min(b[1] for b in boxes)
    x1, y1 = max(b[2] for b in boxes), max(b[3] for b in boxes)
    lx, ly = stone["land_anchor"]
    x1 = x0 + pad8(x1 - x0)
    y0 = y1 - pad8(y1 - y0)  # pad above, never below the ground line
    for n, f in enumerate(lands, start=1):
        cut = Image.new("RGBA", (x1 - x0, y1 - y0), (0, 0, 0, 0))
        cut.alpha_composite(f.crop((max(0, x0), max(0, y0), x1, y1)), (max(0, -x0), max(0, -y0)))
        write_sprite(f"fx_colossus_stone_land_{n}", cut, (lx - x0, ly - y0), symbols, note.format("nature/boulder (landing)"))
    arms = install_arm(symbols, note)
    print(f"installed {arms} root-arm ({len(ARM_ANGLES)} angles), {len(THORN_FRAMES)} thorn and shard, {len(spins)} spin ({side}x{side}) and {len(lands)} landing ({x1 - x0}x{y1 - y0}) frames"
          f"{f'; replaced {len(old)}' if old else ''}")
    return 0


def main() -> int:
    if "--install" in sys.argv:
        return install()
    colours = palette()
    sources = {"what": "Effect proposals for the road Colossus, part 3b (docs/PLAN_colossus_step3.md), rendered with PixelFX and snapped "
                       "to Totoy 36 with hard alpha by tools/art/import_pixelfx.py. Review material; nothing is in the game.",
               "library": "https://github.com/patch-gg/pixelfx (MIT), the owner's clone outside this repo, commit " + COMMIT,
               "alpha_cut": ALPHA_CUT, "effects": {}}
    for name, (effect, options, flags, purpose) in EFFECTS.items():
        sheet, meta = render(name, effect, options, flags)
        info = meta["meta"]["pixelfx"]
        frames = []
        detect = []
        for i, row in enumerate(meta["frames"]):
            f = row["frame"]
            raw = sheet.crop((f["x"], f["y"], f["x"] + f["w"], f["y"] + f["h"]))
            cut = snap(raw, colours, CUTS.get(name, ALPHA_CUT))
            detect.append(snap(raw, colours) if name in CUTS else cut)
            file = f"{name}_{i + 1}.png"
            cut.save(OUT / name / file)
            frames.append(file)
        record = {"fps": info["fps"], "size": info["frameSize"], "pivot": info["pivot"], "frames": frames}
        record.update(anchors(name, OUT / name, record, detect))
        (OUT / name / "frames.json").write_text(json.dumps(record, indent=1) + "\n", encoding="utf-8")
        sources["effects"][name] = {"pixelfx": effect, "options": options, "flags": flags, "for": purpose, "frames": len(frames),
                                    "fps": info["fps"], "pivot": info["pivot"]}
        print(f"{name}: {effect} {len(frames)} frames {info['frameSize']} pivot {info['pivot']}")
    (OUT / "sources.json").write_text(json.dumps(sources, indent=1) + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    sys.exit(main())
