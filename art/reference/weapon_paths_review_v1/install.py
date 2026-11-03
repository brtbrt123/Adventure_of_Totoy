"""Install the approved path frames as palette text grids. Rebuild the standard art pipeline afterwards."""
from pathlib import Path
import json
import re
from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent


def main() -> None:
    palette = json.loads((ROOT / "art/palette.json").read_text())
    lookup = {tuple(bytes.fromhex(c["hex"].lstrip("#"))): c["symbol"] for c in palette["colors"] if c["symbol"] not in palette["reserved"]}
    count = 0
    for weapon in ("katana", "daggers", "scythe"):
        for source in sorted((HERE / "frames" / weapon).glob("*.png")):
            match = re.fullmatch(r"path_swing(\d+)_(\d+)", source.stem)
            assert match, source
            swing, pose = map(int, match.groups())
            im = Image.open(source).convert("RGBA")
            assert im.size == (128, 96)
            pixels = im.load()
            rows = []
            for y in range(im.height):
                row = []
                for x in range(im.width):
                    r, g, b, a = pixels[x, y]
                    assert a in (0, 255), source
                    row.append(lookup[(r, g, b)] if a else ".")
                rows.append("".join(row))
            destination = ROOT / "art/src" / f"fx_weapon_path_{weapon}_attack{swing}_{pose - 2}.txt"
            destination.write_text("# kind: sprite\n# anchor: 48,78\n# Approved weapon path from art/reference/weapon_paths_review_v1\n" + "\n".join(rows) + "\n", encoding="utf-8", newline="\n")
            count += 1
    assert count == 40, count
    print(f"Installed {count} approved path frames as text grids")


if __name__ == "__main__":
    main()
