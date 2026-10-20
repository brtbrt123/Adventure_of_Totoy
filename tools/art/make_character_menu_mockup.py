"""Character menu and HUD pop-up mockups for the human's review (no game code, nothing installed).

Renders, at the 320x180 base resolution (1x) and at 4x (nearest-neighbour sprites, text drawn with the project's real
fonts at 4x size, like the game's canvas_items stretch mode):
  character_menu_1_stats.png              STATS tab, nothing hovered
  character_menu_2_stats_weapon.png       STATS, weapon slot hovered (equipped weapon + its right-click active)
  character_menu_3_stats_aspect.png       STATS, an Aspect slot hovered (Gale Cut)
  character_menu_4_stats_row.png          STATS, a stat row hovered (Attack Speed)
  character_menu_5_inventory.png          INVENTORY tab, Chain Scythe selected
  character_menu_6_over_arena.png         the menu over the dimmed, frozen arena
  character_menu_tooltips_weapon.png      HUD weapon/active box + Q SWAP restyled in the same frame family
  character_menu_tooltips_aspect.png      HUD Aspect hover box restyled
  character_menu_result_defeat.png        DEFEAT panel restyled
  character_menu_result_victory.png       VICTORY panel restyled
  character_menu_*_current.png            the same HUD boxes as hud.gd draws them today (for comparison)
  character_menu_descriptions.png         every description box (3 Aspects, 3 weapons, every stat), 4x
  character_menu_contact.png              everything on one sheet
Each PNG also has a *_4x.png twin (except the two sheets, which are already large).

Every number shown is read from core/tuning.gd (parsed here) and derived with the same formulas as core/weapons.gd
and Player.scaled_ticks. Pillow only. Run from the project root:  python tools/art/make_character_menu_mockup.py
"""
from __future__ import annotations

import json
import math
import re
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "docs" / "previews"
PIXEL_FONT = ROOT / "presentation" / "fonts" / "PixelifySans.ttf"
MENU_FONT = ROOT / "presentation" / "fonts" / "Cinzel.ttf"
W, H = 320, 180

# ---------------------------------------------------------------------------------------------------- palette, art
PAL: dict[str, tuple[int, int, int, int]] = {}
for entry in json.loads((ROOT / "art" / "palette.json").read_text())["colors"]:
    hx = entry["hex"]
    PAL[entry["symbol"]] = (int(hx[1:3], 16), int(hx[3:5], 16), int(hx[5:7], 16), 255)

ATLAS = Image.open(ROOT / "art" / "build" / "sprites.png").convert("RGBA")
FRAMES = json.loads((ROOT / "art" / "build" / "sprites.json").read_text())["frames"]
GROUND = Image.open(ROOT / "presentation" / "arena" / "arena_ground.png").convert("RGBA")
PORTRAIT = Image.open(ROOT / "art" / "reference" / "hero_portrait.jpg").convert("RGB").crop((215, 0, 1715, 1500))


def sprite(name: str) -> Image.Image:
    f = FRAMES[name]
    return ATLAS.crop((f["x"], f["y"], f["x"] + f["w"], f["y"] + f["h"]))


# ---------------------------------------------------------------------------------------------------- tuning numbers
def parse_tuning() -> dict[str, object]:
    """Plain constants of core/tuning.gd (numbers, number arrays, StringNames)."""
    values: dict[str, object] = {}
    pattern = re.compile(r"^const\s+(\w+)\s*:\s*[\w\[\]]+\s*=\s*(.+?)\s*(#.*)?$")
    for line in (ROOT / "core" / "tuning.gd").read_text(encoding="utf-8").splitlines():
        m = pattern.match(line.strip())
        if not m:
            continue
        raw = m.group(2).strip()
        try:
            if raw.startswith("["):
                values[m.group(1)] = [float(v) if "." in v else int(v) for v in raw.strip("[]").split(",")]
            elif re.fullmatch(r"-?\d+", raw):
                values[m.group(1)] = int(raw)
            elif re.fullmatch(r"-?\d+\.\d*", raw):
                values[m.group(1)] = float(raw)
            elif raw.startswith("1.0 / "):
                values[m.group(1)] = 1.0 / float(raw.split("/")[1])
        except ValueError:
            pass
    return values


T = parse_tuning()


def roundi(x: float) -> int:  # Godot's roundi: half away from zero
    return int(math.floor(x + 0.5)) if x >= 0 else -int(math.floor(-x + 0.5))


def secs(ticks: float, digits: int = 2) -> str:
    text = f"{ticks / 60.0:.{digits}f}".rstrip("0").rstrip(".")
    return text


def num(x: float) -> str:
    return str(int(x)) if float(x).is_integer() else f"{x:.1f}"


WEAPONS = {
    "black_katana": {"name": "BLACK KATANA", "prefix": "", "combo": T["COMBO_MAX"], "wind": T["SWING_WINDUP_TICKS"],
                     "act": T["SWING_ACTIVE_TICKS"], "rec": T["SWING_RECOVERY_TICKS"], "dmg": T["SWING_DAMAGE_MULT"],
                     "rng": T["SWING_RANGE_MULT"], "edge": T["EDGE_PER_HIT"], "arc": T["ATTACK_ARC_DOT"],
                     "cost": T["BLACK_KATANA_BUFF_EDGE_COST"], "cd": T["BLACK_KATANA_BUFF_COOLDOWN_TICKS"],
                     "active": "BLACK FORM"},
    "dual_dagger": {"name": "DUAL DAGGER", "combo": T["DAGGER_COMBO_MAX"], "wind": T["DAGGER_SWING_WINDUP_TICKS"],
                    "act": T["DAGGER_SWING_ACTIVE_TICKS"], "rec": T["DAGGER_SWING_RECOVERY_TICKS"],
                    "dmg": T["DAGGER_SWING_DAMAGE_MULT"], "rng": T["DAGGER_SWING_RANGE_MULT"],
                    "edge": T["DAGGER_EDGE_PER_HIT"], "arc": T["ATTACK_ARC_DOT"], "cost": T["LIGHTNING_FORM_EDGE_COST"],
                    "cd": T["LIGHTNING_FORM_COOLDOWN_TICKS"], "active": "LIGHTNING BARRAGE"},
    "chain_scythe": {"name": "CHAIN SCYTHE", "combo": T["SCYTHE_COMBO_MAX"], "wind": T["SCYTHE_SWING_WINDUP_TICKS"],
                     "act": T["SCYTHE_SWING_ACTIVE_TICKS"], "rec": T["SCYTHE_SWING_RECOVERY_TICKS"],
                     "dmg": T["SCYTHE_SWING_DAMAGE_MULT"], "rng": T["SCYTHE_SWING_RANGE_MULT"],
                     "edge": T["SCYTHE_EDGE_PER_HIT"], "arc": T["SCYTHE_ARC_DOT"], "cost": T["REAPER_COIL_EDGE_COST"],
                     "cd": T["REAPER_COIL_COOLDOWN_TICKS"], "active": "REAPER'S COIL"},
}
for w in WEAPONS.values():
    w["swing_ticks"] = [a + b + c for a, b, c in zip(w["wind"], w["act"], w["rec"])]
    w["combo_ticks"] = sum(w["swing_ticks"])
    w["damage"] = [roundi(T["ATTACK_DAMAGE"] * m * 100) / 100 for m in w["dmg"]]
    w["reach"] = [T["ATTACK_RANGE"] * m for m in w["rng"]]
    w["arc_deg"] = math.degrees(math.acos(w["arc"]))


