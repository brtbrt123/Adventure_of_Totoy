# Character menu and pop-up restyle: mockups for review

Status: MOCKUP ONLY (2026-10-21). Nothing in the game changed: no `core/`, `presentation/`, `tests/`, `art/src` or
`art/build` edits, nothing committed. Made by Claude Code while Codex is out. The human approves or rejects the look.

Regenerate: `python tools/art/make_character_menu_mockup.py` (Pillow only; reads `core/tuning.gd`, `art/palette.json`,
`art/build/sprites.png/json`, `presentation/arena/arena_ground.png`, `art/reference/hero_portrait.jpg` and the two fonts
in `presentation/fonts/`).

## Files (each also as `*_4x.png`)

| File | Shows |
|---|---|
| `character_menu_1_stats.png` | STATS tab, nothing hovered (the description box shows a hint) |
| `character_menu_2_stats_weapon.png` | weapon slot hovered: Black Katana and its right-click Black Form |
| `character_menu_3_stats_aspect.png` | Aspect slot X hovered: Gale Cut |
| `character_menu_4_stats_row.png` | stat row hovered: Attack Speed |
| `character_menu_5_inventory.png` | INVENTORY tab, Chain Scythe selected |
| `character_menu_6_over_arena.png` | the menu over the frozen, dimmed arena with the HUD behind the veil |
| `character_menu_tooltips_weapon.png` / `_current` | HUD weapon-active box and Q SWAP, restyled / as today |
| `character_menu_tooltips_aspect.png` / `_current` | HUD Aspect hover box, restyled / as today |
| `character_menu_result_defeat.png` / `_current` | DEFEAT panel, restyled / as today |
| `character_menu_result_victory.png` / `_current` | VICTORY panel, restyled / as today |
| `character_menu_descriptions.png` | every description box (3 Aspects, 3 weapons, 3 actives, 10 stats) at 4x |
| `character_menu_contact.png` | all 14 screens (1x shown at 2x), NOW next to NEW for the HUD boxes |

