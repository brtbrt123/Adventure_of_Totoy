"""GIFs from the hero effects' in-game capture (presentation/review/hero_fx/capture_hero_fx.gd saves the game's own frames and
segments.json, which frames show what).

    python tools/art/hero_fx_capture_gif.py <capture dir> [crop]

Writes art/reference/hero_fx_v1/ingame/<segment>.gif (black_katana, dual_dagger, chain_scythe, dash, parry): the middle of the
window (`crop` of its width and height, default 0.6, so the fight fills the GIF), 30 fps, one palette per GIF.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from staff_capture_gif import save  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "art/reference/hero_fx_v1/ingame"


def main() -> int:
    src = Path(sys.argv[1])
    crop = float(sys.argv[2]) if len(sys.argv) > 2 else 0.6
    segments = json.loads((src / "segments.json").read_text(encoding="utf-8"))
    OUT.mkdir(parents=True, exist_ok=True)
    for name, (start, end) in segments.items():
        frames = []
        for i in range(start, end):
            path = src / f"seq_{i:04d}.png"
            if not path.exists():
                continue
            img = Image.open(path).convert("RGB")
            w, h = img.size
            cw, ch = int(w * crop), int(h * crop)
            left, top = (w - cw) // 2, (h - ch) // 2
            frames.append(img.crop((left, top, left + cw, top + ch)))
        if frames:
            save(frames, OUT / f"{name}.gif")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