def damage_text(w: dict) -> str:
    return "/".join(num(d) for d in w["damage"])


def reach_text(w: dict) -> str:
    vals = [roundi(r) for r in w["reach"]]
    return "/".join(str(v) for v in vals) if len(set(vals)) > 1 else f"{vals[0]}"


KAT = WEAPONS["black_katana"]
# Black Form attack speed: every phase scaled with Player.scaled_ticks (base / mult, rounded, at least 1).
BF_COMBO_TICKS = sum(max(1, roundi(p / T["BLACK_KATANA_ATTACK_SPEED_MULT"]))
                     for trio in zip(KAT["wind"], KAT["act"], KAT["rec"]) for p in trio)
BARRAGE_SLASHES = 8  # Weapons.barrage_slashes() = LIGHTNING_BLINK_ORDER.size()
BARRAGE_TICKS = (T["LIGHTNING_BARRAGE_START_DELAY_TICKS"] + (BARRAGE_SLASHES - 1) * T["LIGHTNING_BARRAGE_INTERVAL_TICKS"]
                 + T["LIGHTNING_BARRAGE_HIT_DELAY_TICKS"] + T["LIGHTNING_BARRAGE_RECOVERY_TICKS"])
DASH_PX = T["DASH_TICKS"] * T["DASH_SPEED"]
MOVE_PX_S = T["PLAYER_SPEED"] * 60

# ---------------------------------------------------------------------------------------------------- descriptions
# Each: title, tag (right side of the title line), two body lines (stone_6) and one numbers line (water_5).
D = {}
D["breaking_edge"] = ("BREAKING EDGE", "ASPECT  KEY Z", [
    f"RIGHT AFTER A SUCCESSFUL PARRY: STEP IN {num(T['BREAKING_EDGE_STEP'])} PX AND STRIKE.",
    "HEAVY POSTURE DAMAGE: TWO OF THEM BREAK THE COLOSSUS.",
    f"{num(T['BREAKING_EDGE_EDGE_COST'])} EDGE  {secs(T['BREAKING_EDGE_WINDOW_TICKS'])} S AFTER A PARRY  "
    f"{num(T['BREAKING_EDGE_DAMAGE'])} DMG  {num(T['BREAKING_EDGE_POSTURE'])} POSTURE"])
D["gale_cut"] = ("GALE CUT", "ASPECT  KEY X", [
    f"AIMED DASH-SLASH: HITS ALL IN A {num(T['GALE_CUT_DISTANCE'])} PX CORRIDOR AND",
    "PASSES THROUGH THE BOSS. IT GIVES NO INVULNERABILITY.",
    f"{num(T['GALE_CUT_EDGE_COST'])} EDGE  CD {secs(T['GALE_CUT_COOLDOWN_TICKS'])} S  {num(T['GALE_CUT_DAMAGE'])} DMG  "
    f"{num(T['GALE_CUT_POSTURE'])} POSTURE  {num(T['GALE_CUT_LANE_WIDTH'])} PX WIDE"])
D["moon_cleave"] = ("MOON CLEAVE", "ASPECT  KEY C", [
    f"HOLD {secs(T['MOON_CLEAVE_WINDUP_TICKS'])} S, THEN RELEASE A CRESCENT WAVE THAT FLIES",
    f"{num(T['MOON_CLEAVE_TRAVEL'])} PX AND PIERCES. GETTING HIT DURING THE HOLD CANCELS IT.",
    f"{num(T['MOON_CLEAVE_EDGE_COST'])} EDGE  CD {secs(T['MOON_CLEAVE_COOLDOWN_TICKS'])} S  "
    f"{num(T['MOON_CLEAVE_DAMAGE'])} DMG  {num(T['MOON_CLEAVE_POSTURE'])} POSTURE"])
DAG, SCY = WEAPONS["dual_dagger"], WEAPONS["chain_scythe"]
D["black_katana"] = ("BLACK KATANA", "WEAPON  EQUIPPED", [
    f"BALANCED {KAT['combo']}-HIT COMBO, {damage_text(KAT)} DMG, REACH {reach_text(KAT)} PX.",
    f"RMB BLACK FORM: {secs(T['BLACK_KATANA_BUFF_DURATION_TICKS'])} S OF X{num(T['BLACK_KATANA_ATTACK_SPEED_MULT'])} "
    f"ATTACK SPEED AND X{num(T['BLACK_KATANA_DAMAGE_MULT'])} DAMAGE.",
    f"FORM {num(KAT['cost'])} EDGE  CD {secs(KAT['cd'])} S FROM ACTIVATION  +{num(KAT['edge'])} EDGE PER HIT"])
D["dual_dagger"] = ("DUAL DAGGER", "WEAPON", [
    f"FAST {DAG['combo']}-HIT COMBO, {damage_text(DAG)} DMG, SHORT REACH. HIT {DAG['combo']} CALLS",
    f"SKY LIGHTNING ({num(T['LIGHTNING_STRIKE_DAMAGE'])} DMG). RMB LIGHTNING BARRAGE: {BARRAGE_SLASHES} BLINK SLASHES.",
    f"BARRAGE {num(DAG['cost'])} EDGE  CD {secs(DAG['cd'])} S  {secs(BARRAGE_TICKS)} S INVULNERABLE  "
    f"+{num(DAG['edge'])} EDGE PER HIT"])
D["chain_scythe"] = ("CHAIN SCYTHE", "WEAPON", [
    f"SLOW, WIDE {SCY['combo']}-HIT SWEEPS THAT ALSO HIT TO THE SIDES, {damage_text(SCY)} DMG.",
    f"RMB REAPER'S COIL: HOOK UP TO {num(T['REAPER_COIL_HOOK_RANGE'])} PX, DRAG THE BOSS IN, STUN, SPIN.",
    f"COIL {num(SCY['cost'])} EDGE  CD {secs(SCY['cd'])} S  STUN {secs(T['REAPER_COIL_STAGGER_TICKS'])} S  "
    f"SPIN {T['REAPER_COIL_SPIN_HITS']} X {num(T['ATTACK_DAMAGE'] * T['REAPER_COIL_SPIN_DAMAGE_MULT'])} DMG"])
