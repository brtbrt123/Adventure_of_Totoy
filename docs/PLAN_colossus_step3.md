# Step 3 plan: the redesigned Colossus in the road engine

Status: **approved and part 3a built** (2026-11-27, Claude). The owner: "lets do the 3a but in victory after defateing the golem we
should do a cut scene", then "i also like your proposal" (the seven recommended choices below). Follows step 3 of
[[FINAL_SCENE_chapter1]]. The owner's Rootcrown playtest ended with "its good for now" (2026-11-27).

**3a in the game (committed 94d6abfb, waiting for the owner's playtest):** `core/colossus.gd`, the encounter and seal in Rootcrown, the
stand-in body `colossus_idle_right_1` (`tools/art/make_colossus_standin.py`), `presentation/explore/colossus_view.gd`; interface in
[[architecture]] ("The Mossbound Colossus on the road"); tests `tests/core/test_colossus.gd` (20) and `tests/smoke_colossus.gd`;
captures and the victory storyboard in `presentation/review/colossus_3a/`. Details: the top of [[STATUS]]. The victory cutscene is
proposed below ("Victory cutscene"), not built.

**3b in the game too (2026-11-27, committed 94d6abfb):** phase 3 at 25 %, Root Snare (with its second lane), Boulder Toss (with its ring of
shock), Heartroot Grab; real warnings, the arena's sounds, shake and dust. Their effects are **proposed only**, rendered with PixelFX
in Totoy 36 (`tools/art/import_pixelfx.py`, `art/reference/pixelfx_colossus_v1/`) and shown in
`presentation/review/colossus_3b/colossus_3b_attacks.png`: the thorns and the stone work; the ring of shock (side-view dust, too
faint after hard alpha) and the root-arm (thin and dark at night) need another try. Wire them on the owner's yes.
Since then (2026-11-28): the thorns, the stone and, for the ring of shock, 14 stone shards round its real band (the owner's option
B) are in the game, and the reworked root-arm (pale root, the song's blue thorns, rearing before it lashes) too: every 3b effect is wired.

**3c in the game (2026-11-28, not committed):** the Briar Ring (warning 4.5 s, not 3.5: the farthest walk in from the clearing is 240 px;
8 damage every 0.8 s outside, not every 0.5 s: a hit hero cannot be hurt for 0.75 s) and the Song Flare (as in the table). Effects
wired on the owner's "Yes, wire them" (`presentation/review/colossus_3c/colossus_3c_attacks.png`): the root-thorn wall, sparse
song-blue shards on the rings, a song-blue mana-burst for the gold blow. **Step 3 is complete** (all ten attacks, three phases, every
effect); next the owner's playtest and tuning, step 4 (the real body), then the story moments with the victory cutscene last.

## Pictures (mock-ups, not gameplay)

In `docs/previews/colossus_step3/`. The boss is a stand-in cut from the approved concept picture; the attack sizes are the
proposed numbers below; the map, night light and warning shapes are the game's own.

| File | Shows |
|---|---|
| `step3_size.png` | three body heights beside Totoy (34 px) |
| `step3_camera.png` | today's camera against the proposed fight camera |
| `step3_behind.png` | Totoy behind the body, without and with the outline |
| `step3_attacks_kept.png` | the six attacks it has today, at the new size |
| `step3_attacks_new.png` | the five new attacks |
| `step3_warnings.png` | today's warnings against glowing edges on the night floor |

Remake: `python tools/art/make_colossus_step3_preview.py mocks`, then the windowed capture
`presentation/review/colossus_step3/capture_mockup.gd`, then `... sheets`.

## Decisions for the owner

| # | Question | Recommended | Other choice |
|---|---|---|---|
| 1 | Body height | **B, 116 px** (3.4x Totoy, fits a 144 px frame) | A 102 px, or C 130 px (needs a 168 px frame) |
| 2 | Camera in the fight | **Slides toward the boss** to show it whole | Keeps following Totoy only (head cut whenever he is below it) |
| 3 | Totoy behind the body | **Pale outline drawn over the body** | The boss tries to stay above him (a fight rule) |
| 4 | Sweep colour | **Stays gold.** The game made it gold on your request (2026-10-16); the plan table and [[GAME_DESIGN]] still say red | Make it red again |
| 5 | Warnings at night | **Glowing 2 px edge** for the boss's warnings | Keep today's look |
| 6 | Leaving mid-fight | **The climb closes** until the fight ends | Walking down resets the boss, as with the other road fights |
| 7 | When the story uses Rootcrown | **After step 4** (real body frames); until then only debug key Y | As soon as step 3 works, with the stand-in |

## What the player gets

- Walking up the climb wakes the Colossus (about 1.5 s, it cannot be hurt yet). The climb closes.
- The road HUD, TAB menu, herbs and stat points all work. The arena's boss panel shows its health and posture.
- Armour as in the arena: normal hits do a quarter of the damage. Hits and parries fill posture; a perfect parry fills it at
  once. A broken Colossus takes 4x damage plus the Edge bonus.
- Reaper's Coil drags it and stuns it for 0.75 s (not a posture break). Every weapon and Aspect works on it.
- Defeat: back to the checkpoint, the boss whole again in phase 1.
- Victory: the story flag `cleared_rootcrown` is set (the beacon lights, already wired), 200 EXP. The death scene, the
  Aspect reward and the memory are step 6.
- Debug key Y clears the win so the fight can be replayed (as T does for the trial).

## Numbers (first guesses, all in `core/tuning.gd`, yours to tune)

Health 600 (arena: 380), posture 100, break window 1.5 s (arena: 1.0 s; the body is bigger, the run-in longer), body
radius 46, walk 0.5 px per tick. Phases at 60 % and 25 %; windups x0.85 after phase 1. Times are seconds in phase 1.

| # | Attack | Colour | Phase | Warning | Damage | Size (px) |
|---|---|---|---|---|---|---|
| 1 | Gold Slam | gold | 1+ | 1.0 | 30 | circle, radius 44, where Totoy stands |
| 2 | Sweep | gold | 1+ | 1.0 | 20 | cone, radius 112, 100 degrees |
| 3 | Red Shards | red | 1+ | 0.8 | 15 | three lanes 240 x 16, 22 degrees apart |
| 4 | Red Stomp | red | 1+ | 1.0 | 25 | ring 76 to 150, safe inside |
| 5 | Gold Combo | gold | 2+ | 0.9 | 25 each | three circles, radius 40, 0.43 s apart |
| 6 | Red Charge | red | 2+ | 1.0 | 28 | lane 260 x 88, the body travels it |
| 7 | Root Snare | red | 1+ | 0.8 | 18 | lane 240 x 28; a second one 0.5 s later at where Totoy went |
| 8 | Boulder Toss | red | 2+ | 0.9 | 24, ring 12 | circle radius 40, then ring 40 to 72 after 0.67 s |
| 9 | Heartroot Grab | gold | 2+ | 0.7 | 26 | lane 220 x 20; a parry adds 60 posture (a perfect one breaks it) |
| 10 | Briar Ring | red | at 60 % and 25 % | 3.5 | 8 per 0.5 s | outside a radius 170 circle, for 10 s |
| 11 | Song Flare | red, then gold | 3 | 0.8 to 1.4; gold 2.3 | 18; 35 | rings 52-88, 112-148, 172-208; then radius 120; a parry breaks it |

Two points differ from the table in [[FINAL_SCENE_chapter1]] or from today's code:
- Gold Combo has two blows today; the plan table says three. Planned: three.
- Heartroot Grab only hurts when it lands. Pulling Totoy in would be a new rule; not planned.

**Fairness check** (`make_colossus_step3_preview.py mocks` prints it) covers the first warning of attacks 1-10: with the
phase 1 times each can be walked out of from its worst spot; with the later phases' times the sweep and the shards need a
dash from the worst spot. The boulder's second ring is not in the script (by hand: at most 22 px to walk in 0.67 s, back
into the crater or out past the ring).
The Song Flare leaves two safe strips of 12 px between its rings, otherwise Totoy dashes through (the first draft left 2 px;
fixed). All of it becomes a core test.

**Nothing from off screen:** the boss starts an attack only when Totoy is near enough to see it (about 230 px to the side,
75 px below, 160 px above); otherwise it walks closer.

## Found while planning

| Finding | Effect | Handled in |
|---|---|---|
| Warning markers are clamped to the arena's 800 x 480 (`telegraph_view.gd`); Rootcrown is 1024 x 720 | markers in the right and lower part would sit in the wrong place; no current fight map is that big | 3a |
| Rootcrown's props use 38 of the 48 light entries; later lights are dropped without a warning | the boss's glow and hit flashes could vanish | 3a: only pass lights that reach the screen |
| The road engine has no posture or armour | the arena's rules move into the new boss module | 3a |
| The road HUD has no boss bar | reuse `boss_panel.tscn` (your scene is not edited) | 3a |

## How it is built

- **core:** a new `core/colossus.gd` (its states, attacks and posture), driven by `core/mob_field.gd` as the mob type
  `colossus`; hits go through `MobField.hit_mob`, so weapons and Aspects reach it. An encounter in the Rootcrown scene data.
  Numbers in `core/tuning.gd`. The arena's `core/boss.gd` and `game_core.gd` stay as they are (practice mode).
- **snapshot** (`docs/architecture.md`): the boss's mob view gains posture and the break time left; hazards (the briars) are listed
  separately from warnings.
- **presentation:** the stand-in body with a simple pose per state, the camera, the outline, glowing warnings, the boss panel,
  the chest light, the arena's existing sounds. Real frames are step 4, real effects step 5.

## Build order (a playtest after each)

| Part | Content | Done when |
|---|---|---|
| **3a** | the fight: encounter, wake, closed climb, attacks 1-6, armour, posture, parry, Reaper's Coil, Aspects, defeat, victory; camera, outline, warnings, boss panel, lights, stand-in | core tests per attack (hit, dodge, parry), a headless smoke that wins and loses, the full run green, captures for you |
| **3b** | three phases, Root Snare, Boulder Toss, Heartroot Grab | the same for the new attacks and phase changes |
| **3c** | Briar Ring, Song Flare, the fairness test over all warnings | the same; then your tuning pass |

## Victory cutscene (the owner asked for one; proposal, nothing built)

**Built last** (owner, 2026-11-27: "we will do the story board cut scene last"): after the rest of the fight (3b, 3c), with the
story moments.

Storyboard: `presentation/review/colossus_3a/colossus_3a_victory_storyboard.png` (panels 2 and 3 are mock-ups over the real scene).
About 8 s, skippable, plays once, then the road goes on with the climb open.

| Beat | Time | What happens |
|---|---|---|
| 1 The last blow | 0 to 0.6 s | the killing hit freezes a moment, the body flashes white |
| 2 It breaks apart | 0.6 to 3 s | blue light bursts from its cracks; it falls into stone and moss; dust and shake |
| 3 The song goes home | 3 to 5.5 s | the song rises from the rubble as motes; the camera follows it up the hill (the planned pan that shows the tower whole) |
| 4 The beacon lights | 5.5 to 8 s | blue-white fire; the whole tower on screen; one caption line (the owner writes it); then the camera returns to Totoy |

How it would work: it starts on `encounter_cleared` for `rootcrown`; the road does not step while it plays (as the weapon cut-ins);
the beats and the caption live in `data/cutscenes/` in the intro's format (`core/cutscene_book.gd`), so the owner edits the words.
To keep "which state a prop shows comes from the snapshot", the beacon would light on a new story flag (`forest_beacon_lit`) that
beat 4 sets, instead of on `cleared_rootcrown` at the kill. The broken-apart look needs the death frames of step 4; until then the
stand-in breaks into square chunks as in the mock. Alternative: painted panels like the intro (about 4 Higgsfield pictures, 6 of the
16.5 credits left).

## Not verified

The feel, the timing and the difficulty (only play shows them). How the HUD overlaps the fight view (hidden in the mock-ups).
The stand-in is not the final look: it is one still picture scaled down, with no animation.
