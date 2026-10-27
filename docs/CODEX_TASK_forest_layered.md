# Codex task: the layered forest route (2026-10-27)

> **Historical task — implementation completed in f70ad0f, followed by playtest fixes through ba1cc3b. Do not re-run this as unfinished work. The owner now requests a fresh glade arch/bush/path redo; read [CODEX_NEXT_SESSION.md](CODEX_NEXT_SESSION.md). Current JSON and Git history supersede the old counts/coordinates below.**

Claude finished the core/data side (see the newest `docs/STATUS.md` entry and `docs/architecture.md` "Layered scenes"). The owner APPROVED the forest ground and the prop sheet on 2026-10-27. Nothing here switches the chapter route.

## What exists

- Scene `forest_layered` (`SceneDefs.FOREST_LAYERED`, `data/scenes/forest_layered_props.json`, 480x288, 28 placements of 25 `forest_*` types in `data/props/prop_defs.json`). It mirrors the painted forest's route: entry `village_side` (left), entry `north` (behind the gate), exits `to_village` (left, to `village`/`return`) and `to_glade` (top, to `glade`/`entrance`), five interactions (`signpost`, `pedestal_west`, `pedestal_east`, `root_gate`, `chest`), checkpoints `forest_layered_entrance` and `forest_layered_puzzle`. Review image: `docs/previews/forest_layered_overlay.png` (gate closed) and `forest_layered_overlay_open.png` (gate open, pedestals lit).
- `ground` is `res://presentation/forest/forest_layered_ground.png`: **you create it** (below). Until it exists the scene has no floor.
- The cut-outs are in `data/props/cutouts_forest/` (extraction output; I kept it out of `art/` on purpose). Move or copy them into `art/reference/layered_forest/props/` if you prefer that place; the defs' `image` is only a file name.

## The two visual states (authoritative, from the core)

Two props change look with the scene state. Never derive them from lights or from your own flags:

| Prop id | Closed / off type | Open / on type | State |
|---|---|---|---|
| `root_gate` | `forest_gate_closed` | `forest_gate_open` | `snapshot.gate_open` |
| `pedestal_west` | `forest_pedestal` | `forest_pedestal_lit` | `&"pedestal_west" in snapshot.lit_switches` |
| `pedestal_east` | `forest_pedestal` | `forest_pedestal_lit` | `&"pedestal_east" in snapshot.lit_switches` |

- Build the placements WITH the state: `PropScene.placements(data, defs, {"gate_open": snapshot.gate_open, "lit": snapshot.lit_switches})`. The returned `type` is the one to draw (and `state` is `&"on"`/`&"off"` for these three). Rebuild `prop_placements` and call `_update_lighting()` when the state changes: on the `switch_lit` and `gate_changed` events (`GameEvent.SWITCH_LIT` = data `{scene, switch_id, lit, all_lit}`; `GATE_CHANGED` = `{scene, gate_open}`), when a scene is entered, and after the debug gate toggle (G / F6).
- Both types of a pair have the same canvas (pedestal 26x49, gate 124x87) and the same anchor, so swapping the type never moves a sprite. Keep it that way when you pad or clean them: one padded size and one header anchor per pair.
- The lit pedestal's teal light sockets go on `forest_pedestal_lit` only (`lamp_plan` reads the placement's resolved `type`). The gate's cyan root glints may get a socket on both gate types.
- The player lights a pedestal with E from its stand point (`ExploreCore`, `interact_pressed`); both lit opens the gate (`gate_open`, colliders swap in the core). The painted forest still has no puzzle: its E on a pedestal does nothing, as before.
- `SaveProfile.gate_open` is the only saved puzzle state (an open gate means both pedestals lit). Please save on the `gate_changed` event (the core now opens the gate by itself, not only the debug key).

## Your tasks (presentation/ and art/ only)

1. **Palette and ground.** Convert `art/reference/layered_forest/forest_ground_only.png` (1619x971) to Totoy 36 at **480x288** (hard pixels, no reserved gold/red) into `presentation/forest/forest_layered_ground.png` (a NEW file; keep the painted forest). Same conversion path as the village/glade grounds.
2. **Sprite cleanup.** Turn the 25 cut-outs into `art/src/forest_*.txt` (one per type, sizes in `prop_defs.json`; pad only top/left/right to multiples of 8 and never below the base; header `# anchor:` = the defs anchor, rounded to an integer where the parser needs it, and keep the exact shared anchor in your import manifest as for the village). Pairs: ONE padded size and anchor for `forest_pedestal`/`forest_pedestal_lit` and for `forest_gate_closed`/`forest_gate_open`. Do not paint over the gate's open walkway or move the trunks. Sources are generated art, not validated: tell me about any silhouette the palette snap damages.
3. **Prop art data.** Extend `presentation/common/prop_art.json` (trim, contact shadows, cast masks) for the 25 types, as for the village.
4. **Draw it.** `explore_scene.gd` already treats `SceneDefs.LAYERED` scenes generically; add the state-aware placements above, the fireflies and lighting for `forest_layered` (already in your `supports` lists), and make sure the chest, door and pedestals are props (no second sprite).
5. **Lighting sockets.** `presentation/common/local_lights.json`: teal sockets for `forest_pedestal_lit`, the standing stone's runes, the open/closed gate glints, the lantern post's warm light (`forest_lantern_post`), glowing flowers if wanted. Max 16 light entries per scene (a `push_warning` when `lamp_plan` drops one would help).
6. **Debug.** A debug jump key for `forest_layered` (F-key and number row, as 5/6/7) in `input_bindings.gd` and `DEBUG_SCENES`; G / F6 keeps toggling the gate (the core lights/unlights the pedestals with it).
7. **Smoke test and captures.** A smoke test: load `forest_layered`, light the west pedestal (sprite changes, gate stays), light the east (gate sprite changes to open and the gate stops blocking), walk through the gate to the glade exit, talk to the signpost, open-state saved. Review captures: hero behind and in front of the gate (closed and open), both pedestals unlit/lit, the three trees, the log, the chest.

## Review findings from Claude on aad352e and 96177a8 (none blocking)

See the newest `docs/STATUS.md` entry. Short: `smoke_night_ambience.gd` uses `assert()` (a failure hangs until the harness timeout instead of exiting 1), the painted glade's four fixture positions are hard-coded in `environment_light.gd`, and the shadow-pass alpha constants from the earlier review are still implicit.

## Open items for the owner (not Codex)

- (Done 2026-10-27: approved.) The forest ground and prop sheet are approved production sources. The sheet's single signpost board (the prompt asked for two arrow boards) and the third fern slot that reads as a small bush are findings, not approved substitutions.
- The gate is 124 px wide against a 50 px trail; it stands across the climb with its trunks on the grass beside it. Say if the gate should be narrower (that is a new generation, or a smaller scale for this prop).

## Final capture for the middle tree (2026-10-27, after your f70ad0f)

`tree_middle` now stands at feet (252,108) and the outline opened a pocket behind its trunk. Capture the hero **behind** it at feet **(248,88)**: `ExploreBot.plan(size, obstacles, hero position, Vector2(248, 88))` reaches it (`tests/core/test_forest_layered.gd::test_the_middle_tree_has_a_reachable_behind_pose` does exactly that); the tree covers 90 % or more of his body there. Remove the "upper boundary prevents walking behind this tree" exception in `tests/smoke_forest_layered.gd` and use this pose for `tree_middle`. Re-take the lit/open and closed variants of that one capture and the overview images (the tree moved 16 px south).