D["black_form"] = ("BLACK FORM", "BLACK KATANA  RMB", [
    f"FOR {secs(T['BLACK_KATANA_BUFF_DURATION_TICKS'])} S YOUR SWINGS ARE X{num(T['BLACK_KATANA_ATTACK_SPEED_MULT'])} "
    f"FASTER AND ALL YOUR HITS DEAL X{num(T['BLACK_KATANA_DAMAGE_MULT'])}.",
    "NO ANIMATION LOCK: USE IT EVEN MID-SWING. NO SWAP WHILE ON.",
    f"{num(KAT['cost'])} EDGE  CD {secs(KAT['cd'])} S FROM ACTIVATION  COMBO {secs(BF_COMBO_TICKS)} S"])
D["lightning_barrage"] = ("LIGHTNING BARRAGE", "DUAL DAGGER  RMB", [
    f"BLINK AROUND THE BOSS: {BARRAGE_SLASHES} AUTOMATIC SLASHES, ONE PER SIDE;",
    "THE LAST CALLS SKY LIGHTNING. YOU CANNOT BE HIT WHILE IT RUNS.",
    f"{num(DAG['cost'])} EDGE  CD {secs(DAG['cd'])} S  {BARRAGE_SLASHES} X "
    f"{num(T['ATTACK_DAMAGE'] * T['LIGHTNING_BARRAGE_DAMAGE_MULT'])} DMG  {secs(BARRAGE_TICKS)} S"])
D["reapers_coil"] = ("REAPER'S COIL", "CHAIN SCYTHE  RMB", [
    "THROW THE CHAIN: A HOOKED BOSS IS DRAGGED IN, STUNNED AND HIT BY",
    "A SPIN. A MISS PULLS YOU TO THE HOOK. YOU CANNOT BE HIT.",
    f"{num(SCY['cost'])} EDGE  CD {secs(SCY['cd'])} S  {num(T['REAPER_COIL_HOOK_RANGE'])} PX  "
    f"STUN {secs(T['REAPER_COIL_STAGGER_TICKS'])} S  {T['REAPER_COIL_SPIN_HITS']} X "
    f"{num(T['ATTACK_DAMAGE'] * T['REAPER_COIL_SPIN_DAMAGE_MULT'])} DMG"])
D["stat_health"] = ("HEALTH", "TOTOY", [
    "DAMAGE YOU CAN TAKE. AFTER A HIT YOU ARE BRIEFLY UNTOUCHABLE.",
    "DASH THROUGH RED ATTACKS, PARRY GOLD ONES.",
    f"{T['PLAYER_MAX_HP']} HP  {secs(T['PLAYER_HURT_INVULN_TICKS'])} S INVULNERABLE AFTER A HIT"])
D["stat_edge"] = ("EDGE", "TOTOY", [
    "PAYS FOR ASPECTS AND WEAPON ACTIVES. HITS AND PARRIES",
    "FILL IT; A COUNTER ON A BROKEN BOSS SPENDS ALL OF IT FOR DAMAGE.",
    f"MAX {num(T['EDGE_MAX'])}  +{num(T['EDGE_PER_PARRY'])} PER PARRY  HITS: SEE THE WEAPON"])
D["stat_move"] = ("MOVE SPEED", "TOTOY", [
    "WALKING SPEED. SWINGING SLOWS YOU TO A SHUFFLE.",
    "",
    f"{num(MOVE_PX_S)} PX/S  X{num(T['ATTACK_MOVE_FACTOR'])} WHILE ATTACKING  "
    f"X{num(T['PARRY_RECOVERY_MOVE_FACTOR'])} AFTER A MISSED PARRY"])
D["stat_dash"] = ("DASH", "TOTOY", [
    "A SHORT BURST WITH INVULNERABILITY. THE ANSWER TO RED ATTACKS.",
    "WORKS WITH EVERY WEAPON.",
    f"{num(DASH_PX)} PX IN {secs(T['DASH_TICKS'])} S  {secs(T['DASH_INVULN_TICKS'])} S INVULNERABLE  "
    f"CD {secs(T['DASH_COOLDOWN_TICKS'])} S"])
D["stat_parry"] = ("PARRY", "TOTOY", [
    "CATCH A GOLD ATTACK IN THE WINDOW. EARLY IN IT IS PERFECT: THE",
    "BOSS'S POSTURE BREAKS AT ONCE. LATER ONLY ADDS POSTURE.",
    f"WINDOW {secs(T['PARRY_ACTIVE_TICKS'])} S  PERFECT {secs(T['PARRY_PERFECT_TICKS'])} S  "
    f"LATE {num(T['PARRY_EARLY_POSTURE'])} POSTURE  MISS {secs(T['PARRY_WHIFF_RECOVERY_TICKS'])} S"])
D["stat_counter"] = ("COUNTER", "TOTOY", [
    f"HITS ON A POSTURE-BROKEN BOSS DEAL X{num(T['COUNTER_DAMAGE_MULT'])} PLUS HALF YOUR EDGE.",
    f"OTHERWISE ITS ARMOR LETS ONLY {roundi(T['ARMOR_DAMAGE_FACTOR'] * 100)}% THROUGH.",
    f"X{num(T['COUNTER_DAMAGE_MULT'])} +{num(T['EDGE_COUNTER_BONUS'])} PER EDGE  BREAK LASTS "
    f"{secs(T['BOSS_BREAK_TICKS'])} S  ARMOR X{num(T['ARMOR_DAMAGE_FACTOR'])}"])
D["stat_damage"] = ("DAMAGE", "BLACK KATANA", [
    "BASE DAMAGE OF EACH SWING OF THE COMBO.",
    f"ARMOR CUTS IT TO {roundi(T['ARMOR_DAMAGE_FACTOR'] * 100)}%; A COUNTER DOES X{num(T['COUNTER_DAMAGE_MULT'])}.",
    f"{damage_text(KAT)}  ARMORED "
    + "/".join(str(max(1, roundi(d * T['ARMOR_DAMAGE_FACTOR']))) for d in KAT["damage"])
    + f"  BLACK FORM X{num(T['BLACK_KATANA_DAMAGE_MULT'])}"])
D["stat_speed"] = ("ATTACK SPEED", "BLACK KATANA", [
    "TIME OF EACH SWING: WIND-UP, STRIKE AND RECOVERY.",
    "THE FINISHER IS SLOWEST AND LEAVES THE LONGEST OPENING.",
    "SWINGS " + " / ".join(secs(t) + " S" for t in KAT["swing_ticks"])
    + f"  COMBO {secs(KAT['combo_ticks'])} S  BLACK FORM {secs(BF_COMBO_TICKS)} S"])
D["stat_reach"] = ("REACH", "BLACK KATANA", [
    f"HOW FAR EACH SWING REACHES, IN A {roundi(KAT['arc_deg'])} DEGREE ARC EACH SIDE",
    "OF WHERE YOU FACE. THE FINISHER REACHES FURTHEST.",
    f"{reach_text(KAT)} PX  DAGGER {reach_text(DAG)}  SCYTHE {reach_text(SCY)} ({roundi(SCY['arc_deg'])} DEG)"])
