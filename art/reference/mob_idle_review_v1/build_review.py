"""Review-only idle loops using the game's original editable creature rigs.

Run: python art/reference/mob_idle_review_v1/build_review.py
Never writes art/src, art/build, presentation or the original generator.
"""
from __future__ import annotations

import json
import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / "tools" / "art"))
import make_chapter1_creatures_art as rig

CELL = (64, 48)
ANCHOR = (32, 40)
MS = 100
PALETTE = json.loads((ROOT / "art" / "palette.json").read_text())
COLORS = {c["symbol"]: tuple(bytes.fromhex(c["hex"].lstrip("#"))) for c in PALETTE["colors"]}


def mossling_frame(index: int) -> tuple[Image.Image, dict]:
    # A full arc each way, with anticipation/landing holds. The loop returns to the same anchor.
    poses = [
        (0, 0, 0, 0), (0, 0, .35, -5), (0, 0, 1, -12),
        (1, 4, -.55, 8), (3, 8, -.35, 16), (5, 10, 0, 22),
        (6, 9, 0, 12), (7, 5, -.25, -2), (7, 0, 1, -18),
        (7, 0, .4, 12), (7, 0, 0, 0), (7, 0, .8, -10),
        (6, 3, -.5, 8), (4, 7, -.3, 17), (1, 9, 0, 22),
        (-2, 8, 0, 12), (-4, 4, -.2, 0), (-4, 0, .9, -16),
        (-4, 0, .25, 8), (-4, 0, .4, -4), (-3, 3, -.2, 8),
        (-1, 4, -.1, 12), (0, 0, .45, -5), (0, 0, 0, 0),
    ]
    x, height, squash, crest = poses[index % len(poses)]
    airborne = height > 0
    # Keep normal calm eyes; no attack eye flare or telegraph-like dirt burst.
    grid = rig.mossling(
        by=15.6 + squash * .9, rx=6.6 + squash * 1.2, ry=5.7 - squash * 1.1,
        crest=crest, tilt=-4 if airborne and index < 8 else (4 if airborne else 0),
        feet=((9.9, 19.8 if airborne else 20.7), (15.7, 19.2 if airborne else 20.7)),
        eye="closed" if index == 20 else "open", arm=-28 if airborne else None,
    )
    im = Image.new("RGBA", CELL)
    sprite = rig.to_image(grid)
    im.alpha_composite(sprite, (ANCHOR[0] - rig.MOSS_A[0] + x, ANCHOR[1] - rig.MOSS_A[1] - height))
    return im, {"offset_x": x, "height": height, "squash": squash}


def boar_frame(index: int) -> tuple[Image.Image, dict]:
    # Slowly lower the neck, root/nibble, chew, lift briefly, then settle to the first pose.
    heads = [0, 0, 5, 12, 22, 32, 40, 43,
             42, 46, 42, 46, 43, 45, 42, 44,
             40, 34, 26, 20, 20, 21, 20, 21,
             28, 36, 43, 45, 41, 45, 38, 29,
             18, 8, 0, 0]
    angle = heads[index % len(heads)]
    chewing = index in range(8, 16) or index in range(20, 24) or index in range(26, 30)
    jaw = 1 if chewing and index % 2 else 0
    grid = rig.boar(
        by=19, head=angle, spines=0, mouth=jaw,
        tail=26 * math.sin(index / 36 * math.tau * 2),
        eye="closed" if index in (18, 19, 33) else "open",
    )
    im = Image.new("RGBA", CELL)
    im.alpha_composite(rig.to_image(grid), (ANCHOR[0] - rig.BOAR_A[0], ANCHOR[1] - rig.BOAR_A[1]))
    return im, {"head_degrees": angle, "jaw": jaw, "grazing": angle >= 38}


def check(im: Image.Image) -> None:
    allowed = {v for k, v in COLORS.items() if k not in PALETTE["reserved"]}
    for r, g, b, a in im.getdata():
        assert a in (0, 255), "soft alpha"
        assert a == 0 or (r, g, b) in allowed, "non-palette or reserved colour"
    box = im.getbbox()
    assert box is not None and box[0] > 0 and box[1] > 0 and box[2] < CELL[0] and box[3] < CELL[1], "clipped pose"


