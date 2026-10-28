# Codex task: make the Woodland Approach playable and draw its mobs (2026-10-28)

Claude finished the core and shared-data side (commit after `00840ff`). Read `docs/architecture.md` "Chapter route, mobs and encounters" first: it is the contract. Stay in `presentation/`, `art/` and your tests. Do not change the approved art. Never merge to main.

## What is already live in the core

- Scene `woodland_layered` (`SceneDefs.WOODLAND_LAYERED`, `data/scenes/woodland_layered_props.json`): route village -> woodland -> forest, entries `west` and `east`, checkpoints `woodland_layered_west/_east`, walkable outline from the approved ground, 31 props with real base colliders (`data/props/prop_defs_woodland.json`, merged by `PropScene.load_defs`), three encounters (3 Mosslings west, 2 Boars east, 2 Mosslings at the camp), both clearings and the camp loop checked open (`tests/core/test_woodland.gd`).
- The painted village/forest/glade are gone from the core. `SceneDefs.IDS` is `[arena]`; use `SceneDefs.ALL` or `LAYERED`. Saves that name a painted id are migrated.
- Mobs, herbs and defeat: `core/mob_field.gd`, `core/mob.gd`, `Tuning.MOBS`; contract and numbers in the architecture section.

## Your jobs, in order

1. **Register the scene in the renderer.** Ground from the scene data; the forest `EnvironmentLight` and fireflies for `woodland_layered`; ambience and music in `village_audio.gd` `set_scene`; a debug jump key; title/Continue must work (a woodland checkpoint is a valid save). The three scene edges: village east exit leads here, this scene's east exit leads to the forest, the forest's west exit returns here.
2. **Production prop art.** Merge `art/reference/woodland_approach_v1/review_prop_art.json` (and the 24 shadow masks) into `presentation/common/prop_art.json` and the shadow manifest so `PropScene.placements` + `PropsLayer` draw the scene without the `art_overrides` of the review renderer. The types now exist in the shared catalogue; their `anchor`, `w`, `h` equal your review defs, only `solid` and `colliders` are new. If an anchor must move for the art, tell Claude (the colliders are relative to it). Retire the review-only scene id `woodland_approach_review` and its local defs when done.
3. **Fight in exploration.** An armed hero fights in any scene that has encounters, so presentation must send `attack_pressed`, `attack_held`, `parry_pressed` and `aim` in every exploration scene (as `Bindings.read_frame` does), plus the new `use_herb_pressed` (suggest F; menu use is later). `ExploreSnapshot.defeated` is true while he is down: show your fade, then simply keep stepping; the core stands him up at the checkpoint (`hero_respawned`), no reload.
4. **Draw the mobs.** `snapshot.mobs` (position, facing, state, state_ticks, hp/max_hp, exposed, since_hit) and the lines in `snapshot.telegraphs` (gold = parry, red = dash; `shape` line, `center`, `direction`, `size`, `width`, `hit_tick`). Art needed: `mossling` (small moss creature) and `boar` (Thornback Boar) frames for idle, alert, chase/walk, windup, strike, recover, crash/stagger (exposed), hurt and dead; one facing, mirrored. States: `idle alert chase windup strike recover crash stagger hurt return dead`. Hit flash on `attack_hit` (target_id is the mob), counter sparks when `kind` is `counter`, the parry spark on `parry_succeeded` (attacker_id is the mob), a small health bar only for mobs below full health, a clear mark for `exposed`, the dead animation over `MOB_DEATH_TICKS` (40). Reuse the fight's warning drawing for the line. `encounters` gives the state per group if you want a "cleared" cue.
5. **Items and saves.** Keep `profile.inventory` in sync: restore with `core.set_inventory(profile.inventory)` on every core and save on `item_received` and `item_used`; `cleared_<id>` flags already travel with `story_flags` (save on `flag_set`). Map `item_id` `herb` to an icon for the receipt popup (reward ids `mossling_clearing_herbs`, `boar_clearing_herbs`, `camp_ambush_herbs`); show a herb count in the HUD.
6. **Sound and effects** from the events: `encounter_started`/`mob_alerted`, `attack_telegraphed` (kind gold/red), `attack_hit`, `mob_staggered`, `mob_defeated`, `encounter_cleared`, `item_used`, `hero_defeated`, `hero_respawned`.
7. **Tests and captures.** A woodland smoke (load, walk both ends, wake the west pack, a parry, clear it, the receipt popup once, Continue after clearing shows no mobs), update `smoke_woodland_blockout.gd` (the review-only renderer), and review captures of both clearings and the camp at gameplay scale with mobs and warnings. Run the full harness.

## Please tell Claude if

- a mob needs a state or snapshot field that is missing, the warning line does not match what the art shows, or a prop base blocks where the sprite looks walkable (the colliders are tuned from the sprite's lowest rows; the owner judges).
- the clearings feel too small with real mob sprites: the free ground is 85 % of the reserved 180x112 rectangles and a 160x100 box fits (`test_woodland.gd`); the outline reaches a few pixels past the painted dirt into the bush fringe to get there.

## Not judged by Claude

How the fights feel (numbers are first guesses in `Tuning.MOBS`), the pacing of the woodland, mob and prop art, the sounds, whether herbs are the right reward.

## Two smokes still assume the old route (the only failures of the full harness)

- `tests/smoke_explore_bot.gd`: the walking bot goes village -> forest -> glade and back. The route now has the woodland between village and forest (village east exit -> woodland `west`; woodland `to_forest` -> forest `village_side`; forest `to_village` -> woodland `east`; woodland `to_village` -> village `return`). Add the two woodland hops.
- `tests/smoke_layered_scenes.gd`: "East exit requests forest" must expect `woodland_layered`.
Everything else passes (Python, import, core 430+, every other smoke).
