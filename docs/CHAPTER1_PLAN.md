# Chapter 1 plan: Roots (the ten-minute forest chapter)

Status: DRAFT for the human's approval. Based on `docs/GAME_DESIGN.md` (human-owned; this plan follows it and invents only
what it says is new). Names marked **(new)** are proposals the human can rename.

## Goal

A complete, playable slice of about ten minutes: begin in Lanternfen, learn dash and parry on the way, win one Aspect,
beat the Mossbound Colossus, restore the forest beacon, see an ending and credits. Everything built here is reused by
chapters 2-6.

## Story beats

1. **Arrival (Lanternfen, evening).** Totoy returns holding a broken beacon key, remembering nothing of the night the
   Heartloom failed. Five of the six beacons on the hills are dark; one glows weakly. Mira (mapmaker) meets him at the
   gate, recognises the key, and says the forest beacon song is the nearest one. Short conversation, no choices.
2. **The smithy.** Tovan hands Totoy a worn Black Katana (the player already owns it) and shows the dash. Totoy can
   test dash and the sword on a training post. Optional: talk to Edda.
3. **Edda's lesson.** Edda explains Aspects: a monster fragment can be bound into a skill slot "without destroying what
   remains of it". She asks Totoy to find the Thornback Stag in the forest, whose fragment is calm enough to bind.
   (Gives the player the character menu tutorial: open TAB, equip an Aspect.)
4. **Forest route.** Three short rooms. Mossling and Thornback Boar teach the combat language: gold = parry, red = dash.
   A small puzzle (light two lanterns to open a root gate). A side path hides a chest with a heal item.
5. **Mini-boss: Thornback Stag (new).** A corrupted guardian animal. Totoy wins, Edda's binding scene plays, the player
   receives the Sprint Aspect (or another, see open questions). A short cutscene: the stag's antlers glow like the
   beacon colour. Mira's voice over: the Colossus waits beyond.
6. **Boss: Mossbound Colossus.** Entrance cutscene (roots break, the camera pans to the golem, title card). The existing
   arena fight with its phase shift. Victory aftermath.
7. **Beacon restored.** The forest beacon lights, briars open, a path to the next chapter appears. Totoy hears the
   first beacon song and a fragment of memory (one image, no dialogue). Return to Lanternfen: Mira marks the next map
   region (Tides). Credits roll; the title screen shows a "Chapter 1 complete" mark.

## Scenes (each is a Godot scene with a camera following the player, 320x180 view)

| # | Scene | World size | Contents |
|---|---|---|---|
| S1 | Lanternfen village | 571x336 (see S1 notes) | Gate, Mira, smithy (Tovan), Edda's hut, training post, 2-3 villagers (flavour), beacon hill view, exits to the forest |
| S2+S3 | Forest route (one scene, see notes) | 480x288 (scale 0.6) | First clearing: Mossling x3, a signpost, first parry lesson; second clearing: Thornback Boar x2, glowmoths; lantern puzzle and root gate, chest |
| S4 | Stag glade | 560x336 (scale 0.7, see notes) | Mini-boss arena (open clearing) |
| S5 | Colossus ruins (existing arena) | 800x480 | Already built; add entrance and exit |
| S6 | Beacon epilogue | one screen | Beacon lighting, memory image, then credits |

**S1 notes (2026-10-21, rescaled 2026-10-22, review stage).** The village is the owner's painting
`art/reference/lanternfen_village_target.png` converted to the palette (`tools/art/make_village_ground_from_reference.py`
-> `presentation/village/village_ground.png`) at **scale 0.7: 571x336** (about 1.8 x 1.9 camera views; the human chose 0.7
on 2026-10-22 because at 816x480 the characters looked tiny next to the buildings, see
`docs/previews/village_scale_options.png`). Layout, spawns and colliders: `core/village_layout.gd` (constants at 0.7;
`build_scaled(s)` for other scales). Totoy arrives through the rune gate on the west side (arrival spawn 120,199; gate
opening 117,183) and leaves for the forest along the east road (exit at the right edge, 567,218, +/- 18 px; return spawn
546,218). Stand points: Mira by the gate (144,206), Tovan at the anvil (316,129), Edda beside her house door (452,165;
doorway 435,155), elder by the shrine (172,286), child on the crossroads (253,210), worker by the crates (337,235), the
training post (328,148, painted, solid), the chest on the west lawn (112,246). The south path is closed for now (a
possible second exit). Actors in the scene: the arena's ground shadow under every person and a per-scene ambient tint
constant on the actors (the review mock uses `Color(0.93, 0.89, 0.84)`, see `tests/capture_village_review.gd`). Review
images: `docs/previews/village_*.png`.