D["stat_edge_gain"] = ("EDGE GAIN", "BLACK KATANA", [
    "EDGE EARNED BY EACH SWING THAT LANDS ON AN UNBROKEN BOSS.",
    "",
    f"KATANA +{num(KAT['edge'])}  DAGGER +{num(DAG['edge'])}  SCYTHE +{num(SCY['edge'])}  "
    f"PARRY +{num(T['EDGE_PER_PARRY'])}"])
D["none"] = ("", "", ["HOVER OR SELECT A SLOT OR A STAT TO READ ABOUT IT.", "",
                      "ARROWS/WASD: MOVE   ENTER/CLICK: SELECT"])

# The stat list (right column of the STATS tab): (label, value, description key).
STAT_ROWS = [
    ("header", "BASE", None),
    ("HEALTH", str(T["PLAYER_MAX_HP"]), "stat_health"),
    ("EDGE", f"{num(T['EDGE_MAX'])} MAX", "stat_edge"),
    ("MOVE SPEED", f"{num(MOVE_PX_S)} PX/S", "stat_move"),
    ("DASH", f"{num(DASH_PX)} PX  {secs(T['DASH_COOLDOWN_TICKS'], 1)}S", "stat_dash"),
    ("PARRY", f"{secs(T['PARRY_ACTIVE_TICKS'])} S", "stat_parry"),
    ("COUNTER", f"X{num(T['COUNTER_DAMAGE_MULT'])} +EDGE", "stat_counter"),
    ("header", "BLACK KATANA", None),
    ("DAMAGE", damage_text(KAT), "stat_damage"),
    ("ATTACK SPEED", f"{secs(KAT['combo_ticks'])} S", "stat_speed"),
    ("REACH", f"{reach_text(KAT)} PX", "stat_reach"),
    ("EDGE GAIN", f"+{num(KAT['edge'])}/HIT", "stat_edge_gain"),
    ("RMB BLACK FORM", f"{num(KAT['cost'])}E {secs(KAT['cd'])}S", "black_form"),
]


