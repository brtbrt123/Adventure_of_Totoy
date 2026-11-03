"""The five SpriteCook-kit mockups again at the 384x216 view (review only, not installed).

Same kit parts, helpers and fonts as mockups.py; the layouts are re-spaced for 384x216 (20% more
world each way), drawn at base resolution and scaled x4 with nearest-neighbour to 1536x864 (a
pixel-for-pixel review size; at a 1280x720 window the game would run 3x with letterboxing).
Woodland backgrounds are true 384x216 cuts of woodland_full.png (a 2x render of the 640x400 map),
centred like the 320x180 captures; the village and glade captures are cropped to 16:9 and scaled.

  python -P art/reference/ui_kit_spritecook_v1/mockups_384.py   (after build_kit.py)
"""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))  # our own scripts only; downloads live in raw/
import mockups as m  # also puts tools/art on the path and loads the kit
from mockups import (CREAM, G6, INK, LIL, ST3, ST4, ST5, T2, bk, button, health_bar, keybadge, level_pillar, medallion,
                     mob_plate, ns, panel, plate, put, ribbon, slot, socket, thin_bar, uc)

W, H, S = 384, 216, 4
OUT = m.HERE / "mockups_384x216"
FULL = Image.open(m.ROOT / "presentation/review/chapter1_expansion/woodland_full.png").convert("RGBA").resize((640, 400), Image.NEAREST)