def backdrop(size: tuple[int, int]) -> Image.Image:
    im = Image.new("RGBA", size, COLORS["2"] + (255,))
    d = ImageDraw.Draw(im)
    for y in range(size[1]):
        for x in range(size[0]):
            value = (x * 73 + y * 37 + x * y * 11) % 173
            if value < 7:
                d.point((x, y), fill=COLORS["3"])
    # Two short grass blades next to the grazing snout, separately from the sprite art.
    return im


def scene_frame(im: Image.Image, name: str, info: dict) -> Image.Image:
    stage = backdrop((96, 64))
    d = ImageDraw.Draw(stage)
    lift = int(info.get("height", 0))
    x = 48 + int(info.get("offset_x", 0))
    radius = max(3, 8 - lift // 3) if name == "mossling" else 18
    # Opaque palette shadow is review scenery, never baked into the sprite frames.
    d.ellipse((x - radius, 48 - 2, x + radius, 48 + 1), fill=COLORS["8"])
    if name == "boar":
        for dx in (16, 19, 22):
            d.line((48 + dx, 49, 47 + dx, 46), fill=COLORS["5"])
        if info.get("grazing") and info["jaw"]:
            d.point((68, 45), fill=COLORS["6"])
    stage.alpha_composite(im, (16, 8))
    return stage


def save_loop(name: str, frames: list[Image.Image], meta: list[dict]) -> None:
    folder = OUT / "frames" / name
    folder.mkdir(parents=True, exist_ok=True)
    for index, im in enumerate(frames):
        check(im)
        im.save(folder / f"{name}_idle_{index + 1:02}.png")
    sheet = Image.new("RGBA", (CELL[0] * 8, CELL[1] * math.ceil(len(frames) / 8)))
    for index, im in enumerate(frames):
        sheet.alpha_composite(im, ((index % 8) * CELL[0], (index // 8) * CELL[1]))
    sheet.save(OUT / f"{name}_sheet.png")
    previews = [scene_frame(im, name, data).resize((576, 384), Image.Resampling.NEAREST).convert("RGB") for im, data in zip(frames, meta)]
    previews[0].save(OUT / f"{name}_idle.gif", save_all=True, append_images=previews[1:], duration=MS, loop=0, disposal=2, optimize=False)
    (OUT / f"{name}.json").write_text(json.dumps({"review_only": True, "cell": CELL, "anchor": ANCHOR, "frame_ms": MS, "loop_ms": MS * len(frames), "poses": meta}, indent=2) + "\n")


def main() -> None:
    moss = [mossling_frame(i) for i in range(24)]
    boar = [boar_frame(i) for i in range(36)]
    save_loop("mossling", [p[0] for p in moss], [p[1] for p in moss])
    save_loop("boar", [p[0] for p in boar], [p[1] for p in boar])
    title_font = ImageFont.truetype(str(ROOT / "presentation/fonts/Cinzel.ttf"), 24)
    previews = []
    for t in range(72):
        out = Image.new("RGB", (1152, 440), COLORS["0"])
        d = ImageDraw.Draw(out)
        for side, (name, poses, title) in enumerate((("mossling", moss, "Mossling - playful hops"), ("boar", boar, "Thornback Boar - grazing"))):
            im, data = poses[t % len(poses)]
            tile = scene_frame(im, name, data).resize((576, 384), Image.Resampling.NEAREST)
            out.paste(tile, (576 * side, 48))
            d.text((576 * side + 20, 10), title, font=title_font, fill=COLORS["1"])
        previews.append(out)
    previews[0].save(OUT / "idle_review.gif", save_all=True, append_images=previews[1:], duration=MS, loop=0, disposal=2, optimize=False)
    # Full pose sheet at integer 4x for inspection, with transparencies preserved.
    for name in ("mossling", "boar"):
        im = Image.open(OUT / f"{name}_sheet.png")
        im.resize((im.width * 4, im.height * 4), Image.Resampling.NEAREST).save(OUT / f"{name}_sheet_4x.png")
    print("REVIEW OK: 24 Mossling frames, 36 boar frames; palette/hard alpha/unclipped checks passed")


if __name__ == "__main__":
    main()