# ---------------------------------------------------------------------------------------------------- canvas
class Canvas:
    """Draws in 320x180 game pixels at an integer scale."""

    def __init__(self, scale: int, base: Image.Image | None = None):
        self.s = scale
        self.im = base.copy() if base is not None else Image.new("RGBA", (W * scale, H * scale), PAL["0"])
        self.d = ImageDraw.Draw(self.im)
        self.fonts: dict[tuple, ImageFont.FreeTypeFont] = {}
        # Text is drawn supersampled (8 samples per game pixel) and reduced by coverage, then cut at a threshold:
        # hard pixels like pixel_text.gdshader, but without FreeType's small-size hinting artefacts at 1x.
        self.q = max(1, 8 // scale)

    def rect(self, x: float, y: float, w: float, h: float, sym: str) -> None:
        if w <= 0 or h <= 0:
            return
        s = self.s
        self.d.rectangle([round(x * s), round(y * s), round((x + w) * s) - 1, round((y + h) * s) - 1], fill=PAL[sym])

    def px(self, x: int, y: int, sym: str) -> None:
        self.rect(x, y, 1, 1, sym)

    def outline(self, x: int, y: int, w: int, h: int, sym: str) -> None:
        self.rect(x, y, w, 1, sym)
        self.rect(x, y + h - 1, w, 1, sym)
        self.rect(x, y, 1, h, sym)
        self.rect(x + w - 1, y, 1, h, sym)

    def veil(self, alpha: float) -> None:
        layer = Image.new("RGBA", self.im.size, PAL["0"][:3] + (round(255 * alpha),))
        self.im.alpha_composite(layer)
        self.d = ImageDraw.Draw(self.im)

    def image(self, img: Image.Image, x: float, y: float, scale: int = 1, mirror: bool = False) -> None:
        if mirror:
            img = img.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
        k = self.s * scale
        big = img.resize((img.width * k, img.height * k), Image.Resampling.NEAREST)
        self.im.alpha_composite(big, (round(x * self.s), round(y * self.s)))

    def sprite(self, name: str, x: float, y: float, scale: int = 1) -> None:
        self.image(sprite(name), x, y, scale)

    def sprite_feet(self, name: str, fx: float, fy: float, scale: int = 1) -> None:
        f = FRAMES[name]
        self.sprite(name, fx - f.get("ax", 0) * scale, fy - f.get("ay", 0) * scale, scale)

    def sprite_rect(self, name: str, x: float, y: float, w: int, h: int) -> None:
        """A sprite stretched into a game-pixel rect (as hud.ui() does), nearest-neighbour at the canvas scale."""
        img = sprite(name).resize((w * self.s, h * self.s), Image.Resampling.NEAREST)
        self.im.alpha_composite(img, (round(x * self.s), round(y * self.s)))

    def ellipse(self, cx: float, cy: float, rx: float, ry: float, sym: str) -> None:
        s = self.s
        self.d.ellipse([(cx - rx) * s, (cy - ry) * s, (cx + rx) * s - 1, (cy + ry) * s - 1], fill=PAL[sym])

    # --- text: `at` is the top of the capitals, like Hud.lettering; hard alpha like pixel_text.gdshader
    def font(self, face: str, size: int) -> ImageFont.FreeTypeFont:
        key = (face, size)
        if key not in self.fonts:
            f = ImageFont.truetype(str(MENU_FONT if face == "menu" else PIXEL_FONT), size * self.s * self.q)
            if face == "menu":
                f.set_variation_by_axes([900])
            self.fonts[key] = f
        return self.fonts[key]

    def width(self, text: str, face: str = "pixel", size: int = 9) -> float:
        return self.font(face, size).getlength(text.upper()) / (self.s * self.q)

    def text(self, x: float, y: float, text: str, sym: str, face: str = "pixel", size: int = 9,
             outline: str | None = None, align: str = "left") -> float:
        text = text.upper()
        f = self.font(face, size)
        wpx = self.width(text, face, size)
        if align == "center":
            x -= wpx / 2
        elif align == "right":
            x -= wpx
        x = math.floor(x)
        cap_top = f.getbbox("H")[1]
        k = self.s * self.q
        mask = Image.new("L", (self.im.width * self.q, self.im.height * self.q), 0)
        ImageDraw.Draw(mask).text((x * k, round(y * k - cap_top)), text, font=f, fill=255)
        if self.q > 1:
            mask = mask.resize(self.im.size, Image.Resampling.BOX)
        mask = mask.point(lambda v: 255 if v >= 112 else 0)
        if outline:
            ring = mask.filter(ImageFilter.MaxFilter(2 * self.s + 1))
            self.im.paste(Image.new("RGBA", self.im.size, PAL[outline]), (0, 0), ring)
        self.im.paste(Image.new("RGBA", self.im.size, PAL[sym]), (0, 0), mask)
        self.d = ImageDraw.Draw(self.im)
        return wpx


# ---------------------------------------------------------------------------------------------------- shared frame
# ONE routine draws every pop-up: the character menu, its description box, the HUD hover boxes and the result panels.
# Layers from the outside in: 1 px ink edge, 1 px accent line, 1 px ink, a 1 px bevel (light top/left, dark
# bottom/right), the ink fill; plus a 5x5 diamond on each corner of the accent line. A theme is just three symbols.
THEMES = {
    "menu": {"accent": "v", "bevel_hi": "f", "bevel_lo": "8", "gem": "1", "plate": "k"},      # lilac, the HUD Edge colour
    "info": {"accent": "t", "bevel_hi": "f", "bevel_lo": "8", "gem": "u", "plate": "k"},      # teal, the HUD HP colour
    "victory": {"accent": "u", "bevel_hi": "g", "bevel_lo": "8", "gem": "p", "plate": "t"},   # teal and pale water
    "defeat": {"accent": "q", "bevel_hi": "a", "bevel_lo": "8", "gem": "s", "plate": "9"},    # muted skin/dirt, no red
}
GEM = ["..0..", ".0a0.", "0agA0", ".0a0.", "..0.."]  # a = accent, g = gem colour, A = accent (centre ring)


def gem(c: Canvas, cx: int, cy: int, theme: dict) -> None:
    for j, row in enumerate(GEM):
        for i, ch in enumerate(row):
            if ch == ".":
                continue
            sym = {"0": "0", "a": theme["accent"], "g": theme["gem"], "A": theme["accent"]}[ch]
            c.px(cx - 2 + i, cy - 2 + j, sym)


def frame(c: Canvas, x: int, y: int, w: int, h: int, theme_name: str = "menu", gems: bool = True,
          fill: str = "0") -> None:
    t = THEMES[theme_name]
    c.rect(x, y, w, h, "0")
    c.outline(x + 1, y + 1, w - 2, h - 2, t["accent"])
    c.rect(x + 3, y + 3, w - 6, h - 6, fill)
    c.rect(x + 3, y + 3, w - 6, 1, t["bevel_hi"])
    c.rect(x + 3, y + 3, 1, h - 6, t["bevel_hi"])
    c.rect(x + 3, y + h - 4, w - 6, 1, t["bevel_lo"])
    c.rect(x + w - 4, y + 3, 1, h - 6, t["bevel_lo"])
    if gems:
        for gx, gy in ((x + 1, y + 1), (x + w - 2, y + 1), (x + 1, y + h - 2), (x + w - 2, y + h - 2)):
            gem(c, gx, gy, t)


def banner(c: Canvas, cx: int, y: int, w: int, h: int, theme_name: str) -> None:
    """A title plate with notched ribbon ends, centred on cx (used by the result panels)."""
    t = THEMES[theme_name]
    x = cx - w // 2
    c.rect(x, y, w, h, "0")
    c.rect(x + 1, y + 1, w - 2, h - 2, t["accent"])
    c.rect(x + 2, y + 2, w - 4, h - 4, t["plate"])
    c.rect(x + 2, y + 2, w - 4, 1, t["gem"])
    # notched ends: a V cut into both short sides
    mid = y + h // 2
    for k in range(5):
        for side in (x + k, x + w - 1 - k):
            c.rect(side, mid - (4 - k), 1, 1 + 2 * (4 - k), "0")
    gem(c, cx, y + h - 1, t)
    # wings: small accent lines running out of the plate
    c.rect(x - 8, mid, 6, 1, t["accent"])
    c.rect(x + w + 2, mid, 6, 1, t["accent"])
    c.px(x - 10, mid, t["gem"])
    c.px(x + w + 9, mid, t["gem"])


def slot(c: Canvas, x: int, y: int, w: int, h: int, state: str = "") -> None:
    """An item/skill slot: ink fill, stone border; hovered/selected get a cream line and teal corner brackets."""
    c.rect(x, y, w, h, "0")
    c.outline(x, y, w, h, "1" if state else "f")
    c.rect(x + 1, y + 1, w - 2, 1, "e")
    if state:
        for bx, by, dx, dy in ((x - 2, y - 2, 1, 1), (x + w + 1, y - 2, -1, 1), (x - 2, y + h + 1, 1, -1),
                               (x + w + 1, y + h + 1, -1, -1)):
            c.rect(min(bx, bx + 3 * dx), by, 4, 1, "u")
            c.rect(bx, min(by, by + 3 * dy), 1, 4, "u")


def key_badge(c: Canvas, x: int, y: int, letter: str) -> None:
    c.rect(x, y, 8, 8, "0")
    c.outline(x, y, 8, 8, "v")
    c.text(x + 4, y + 1, letter, "1", size=9, align="center")


CURSOR = ["0.........", "00........", "010.......", "0110......", "01110.....", "011110....", "0111110...",
          "01111110..", "0111100...", "010110....", "00.0110...", "....0110..", ".....00..."]


def cursor(c: Canvas, x: int, y: int) -> None:
    for j, row in enumerate(CURSOR):
        for i, ch in enumerate(row):
            if ch != ".":
                c.px(x + i, y + j, ch)


# ---------------------------------------------------------------------------------------------------- arena + HUD
def arena(c: Canvas, mode: str = "fight") -> None:
    """A frozen arena view composed from the game's own ground, props, hero and boss frames."""
    origin = (240, 160)
    crop = GROUND.crop((origin[0], origin[1], origin[0] + W, origin[1] + H))
    c.image(crop, 0, 0)
    c.sprite_feet("prop_small_6", 40, 160)
    hero, boss = (58, 152), (108, 150)
    if mode != "victory":
        c.ellipse(boss[0], boss[1], 20, 5, "2")
        c.sprite_feet("golem2_idle_1" if mode == "fight" else "golem2_roar_3" if "golem2_roar_3" in FRAMES
                      else "golem2_idle_1", *boss)
    else:
        c.sprite_feet(max((k for k in FRAMES if k.startswith("golem2_death_")), key=lambda k: int(k.rsplit("_", 1)[1])),
                      *boss)
    c.ellipse(hero[0], hero[1], 8, 3, "2")
    hero_frame = {"fight": "hero2_idle_right_1", "defeat": "hero2_hurt_right_4",
                  "victory": "hero2_victory_right_6" if "hero2_victory_right_6" in FRAMES else "hero2_idle_right_1"}[mode]
    c.sprite_feet(hero_frame, *hero)


def bar(c: Canvas, x: int, y: int, w: int, frac: float, sym: str, h: int = 3, ghost: float = -1) -> None:
    c.rect(x - 1, y - 1, w + 2, h + 2, "0")
    c.rect(x, y, w, h, "e")
    amount = math.floor(w * max(0.0, min(1.0, frac)))
    if amount > 0:
        c.rect(x, y, amount, h, sym)
        c.rect(x, y, amount, 1, "u" if sym == "t" else "j")
        if h > 2:
            c.rect(x, y + h - 1, amount, 1, "f")


def portrait(c: Canvas) -> None:
    size = round(26 * c.s)
    img = PORTRAIT.resize((size, size), Image.Resampling.LANCZOS).convert("RGBA")
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).ellipse([0, 0, size - 1, size - 1], fill=255)
    img.putalpha(mask)
    c.im.alpha_composite(img, (round((24.54 - 13) * c.s), round((24.2 - 13) * c.s)))


