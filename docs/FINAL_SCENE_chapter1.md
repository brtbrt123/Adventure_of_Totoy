# Chapter 1 final scene and boss (PLAN, draft)

Status: **draft for the owner** (2026-11-03, Claude). The owner: "we will create the finals scene with a boss matching our story
we will not use the arena that we have make a draft or plan on this first then after we will fix the story line and nariation".
So: this plan comes first; the road story (`docs/STORY_ROAD_chapter1.md`) and its narration are revised after it.
Nothing here is built. Words marked **(new)** are proposals the owner renames freely.

## Where it sits in the chapter

Lanternfen -> Woodland Approach -> Forest Route -> Root Hollow (-> Hollow Trial, optional) -> Stag Glade -> **the final scene** ->
ending. The Stag Glade's root arch, which today leads to the old arena (`glade_layered` exit `to_arena`), leads here instead.

## The story it has to finish

From the road draft: the blue light is the **forest beacon's song**. When the beacon went dark the song fled into living hearts;
the Stag held one thread of it, and Edda bound it into Totoy's cracked key. The rest of the song is caught in the roots of the
ruins, where something huge sleeps. GAME_DESIGN gives chapter 1 its world change: **the forest beacon is restored and the paths
through the briars open**, and its boss: the **Mossbound Colossus**, one of the six guardians, twisted by a failure of the valley.

The twist that fits both: **the Colossus is not guarding the beacon from Totoy. It is holding the song so it cannot leave.** When
the Heartloom failed, the forest's guardian wrapped its roots round the dying beacon and would not let go; the holding is what keeps
the beacon dark. Beating it means making it let go, not killing it (Edda's rule: bind without destroying what remains). This also
seeds the chapter 6 question (a guardian holding on too hard; the Regent's choice) without telling it.

## The scene: Beacon Hill **(new name)**

| | |
|---|---|
| Place | Past the glade's root arch: an old stone stair climbs a hill to the forest beacon, a dark stone lantern-tower wrapped in roots as thick as houses. |
| Size | About 640x384 at the game's scale (a little bigger than the glade, 560x336): a short approach path, then an open fight floor on the hilltop. |
| Floor | One open ring for the fight (no pillars to snag the boss, the old arena's problem), roots and broken stones at its edge as the wall, the beacon at the top as the backdrop. |
| Art | A layered scene like the others (one floor painting + separate props): the owner's images, converted with the existing pipeline (`tools/art/extract_props.py`, the shadow and light tools). |
| Light | Night; the beacon dark until the end; the key's blue and the song's blue in the boss's cracks; the lighting tools from today (stone glow, lamp shadows). |

## The boss: three options

| | A. Mossbound Colossus, new home (**recommended**) | B. A new boss | C. Colossus, arena mode, new map |
|---|---|---|---|
| Who | The existing Colossus, recast as the forest's guardian holding the song | Something new built for this story (e.g. the beacon's roots themselves come alive) | The existing Colossus |
| Story fit | Good: GAME_DESIGN's own chapter 1 boss, with the twist above | Best, but it leaves GAME_DESIGN's chapter 1 boss behind | Good |
| Fight | Its 6 attacks kept (gold slam, gold combo: parry; red sweep, red shards, red stomp, red charge: dodge), posture break and counter, phase 2 at half health | All new attacks under the gold/red rule | Unchanged |
| Engine | Moved into the road's fight engine (`core/mob_field.gd`, like the Stag and the Warden): same HUD, TAB menu, checkpoints and herbs as the road, **and the stat points count** | Road engine | Stays in the separate arena mode: its own HUD and menu, base stats, a separate result screen |
| Art | Exists (its body frames and effects) | All new: body, every attack, effects (the biggest job) | Exists; only the new map |
| Work | Medium: port the boss into the road engine (core) and draw it in the road renderer (presentation) | Large | Small, but it keeps the split the owner wants to leave |

## The beats (draft; the narration gets fixed after this plan)

1. **The climb.** Narration: the hill, the dark beacon, the roots that breathe. The key hums louder at every step.
2. **The entrance** (short cutscene: camera pan up the hill, title card **MOSSBOUND COLOSSUS / GUARDIAN OF THE FOREST BEACON**).
   The roots part; the Colossus rises from them, the song's blue showing through its cracks.
3. **Phase 1.** Gold slam, red sweep, red shards: the chapter's colour lessons, one at a time.
4. **Phase shift at half health** (a short moment, no long cutscene): it tears a root from the hill; the blue flares; Totoy's key
   answers. Phase 2 adds the gold combo, the red stomp and the red charge.
5. **It lets go.** Posture broken for the last time, the Colossus kneels (like the Stag). The song pours out of its roots, along
   Totoy's key, into the beacon.
6. **The beacon lights.** Blue-white fire on the hilltop; the briars around the hill draw back (the chapter's world change).
   The Colossus settles into the hill as moss and stone, the beacon burning on its back (freed, not destroyed: the owner's call).
7. **The memory.** One image, no dialogue (CHAPTER1_PLAN step 7): a second piece of the night the Heartloom failed.
8. **Home.** Back in Lanternfen: one of the dark hills now answers; Mira marks the next region (Tides). Credits; the title screen
   shows "Chapter 1 complete".

## Build plan (after the owner chooses A, B or C)

| Step | What | Who (AGENTS.md split; Claude covers presentation while Codex is out) |
|---|---|---|
| 1 | The owner's images for Beacon Hill (floor painting and props; the beacon dark and lit) | owner (image generation, Claude writes the prompts) |
| 2 | The layered scene: conversion, props, colliders, entry from the glade, checkpoint at the foot of the hill | Claude (tools, core data) + presentation |
| 3 | The boss in the road engine (option A): attack table, telegraphs, posture break and counter window, phase 2, Reaper's Coil drag and stun, deterministic core tests | Claude (core) |
| 4 | Drawing it in the road renderer: its frames, attack effects and the boss panel (reuse `boss_panel.tscn`) | presentation |
| 5 | Story moments: the climb narration, the entrance card, the phase-shift moment, the letting-go, the beacon lighting, the memory image, the return home | presentation + data (cutscene and dialogue files) |
| 6 | Retire the old arena from the story path (the title's BOSS FIGHT mode: keep or remove, the owner's call) | presentation |
| 7 | Tests, in-game captures, the owner's playtest | all |

## Questions for the owner

1. **A, B or C?** (Recommended: A, the Colossus in its new home, run by the road engine.)
2. **The guardian's fate**: freed and settling into the hill (as drafted), or destroyed?
3. **The scene's name**: Beacon Hill, or another.
4. **The old arena**: remove it entirely, or keep it only as the title screen's BOSS FIGHT practice mode.
5. **What the second memory shows** (step 7), so the road's first memory can lead into it.
