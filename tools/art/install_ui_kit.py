"""Install the approved SpriteCook UI kit (art/reference/ui_kit_spritecook_v1/kit) as game textures in art/ui_kit.

Copies the parts the game draws and writes art/ui_kit/kit.json (size and 9-slice borders in game pixels), which
presentation/common/ui_kit.gd reads. Every file is already Totoy 36 with hard alpha (build_kit.py checks it); this
re-checks, so a bad copy fails here.

    python tools/art/install_ui_kit.py
"""
from __future__ import annotations

import json
import shutil
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "art" / "reference" / "ui_kit_spritecook_v1" / "kit"
DST = ROOT / "art" / "ui_kit"
PARTS = [
    "panel_large_ornate", "panel_medium", "panel_small", "slot_frame", "slot_floor", "cooldown_sweep",
    "aspect_socket_open", "aspect_socket_locked", "weapon_medallion", "health_bar_frame", "fill_health", "fill_ghost",
    "fill_edge", "fill_exp", "thin_bar_frame", "fill_health_thin", "fill_ghost_thin", "fill_edge_thin", "fill_exp_thin",
    "level_pillar", "level_shield", "name_ribbon", "tab_on", "tab_off", "button_normal", "button_pressed",
    "button_locked", "key_badge", "icon_padlock", "icon_check", "icon_rune",
]


def main() -> None:
    palette = json.loads((ROOT / "art" / "palette.json").read_text(encoding="utf-8"))
    reserved = {c["hex"].lower() for c in palette["colors"] if c["symbol"] in palette["reserved"]}
    allowed = {c["hex"].lower() for c in palette["colors"]} - reserved
    meta = json.loads((SRC / "kit.json").read_text(encoding="utf-8"))["parts"]
    DST.mkdir(exist_ok=True)
    out: dict[str, dict] = {}
    for name in PARTS:
        img = Image.open(SRC / f"{name}.png").convert("RGBA")
        px = list(img.getdata())
        if any(a not in (0, 255) for *_, a in px):
            raise SystemExit(f"{name}: partial alpha")
        used = {"#%02x%02x%02x" % (r, g, b) for r, g, b, a in px if a}
        if not used <= allowed:
            raise SystemExit(f"{name}: colours outside Totoy 36 or reserved: {sorted(used - allowed)[:4]}")
        shutil.copyfile(SRC / f"{name}.png", DST / f"{name}.png")
        # the aspect socket is installed under its game name
        entry = {"size": list(img.size)}
        nine = meta.get(name, {}).get("nine_slice")
        if nine:
            entry["nine_slice"] = nine
        out[name] = entry
    (DST / "kit.json").write_text(json.dumps({"units": "game pixels", "parts": out}, indent=1) + "\n", encoding="utf-8", newline="\n")
    print(f"installed {len(out)} parts into {DST.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