1x is the 320x180 base. 4x is what a 1280x720 window shows: sprites nearest-neighbour, text drawn with the real fonts
at 4x (the game's `canvas_items` stretch mode draws HUD text at window resolution). **Judge the text on the 4x files.**
At 1x Pixelify Sans at 9 px loses letters (C looks like O, B like G, 5 like S); the game never shows it that way.

## Layout (game pixels, 320x180)

- **Veil:** ink at about 60% over the frozen arena (the only semi-transparent pixels). In scenes 1-5 the veil is darker
  (86%) to show the panel alone.
- **Panel:** 6,16 to 314,178 in the shared frame (below), lilac accent. Folder **tabs** on its top edge: STATS and
  INVENTORY in Cinzel; the active one is the panel's own ink, open at the bottom, lilac border with corner gems; the
  inactive one sits lower with a grey border and grey text. Top right: `WAYKEEPER TOTOY`.
- **STATS, left:** Totoy (`hero2_idle_right_1` at 2x) in a 52x101 box on a stone strip.
- **STATS, middle:** `WEAPON` slot 50x50 with the HUD medallion (frame plus blade glyph for the katana), an `E` badge
  (equipped), the name under it; `ASPECTS`: three 26x26 slots with the HUD's `ui_aspect_*` icons and Z/X/C key badges.
- **STATS, right:** the stat list, 8 px rows, two lilac section headers (`BASE`, then the equipped weapon's name),
  label left in grey, value right in stone_6. Hovered row: dark-blue plate, cream underline and `>` (the title menu's
  selected-item look).
- **Hovered/selected slot:** cream 1 px border plus teal corner brackets.
- **Description box:** 11,125, 298x40, teal accent: title (Cinzel), a teal tag on the right (`ASPECT KEY X`,
  `WEAPON EQUIPPED`, `BLACK KATANA RMB`...), two body lines (stone_6) and one numbers line (water_5, the HUD's cooldown
  colour). The script fails if any line is wider than the box.
- **Bottom hint:** `TAB: SWITCH    ESC: CLOSE`.
- **INVENTORY:** 6x3 grid of 32x32 slots (step 33) at 13,23. Weapons in slots 1-3; the katana uses its 32 px blade glyph,
  dagger and scythe show the centre 32x32 of their HUD medallion (the ring is cut off). `E` badge on the equipped one.
  Right: a detail card (the 48 px medallion, name, `EQUIPPED`/`NOT EQUIPPED`, `SWAP: Q / IN THE ARENA`). The
  description box below as on STATS.

## The shared frame (one routine for every pop-up)

In the script this is `frame(canvas, x, y, w, h, theme, gems=True)`; in Godot it would be one static function, for
example `Hud.draw_panel(canvas: CanvasItem, rect: Rect2, theme: StringName, gems: bool = true)`, used by the HUD boxes,
the result panels, the character menu, its description box and any later pop-up. From the outside in:

1. 1 px ink edge, 2. 1 px accent line, 3. 1 px ink, 4. 1 px bevel (light top/left, dark bottom/right), 5. ink fill,
6. a 5x5 diamond gem centred on each corner of the accent line (ink outline, accent ring, a light centre).

A theme is only four palette symbols (accent, bevel light, bevel dark, gem, plus a plate colour for banners):

| Theme | Accent | Used for |
|---|---|---|
| `menu` | lilac `v` | character menu, weapon/active box, Q SWAP plate |
| `info` | teal_1 `t` | description box, Aspect hover box |
| `victory` | teal_2 `u`, plate teal_1, gem water_6 | VICTORY |
| `defeat` | skin_1 `q`, plate dirt_2, gem skin_3 | DEFEAT (muted warm, no reserved red or gold) |

Two helpers sit on top of it: `banner()` (a title plate with notched ribbon ends, a gem under it and short accent wings;
the result panels' title) and `slot()` (ink square with a stone border; hovered/selected: cream border and teal corner
brackets). Everything is filled rectangles and single pixels on the 320x180 grid, so it stays hard-edged at any window
size. The text keeps its current fonts, sizes and colours.

**HUD boxes restyled, text unchanged:** weapon-active box (`RMB 50E` / `FORM OFF` / `CD READY`) now framed at
176,139 64x39 with a divider under the first line (it moves 2-3 px up and left to fit the frame and stays clear of the
Z socket); `Q SWAP` becomes a framed plate with Q in a key cap. Aspect hover box (`X GALE CUT` / `35 EDGE` /
`CD READY`) framed at 156,60 160x44, with the key in a badge, a divider and the Aspect's icon on the right. DEFEAT and
VICTORY: framed panel with a banner title in Cinzel (today it is the pixel font at 18 px); all lines kept
(`R TO RESTART`, `TIME`, `BEST`, `ESC: TITLE`). The result panels have no veil, as today.

## Controls proposed

- Open/close: **C** or **I** (C is Moon Cleave today, so either C moves or the menu uses I only; your call). **ESC**
  closes (it is "back to title" on the result screen only).
- Switch tab: **TAB**, or **Q / E** while the menu is open (Q is the weapon swap in the arena; it is free while paused).
- Move the selection: arrow keys or WASD over slots and stat rows; Enter or a left click selects (pins the description).
- Mouse: hover shows the description, click pins it.
- **The game is paused while the menu is open** (the core does not advance; presentation draws the last snapshot under
  the veil). Opening is refused during a cut-in and on the result screen.

## Where every number comes from

All read from `core/tuning.gd` by the script; derived values use the formulas of `core/weapons.gd` and
`Player.scaled_ticks`. Seconds = ticks / 60.

| Shown | Source |
|---|---|
| Health 100, 0.75 s after a hit | `PLAYER_MAX_HP`, `PLAYER_HURT_INVULN_TICKS` |
| Edge 100, +25 per parry | `EDGE_MAX`, `EDGE_PER_PARRY` |
| Move speed 60 px/s, x0.3 attacking, x0.5 after a missed parry | `PLAYER_SPEED` x 60, `ATTACK_MOVE_FACTOR`, `PARRY_RECOVERY_MOVE_FACTOR` |
| Dash 30 px in 0.1 s, 0.13 s invulnerable, CD 0.67 s | `DASH_TICKS` x `DASH_SPEED`, `DASH_INVULN_TICKS`, `DASH_COOLDOWN_TICKS` |
| Parry window 0.23 s, perfect 0.1 s, late 35 posture, miss 0.33 s | `PARRY_ACTIVE_TICKS`, `PARRY_PERFECT_TICKS`, `PARRY_EARLY_POSTURE`, `PARRY_WHIFF_RECOVERY_TICKS` |
| Counter x4 + 0.5 per Edge, break 1 s, armor x0.25 (25%) | `COUNTER_DAMAGE_MULT`, `EDGE_COUNTER_BONUS`, `BOSS_BREAK_TICKS`, `ARMOR_DAMAGE_FACTOR` (rules in `GameCore._land_player_hit`) |
| Katana damage 10/12/20, armored 3/3/5 | `ATTACK_DAMAGE` x `SWING_DAMAGE_MULT` (`Weapons.damage_mults`) |
| Katana attack speed 0.32/0.3/0.48 s, combo 1.1 s | `SWING_WINDUP/ACTIVE/RECOVERY_TICKS` (`Weapons.swing_phases`) |
| Black Form combo 0.75 s | each phase / `BLACK_KATANA_ATTACK_SPEED_MULT`, rounded (`Player.scaled_ticks`) |
| Reach 26/26/33 px, 78 deg each side | `ATTACK_RANGE` x `SWING_RANGE_MULT`, acos(`ATTACK_ARC_DOT`) |
| Dagger reach 20, scythe 34/34/36 (102 deg) | `DAGGER_SWING_RANGE_MULT`, `SCYTHE_SWING_RANGE_MULT`, acos(`SCYTHE_ARC_DOT`) |
| Edge gain +25 / +20 / +25 | `EDGE_PER_HIT`, `DAGGER_EDGE_PER_HIT`, `SCYTHE_EDGE_PER_HIT` (`Weapons.edge_per_hit`) |
| Black Form 50 Edge, 10 s, x1.5 speed, x1.4 damage, CD 30 s | `BLACK_KATANA_BUFF_*` (`Weapons.active_*`) |
| Dagger 6/6/6/9, 4 hits, sky lightning 20 | `DAGGER_*`, `LIGHTNING_STRIKE_DAMAGE` |
| Lightning Barrage 60 Edge, CD 12.5 s, 8 x 6 dmg, 0.92 s | `LIGHTNING_FORM_EDGE_COST`, `LIGHTNING_FORM_COOLDOWN_TICKS`, `LIGHTNING_BLINK_ORDER` size, `LIGHTNING_BARRAGE_DAMAGE_MULT`, `Weapons.barrage_total_ticks` |
| Scythe 10/11/17, 3 hits | `SCYTHE_SWING_DAMAGE_MULT` |
| Reaper's Coil 50 Edge, CD 10 s, 150 px, stun 0.75 s, spin 2 x 12 | `REAPER_COIL_EDGE_COST`, `_COOLDOWN_TICKS`, `_HOOK_RANGE`, `_STAGGER_TICKS`, `_SPIN_HITS`, `_SPIN_DAMAGE_MULT` |
| Breaking Edge 25 Edge, 0.83 s after a parry, 26 px step, 20 dmg, 55 posture | `BREAKING_EDGE_*` |
| Gale Cut 35 Edge, CD 5 s, 120 px corridor 18 px wide, 15 dmg, 10 posture, passes through the boss | `GALE_CUT_*`; pass-through: `GameCore._player_passes_through_boss` |
| Moon Cleave 80 Edge, CD 1.5 s, hold 0.5 s, 140 px, 40 dmg, 20 posture | `MOON_CLEAVE_*` |

No crit stat exists in the core, so none is shown; the counter (x4 on a broken boss) is the closest thing and has its
own row. The texts of all 19 descriptions are in the script (`D`) and on `character_menu_descriptions.png`.

## Open questions for the human

1. **Inventory contents:** today only the three weapons exist. What else goes in? `GAME_DESIGN.md` mentions Aspect
   fragments, artifacts (two slots, three later) and crafting materials. Separate tabs or one grid? 18 slots enough?
2. **Display only?** Are the stats read-only, or should the menu also equip (pick the weapon here instead of Q, choose
   Aspects for the slots as the design's checkpoint equip describes)? Equipping changes rules, so it needs core work.
3. **Open key:** C is Moon Cleave. Use I, Tab, or move Moon Cleave?
4. **Pause:** should the arena freeze while it is open (proposed), or only at checkpoints/out of combat?
5. **Which numbers:** players may prefer fewer numbers (seconds and damage only, no posture, no ticks). Too many?
6. **Damage shown:** base damage (shown) or what the armored Colossus actually takes (25%)? Both are in the description.
7. **Inventory weapon icons:** the dagger/scythe icons are the medallion centres cut to 32 px; dedicated 32 px item
   icons would look cleaner (new art).
8. The result panels' titles change from the pixel font to Cinzel; keep that, or keep the pixel font?

## Not judged

Whether it looks good and fits the game (the human's call); readability at 1280x720 on a real screen; how hover and tab
switching feel in motion; whether the defeat palette (muted brown) reads as "defeat" without red.