def hud(c: Canvas, hover_box: bool = False, restyled: bool = False, result: bool = False) -> None:
    """A replica of hud.gd's layout (positions copied from it); katana equipped, Edge 50, all ready."""
    portrait(c)
    bar(c, 47, 20, 68, 0.72, "t", 5)
    bar(c, 47, 33, 66, 0.5, "v", 2)
    bar(c, 47, 40, 66, 1.0, "n", 2)
    c.sprite_rect("ui_profile", 2, 2, 125, 48)
    c.sprite_rect("ui_icon_edge_1", 39, 31, 6, 6)
    c.sprite_rect("ui_icon_dash_1", 39, 38, 6, 6)
    c.sprite_rect("ui_icon_parry_1", 116, 32, 7, 7)
    if not result:
        px, py = 56, 57  # boss panel above the Colossus's head (Hud.boss_panel)
        c.sprite_rect("ui_boss", px, py + 7, 104, 24)
        c.text(px + 52, py, "MOSSBOUND COLOSSUS", "z", outline="0", align="center")
        bar(c, px + 8, py + 18, 88, 0.9, "7", 3)
        bar(c, px + 20, py + 27, 64, 0.2, "v", 2)
    # weapon socket
    c.sprite("ui_weapon_frame_1", 269, 130)
    c.sprite("ui_weapon_totoy_blade_1", 277, 138)
    c.text(293, 154 + 14 - 6, "BLACK", "j", outline="0", align="center")
    sockets = [(241, 147), (253, 116), (284, 100)]
    icons = ["ui_aspect_breaking_edge_1", "ui_aspect_gale_cut_1", "ui_aspect_moon_cleave_1"]
    keys, costs = "ZXC", [T["BREAKING_EDGE_EDGE_COST"], T["GALE_CUT_EDGE_COST"], T["MOON_CLEAVE_EDGE_COST"]]
    for (sx, sy), icon, key, cost in zip(sockets, icons, keys, costs):
        c.sprite(icon, sx, sy)
        c.rect(sx - 3, sy + 15, 7, 7, "0")
        c.text(sx - 2, sy + 16, key, "1")
        c.text(sx + 12, sy + 12 + 12, f"{int(cost)}E", "v" if 50 >= cost else "i", size=12, outline="0",
               align="center")
    if restyled:
        weapon_box_new(c)
    else:
        weapon_box_old(c)
    if hover_box:
        (aspect_box_new if restyled else aspect_box_old)(c)


def weapon_box_old(c: Canvas) -> None:
    w = c.width("Q SWAP", size=10)
    c.rect(179, 133, w + 4, 11, "0")
    c.text(181, 135, "Q SWAP", "1", size=10)
    c.rect(179, 145, 62, 33, "0")
    c.text(181, 147, f"RMB {int(KAT['cost'])}E", "v", size=10)
    c.text(181, 157, "FORM OFF", "j", size=10)
    c.text(181, 167, "CD READY", "o", size=10)


def weapon_box_new(c: Canvas) -> None:
    # Q SWAP: a small framed plate with the key in its own cap
    frame(c, 176, 123, 50, 15, "menu", gems=False)
    key_badge(c, 180, 126, "Q")
    c.text(191, 127, "SWAP", "1", size=10)
    # the active box: same three lines, framed, with a divider under the key line
    frame(c, 176, 139, 64, 39, "menu")
    c.text(181, 144, f"RMB {int(KAT['cost'])}E", "v", size=10)
    c.rect(181, 152, 54, 1, "f")
    c.text(181, 155, "FORM OFF", "j", size=10)
    c.text(181, 165, "CD READY", "o", size=10)


def aspect_box_old(c: Canvas) -> None:
    c.rect(160, 65, 154, 36, "0")
    c.text(163, 68, "X GALE CUT", "1", size=10)
    c.text(163, 78, f"{int(T['GALE_CUT_EDGE_COST'])} EDGE", "v", size=10)
    c.text(163, 88, "CD READY", "o", size=10)


def aspect_box_new(c: Canvas) -> None:
    frame(c, 156, 60, 160, 44, "info")
    c.sprite("ui_aspect_gale_cut_1", 286, 70)
    key_badge(c, 161, 65, "X")
    c.text(172, 66, "GALE CUT", "1", size=10)
    c.rect(161, 75, 120, 1, "f")
    c.text(161, 79, f"{int(T['GALE_CUT_EDGE_COST'])} EDGE", "v", size=10)
    c.text(161, 89, "CD READY", "o", size=10)


def result_old(c: Canvas, victory: bool) -> None:
    lines = ["TIME 0:27.2", "BEST 0:17.2"] if victory else []
    extra = len(lines) + 1
    c.rect(60, 67, 200, 43 + extra * 8, "0")
    c.text(160, 74, "VICTORY" if victory else "DEFEAT", "1", size=18, outline="0", align="center")
    c.text(160, 96, "R TO RESTART", "o", outline="0", align="center")
    y = 105
    for line in lines:
        c.text(160, y, line, "1", outline="0", align="center")
        y += 8
    c.text(160, y, "ESC: TITLE", "o", outline="0", align="center")


def result_new(c: Canvas, victory: bool) -> None:
    theme = "victory" if victory else "defeat"
    lines = ["TIME 0:27.2", "BEST 0:17.2"] if victory else []
    h = 46 + (len(lines) * 9 + 4 if lines else 0)
    top = 86 - h // 2
    frame(c, 64, top, 192, h, theme)
    banner(c, 160, top - 8, 112, 22, theme)
    title = "VICTORY" if victory else "DEFEAT"
    c.text(160, top - 2, title, "1", face="menu", size=13, outline="0", align="center")
    t = THEMES[theme]
    y = top + 21
    c.text(160, y, "R TO RESTART", "o" if victory else "j", align="center")
    y += 10
    if lines:
        c.rect(110, y - 2, 100, 1, "f")
        y += 2
        for line in lines:
            c.text(160, y, line, "1", align="center")
            y += 9
    c.rect(124, y, 72, 1, t["accent"])
    c.px(160, y, t["gem"])
    y += 4
    c.text(160, y, "ESC: TITLE", "o" if victory else "j", align="center")


