# Runebound Warden: integrated presentation

2026-10-31. Branch `agent/codex/progression`. Owner approved design and instructed integration, after requesting a 2.5x body. No main merge; unrelated dirty work preserved.

## What is installed

- 60 enlarged body frames derived from V4, nearest-neighbour 2.5x (120x120 before transparent trim), feet anchor (50,110) before trim. 75 compact body-attached FX retain V4 pixels and individual anchors. `art/reference/warden_size_2p5/install_sources.py` writes 135 text grids, trims padding without moving visible pixels relative to feet, and builds pose-specific chest/hook metadata.
- Shared `mob_view.gd` covers all Warden core states, selects the current `attack` rather than queued `attack_id`, loops dormant idle from simulation time, spreads three strike poses over the actual active interval and all eight death poses over core death duration. Guard-hit recoil is restricted to non-attacking guarded poses; sparks never cancel an attack pose. Guarded hits preserve the body instead of flashing its entire silhouette white. The enlarged HP/level decoration and cosmetic shadows follow its new height.
- Shared Explore creature effects delegate Warden cosmetics to `warden_effects.gd`, preserving existing Stag/moth effects. Chest effects follow the pose, bodies are drawn over attached effects, and a small additive chest/floor glow turns off with `guarded`. Guard hit, guard break, exposed dust, arrival, wake, weapon arc and crumbling debris are included.
- Floor effects use actual committed telegraph centre, direction, size, width, half-angle and start/hit/end ticks. Cleave shows the complete cone immediately during damage. Lash creep stays in the core lane; the strike joins the pose's hook to its locked endpoint. Spore Ring has active spores and a subdued recovery scorch. The existing shared warning renderer supplies gold/red cone/capsule/circle warnings. Bright damage effects stop at `end_tick`, and parry/death/scene changes clear pending effects.
- 13 recorded foley remixes (wake, two steps, three tells, three strikes, two guard hits, guard break, death), registered with source hashes and processing in `presentation/audio/sources.json`. Rebuild with `python presentation/audio/build_warden_audio.py`. No new downloaded/generated recordings and no synthesized oscillators. Optional exposed hum and trial wave cues are not added. See the audio README for mapping and listening order.
- Foley uses two dedicated voices, below warning levels; an overlapping second voice is quieter. Gold/red warnings retain the existing cue pool and ducking. Strike audio follows a live core strike (including misses), never an unconfirmed delayed timer. Quiet footsteps play once per full walk cycle. Guarded hits select their own cue instead of armor_hit; perfect-parry audio remains intact.

## Review media

- `contact_sheet_runtime.png`: actual OpenGL renderer, attacks with windups, guard hit, exposure, death, both facings.
- `cleave_parry_exposed.gif`: 70 renderer samples at three core ticks/sample, encoded 50ms each; a real parry input causes core exposure and cancels the chain.
- Individual PNGs keep the original 1152x648 window output (384x216 at integer 3x). `loop_*.png` are the GIF source sequence. `build_media.py` rebuilds the package.
- [Sound preview](../../audio/warden_preview.wav): separated foley cues, in the audio README's order. Owner listening approval remains pending.

Reproduce captures:

```powershell
$env:TOTOY_SAVE_PATH = 'user://warden_capture_test_save.json'
& 'C:\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe' --path . --script res://tests/capture_warden.gd --quit-after 15000
python presentation/review/warden/build_media.py
```

These are **test encounters**, replacing the glade's Stag with a Warden in memory. The trial room, waves and rewards are not installed by this work. The fixture chooses the initial Ring attack index, periodically restores hero HP, directly applies guard/death test damage through core's hit function, and uses actual input for the parry. Attack timing, chain, guard, hit geometry, damage and exposure are all real core results, not painted snapshot states. The temporary glade objective/ribbon and victory reward belong to the fixture's host map. This is not a manual playthrough.

## Validation and limits

Verified Godot `4.7.2.stable.official.ed1daf0bf`. Source validation, atlas build and standard contact-sheet generation completed; atlas is 1024x8086, below 8192. Initial oversized atlas attempts failed; transparent trimming and replacing frozen ground PNGs with actual-geometry drawing solved this without editing Claude-owned tooling. No core/data/tools/harness changes.

`tests/test_warden_art.py`: 135 installed atlas frames exactly preserve reference opaque pixels in feet coordinates (60 enlarged bodies,75 attached FX); audio hashes/PCM format/peaks pass. `tests/smoke_warden_presentation.gd`: state/attack frame availability, current versus queued attack, idle clock, strike/death coverage, guard-hit pose protection, arbitrary geometry, active timing, cancellation, transition cleanup, rune glow and distinct audio routing/two-voice structure pass. Existing creature FX smoke also passes. `tests/capture_warden.gd` reports `WARDEN CAPTURE OK` for all three windups/strikes, successful parry exposure, guard/death and both facings.

Full validation: the harness's Python tests, Godot import and all52 headless smoke scripts pass. Its core run exceeded the initial90-second limit; the standalone core rerun at the standard300-second limit passed **554 tests,0 failed,exit0**. The9 focused Warden core cases also pass. Logs: `art/reference/warden_size_2p5/harness_normal_log.txt`, `core_300_log.txt`, `warden_core_log.txt`. The original short-timeout harness invocation exited1, so this result combines that harness's successful suites with the successful bounded core rerun. The first sandboxed attempt was stopped after denied log/save access. Contact-sheet cleanup also required ordinary filesystem access for generated .import files. Normal runs use only isolated test-save paths, never the owner's save.

The renderer exits with the existing single static OpenGL texture leak warning (5460 bytes); no capture script errors were reported. Headless sandbox runs report root-certificate/log permission errors; these do not establish a gameplay failure. Graphify query/update remain unavailable (`No module named graphify`).

Claude cross-review was requested read-only. The owner explicitly approved external Claude review after automatic approval review requested specific authorization, but the authenticated run failed: `OAuth session expired and could not be refreshed`. **Cross-review remains pending; no PASS is claimed.** Request text and failure output are retained here. Claude Code must be signed in before retrying.

Human-only judgement: appearance/readability on busy terrain, whether the enlarged silhouette and unchanged radius11 collision feel right, attack feel/balance, overlap in crowded waves, audio tone/mix and performance in the future trial. Body and physical blade are now 2.5x larger while gameplay geometry remains unchanged; the floor indicator is authoritative for damage reach. No range/collision/damage tweak was made to conceal this distinction. No listening or owner playtest approval is claimed.
