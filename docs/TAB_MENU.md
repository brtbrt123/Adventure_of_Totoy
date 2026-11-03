# TAB menu (character menu)

Redesigned with the owner on 2026-11-03. Owner's words: "fix the tab menu improve the layout, and design, make it consistent in layout and design, make sure every function is useful and needed". Mockups first (`presentation/review/menu_redesign/`, made by `build_mockup.gd` there), the owner's changes ("make the weapon slot like the aspect slot only 1 slot then weapon name then information ... scroll down to find more", "make the item 2 slot but the other 1 is empty"), then "Yes, build it".

## What it shows

Three tabs, one layout: the content on the left (x 16..226), the **detail card** on the right (x 232..368) that always describes what is selected, the same selection mark everywhere (teal corners; a dark blue fill on rows), Cinzel for titles, Pixelify Sans for text, the key font only on key badges, and a footer that lists only the keys that work right now (key names in Cinzel, because both pixel fonts draw B like G).

| Tab | Left | Card |
|---|---|---|
| HERO | Totoy, LEVEL n, EXP bar, points to spend, VITALITY / MIGHT / AGILITY with 10 pips and a "+", RESPEC (free, only in Lanternfen, only when points are spent) | YOUR STATS: health, damage, dash cooldown, move speed, Edge, with what one more point of the selected stat adds; what the stat does |
| GEAR | WEAPON: one medallion socket with the name, type and combo, damage, reach, RMB skill and cost. ASPECTS: sockets Z X C (locked ones show a padlock). ITEMS: slot 1 (herbs and their count once the Elder's slot is open), slot 2 always empty for now | the selected weapon / Aspect / item; ENTER on the weapon or a socket turns the card into a **list** (three rows in view, scroll bar, the highlighted entry's text), ENTER equips, ESC goes back |
| QUESTS | Chapter 1 tasks: done ones ticked, the current one highlighted with a rune, later ones hidden | CURRENT TASK, its reward (EXP, items) and why the road is still closed; ALL TASKS DONE at the end |

In the boss fight (`arena.gd`, `progression == null`): HERO shows Totoy and "stat points are spent on the road; this fight uses base stats" (true: `GameCore` applies only the weapon and Aspects), the card the base numbers; GEAR offers every Aspect; QUESTS the fight's goal. The fight's HUD strip, sockets and boss panel are hidden while the menu is open (`hud.gd` `menu_open`).

Removed in the redesign: the ASPECTS tab, the Aspect tiles in ITEMS (they were in four places), the 8 empty item slots, the second description box under ITEMS, the floating Aspect picker over the stat rows, the boss fight's separate STATUS layout with its 13-row stat list, the instruction lines, and the unused description entries (stat rows, weapon actives, "none", "empty").

Bugs fixed on the way: "IN YOUR HANDS / EQUIPPED" for the katana before Tovan gives it (GEAR now says NO WEAPON and refuses the list), "COOLDOWN 0 S", the boss fight's QUESTS saying "follow the objective marker on the road", the fight HUD showing through the menu.

## Files

- `presentation/arena/character_menu.gd`: the controller. State (tab, `hero_selection`, `gear_selection`, `list_kind/slot/selection/scroll`, `feedback`, `notice`), input (`poll_input`, `click`, `hover_at`, `move_selection`, `accept`), the four requests (`equip_request`, `aspect_request`, `stat_request`, `respec_request`), the clickable rects (`tab_rect`, `row_rect`, `plus_rect`, `respec_rect`, `weapon_rect`, `socket_rect`, `item_rect`, `list_row_rect`), the texts (`descriptions`, `stat_text`, `stat_lines`) and what each scene shows (`_hero_data`, `_gear_data`, `_quests_data`, `_hero_card`, `_gear_card`, `_list_card`, `_quests_card`, `footer`). It draws only the teal corners.
- Editable scenes in `presentation/ui/` (each with a small script that only fills in text and icons): `menu_shell.tscn` (veil, tabs, name, panel, card frame, footer with two hidden template labels), `menu_hero.tscn`, `menu_gear.tscn`, `menu_quests.tscn`, `menu_card.tscn` (info and list layouts). `menu_icons.gd` makes the atlas icons. `editor_backdrop.gd` shows the frame behind a piece opened alone in the editor.
- `tools/godot/build_menu_scenes.gd` made the five scenes once (`godot --headless --path . --script res://tools/godot/build_menu_scenes.gd`). Running it again **overwrites edits made in the editor**. If a socket, row or slot is moved in a scene, move its rect in `character_menu.gd` too.
- Old scenes deleted: `menu_status`, `menu_aspects`, `menu_items`, `menu_arena_status`, `menu_description`, `menu_picker`.

## Rules worth keeping

- The road opens the menu on HERO, except during Edda's lesson (objective `edda_equip`), when it opens on GEAR at socket Z (setting Sprint there is the task).
- The Aspect list shows only owned Aspects (all in the boss fight) plus "n MORE TO FIND". The weapon list shows every weapon (the core has no weapon ownership); it refuses to open while unarmed.
- Item slot 2 is shown empty even though the core keeps it locked (owner: "the other 1 is empty since we dont have currently another item").

## Tests and captures

- `tests/smoke_character_menu.gd` (boss fight: tabs, arrows reach everything, hover, both lists, one core step per request, swaps, NOT NOW reasons, scrolling by keys / wheel / click, real numbers, HUD strip hidden under the menu, saved loadout).
- `tests/smoke_progression.gd` (road: Edda's lesson opens on socket Z, owned-only list, herb count, the finished quest list, the "+").
- `tests/capture_ui_kit.gd`, `tests/capture_ward_echo_sprint_game.gd` (windowed captures) use the new API.
- In-game pictures: `presentation/review/menu_redesign/ingame_*.png`.

## Open

- Both pixel fonts draw B like G at these sizes ("TAB" reads "TAG", "BRING" reads "GRING"). The menu uses Cinzel for key names; the font question is the owner's.
- The boss fight ignores stat points (`GameCore` applies only the loadout). A design question for the owner.
