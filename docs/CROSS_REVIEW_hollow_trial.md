# Cross-review: Codex's Hollow Trial presentation (Claude, 2026-10-31)

Reviewed: `3ef88a54` (editable visual scene, props, registration handoff) and `9357f236` (runtime wiring, altar chest, core-driven trial cues), against the core contract in `docs/architecture.md` "Trial rooms". **Verdict: PASS, with four fixes requested (P2) and four small notes (P3).** None blocks play; the P2s matter for readability and for the owner's goal of editing the room in Godot.

## What I ran

- `bake_maps.gd` over `presentation/maps/`: **Codex's `hollow_trial_layered.tscn` bakes back byte for byte** to `data/scenes/hollow_trial_layered_props.json` (and the glade spike too). The editable scene and the core data agree.
- `presentation/review/hollow_trial/check_scene.gd` and `check_gameplay.gd`, headless: both pass (`HOLLOW TRIAL SCENE OK`, `HOLLOW TRIAL GAMEPLAY PRESENTATION OK`).
- `python tools/art/validate_art.py`: 3691 sources, 3695 PNGs pass.
- Core suite 568 pass; Python tests and the map/prop round trips pass; `smoke_profile` and `smoke_variant_atlases` pass on the committed atlas.
- Looked at Codex's real gameplay captures in `presentation/review/hollow_trial/` (`game_*.png`).

## Interface and rules boundary: correct

- Reads only the contract: `ExploreSnapshot.trial` (state, wave, waves, alive, sealed), the `trial_*` events, `trial_spawn_warned.positions/arrive_tick`, `mob_alerted.position`, the story flags for the altar and chest. No mob, wave, timer, flag, hit area or reward is invented in presentation (checked `trial_scene_fx.gd`, `trial_scene_art.gd`, the `explore_scene.gd` hooks).
- Prop states go through `PropScene.placements` with the `trial` tag, the same rule the core uses for colliders. The entry roots refresh when `sealed` changes.
- HUD objective and hints follow the trial state; the chest hint appears only after a win and disappears once it is opened; "FINAL WAVE" uses the event's `waves`.
- Warning drawing (gold/red) is unchanged; spawn marks are separate and end at `arrive_tick`.

## Fixes requested (P2)

1. **Hard-coded altar position.** `TrialArt.draw_ring(self, Vector2(256,180), ...)` (`explore_scene.gd:852`), the activation/clear pulses (`trial_scene_fx.gd:60`) and the progress segments (`draw_altar_progress`, `Rect2(245+i*10,170,...)`) assume the altar at (256,180). The owner's goal is to move things in the Godot scene; if the altar moves, these stay behind. Read the altar's feet from the `trial_altar` placement (or the `altar` object) instead.
2. **The decorative rune ring reads like an indicator.** In play (`game_spawn_warning.png`, `game_wave2_warden_boars.png`) the code-drawn ellipse of dark-blue squares hugs the hero at the altar and looks like a warning or a selection ring, and it floats as a perfect geometric ellipse over the painted dirt. Make it part of the ground art (worn, broken flagstones painted into the floor) or much quieter (ground colours, irregular, no blue), so nothing but real warnings looks like a ring around the player.
3. **Contrast: the Boar disappears on the floor.** In `game_wave2_warden_boars.png` the Boar on the left is dark-on-dark and barely readable; this is the owner's review item 6, confirmed in a real capture. Lighten the floor a step, add a soft light pool from the altar and rim rocks over the fight floor, or a slightly stronger actor rim/contact shadow in this scene.
4. **Blocky shadow artifact near the top edge.** In `game_wave2_warden_boars.png`, top-left around the Boar's red marker, a magnified, chunky copy of a rim rock is drawn (blocks of about 3 world px, coloured, not a clean shadow). Likely `TrialArt.draw_floor`'s projected local-light shadow (the `LocalShadow.plan` transform scaling the silhouette) or its colour tag missing the shadow pass. Reproduce with the wave-2 capture and check those transforms.

## Notes (P3)

1. `hint_text()` shows "[E] BEGIN TRIAL" without checking `snapshot.armed`; the core refuses an unarmed hero. Unreachable today (the room is behind a cleared fight), but cheap to match.
2. `TrialArt.visual_placements` overrides the anchor and size of non-solid `hollow_trial_*` props from the atlas. Since the catalogue was resynced (`c8b9c801`, chest 40x64, anchor 20,64) the override is redundant; drop it so the drawing has one source.
3. Arrival pulses key off every `mob_alerted` in the room. Fine today (only trial mobs live there); if the room ever gets ambient mobs, filter by the trial encounter.
4. `game_chest_open_reward.png` shows a number ("…000") cut behind the level badge. It looks like an existing HUD readout rather than the trial; worth a look in the HUD pass.

## Cannot judge

The look and feel, whether crowded waves stay readable at full speed, the reused sounds, and whether the trial is hard but fair: these are the owner's call after a real playthrough. The gameplay check restores HP and uses lethal hits to speed up clears, so it proves the wiring, not the balance.
