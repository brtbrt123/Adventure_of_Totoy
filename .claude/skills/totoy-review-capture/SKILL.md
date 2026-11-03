---
name: totoy-review-capture
description: Use to see or debug Adventure of Totoy visually: run a windowed Godot capture or a real-input playthrough, make GIFs, and chase a visual bug by hiding layers.
---

# Totoy review captures

Visual problems are reported by the owner; chase functional ones (console errors, broken flow) yourself. Show the owner pictures; never claim a look is good (you cannot judge it).

## Run a capture (window only; headless saves nothing)
`"C:\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe" --path . --resolution 1152x648 --script res://presentation/review/<dir>/<script>.gd`
- Frames go to `%APPDATA%\Godot\app_userdata\Adventure of Totoy\<name>\seq_NNNN.png` (+ `segments.json`).
- Existing scripts: `presentation/review/hero_fx/` (capture_hero_fx, capture_forms, capture_aspects, capture_mobs `-- --part=stag`), `presentation/review/staff/capture_staff.gd`, `presentation/review/mobile/capture_mobile_view.gd`, `presentation/review/playthrough/capture_start.gd` (title, NEW GAME, intro, village, Mira, with a throwaway save `user://playthrough_save.json`; the owner's save is never touched).
- GIFs: `python tools/art/hero_fx_capture_gif.py <capture dir> 0.55 <out dir>`. Attack ranges sheet: `python tools/art/attack_range_sheet.py`.

## Patterns that work
- Drive the game with real input: `Input.parse_input_event(InputEventAction)` (plain `Input.action_press` does not reach `_input` handlers). Set `Engine.set_meta(Explore.START_META, {...})` to start a scene; set env `TOTOY_SAVE_PATH`.
- Trial fights: walk to (256,204), press interact, clear waves with `core.mobs.hit_mob(..., 10000.0, ...)`, refill hero hp and top up the Warden each tick; skip weapon cut-ins by advancing them.
- Find which node draws a bug: freeze with `paused = true`, hide each CanvasItem under `HUD`, compare pixels in the bug's area. (This found the cut-in warm-up haze.)
- One scene per run: switching scenes inside one capture script can end it silently.
- Delete temporary probe scripts and their `.uid` before committing.