# ---------------------------------------------------------------------------------------------------- the menu
PANEL = (6, 16, 308, 162)  # x, y, w, h of the menu body (y 16..178)
DESC = (11, 125, 298, 40)


def tabs(c: Canvas, active: str) -> None:
    """Folder tabs on the panel's top edge: the active one is the panel's own ink, open at the bottom so it flows
    into the panel; inactive ones sit lower, grey-bordered, closed by the panel's border."""
    specs = [("STATS", 12, 54), ("INVENTORY", 68, 84)]
    top = PANEL[1] + 1  # the panel's accent line
    for label, x, w in specs:
        if label == active:
            continue
        c.rect(x, 7, w, top - 7, "0")
        c.rect(x + 1, 8, w - 2, 1, "f")
        c.rect(x + 1, 8, 1, top - 8, "f")
        c.rect(x + w - 2, 8, 1, top - 8, "f")
        c.text(x + w / 2, 10, label, "i", face="menu", size=10, align="center")
    for label, x, w in specs:
        if label != active:
            continue
        c.rect(x, 3, w, top + 3 - 3, "0")
        c.rect(x + 1, 4, w - 2, 1, "v")
        c.rect(x + 1, 4, 1, top - 3, "v")
        c.rect(x + w - 2, 4, 1, top - 3, "v")
        c.rect(x + 3, 6, w - 6, 1, "f")
        gem(c, x + 1, 4, THEMES["menu"])
        gem(c, x + w - 2, 4, THEMES["menu"])
        c.text(x + w / 2, 8, label, "1", face="menu", size=10, align="center")
    c.text(W - 12, 9, "TOTOY", "j", face="menu", size=10, align="right")
    c.text(W - 12 - c.width("TOTOY", "menu", 10) - 6, 10, "WAYKEEPER", "i", align="right")


def menu_base(c: Canvas, active: str) -> None:
    frame(c, *PANEL, "menu")
    tabs(c, active)
    c.text(160, 168, "TAB: SWITCH    ESC: CLOSE", "i", align="center")


def description(c: Canvas, key: str) -> None:
    title, tag, lines = D[key]
    frame(c, *DESC, "info", gems=False)
    x0 = DESC[0] + 5
    if not title:
        c.text(160, DESC[1] + 9, lines[0], "i", align="center")
        c.text(160, DESC[1] + 23, lines[2], "f", align="center")
        return
    c.text(x0, DESC[1] + 4, title, "1", face="menu", size=10)
    c.text(DESC[0] + DESC[2] - 6, DESC[1] + 4, tag, "u", align="right")
    for i, line in enumerate(lines):
        if line:
            limit = DESC[2] - 10
            assert c.width(line) <= limit, f"description line too wide ({c.width(line):.0f} > {limit}): {line}"
            c.text(x0, DESC[1] + 13 + i * 8, line, "o" if i == 2 else "j")


def stats_tab(c: Canvas, hover: str | None) -> None:
    menu_base(c, "STATS")
    # figure box: Totoy at 2x standing on a stone strip with a shadow
    fx, fy, fw, fh = 11, 21, 52, 101
    c.rect(fx, fy, fw, fh, "0")
    c.outline(fx, fy, fw, fh, "f")
    c.rect(fx + 1, fy + fh - 16, fw - 2, 15, "e")
    c.rect(fx + 1, fy + fh - 16, fw - 2, 1, "f")
    c.ellipse(fx + fw / 2, fy + fh - 9, 13, 3, "0")
    hero = sprite("hero2_idle_right_1")
    bbox = hero.getbbox()
    feet_x = fx + fw / 2 - ((bbox[0] + bbox[2]) / 2 - FRAMES["hero2_idle_right_1"]["ax"]) * 2
    c.sprite_feet("hero2_idle_right_1", round(feet_x), fy + fh - 9, 2)
    # weapon slot, centred in the middle column
    mid = 110
    c.text(mid, 20, "WEAPON", "i", align="center")
    sx, sy = mid - 25, 27
    slot(c, sx, sy, 50, 50, "hover" if hover == "weapon" else "")
    c.sprite("ui_weapon_frame_1", sx + 1, sy + 1)
    c.sprite("ui_weapon_totoy_blade_1", sx + 9, sy + 9)
    c.rect(sx + 41, sy + 1, 8, 8, "0")
    c.outline(sx + 41, sy + 1, 8, 8, "v")
    c.text(sx + 45, sy + 2, "E", "1", align="center")
    c.text(mid, 80, "BLACK KATANA", "1", align="center")
    # aspects
    c.text(mid, 89, "ASPECTS", "i", align="center")
    icons = ["ui_aspect_breaking_edge_1", "ui_aspect_gale_cut_1", "ui_aspect_moon_cleave_1"]
    for i, (icon, key) in enumerate(zip(icons, "ZXC")):
        ax = 68 + i * 29
        slot(c, ax, 96, 26, 26, "hover" if hover == ["breaking_edge", "gale_cut", "moon_cleave"][i] else "")
        c.sprite(icon, ax + 1, 97)
        key_badge(c, ax - 2, 96 + 17, key)
    # stats
    sx0, sx1 = 159, 307
    y = 21
    desc_key = {"weapon": "black_katana"}.get(hover or "", hover)
    for label, value, key in STAT_ROWS:
        if label == "header":
            c.text(sx0, y, value, "v")
            c.rect(sx0 + c.width(value) + 4, y + 3, sx1 - sx0 - c.width(value) - 4, 1, "f")
        else:
            on = hover == key
            if on:
                c.rect(sx0 - 2, y - 1, sx1 - sx0 + 3, 8, "k")
                c.rect(sx0 - 2, y + 7, sx1 - sx0 + 3, 1, "1")
            c.text(sx0 + (5 if on else 0), y, label, "1" if on else "i")
            if on:
                c.text(sx0 - 1, y, ">", "1")
            assert c.width(label) + c.width(value) + 8 < sx1 - sx0, label
            c.text(sx1, y, value, "1" if on else "j", align="right")
        y += 8
    description(c, desc_key or "none")