def new(origin: tuple[int, int] | None = None, rel: str | None = None) -> uc.Canvas:
    if origin is not None:
        ox = max(0, min(640 - W, origin[0]))
        oy = max(0, min(400 - H, origin[1]))
        bg = FULL.crop((ox, oy, ox + W, oy + H))
    else:
        im = Image.open(m.ROOT / rel).convert("RGBA")
        w, h = im.size
        if w / h > W / H:
            cw = round(h * W / H)
            im = im.crop(((w - cw) // 2, 0, (w - cw) // 2 + cw, h))
        else:
            ch = round(w * H / W)
            im = im.crop((0, (h - ch) // 2, w, (h - ch) // 2 + ch))
        bg = im.resize((W * S, H * S), Image.LANCZOS)
    return uc.Canvas(bg, (W, H))


def save(cv: uc.Canvas, name: str) -> Path:
    cv.flush()
    OUT.mkdir(exist_ok=True)
    path = OUT / name
    cv.big.convert("RGB").save(path)
    return path


def hud_screen() -> Path:
    cv = new((0, 152))  # woodland_view_170_260's centre, clamped to the map edge
    px, py = 170, 126   # Totoy's feet in this cut
    cv.shadow(px + 92, py + 2, 10)
    cv.sprite("boar_idle_right_1", px + 92, py + 2, flip=True)
    cv.shadow(px - 48, py + 12, 6)
    cv.sprite("mossling_idle_right_1", px - 48, py + 12)
    cv.shadow(px + 26, py + 24, 6)
    cv.sprite("mossling_idle_right_3", px + 26, py + 24, flip=True)
    cv.flush()
    uc.lane(cv, px + 80, py - 5, px + 10, py - 9, 12)
    mob_plate(cv, px + 90, py - 26, 2, "Thornback Boar", 0.62, 0.78, above=True)
    mob_plate(cv, px - 48, py - 9, 1, "Mossling", 0.35, 0.5)
    mob_plate(cv, px + 26, py + 3, 1, "Mossling", 1.0, 1.0)
    uc.damage(cv, px - 48, py - 24, "12", "hit")
    uc.damage(cv, px, py - 44, "-20", "hurt")
    uc.damage(cv, px + 90, py - 46, "36", "counter")
    plate(cv, 4, 4, 188, "Speak to the Elder at the shrine")
    ribbon(cv, 252, 3, 124, "Woodland Approach", 6.2)
    cv.text(15, 36.5, "LV", 5.0, m.BR_L, 900, "ms", outline=1)
    level_pillar(cv, 5, 40, 116, 0.62, 5)
    medallion(cv, 3, 170)
    slot(cv, 50, 153, "normal", icon="icon_herb", key="1", count=3)
    slot(cv, 78, 153, "locked", key="2")
    health_bar(cv, 47, 182, 136, 0.86, 0.95, 118, 138)
    thin_bar(cv, 52, 197, 104, 0.72)
    cv.text(161, 204.4, "Edge", 5.0, T2, 800, outline=1)
    for i, (k, sprint) in enumerate((("Z", True), ("X", False), ("C", False))):
        socket(cv, 291 + i * 31, 177, sprint, k)
    cv.text(305, 174.5, "Sprint", 5.0, T2, 800, "ms", outline=1)
    return save(cv, "1_hud.png")


def dialogue_screen() -> Path:
    cv = new(rel="presentation/review/chapter1_expansion/current_village_layered.png")
    cv.veil((20, 16, 26, 80))
    keybadge(cv, 12, 132, "ESC")
    cv.text(36, 140.2, "skip", 5.2, ST5, 700, outline=1)
    panel(cv, "panel_large_ornate", 6, 146, 372, 66)
    frame = ns("slot_frame", 54, 54)
    put(cv, frame, 14, 152)
    fx0, fy0, fx1, fy1 = bk.interior(frame)
    cv.portrait("portrait_tovan_neutral", 14 + fx0, 152 + fy0, min(fx1 - fx0, fy1 - fy0))
    ribbon(cv, 74, 139, 66, "Tovan", 7.0)
    cv.text(78, 169, "Hold out your hands, Totoy. This is a Black Katana,", 7.0, CREAM, 600)
    cv.text(78, 180, "and it is yours. It was always yours.", 7.0, CREAM, 600)
    cv.text(78, 192, "Remember the colours: gold, parry. Red, dash.", 7.0, ST5, 600)
    cv.ptext(346, 155, "2/5", ST4, outline=None, align="r")
    keybadge(cv, 334, 194, "E")
    cv.poly([(348, 197), (354, 197), (351, 201)], T2)
    return save(cv, "2_dialogue.png")


def shell(cv: uc.Canvas, active: int) -> None:
    cv.veil((20, 16, 26, 205))
    panel(cv, "panel_large_ornate", 4, 6, 376, 204)
    for i, name in enumerate(["Status", "Aspects", "Items", "Quests"]):
        tx = 14 + i * 60
        put(cv, ns("tab_on" if i == active else "tab_off", 56), tx, 22)
        cv.text(tx + 28, 32.6, name, 6.2, CREAM if i == active else ST5, 900, "ms")
    ribbon(cv, 148, 0, 88, "Totoy", 7.0)
    w = keybadge(cv, 316, 24, "TAB")
    cv.text(318 + w, 31.4, "close", 5.2, ST5, 700)


def status_screen() -> Path:
    cv = new((128, 17))
    shell(cv, 0)
    x0, y0, x1, y1 = panel(cv, "panel_small", 12, 42, 88, 74)
    side = min(x1 - x0, y1 - y0)
    cv.portrait("portrait_totoy_neutral", (x0 + x1 - side) // 2, y0, side)
    put(cv, m.KIT["level_shield"], 12, 122)
    cv.ptext(21, 127, "5", CREAM, 2, align="c")
    cv.text(36, 131, "Totoy", 8.0, CREAM, 900)
    cv.text(36, 139, "Waykeeper", 5.2, T2, 800)
    thin_bar(cv, 12, 146, 88, 0.7, "fill_exp_thin")
    cv.ptext(56, 157, "120/170", ST5, outline=None, align="c")
    for j, (k, v, col) in enumerate((("Health", "138", G6), ("Edge", "100", T2), ("Damage", "+9%", CREAM), ("Dash", "36", CREAM))):
        cv.text(14, 172 + j * 8, k, 5.6, ST5, 700)
        cv.ptext(99, 167 + j * 8, v, col, outline=None, align="r")
    cv.text(108, 51, "Stat points", 7.4, CREAM, 900)
    keybadge(cv, 166, 44, "2")
    cv.text(180, 51, "to spend", 5.2, LIL, 800)
    stats = (("Vitality", 3, "fill_health_thin"), ("Might", 3, "fill_exp_thin"), ("Agility", 2, "fill_edge_thin"))
    for j, (name, pts, fill) in enumerate(stats):
        sy = 56 + j * 34
        panel(cv, "panel_medium", 106, sy, 150, 32)
        cv.text(113, sy + 13.5, name, 6.6, CREAM, 900)
        cv.ptext(226, sy + 8, f"{pts}/10", CREAM, outline=None, align="r")
        thin_bar(cv, 112, sy + 18, 104, pts / 10, fill)
        put(cv, ns("button_normal", 16, 16), 232, sy + 8)
        cv.ptext(240, sy + 13, "+", T2, 2, outline=None, align="c")
    button(cv, 106, 163, 46, "Confirm", "normal")
    button(cv, 156, 163, 38, "Undo", "pressed")
    button(cv, 198, 163, 56, "Respec", "locked")
    cv.text(181, 186, "Respec opens in Lanternfen", 5.0, ST5, 700, "ms")
    cv.text(181, 195, "+6 health, +3% damage or a quicker dash a point", 5.0, ST4, 700, "ms")
    cv.text(268, 51, "Loadout", 7.4, CREAM, 900)
    slot(cv, 266, 56, "normal", size=30, icon="icon_katana")
    cv.text(302, 68, "Black Katana", 6.2, CREAM, 800)
    cv.text(302, 76, "three-strike combo", 5.0, ST5, 700)
    cv.text(268, 100, "Aspects", 5.8, T2, 900)
    for i, (k, sprint) in enumerate((("Z", True), ("X", False), ("C", False))):
        socket(cv, 266 + i * 35, 104, sprint, k)
    cv.text(268, 154, "Items", 5.8, T2, 900)
    slot(cv, 266, 158, "normal", icon="icon_herb", key="1", count=3)
    slot(cv, 294, 158, "locked", key="2")
    cv.text(324, 170, "Herb", 6.2, CREAM, 800)
    cv.text(324, 178, "heals 35", 5.0, ST5, 700)
    return save(cv, "3_status.png")


def aspects_screen() -> Path:
    cv = new((256, 152))
    shell(cv, 1)
    cv.text(16, 52, "Owned", 6.4, T2, 900)
    panel(cv, "panel_medium", 12, 56, 146, 42)
    socket(cv, 18, 61, True)
    cv.text(50, 72, "Sprint", 7.2, CREAM, 900)
    cv.text(50, 80, "bound by Edda", 5.2, T2, 700)
    put(cv, m.KIT["icon_check"], 136, 66)
    cv.text(50, 88, "in socket Z", 5.2, ST5, 700)
    cv.text(16, 114, "Not yet found", 6.4, ST5, 900)
    cv.text(84, 114, "8 more to find", 5.0, ST4, 700)
    for i in range(8):
        slot(cv, 14 + (i % 4) * 36, 119 + (i // 4) * 36, "locked", size=28)
    panel(cv, "panel_medium", 168, 44, 208, 86)
    socket(cv, 176, 52, True)
    cv.text(210, 63, "Sprint", 9.0, CREAM, 900)
    cv.text(210, 72, "Aspect of the fleet-footed", 5.4, T2, 700)
    cv.text(178, 96, "Run twice as fast for 3 seconds.", 5.8, CREAM, 700)
    cv.ptext(178, 101, "20", T2, outline=None)
    cv.text(188, 106.4, "Edge", 5.4, ST5, 700)
    cv.ptext(212, 101, "12", T2, outline=None)
    cv.text(222, 106.4, "s cooldown", 5.4, ST5, 700)
    cv.text(178, 118, "Works on the road; Edge refills when no foe is near.", 5.0, ST5, 700)
    put(cv, m.KIT["icon_rune"], 170, 141)
    cv.text(186, 150, "Sockets", 6.4, T2, 900)
    for i, (k, sprint) in enumerate((("Z", True), ("X", False), ("C", False))):
        socket(cv, 178 + i * 38, 156, sprint, k)
    cv.text(326, 172, "1 of 3", 6.4, CREAM, 900, "ms")
    cv.text(326, 180, "open", 5.2, ST5, 700, "ms")
    return save(cv, "4_aspects.png")


def cards_screen() -> Path:
    cv = new(rel="presentation/review/chapter1_expansion/current_glade_layered.png")
    cv.veil((20, 16, 26, 120))
    panel(cv, "panel_medium", 6, 8, 184, 42)
    cv.text(14, 21, "Training  2 of 4", 5.4, T2, 900)
    cv.text(14, 32, "Dash through the ring", 7.4, CREAM, 900)
    w = keybadge(cv, 14, 36, "SHIFT")
    cv.text(17 + w, 43.6, "dash", 5.2, ST5, 700)
    thin_bar(cv, 134, 13, 50, 0.5)
    panel(cv, "panel_small", 6, 56, 184, 36)
    slot(cv, 12, 62, "empty", icon="icon_check")
    cv.text(42, 72, "Task complete", 6.6, T2, 900)
    cv.text(42, 82, "Strike the post three times", 5.6, CREAM, 700)
    cv.ptext(182, 68, "+10", G6, outline=None, align="r")
    panel(cv, "panel_medium", 6, 98, 184, 50)
    slot(cv, 14, 106, "normal", size=32, icon="icon_katana")
    cv.text(54, 115, "Received", 5.6, T2, 900)
    cv.text(54, 127, "Black Katana", 8.4, CREAM, 900)
    cv.text(54, 137, "A worn blade. It was always yours.", 5.2, ST5, 700)
    panel(cv, "panel_small", 6, 154, 184, 48)
    slot(cv, 13, 163, "normal", icon="icon_herb", count=1)
    cv.text(46, 173, "Herb", 7.2, CREAM, 900)
    cv.text(46, 182, "dropped by a Mossling", 5.2, ST5, 700)
    keybadge(cv, 46, 186, "1")
    cv.text(60, 194, "heals 35", 5.0, G6, 700)
    ribbon(cv, 200, 10, 172, "Welcome to Lanternfen", 7.0)
    cv.text(286, 38, "Find Mira by the gate to begin.", 5.8, CREAM, 700, "ms", outline=1)
    panel(cv, "panel_large_ornate", 194, 50, 184, 56)
    put(cv, m.KIT["level_shield"], 206, 68)
    cv.ptext(215, 73, "5", CREAM, 2, align="c")
    cv.text(298, 81, "Level up", 10.5, CREAM, 900, "ms")
    cv.text(298, 94, "+5 health   +2 stat points", 5.8, LIL, 800, "ms")
    panel(cv, "panel_medium", 194, 112, 184, 50)
    socket(cv, 202, 118, True, "Z")
    cv.text(238, 126, "Aspect bound", 5.6, T2, 900)
    cv.text(238, 138, "Sprint", 8.4, CREAM, 900)
    cv.text(238, 148, "run twice as fast", 5.2, ST5, 700)
    panel(cv, "panel_small", 194, 168, 184, 38)
    put(cv, m.KIT["icon_padlock"], 206, 180)
    cv.text(222, 182, "The rune gate holds", 6.6, CREAM, 900)
    cv.text(222, 192, "Finish your tasks in Lanternfen.", 5.2, ST5, 700)
    return save(cv, "5_cards.png")


def contact(paths: list[Path]) -> Path:
    ims = [Image.open(p) for p in paths]
    tw, th, pad = 768, 432, 12
    out = Image.new("RGB", (2 * (tw + pad) + pad, 3 * (th + pad) + pad), (28, 24, 36))
    for k, im in enumerate(ims):
        out.paste(im.resize((tw, th), Image.LANCZOS), (pad + (k % 2) * (tw + pad), pad + (k // 2) * (th + pad)))
    path = OUT / "contact.png"
    out.save(path)
    return path


if __name__ == "__main__":
    paths = [hud_screen(), dialogue_screen(), status_screen(), aspects_screen(), cards_screen()]
    print("\n".join(str(p.relative_to(m.ROOT)) for p in paths + [contact(paths)]))
