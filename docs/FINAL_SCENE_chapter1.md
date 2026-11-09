# Chapter 1 final scene and boss (PLAN, v2)

Status: **plan with the owner's decisions** (2026-11-03, Claude). History: v1 offered three boss options; the owner chose:
"lets go with the mossbound collosal we will just improve the design make it bigger, improve the effects, add more attacks
we will also make the new scene or map taht match our story", and answered the questions: "the guardian is destryoed", the
scene name and the second memory are Claude's to propose, the old arena: "keep it for now". After this plan the road story and
narration (`docs/STORY_ROAD_chapter1.md`) are revised to lead into it. Pictures come before wiring.

Progress: step 1 done (both concept pictures approved 2026-11-09: "Approve both"); step 2 done as a scene (owner: "Approve, build it"):
the map `rootcrown_layered` is in the game, reached only by debug key **Y** until the boss lives there (the glade's arch still leads
to the old arena, so the story never reaches a map without a fight). **The owner played it and rejected it** (2026-11-09):
"i dont like the looks since it doesnt match our other scene and the stage is too small". Next: redo step 2 (see "Redo after the
playtest" below, pictures first), then step 3, the boss in the road engine.

## Decisions

| Question | Answer |
|---|---|
| Boss | The **Mossbound Colossus**, redesigned: bigger body, better effects, more attacks |
| Engine | Option A: it fights in the road's fight engine (like the Stag and the Warden): same HUD, TAB menu, herbs, checkpoints, and the stat points count |
| Scene | A new layered map that matches the story (name below) |
| The guardian's fate | **Destroyed** |
| The old arena | Kept for now (the title screen's BOSS FIGHT practice mode); out of the story |
| Scene name, second memory | Proposed below (the owner can rename) |

## The scene: ROOTCROWN (proposed name)

The forest beacon's hill, where the Colossus's roots have grown over the beacon tower like a crown. "Roots" is the chapter's
name, the roots hold the song, and the name says both. The scene banner reads **ROOTCROWN**.

| | |
|---|---|
| Way in | The Stag Glade's root arch opens onto a stone stair that climbs the hill (the glade's exit `to_arena` points here once the boss lives here) |
| Layout | South: the stair and a small landing (checkpoint). North: the open hilltop ring, about 300x180 px of clear floor, no pillars (the old arena's boss snagged on them). Around the ring: a wall of roots and broken stones. At the top: the beacon tower, dark, wrapped in roots. |
| Size | 640x360 as built (the glade is 560x336) |
| Night | Moonlight; the song's blue leaking from the roots and the Colossus's cracks; the beacon dark until the end, then blue-white |
| Props | the beacon tower (dark, lit), root walls (pieces), broken standing stones, rubble, roots, a few dead lanterns on the stair, thorn briars round the edge (before and after they draw back) |
| Art | The owner's images, generated and converted like the other layered scenes; prompts at the end of this page |

## The Colossus, redesigned

| | Now | Proposed |
|---|---|---|
| Size | 48x48 frames, a 20 px body (smaller than the Stag's 96x64) | **About 3x: 144x144 frames, a 46 px body**: two thirds of the screen's height, three and a half times Totoy |
| Look | moss golem | A hill of mossy stone on legs of root; its chest is a cracked hollow where the stolen song burns blue; roots trail from its back into the ground (and, at the start, into the beacon) |
| Phases | 2 (phase 2 at half health) | **3**: 100-60 %, 60-25 %, under 25 % (the song tears loose) |
| Attacks | 6 | **11**: the 6 kept and 5 new, below |
| Effects | small sprite effects | stone chunks and dust, root tearing, ground cracks, blue light leaking from cracks (real lights, like the lamps), shockwave rings, screen shake, the old effects redrawn in the staff style of the hero effects redo |

### The attacks (gold = parry it, red = dodge it)

| # | Attack | Colour | What it does | Phase |
|---|---|---|---|---|
| 1 | Gold Slam (kept) | gold | overhead fist into the ground in front | 1, 2, 3 |
| 2 | Red Sweep (kept) | red | wide arm swing, a cone | 1, 2, 3 |
| 3 | Red Shards (kept) | red | stone shards in three lanes | 1, 2, 3 |
| 4 | Red Stomp (kept) | red | a ring round its feet (stand inside the gap or far out) | 1, 2, 3 |
| 5 | Gold Combo (kept) | gold | two blows then a third, each parryable | 2, 3 |
| 6 | Red Charge (kept) | red | a straight rush across the ring | 2, 3 |
| 7 | **Root Snare** (new) | red | roots burst from the ground in a line toward Totoy, then a second line where he dodged to | 1, 2, 3 |
| 8 | **Boulder Toss** (new) | red | tears a stone from the hill and throws it at where Totoy stands; it lands with a small shockwave | 2, 3 |
| 9 | **Heartroot Grab** (new) | gold | a root-arm lunges to seize Totoy; parried, the arm snaps back and its posture cracks wide | 2, 3 |
| 10 | **Briar Ring** (new, once per phase change) | red | thorns rise round the edge of the ring, the floor shrinks for a while; telegraphed before they rise | 2, 3 |
| 11 | **Song Flare** (new, phase 3) | red then gold | the blue song bursts out in waves (dash through), and the last wave is a gold blow that can be parried for the final posture break | 3 |

Every attack keeps the game's rules: a readable windup, gold or red, at most two things to watch at once, nothing from off screen.
Numbers (damage, timings, health, posture) go in `core/tuning.gd` and are the owner's to tune after the first playtest.

## The beats (draft; the narration is rewritten with the road story)

1. **The climb.** Up the stair; dead lanterns; the key hums louder at every step. A checkpoint on the landing.
2. **The entrance.** Short cutscene: the camera climbs to the hilltop; the roots round the beacon tighten; the Colossus pulls itself
   out of them. Title card: **MOSSBOUND COLOSSUS / GUARDIAN OF THE FOREST BEACON**.
3. **Phase 1.** Slam, sweep, shards, stomp, the root snare: the chapter's colour lessons one at a time.
4. **Phase 2 at 60 %.** It tears its roots out of the beacon; the briars rise round the ring; boulders, the grab, the combo, the charge.
5. **Phase 3 at 25 %.** The song tears loose from its chest: the song flare. It is losing itself.
6. **The end: destroyed.** The last posture break and Totoy's finishing blow. It does not kneel like the Stag: it breaks apart into
   stone and moss. Edda's rule (bind without destroying) could not be kept this time; the guardian had become the roots that held
   the song. The song pours out of the rubble, along the cracked key, into the beacon.
7. **The beacon lights.** Blue-white fire on the hilltop; the briars draw back; the forest's paths open (the chapter's world change).
   Something is left in the rubble: a stone fragment of the guardian (an Aspect for Edda to bind at home: **Stone Ward** fits).
8. **The second memory** (proposed, one or two pictures, no dialogue): night, the beacon hill, a beacon still lit behind him; Totoy
   runs down the slope with the key in both hands. Someone calls his name from the dark, a voice he trusts. The beacon goes out
   behind him, and the key cracks in his hands. (It answers nothing yet: did he run to save the key, or from something?
   It sets up the later chapters without naming the Regent.)
9. **Home.** Lanternfen: a second hill answers the first; Edda binds the guardian's fragment; Mira marks the next region (Tides).
   Credits; "Chapter 1 complete" on the title screen.

## The map as built (2026-11-09, first build: look and size rejected in the owner's playtest)

| | |
|---|---|
| Scene | `rootcrown_layered`, title ROOTCROWN, 640x360 (the glade is 560x336): `data/scenes/rootcrown_layered_props.json`, editable `presentation/maps/rootcrown_layered.tscn` (the source of truth; `tools/godot/bake_maps.gd` writes the JSON back) |
| Art | `python tools/art/make_rootcrown_art.py` turns the approved `art/reference/rootcrown_v1/ground_raw.png` into the floor `presentation/forest/rootcrown_layered_ground.png` and `props_raw.png` into 14 props (`art/src/rootcrown_*.txt`, `data/props/prop_defs_rootcrown.json`, `presentation/props/rootcrown_*.tscn`): the beacon tower dark and lit (one canvas, a state pair), 3 standing stones, 2 dead stone lanterns, 2 rubble piles, 3 root clusters, 2 briar clumps |
| Walkable | The plateau oval (centre 302,197, radii 228x96) and the stair corridor x 280..364 down to the bottom edge; the outline is clockwise like every scene's |
| Way in and out | Entry `glade_side` (322,338) at the top of the stair; exit `to_glade` (the bottom edge of the stair) goes to the glade's new entry `rootcrown_side` (516,36), just under its root arch. The glade's arch exit still leads to the arena. |
| Checkpoint | `rootcrown_layered_stair` (322,280), on the landing |
| Fight floor | 264x120 open floor from (190,132); the Colossus starts at (322,168) (`docs/previews/rootcrown_v1/layout.json`) |
| Beacon | prop `beacon` at (321,108): `rootcrown_tower_dark` until the story flag `cleared_rootcrown`, then `rootcrown_tower_lit` (same place, same body); a faint blue glow when dark, a big blue-white light when lit (`presentation/common/local_lights.json`) |
| Light | the game's night light with the Root Hollow strength (0.82), per-light colours, fireflies at the edges, the Root Hollow look (`presentation/effects/looks/rootcrown_layered.tres`), the forest ambience |
| Tests | `tests/core/test_rootcrown.gd` (5), plus the route and layered-progress tests; capture: `presentation/review/rootcrown_v1/capture_rootcrown.gd` |

## Redo after the playtest (a proposal for the next session; the owner decides, pictures first)

The owner's words: the looks "doesnt match our other scene" and "the stage is too small". Neither agent can judge the look, so the
next session shows pictures (the new floor and props next to the Stag Glade and Root Hollow) before anything is wired.

| | Proposal |
|---|---|
| Size | About the old arena's size (800x480; its walkable floor is 744x424) or bigger, with an open fight floor of at least about 560x300 (well over one 384x216 screen in both directions), the stair at the bottom and the beacon at the top. Measure the floor against the 3x Colossus's reach before building. |
| Floor | Made the way the other forest floors were made, with the Stag Glade's and Root Hollow's own ground paintings as the base or the only style references (same grass, dirt and stone, same texture density and light), converted with the same pipeline. |
| Props | Reuse the existing forest props where they fit, so they match by construction: `glade_stone_*`, `glade_rock_*`, `glade_thorns`, `root_hollow_rune_stones`, `root_hollow_boulder`, `root_hollow_roots`, `root_hollow_tree_rootwall`, `forest_standing_stone`, lantern posts. New art only for the beacon tower (dark and lit), made with those props as references. |
| Keep | The scene id `rootcrown_layered`, its registration and wiring, debug key Y, the glade entry `rootcrown_side`, the beacon state pair on `cleared_rootcrown` and its light sockets, `tests/core/test_rootcrown.gd` (new numbers), `tools/art/make_rootcrown_art.py` (new inputs). |
| Remove when replaced | the 14 `rootcrown_*` props (art/src, art/build/sprites, presentation/props, prop_defs_rootcrown.json) and the floor painting, unless the owner wants some kept |

## Build order (each step shows the owner pictures before anything is wired)

| Step | What | Notes |
|---|---|---|
| 1 | **Concept pictures**: the redesigned Colossus (one sheet, idle from the side, the size next to Totoy) and the Rootcrown hilltop | image generation (Higgsfield, about 23 credits left at 1.5 an image) or the owner's own; the owner approves the look |
| 2 | The **Rootcrown map**: floor painting and props from the approved pictures, converted (`tools/art/extract_props.py`, shadows, lights), colliders, the stair, the checkpoint, the glade's exit pointing here | layered scene like the others; first build 2026-11-09 **rejected in the playtest** (look and size): redo, see "Redo after the playtest"; the glade's exit switches when step 3 lands |
| 3 | The **boss in the road engine**: the 6 kept attacks at the new size, the posture break and counter window, Reaper's Coil drag and stun, three phases, then the 5 new attacks; deterministic core tests for each | core (`core/mob_field.gd` or a boss module it drives) |
| 4 | The **body frames** at 144 px: one pose sheet per attack (windup, strike, recover), idle, walk, hurt, posture broken, death | generated references, converted like the Warden's 2.5x poses; the owner approves the sheets |
| 5 | The **effects**: the attack effects in the staff style, the blue cracks as real lights, shockwaves, debris, shake; the boss panel (`boss_panel.tscn`) | presentation |
| 6 | The **story moments**: the climb, the entrance card, the phase changes, the death, the beacon lighting, the second memory, home and credits | cutscene and dialogue data, presentation |
| 7 | Tests, in-game captures and GIFs, the owner's playtest and tuning | all |

## Picture prompts (step 1, for the owner's review before generating)

- **Colossus concept**: "Pixel art game boss concept sheet, dark fantasy forest, side view facing right, a huge golem of mossy grey
  stone standing on thick tree-root legs, its chest a cracked hollow with a glowing blue light inside, blue light leaking through
  cracks in its arms, roots trailing from its back into the ground, moss and small ferns on its shoulders, muted greens browns and
  greys, dark outlines, 3/4 top-down game view, a small human hero at its feet for scale, plain flat background, no text."
- **Rootcrown hilltop**: "Pixel art top-down 3/4 game map, night, a round open hilltop clearing in a dark forest, a ruined stone
  beacon tower at the top wrapped in enormous tree roots, a stone stair climbing from the bottom of the image, roots and broken
  standing stones round the edge of the clearing, thorn briars, faint blue light glowing between the roots, muted greens browns and
  greys, same art style as the reference, no characters, no text."
  (with the village and glade paintings as style references, as before)

## Still open (after the pictures)

- The Colossus's numbers (health, damage, timings) for the first playtest.
- Whether the title screen's BOSS FIGHT later uses the new Colossus too (the owner said keep the old arena for now).
