"""GIFs from the Star Staff's in-game capture (presentation/review/staff/capture_staff.gd saves the game's own frames).

    python tools/art/staff_capture_gif.py <capture dir> [scale]

Writes art/reference/staff_v1/ingame/staff_ingame_casts.gif (the casts and the blink) and staff_ingame_ultimate.gif
(Disintegration: the cut-in, the circle, the meteor, the blast, the crater), 30 fps, one palette per GIF.
"""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "art/reference/staff_v1/ingame"


def save(frames: list[Image.Image], path: Path) -> None:
    sample = frames[:: max(1, len(frames) // 16)]
    w, h = frames[0].size
    mosaic = Image.new("RGB", (w // 2, h // 2 * len(sample)))
    for i, f in enumerate(sample):
        mosaic.paste(f.resize((w // 2, h // 2)), (0, i * (h // 2)))
    pal = mosaic.quantize(colors=255, method=Image.Quantize.MEDIANCUT)
    q = [f.quantize(palette=pal, dither=Image.Dither.NONE) for f in frames]
    q[0].save(path, save_all=True, append_images=q[1:], duration=[40 if i % 3 == 2 else 30 for i in range(len(q))], loop=0, disposal=1)
    print(path.name, len(frames), "frames", round(path.stat().st_size / 1e6, 1), "MB")


def main() -> int:
    src = Path(sys.argv[1])
    scale = float(sys.argv[2]) if len(sys.argv) > 2 else 0.75
    files = sorted(src.glob("seq_*.png"))
    frames = []
    for f in files:
        img = Image.open(f).convert("RGB")
        if scale != 1.0:
            img = img.resize((round(img.width * scale), round(img.height * scale)), Image.LANCZOS)
        frames.append(img)
    if not frames:
        print("no frames in", src)
        return 1
    split = int(sys.argv[3]) if len(sys.argv) > 3 else len(frames) // 2
    OUT.mkdir(parents=True, exist_ok=True)
    save(frames[:split], OUT / "staff_ingame_casts.gif")
    save(frames[split:], OUT / "staff_ingame_ultimate.gif")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
