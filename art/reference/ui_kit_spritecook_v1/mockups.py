"""Five review mockups built from the SpriteCook kit (review only, not installed).

Gameplay HUD, dialogue card, TAB Status, TAB Aspects and notification cards, drawn at the 320x180
base resolution and scaled x4 with nearest-neighbour to 1280x720, over real game captures. Every
UI pixel comes from kit/*.png, 9-sliced (corners kept, edges tiled, never stretched). Words use
Cinzel at window resolution like the game (docs/decisions/0004-sharp-ui-text.md); numbers and key
letters use the crisp pixel font of tools/art/ui_concept_claude.py, whose Canvas, sprites and
portraits this reuses. Layout follows that v3 concept.

  python -P art/reference/ui_kit_spritecook_v1/mockups.py   (after build_kit.py)
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

from PIL import Image

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
sys.path.insert(0, str(HERE))  # our own scripts only; downloads live in raw/
sys.path.insert(0, str(ROOT / "tools" / "art"))
import build_kit as bk  # noqa: E402
import ui_concept_claude as uc  # noqa: E402

KIT = {p.stem: Image.open(p).convert("RGBA") for p in (HERE / "kit").glob("*.png")}
BORDERS = {k: tuple(v["nine_slice"]) for k, v in json.loads((HERE / "kit" / "kit.json").read_text())["parts"].items()
           if v.get("nine_slice")}
OUT = HERE / "mockups"

CREAM, INK, LIL, G6, G5 = uc.CREAM, uc.INK, uc.LIL, uc.G6, uc.G5
ST3, ST4, ST5, T2, W6, BR_L = uc.ST3, uc.ST4, uc.ST5, uc.T2, uc.W6, uc.BR_L


# ---- kit widgets ------------------------------------------------------------------------------------------------------

def ns(name: str, w: int, h: int | None = None) -> Image.Image:
    return bk.nine(KIT[name], BORDERS[name], (w, KIT[name].height if h is None else h))


def put(cv: uc.Canvas, img: Image.Image, x: int, y: int) -> Image.Image:
    cv.ui.alpha_composite(img, (x, y))
    return img


def background(rel: str) -> Image.Image:
    """A real capture at 1280x720: 4x captures as they are, others cropped to 16:9 and smoothly scaled."""
    im = Image.open(ROOT / rel).convert("RGBA")
    if im.size == (1280, 720):
        return im
    w, h = im.size
    if w / h > 16 / 9:
        cw = round(h * 16 / 9)
        im = im.crop(((w - cw) // 2, 0, (w - cw) // 2 + cw, h))
    else:
        ch = round(w * 9 / 16)
        im = im.crop((0, (h - ch) // 2, w, (h - ch) // 2 + ch))
    return im.resize((1280, 720), Image.LANCZOS)


def keybadge(cv: uc.Canvas, x: int, y: int, label: str, locked: bool = False) -> int:
    w = max(11, uc.pwidth(label) + 6)
    put(cv, ns("key_badge", w, 11), x, y)
    cv.ptext(x + (w - uc.pwidth(label)) // 2, y + 3, label, ST4 if locked else CREAM, outline=None)
    return w


def slot(cv: uc.Canvas, x: int, y: int, state: str = "normal", size: int = 24, icon: str | None = None,
         key: str | None = None, count: int | None = None) -> None:
    put(cv, bk.slot(KIT, state, size, icon), x, y)
    if count is not None:
        cv.ptext(x + size - 5, y + 4, str(count), CREAM, align="r")
    if key:
        keybadge(cv, x + size - 9, y + size - 8, key, locked=state == "locked")


def socket(cv: uc.Canvas, x: int, y: int, sprint: bool, key: str | None = None) -> None:
    img = KIT["aspect_socket_sprint" if sprint else "aspect_socket_locked"]
    put(cv, img, x, y)
    if key:
        keybadge(cv, x + img.width // 2 - 5, y + img.height - 10, key, locked=not sprint)


def medallion(cv: uc.Canvas, x: int, y: int) -> None:
    m = KIT["weapon_medallion"]
    put(cv, bk.centre_in(m, KIT["icon_katana"], bk.interior(m)), x, y)


def fill_in(cv: uc.Canvas, x: int, y: int, box: tuple[int, int, int, int], name: str, frac: float) -> None:
    """A fill strip from the left of a trough interior, frac of its width (pointed tip kept)."""
    x0, y0, x1, y1 = box
    fw = round((x1 - x0) * max(0.0, min(1.0, frac)))
    l, _, r, _ = BORDERS[name]
    if fw >= l + r:
        strip = ns(name, fw)
        put(cv, strip, x + x0, y + y0 + (y1 - y0 - strip.height) // 2)


def health_bar(cv: uc.Canvas, x: int, y: int, w: int, p: float, ghost: float, cur: int, mx: int) -> None:
    frame = ns("health_bar_frame", w)
    box = bk.interior(frame)
    put(cv, frame, x, y)
    fill_in(cv, x, y, box, "fill_ghost", ghost)
    fill_in(cv, x, y, box, "fill_health", p)
    # the numbers sit past the tip: ink on the textured green fill does not read
    cv.ptext(x + w + 3, y + box[1] + 1, f"{cur}/{mx}", CREAM)


def thin_bar(cv: uc.Canvas, x: int, y: int, w: int, p: float, fill: str = "fill_edge_thin", ghost: float = 0.0) -> None:
    frame = ns("thin_bar_frame", w)
    box = bk.interior(frame)
    put(cv, frame, x, y)
    if ghost > p:
        fill_in(cv, x, y, box, "fill_ghost_thin", ghost)
    fill_in(cv, x, y, box, fill, p)


def level_pillar(cv: uc.Canvas, x: int, y: int, h: int, p: float, lv: int) -> None:
    pil = ns("level_pillar", KIT["level_pillar"].width, h)
    put(cv, pil, x, y)
    tx0, ty0, tx1, ty1 = bk.interior(pil, (pil.width // 2, h - 20))
    l, _, r, _ = BORDERS["fill_exp_thin"]
    up = KIT["fill_exp_thin"].rotate(90, expand=True)  # tip points up
    fh = round((ty1 - ty0) * p)
    if fh >= l + r:
        strip = bk.nine(up, (0, r, 0, l), (up.width, fh)).crop((0, 0, min(up.width, tx1 - tx0), fh))
        put(cv, strip, x + tx0 + (tx1 - tx0 - strip.width) // 2, y + ty1 - fh)
    sx0, sy0, sx1, sy1 = bk.interior(pil, (pil.width // 2, 8))
    cv.ptext((x + sx0 + x + sx1) // 2, y + sy0 + (sy1 - sy0 - 12) // 2, str(lv), CREAM, 2, align="c")


def ribbon(cv: uc.Canvas, x: int, y: int, w: int, text: str, size: float = 6.4) -> None:
    put(cv, ns("name_ribbon", w), x, y)
    cv.text(x + w / 2, y + 10.4, text, size, CREAM, 800, "ms")


def plate(cv: uc.Canvas, x: int, y: int, w: int, text: str) -> None:
    """The objective line: the gem-capped health trough as a plate."""
    frame = ns("health_bar_frame", w)
    box = bk.interior(frame)
    put(cv, frame, x, y)
    cv.text(x + box[0] + 2, y + box[3] - 2.2, text, 5.8, CREAM, 700)


def panel(cv: uc.Canvas, name: str, x: int, y: int, w: int, h: int) -> tuple[int, int, int, int]:
    img = ns(name, w, h)
    put(cv, img, x, y)
    x0, y0, x1, y1 = bk.interior(img)
    return x + x0, y + y0, x + x1, y + y1


def button(cv: uc.Canvas, x: int, y: int, w: int, label: str, state: str = "normal") -> None:
    put(cv, ns(f"button_{state}", w), x, y)
    if state == "locked":
        put(cv, KIT["icon_padlock"], x + 6, y + 3)
        cv.text(x + w / 2 + 4, y + 10.6, label, 6.0, ST4, 900, "ms")
    else:
        cv.text(x + w / 2, y + 10.6, label, 6.0, CREAM, 900, "ms")


def mob_plate(cv: uc.Canvas, cx: int, y: int, lv: int, name: str, p: float, ghost: float, above: bool = False) -> None:
    w = 40
    x = cx - w // 2
    cv.text(cx + 5, y - 1.5, name, 5.2, CREAM, 800, "ms", outline=1)
    thin_bar(cv, x + 9, y + 1, w - 9, p, "fill_health_thin", ghost)
    keybadge(cv, x, y, str(lv))
    if above:
        cv.ptext(x + 4, y + 3, str(lv), LIL, outline=None)


def save(cv: uc.Canvas, name: str) -> Path:
    cv.flush()
    OUT.mkdir(exist_ok=True)
    path = OUT / name
    cv.big.convert("RGB").save(path)
    return path


# ---- screens ----------------------------------------------------------------------------------------------------------

def hud_screen() -> Path:
    cv = uc.Canvas(background("presentation/review/chapter1_expansion/woodland_view_170_260.png"))
    cv.shadow(252, 110, 10)
    cv.sprite("boar_idle_right_1", 252, 110, flip=True)
    cv.shadow(112, 120, 6)
    cv.sprite("mossling_idle_right_1", 112, 120)
    cv.shadow(186, 132, 6)
    cv.sprite("mossling_idle_right_3", 186, 132, flip=True)
    cv.flush()
    uc.lane(cv, 240, 103, 170, 99, 12)
    mob_plate(cv, 250, 84, 2, "Thornback Boar", 0.62, 0.78, above=True)
    mob_plate(cv, 112, 101, 1, "Mossling", 0.35, 0.5)
    mob_plate(cv, 186, 113, 1, "Mossling", 1.0, 1.0)
    uc.damage(cv, 112, 86, "12", "hit")
    uc.damage(cv, 160, 66, "-20", "hurt")
    uc.damage(cv, 250, 64, "36", "counter")
    plate(cv, 4, 4, 156, "Speak to the Elder at the shrine")
    ribbon(cv, 206, 3, 110, "Woodland Approach", 5.8)
    cv.text(15, 31.5, "LV", 5.0, BR_L, 900, "ms", outline=1)
    level_pillar(cv, 5, 34, 96, 0.62, 5)
    medallion(cv, 3, 134)
    slot(cv, 48, 117, "normal", icon="icon_herb", key="1", count=3)
    slot(cv, 76, 117, "locked", key="2")
    health_bar(cv, 45, 146, 114, 0.86, 0.95, 118, 138)
    thin_bar(cv, 50, 161, 86, 0.72)
    cv.text(139, 168.4, "Edge", 5.0, T2, 800, outline=1)
    for i, (k, sprint) in enumerate((("Z", True), ("X", False), ("C", False))):
        socket(cv, 226 + i * 31, 141, sprint, k)
    cv.text(240, 138.5, "Sprint", 5.0, T2, 800, "ms", outline=1)
    return save(cv, "1_hud.png")


def dialogue_screen() -> Path:
    cv = uc.Canvas(background("presentation/review/chapter1_expansion/current_village_layered.png"))
    cv.veil((20, 16, 26, 80))
    keybadge(cv, 12, 98, "ESC")
    cv.text(36, 106.2, "skip", 5.2, ST5, 700, outline=1)
    panel(cv, "panel_large_ornate", 6, 110, 308, 66)
    frame = ns("slot_frame", 54, 54)
    put(cv, frame, 14, 116)
    fx0, fy0, fx1, fy1 = bk.interior(frame)
    cv.portrait("portrait_tovan_neutral", 14 + fx0, 116 + fy0, min(fx1 - fx0, fy1 - fy0))
    ribbon(cv, 74, 103, 66, "Tovan", 7.0)
    cv.text(78, 133, "Hold out your hands, Totoy. This is a Black Katana,", 7.0, CREAM, 600)
    cv.text(78, 144, "and it is yours. It was always yours.", 7.0, CREAM, 600)
    cv.text(78, 156, "Remember the colours: gold, parry. Red, dash.", 7.0, ST5, 600)
    cv.ptext(282, 119, "2/5", ST4, outline=None, align="r")
    keybadge(cv, 270, 158, "E")
    cv.poly([(284, 161), (290, 161), (287, 165)], T2)
    return save(cv, "2_dialogue.png")


def shell(cv: uc.Canvas, active: int) -> None:
    cv.veil((20, 16, 26, 205))
    panel(cv, "panel_large_ornate", 4, 6, 312, 170)
    for i, name in enumerate(["Status", "Aspects", "Items", "Quests"]):
        tx = 14 + i * 54
        on = i == active
        put(cv, ns("tab_on" if on else "tab_off", 50), tx, 20)
        cv.text(tx + 25, 30.6, name, 6.0, CREAM if on else ST5, 900, "ms")
    ribbon(cv, 116, 0, 88, "Totoy", 7.0)
    w = keybadge(cv, 252, 22, "TAB")
    cv.text(254 + w, 29.4, "close", 5.2, ST5, 700)


def status_screen() -> Path:
    cv = uc.Canvas(background("presentation/review/chapter1_expansion/woodland_view_320_125.png"))
    shell(cv, 0)
    # left: portrait, level, experience, derived numbers (the panel's 30x20 corner ornaments stay clear)
    x0, y0, x1, y1 = panel(cv, "panel_small", 12, 38, 76, 58)
    side = min(x1 - x0, y1 - y0)
    cv.portrait("portrait_totoy_neutral", (x0 + x1 - side) // 2, y0, side)
    put(cv, KIT["level_shield"], 12, 98)
    cv.ptext(21, 103, "5", CREAM, 2, align="c")
    cv.text(34, 107, "Totoy", 8.0, CREAM, 900)
    cv.text(34, 115, "Waykeeper", 5.2, T2, 800)
    thin_bar(cv, 12, 121, 76, 0.7, "fill_exp_thin")
    cv.ptext(50, 132, "120/170", ST5, outline=None, align="c")
    for j, (k, v, col) in enumerate((("Health", "138", G6), ("Edge", "100", T2))):
        cv.text(14, 146 + j * 8, k, 5.6, ST5, 700)
        cv.ptext(87, 141 + j * 8, v, col, outline=None, align="r")
    # middle: stat points
    cv.text(96, 47, "Stat points", 7.2, CREAM, 900)
    keybadge(cv, 151, 40, "2")
    cv.text(165, 47, "to spend", 5.2, LIL, 800)
    stats = (("Vitality", 3, "fill_health_thin"), ("Might", 3, "fill_exp_thin"), ("Agility", 2, "fill_edge_thin"))
    for j, (name, pts, fill) in enumerate(stats):
        sy = 51 + j * 30
        panel(cv, "panel_medium", 94, sy, 112, 29)
        cv.text(101, sy + 12.5, name, 6.4, CREAM, 900)
        cv.ptext(181, sy + 7, f"{pts}/10", CREAM, outline=None, align="r")
        thin_bar(cv, 100, sy + 15, 82, pts / 10, fill)
        put(cv, ns("button_normal", 14, 14), 185, sy + 8)
        cv.ptext(192, sy + 12, "+", T2, 2, outline=None, align="c")
    button(cv, 92, 143, 38, "Confirm", "normal")
    button(cv, 132, 143, 32, "Undo", "pressed")
    button(cv, 166, 143, 42, "Respec", "locked")
    cv.text(150, 166, "Respec opens in Lanternfen", 5.0, ST5, 700, "ms")
    # right: loadout, aspects, items
    cv.text(214, 47, "Loadout", 7.2, CREAM, 900)
    slot(cv, 212, 51, "normal", size=30, icon="icon_katana")
    cv.text(246, 63, "Black Katana", 6.2, CREAM, 800)
    cv.text(246, 71, "three-strike combo", 5.0, ST5, 700)
    cv.text(214, 92, "Aspects", 5.8, T2, 900)
    for i, (k, sprint) in enumerate((("Z", True), ("X", False), ("C", False))):
        socket(cv, 212 + i * 31, 95, sprint, k)
    cv.text(214, 141, "Items", 5.8, T2, 900)
    slot(cv, 212, 144, "normal", icon="icon_herb", key="1", count=3)
    slot(cv, 239, 144, "locked", key="2")
    cv.text(268, 155, "Herb", 6.2, CREAM, 800)
    cv.text(268, 163, "heals 35", 5.0, ST5, 700)
    return save(cv, "3_status.png")


def aspects_screen() -> Path:
    cv = uc.Canvas(background("presentation/review/chapter1_expansion/woodland_view_470_260.png"))
    shell(cv, 1)
    cv.text(16, 47, "Owned", 6.4, T2, 900)
    x0, y0, x1, y1 = panel(cv, "panel_medium", 12, 50, 122, 40)
    socket(cv, 18, 54, True)
    cv.text(50, 64, "Sprint", 7.2, CREAM, 900)
    cv.text(50, 72, "bound by Edda", 5.2, T2, 700)
    put(cv, KIT["icon_check"], 112, 57)
    cv.text(50, 80, "in socket Z", 5.2, ST5, 700)
    cv.text(16, 101, "Not yet found", 6.4, ST5, 900)
    cv.text(84, 101, "8 more to find", 5.0, ST4, 700)
    for i in range(8):
        slot(cv, 14 + (i % 4) * 30, 104 + (i // 4) * 28, "locked")
    # detail
    x0, y0, x1, y1 = panel(cv, "panel_medium", 142, 40, 166, 78)
    socket(cv, 150, 46, True)
    cv.text(184, 56, "Sprint", 9.0, CREAM, 900)
    cv.text(184, 65, "Aspect of the fleet-footed", 5.4, T2, 700)
    cv.text(150, 88, "Run twice as fast for 3 seconds.", 5.8, CREAM, 700)
    cv.ptext(150, 93, "20", T2, outline=None)
    cv.text(160, 98.4, "Edge", 5.4, ST5, 700)
    cv.ptext(184, 93, "12", T2, outline=None)
    cv.text(194, 98.4, "s cooldown", 5.4, ST5, 700)
    cv.text(150, 108, "Works on the road; Edge refills when no foe is near.", 5.0, ST5, 700)
    put(cv, KIT["icon_rune"], 144, 121)
    cv.text(158, 130, "Sockets", 6.4, T2, 900)
    for i, (k, sprint) in enumerate((("Z", True), ("X", False), ("C", False))):
        socket(cv, 150 + i * 34, 134, sprint, k)
    cv.text(276, 150, "1 of 3", 6.4, CREAM, 900, "ms")
    cv.text(276, 158, "open", 5.2, ST5, 700, "ms")
    return save(cv, "4_aspects.png")


def cards_screen() -> Path:
    cv = uc.Canvas(background("presentation/review/chapter1_expansion/current_glade_layered.png"))
    cv.veil((20, 16, 26, 120))
    # training
    panel(cv, "panel_medium", 6, 6, 152, 38)
    cv.text(14, 18, "Training  2 of 4", 5.4, T2, 900)
    cv.text(14, 28, "Dash through the ring", 7.2, CREAM, 900)
    w = keybadge(cv, 14, 31, "SHIFT")
    cv.text(17 + w, 38.6, "dash", 5.2, ST5, 700)
    thin_bar(cv, 106, 11, 44, 0.5)
    # welcome
    ribbon(cv, 164, 8, 150, "Welcome to Lanternfen", 6.6)
    cv.text(239, 34, "Find Mira by the gate to begin.", 5.6, CREAM, 700, "ms", outline=1)
    # task complete
    panel(cv, "panel_small", 6, 48, 152, 32)
    slot(cv, 11, 52, "empty", icon="icon_check")
    cv.text(40, 61, "Task complete", 6.4, T2, 900)
    cv.text(40, 70, "Strike the post three times", 5.4, CREAM, 700)
    cv.ptext(150, 58, "+10", G6, outline=None, align="r")
    # level up
    panel(cv, "panel_large_ornate", 164, 44, 150, 46)
    put(cv, KIT["level_shield"], 174, 56)
    cv.ptext(183, 61, "5", CREAM, 2, align="c")
    cv.text(246, 67, "Level up", 10.0, CREAM, 900, "ms")
    cv.text(246, 79, "+5 health   +2 stat points", 5.6, LIL, 800, "ms")
    # item received
    panel(cv, "panel_medium", 6, 84, 152, 44)
    slot(cv, 13, 91, "normal", size=30, icon="icon_katana")
    cv.text(50, 98, "Received", 5.6, T2, 900)
    cv.text(50, 109, "Black Katana", 8.0, CREAM, 900)
    cv.text(50, 118, "A worn blade. It was always yours.", 5.0, ST5, 700)
    # aspect bound
    panel(cv, "panel_medium", 164, 94, 150, 44)
    socket(cv, 172, 99, True, "Z")
    cv.text(206, 107, "Aspect bound", 5.6, T2, 900)
    cv.text(206, 118, "Sprint", 8.0, CREAM, 900)
    cv.text(206, 127, "run twice as fast", 5.2, ST5, 700)
    # herb drop
    panel(cv, "panel_small", 6, 132, 152, 42)
    slot(cv, 12, 139, "normal", icon="icon_herb", count=1)
    cv.text(42, 148, "Herb", 7.0, CREAM, 900)
    cv.text(42, 157, "dropped by a Mossling", 5.2, ST5, 700)
    keybadge(cv, 42, 160, "1")
    cv.text(56, 168, "heals 35", 5.0, G6, 700)
    # gate
    panel(cv, "panel_small", 164, 142, 150, 32)
    put(cv, KIT["icon_padlock"], 174, 153)
    cv.text(188, 155, "The rune gate holds", 6.4, CREAM, 900)
    cv.text(188, 164, "Finish your tasks in Lanternfen.", 5.2, ST5, 700)
    return save(cv, "5_cards.png")


def contact(paths: list[Path]) -> Path:
    ims = [Image.open(p) for p in paths]
    tw, th, pad = 640, 360, 12
    out = Image.new("RGB", (2 * (tw + pad) + pad, 3 * (th + pad) + pad), (28, 24, 36))
    for k, im in enumerate(ims):
        out.paste(im.resize((tw, th), Image.LANCZOS), (pad + (k % 2) * (tw + pad), pad + (k // 2) * (th + pad)))
    kit = Image.open(HERE / "kit_sheet.png")
    kit.thumbnail((tw, th), Image.LANCZOS)
    out.paste(kit, (pad + tw + pad + (tw - kit.width) // 2, pad + 2 * (th + pad) + (th - kit.height) // 2))
    path = OUT / "contact.png"
    out.save(path)
    return path


def main() -> None:
    paths = [hud_screen(), dialogue_screen(), status_screen(), aspects_screen(), cards_screen()]
    print("\n".join(str(p.relative_to(ROOT)) for p in paths + [contact(paths)]))


if __name__ == "__main__":
    main()