def inventory_tab(c: Canvas, selected: int) -> None:
    menu_base(c, "INVENTORY")
    gx, gy, step = 13, 23, 33
    items = [("black_katana", True), ("dual_dagger", False), ("chain_scythe", False)]
    for idx in range(18):
        col, row = idx % 6, idx // 6
        x, y = gx + col * step, gy + row * step
        slot(c, x, y, 32, 32, "sel" if idx == selected else "")
        if idx < len(items):
            wid, equipped = items[idx]
            inv_icon(c, wid, x, y)
            if equipped:
                c.rect(x + 24, y + 1, 7, 8, "0")
                c.outline(x + 24, y + 1, 7, 8, "v")
                c.text(x + 27.5, y + 2, "E", "1", align="center")
    # detail panel on the right
    dx, dw = 216, 93
    c.rect(dx, 21, dw, 101, "0")
    c.outline(dx, 21, dw, 101, "f")
    wid, equipped = items[selected]
    medal = {"black_katana": None, "dual_dagger": "ui_weapon_dual_dagger_1", "chain_scythe": "ui_weapon_chain_scythe_1"}[wid]
    cx = dx + dw // 2
    if medal:
        c.sprite(medal, cx - 24, 25)
    else:
        c.sprite("ui_weapon_frame_1", cx - 24, 25)
        c.sprite("ui_weapon_totoy_blade_1", cx - 16, 33)
    c.text(cx, 76, WEAPONS[wid]["name"], "1", align="center")
    c.text(cx, 85, "EQUIPPED" if equipped else "NOT EQUIPPED", "v" if equipped else "i", align="center")
    c.rect(dx + 6, 95, dw - 12, 1, "f")
    c.text(cx, 99, "SWAP: Q", "o", align="center")
    c.text(cx, 107, "IN THE ARENA", "o", align="center")
    description(c, wid)


def inv_icon(c: Canvas, wid: str, x: int, y: int) -> None:
    if wid == "black_katana":
        c.sprite("ui_weapon_totoy_blade_1", x, y)
        return
    medal = sprite({"dual_dagger": "ui_weapon_dual_dagger_1", "chain_scythe": "ui_weapon_chain_scythe_1"}[wid])
    inner = medal.crop((8, 8, 40, 40))  # the medallion's centre (its ring is the HUD socket's, not the slot's)
    c.image(inner, x, y)


def flat_background(c: Canvas) -> None:
    arena(c)
    c.veil(0.86)


# ---------------------------------------------------------------------------------------------------- scenes
def scene(kind: str, scale: int) -> Image.Image:
    c = Canvas(scale)
    if kind.startswith("menu"):
        over_arena = kind == "menu6"
        arena(c)
        if over_arena:
            hud(c)
        c.veil(0.62 if over_arena else 0.86)
        if kind == "menu5":
            inventory_tab(c, 2)
            cursor(c, gx_cursor := 13 + 2 * 33 + 22, 23 + 22)
            del gx_cursor
        else:
            hover = {"menu1": None, "menu2": "weapon", "menu3": "gale_cut", "menu4": "stat_speed",
                     "menu6": "gale_cut"}[kind]
            stats_tab(c, hover)
            pos = {"menu2": (110, 62), "menu3": (113, 112), "menu4": (250, 95), "menu6": (113, 112)}.get(kind)
            if pos:
                cursor(c, *pos)
    elif kind in ("tip_weapon", "tip_aspect", "tip_weapon_current", "tip_aspect_current"):
        arena(c)
        hud(c, hover_box=kind.startswith("tip_aspect"), restyled=not kind.endswith("current"))
        if kind.startswith("tip_aspect"):
            cursor(c, 262, 128)
    elif kind.startswith("defeat") or kind.startswith("victory"):
        victory = kind.startswith("victory")
        arena(c, "victory" if victory else "defeat")
        hud(c, result=True, restyled=not kind.endswith("current"))
        (result_old if kind.endswith("current") else result_new)(c, victory)
    return c.im


FILES = {
    "menu1": "character_menu_1_stats", "menu2": "character_menu_2_stats_weapon",
    "menu3": "character_menu_3_stats_aspect", "menu4": "character_menu_4_stats_row",
    "menu5": "character_menu_5_inventory", "menu6": "character_menu_6_over_arena",
    "tip_weapon": "character_menu_tooltips_weapon", "tip_aspect": "character_menu_tooltips_aspect",
    "tip_weapon_current": "character_menu_tooltips_weapon_current",
    "tip_aspect_current": "character_menu_tooltips_aspect_current",
    "defeat": "character_menu_result_defeat", "victory": "character_menu_result_victory",
    "defeat_current": "character_menu_result_defeat_current",
    "victory_current": "character_menu_result_victory_current",
}


def descriptions_sheet() -> Image.Image:
    keys = [k for k in D if k != "none"]
    s = 4
    rows = []
    for k in keys:
        c = Canvas(s)
        c.rect(0, 0, W, H, "8")
        description(c, k)
        rows.append(c.im.crop((DESC[0] * s - 8, DESC[1] * s - 8, (DESC[0] + DESC[2]) * s + 8,
                               (DESC[1] + DESC[3]) * s + 8)))
    cols = 2
    rw, rh = rows[0].size
    sheet = Image.new("RGBA", (cols * rw, math.ceil(len(rows) / cols) * rh), PAL["8"])
    for i, r in enumerate(rows):
        sheet.alpha_composite(r, ((i % cols) * rw, (i // cols) * rh))
    return sheet


def contact(images: dict[str, Image.Image]) -> Image.Image:
    order = ["menu1", "menu2", "menu3", "menu4", "menu5", "menu6", "tip_weapon_current", "tip_weapon",
             "tip_aspect_current", "tip_aspect", "defeat_current", "defeat", "victory_current", "victory"]
    labels = {"menu1": "1 STATS", "menu2": "2 WEAPON HOVER", "menu3": "3 ASPECT HOVER", "menu4": "4 STAT HOVER",
              "menu5": "5 INVENTORY", "menu6": "6 OVER THE ARENA", "tip_weapon_current": "WEAPON BOX NOW",
              "tip_weapon": "WEAPON BOX NEW", "tip_aspect_current": "ASPECT HOVER NOW",
              "tip_aspect": "ASPECT HOVER NEW", "defeat_current": "DEFEAT NOW", "defeat": "DEFEAT NEW",
              "victory_current": "VICTORY NOW", "victory": "VICTORY NEW"}
    k, cols, pad, lab = 2, 2, 8, 14
    cw, ch = W * k + pad, H * k + pad + lab
    sheet = Image.new("RGBA", (cols * cw + pad, math.ceil(len(order) / cols) * ch + pad), PAL["e"])
    font = ImageFont.truetype(str(PIXEL_FONT), 18)
    d = ImageDraw.Draw(sheet)
    for i, key in enumerate(order):
        x, y = pad + (i % cols) * cw, pad + (i // cols) * ch
        d.text((x, y - 2), labels[key], font=font, fill=PAL["1"])
        sheet.alpha_composite(images[key].resize((W * k, H * k), Image.Resampling.NEAREST), (x, y + lab))
    return sheet


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    ones: dict[str, Image.Image] = {}
    for kind, name in FILES.items():
        one = scene(kind, 1)
        four = scene(kind, 4)
        one.convert("RGB").save(OUT / f"{name}.png")
        four.convert("RGB").save(OUT / f"{name}_4x.png")
        ones[kind] = one
        print("wrote", name)
    contact(ones).convert("RGB").save(OUT / "character_menu_contact.png")
    descriptions_sheet().convert("RGB").save(OUT / "character_menu_descriptions.png")
    print("wrote character_menu_contact.png, character_menu_descriptions.png")


if __name__ == "__main__":
    main()