**S2+S3 and S4 notes (2026-10-22, final scales).** S2 and S3 are merged into ONE forest route scene. Both scenes are the owner's paintings (`art/reference/forest_route_target.png`, `stag_glade_target.png`) converted to the palette by `tools/art/make_forest_ground_from_reference.py` at the human's chosen scales (after `docs/previews/forest_scale_options.png` and `glade_scale_options.png`): **forest 0.6 = 480x288** (`presentation/forest/forest_route_ground.png`), **glade 0.7 = 560x336** (`stag_glade_ground.png`); the characters keep their pixel size. Layouts: `core/forest_layout.gd`, `core/glade_layout.gd` (`SCALE`, `*_1X` tables measured on the 800x480 painting, plain constants at the game scale, `build_scaled(s)` for others; shared edge helper `core/scene_bounds.gd`). Positions below are at the game scales. Forest: entry at the left edge (trigger x 0..7, y 144..179; arrival 14,161). **The exit is behind the lantern puzzle** (the human's decision): the painted path behind the root gate leaves at the top edge (trigger x 367..410, y 0..10; point 388,8), reachable only when lighting both pedestals opens the gate (`build_with_gate(true)`). A short trail east past the second pedestal is a **dead end** with the chest (farthest walkable spot 444,194); the right edge is sealed. Mosslings 102,157 / 139,134 / 151,178 (first clearing), Boars 237,199 / 294,207 and Glowmoths 264,169 / 351,148 (second clearing); signpost 149,112 (stand 157,126), lantern pedestals (puzzle switches, painted UNLIT) 307,145 (stand 308,157) and 382,168 (stand 378,181), root gate (door) 377,114 (stand 358,127), chest 413,235 (stand 413,198); checkpoints 24,161 and 336,180. Glade: entry at the left edge on the bottom-left trail (trigger x 0..8, y 288..336; player start 25,312; checkpoint 42,308), exit inside the root arch (trigger x 423..449, y 73..87; point 436,81), Stag start 410,168 (across the ring), spring 312,176 (decor, walkable). Only two standing stones are solid (the "2" rune stone at the back and the right rune stone, radius 5 each): with all five solid the Stag (radius 20, not scaled) could reach only 68.9 % of the fight area at 0.7; now 83.4 %. Actors need the arena's ground shadow and a per-scene ambient tint to sit in the paintings (see `docs/STATUS.md`). Review images: `docs/previews/forest_*.png`, `glade_*.png`.

Scene transitions: edge doors with a short fade; the save records the last checkpoint (village gate, glade entrance,
ruins gate).

## NPCs

| NPC | Where | Role | Notes |
|---|---|---|---|
| **Mira**, mapmaker | S1 gate, S6 | Story guide, quest log voice | Shows the map; marks objectives |
| **Tovan**, smith | S1 smithy | Weapons, hints, a training post | Lets the player view weapons (inventory) |
| **Edda**, Aspect keeper | S1 hut, S4 | Aspect lesson and binding scene | Teaches the equip flow |
| Villager 1-3 (new) | S1 | Flavour, a hint about the forest | One has a small errand (optional) |

Dialogue box needs: portrait, name, typewriter text, ENTER to advance, skippable; line count budget about 60 lines total.

## Mobs

All mobs are readable with the gold/red rule; each has at most two attacks.

| Mob | Scenes | HP / size | Attacks and tells | Teaches |
|---|---|---|---|---|
| **Mossling** (new) | S2 | low, small | Gold lunge (parry) after a short crouch | The gold parry |
| **Thornback Boar** (new) | S3 | medium | Red charge in a straight line (dash through it) | The red dodge |
| **Glowmoth** (new) | S3 | tiny | Slow floating shots with a red warning ring | Spacing and dash |
| **Thornback Stag** (mini-boss, new) | S4 | high | Gold antler slam, red charge, a short second phase (roots) | Combines both |
| **Mossbound Colossus** | S5 | boss | Existing attacks | The final exam |

Mob core needs: a generic `Enemy` entity (state machine, telegraph, hit/posture) in `core/`, with the boss reusing the
same rules where possible; several enemies on screen; drops (herb heals).

## Items and progression (kept very small)

- **Herb** (heal), dropped by mobs and found in chests, used from a quick slot (key F or the menu).
- **Forest Beacon Shard**, a story item (non-usable), shown in the inventory after the boss.
- Aspect rewards: Sprint from the Stag (proposal); Echo Step and Stone Ward unlocked as chests or at Edda; the five
  existing aspects are already owned. (Open question below.)
- Weapons: the three existing ones are all available from the start for the slice, or unlocked at Tovan (open question).

## Systems to build (in order), with the owner under the current Codex-limit arrangement

| # | System | Layer | Notes |
|---|---|---|---|
| 1 | Scene manager, transitions, checkpoints, save of chapter state | core + presentation | **Done 2026-10-22** (with the walking of step 2): `core/scene_defs.gd`, `core/explore_core.gd`, `SaveProfile.scene_id/checkpoint_id/gate_open` (optional fields, no version bump needed) |
| 2 | Player exploration mode: walking in non-combat scenes, interact key (E), no boss | core + presentation | **Walking done 2026-10-22** (`presentation/explore/`): E emits `interact` and shows a `...` bubble; dialogue is step 3 |
| 3 | Dialogue system and NPCs | presentation (+ tiny core state for flags) | Data-driven dialogue files in `data/` |
| 4 | Generic enemies and AI (Mossling, Boar, Glowmoth) | core + art | Telegraph, hit, posture, drops |
| 5 | Level scenes S1-S4 (tilemaps, props, colliders, doors, lantern puzzle) | art + presentation | Same ground pipeline as the arena (paintings converted to the Totoy palette, colliders overlaid) |
| 6 | Mini-boss Stag | core + art | Reuses enemy and boss machinery |
| 7 | Cutscenes (entrance, binding, beacon, credits) | presentation | Simple scripted camera/dialogue timelines |
| 8 | Quest log and objective markers | presentation + core flags | One line "current objective" is enough for the slice |
| 9 | Polish: music/ambient, sound pass, balance, controller, playtest | all | |

## Milestones and acceptance

- **M1 Walkable village:** S1 with Mira, Tovan, Edda talking; transition to a stub forest scene and back; checkpoints saved.
- **M2 Combat tutorial:** S2 with Mosslings and the parry lesson; S3 with Boars and Glowmoths; mobs fully readable.
- **M3 Mini-boss and Aspect:** S4 Stag fight, binding cutscene, the Aspect appears in the menu and works.
- **M4 Boss integration:** Colossus entrance/exit, ending, credits, "Chapter 1 complete" mark on the title.
- **M5 Slice polish:** audio pass, balance, playtest with 3+ people, a short gameplay video for the case study.
- Each milestone is playable on its own and ends with a green test run, a commit and a push.

## Testing

Core: new unit tests for enemies, drops, save format, dialogue flags, checkpoints; mutation checks for the rules.
Presentation: smoke tests per scene (loads, camera, transitions, NPC interaction, dialogue skip), a full headless
"play-through" bot test of S1-S5 with scripted input (reaches the credits), plus captures reviewed by the human.

## Open questions for the human

1. Which Aspect does the Stag give: Sprint (proposal), Echo Step or Stone Ward?
2. Are all three weapons available from the start, or do Tovan or chests unlock them during the chapter?
3. Healing: herbs in a quick slot, a checkpoint refill only, or both?
4. Should Lanternfen already have a few shop/quest interactions, or stay a pure story hub for the slice?
5. Music: do you have tracks, or should the slice use original placeholders/silence?
6. Are the proposed mob and mini-boss names fine, or do you want the creature concepts first (art-first, as with the
   weapons)?
