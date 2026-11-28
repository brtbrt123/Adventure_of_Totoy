# Step 4: the Mossbound Colossus's body (PLAN and progress)

Build step 4 of [[FINAL_SCENE_chapter1]]: real body frames in place of the step 3 stand-in (one still picture moved per state,
`colossus_idle_right_1`). Step 3 ([[PLAN_colossus_step3]]) passed the owner's playtest on 2026-11-28 ("ITS GOOD NOW").

Owner, 2026-11-28: "OKAY LETS START ALSO WE NEED AN ANIMATION WHEN HE IS APPEARING". The method is the one recommended to the
owner: **rig the approved concept** (no credits, every frame matches the approved look, any pose can be changed by numbers).

## How the frames are made

`tools/art/rig_colossus.py` cuts the golem out of the approved concept (`art/reference/rootcrown_v1/colossus_concept_1.png`, the
same cut-out as the stand-in, but keeping the mouth and the fists' cracks) and splits it by fixed polygons into six parts: two arms
(pivots at the shoulders), the head, two root legs, and the body with its moss mantle. A pose moves the parts at the concept's
own size (body offset, arm rotations, the head's nod, root steps, how deep it is sunk), then the frame is shrunk to the stand-in's
size (116 px tall, the owner's choice B) and snapped to Totoy 36 without gold and red, with hard alpha. Posing before shrinking
keeps one pixel size and no rotation jaggies. Details that keep the parts whole:
- the shoulders stay on the body (a raised arm leaves its shoulder in place), the moss above the head is mirrored into the head's
  hole (a nod shows moss and shadow, not a hole), the roots reach up under the belly (a lifted body shows roots, not a seam);
- specks of the cut-out's edge are cleared; the song in the chest and cracks has four states by swapping its colours along their
  ramp: dark (asleep), dim (broken), lit, bright (windups, roar);
- sunk in the ground, the frame gets a rim of broken earth (dark edge, lit crest) so it rises out of the ground.

`python tools/art/rig_colossus.py --preview` writes the poses to `art/reference/colossus_body_v1/` (`poses.json`, `.gdignore`).
`python tools/art/make_colossus_4a_review.py` makes the review sheet and GIFs in `presentation/review/colossus_4a/`.

## 4a: the look test and the appearing (2026-11-28, approved: "Approve, do 4b")

Shown to the owner (PREVIEWS composited by Python on the Rootcrown ground painting with Totoy's real frames and the approved
effects: not the game renderer, so no night light, props or shadows):
- `colossus_4a_poses.png`: the key poses (idle, Gold Slam windup and strike, posture broken, roar) and the ten poses of the appearing;
- `colossus_4a_appear.gif`: the appearing at game speed;
- `colossus_4a_slam.gif`: a Gold Slam at its real timing (windup 60 ticks, the blow, recover 26).

**The appearing (proposed).** Asleep it is a mossy mound with only its face showing, the song dark. When the hero wakes it: the
song glows in the moss, one fist bursts out of the ground (stone shards burst up, `fx_colossus_shard`), then the other, it plants
both fists (dust: the first frames of `fx_colossus_stone_land`), pulls itself out of the ground, roots tearing free, stands, and
roars with its arms up and the song blazing. The screen shakes at each burst. It takes **2.5 s instead of 1.5 s**
(`COLOSSUS_WAKE_TICKS` 90 -> 150, a core number: it cannot be hurt meanwhile, as now). The poses come from `state` and
`state_ticks` only (`alert`), as every mob's. The entrance title card (MOSSBOUND COLOSSUS) stays in the story moments of step 6.

## 4b: every frame (2026-11-28, approved: "Approve, do 4c")

`python tools/art/rig_colossus.py --frames` writes all **86 frames** to `art/reference/colossus_body_v1/frames/` with `frames.json`
(size, feet, a note, the **attachment points** of both fists and the chest per frame, and the appearing's first ticks). Frames are
named `colossus_<set>_right_<n>` (the mob convention). The sets, and which attacks share them:

| Set | Frames | Plays for |
|---|---|---|
| `sleep` | 2 | asleep (the mossy mound, breathing) |
| `appear` | 25 | waking (`alert`): 10 key poses with two in-betweens each, first ticks in `frames.json` (proposed wake 150 ticks) |
| `idle`, `walk` | 4, 6 | standing; the knuckle-walk (a fist and the opposite roots lift in turn) |
| `slam_windup`, `slam_strike`, `slam_recover` | 3, 2, 1 | Gold Slam; Gold Combo (re-raises between its blows); the recover also ends Root Snare and Boulder Toss |
| `sweep_*` | 2, 2, 1 | the gold Sweep: the right arm draws back and swings across |
| `shards_*` | 2, 1, 1 | Red Shards; the Song Flare's rings (the chest opens and bursts on each ring) |
| `stomp_*` | 2, 1, 1 | Red Stomp: it rears up on one root leg and stamps |
| `charge_*` | 2, 2, 1 | Red Charge: it crouches, then rushes with its fists in front |
| `snare_windup`, `snare_strike` | 2, 2 | Root Snare: a fist into the ground, then the other for the second lane |
| `boulder_windup`, `boulder_strike` | 2, 1 | Boulder Toss: it tears up a stone, lifts it overhead (held at the fists' points), throws |
| `grab_*` | 2, 1, 1 | Heartroot Grab: the right arm draws back and lunges (the root-arm stays an effect) |
| `broken`, `stagger` | 2, 2 | posture broken (slumped, the song flickers); Reaper's Coil stun |
| `roar` | 2 | a new phase (the Briar Ring rises meanwhile); the Song Flare's gold blow |
| `death` | 8 | the last blow, it sags, the arms break off and fall, the head topples, it sinks and breaks into stone-shaped chunks, a heap of outlined stones with moss and a dark chip of the song |

New in the rig for 4b: arms that leave their shoulders (offsets), shoulders as their own part (a dying frame drops them), clipping
at the ground, and the crumble (irregular stone-shaped chunks fall from the top down while a heap grows). Every frame passes the
art rules (Totoy 36 without gold and red, hard alpha, multiples of 8; checked by the review script). About 1.6 million pixels: the
atlas (2048x5448 of at most 8192) has room.

Shown to the owner (`python tools/art/make_colossus_4b_review.py`, PREVIEWS composited by Python as in 4a, in
`presentation/review/colossus_4b/`): `colossus_4b_frames_fight.png`, `colossus_4b_frames_appear_death.png`, and a GIF per attack
and state at its real timing (`colossus_4b_<key>.gif`: idle, walk, slam, combo, sweep, shards, stomp, charge, snare, boulder, grab,
flare, broken, stagger, roar, death, appear).

## 4c: the body in the game (2026-11-28, waiting for the owner's playtest)

- **Art:** `python tools/art/rig_colossus.py --install` writes the 86 grids into `art/src` (the stand-in `colossus_idle_right_1` is
  now the rigged idle; old `colossus_*_right_*` grids not in the set are removed) and `presentation/explore/colossus_frames.json`
  (fists and chest per frame, the appearing's first ticks). Validate, build (atlas 2048x6294 of 8192), preview (26 contact pages),
  import. `tools/art/make_colossus_standin.py` is history: running it would overwrite the rigged idle.
- **Presentation** (`presentation/explore/colossus_view.gd`): `body_frame(mob, telegraphs, tick, moving)` picks the frame from the
  snapshot only: asleep the mound (`sleep`, breathing on the simulation tick), `alert` the appearing by `state_ticks`, `chase` the
  walk while it moves (position memory, nothing rules-bearing) or idle, `windup`/`strike` the attack's set by `attack_id` and its
  warnings' ticks (windup frames over 3/4 of the warning, the last held and trembling from 80 %, the falling frame 3 ticks before
  a blow; a combo re-raises between blows; the snare's second lane takes the other fist; the boulder is torn up, held overhead to
  45 % of its warning and thrown; the flare bursts on each ring and roars for its gold blow), `recover` the attack's recover frame
  then idle, `posture_broken`, `stagger`, `roar`, `dead` (8 frames, 5 ticks each). A missing frame warns once and draws the
  standing one. The chest light follows the frame's chest (`chest_at`). The stone of the Boulder Toss is drawn between the fists
  while held, its flight starts at the throw and still lands on the warned tick (its shadow grows only in flight). The appearing's
  floor breaks (`APPEAR_CUES`): stone shards where each fist bursts out, dust where they plant, a stomp and a shake at each.
- **Camera:** the fight view also tries to keep its reach in view (`REACH` 116 x 142: fists overhead or flung wide), after which the
  standing body and the hero's margins rule as before.
- **Core:** `COLOSSUS_WAKE_TICKS` 90 -> 150 (the owner's yes to the 2.5 s appearing; it cannot be hurt meanwhile).
- **Tests:** `tests/smoke_colossus.gd` checks all 86 body frames are in the atlas, the appearing fits the wake, it plays asleep to the
  last appearing frame with its shards and dust, the chest light sits on the frame's chest, its attacks played 8+ windup/strike
  frames, the death frames played, and no body frame is missing. Core 609 pass.
- **Pictures:** `presentation/review/colossus_4c/capture_4c.gd` (windowed) and `tools/art/make_colossus_4c_sheet.py`:
  `colossus_4c_body.png` (16 real captures at night) and `colossus_4c_appear.gif` (the appearing from the real frames).

## Next

- The owner's playtest of the body (debug key Y). Then **4d**: the story uses Rootcrown (the glade's arch leads there instead of the
  old arena; the owner's choice 7 of step 3). After the dead state (40 ticks) the body is gone: whether the heap stays as a prop is
  the owner's call (the victory cutscene comes last).

## The Gold Sweep reworked (2026-11-28, in the game: the owner's "Looks good, wire it")

Owner: "do we have a proper animation on an arm swing" (no: 2 strike frames in about 3 ticks, the arm ending limp across the legs,
no trail), then "Yes, rework it". The rig gained arm shortening along the arm (`arm_*_len`, a fist swinging toward the viewer) and
smears (`smear`: pale dithered ghosts of the right arm where it just was, outside the body). The new Sweep: 2 windup frames (the arm
out, then drawn back at chest height), 4 swing frames (the swing starts with a smear, the fist passes in front shortened, the arm
across the belly to the far left, the follow-through) with the body twisting, 2 recover frames. Proposed timing: the swing frames
start 4 and 2 ticks before the blow, on it, and 4 after (2 ticks each at least, so they read). Review copy:
`python tools/art/rig_colossus.py --set sweep --to sweep_v2` (`art/reference/colossus_body_v1/sweep_v2/`);
`python tools/art/make_colossus_sweep_review.py`: `presentation/review/colossus_sweep/colossus_sweep_before_after.gif` (now vs
reworked, real speed then slowed 4 times) and `colossus_sweep_swing_frames.png`. On the owner's yes: `--install`, `COUNTS`
(sweep_strike 4, sweep_recover 2) and the sweep's swing timing in `colossus_view.gd`, smoke, captures.
The owner asked for "a gif with full effect even the gold mark": `presentation/review/colossus_sweep/capture_sweep.gd` (windowed)
records the REAL game (gold cone, parry marker, hit and parry effects, HUD) with `sweep_view_mock.gd` drawing the reworked frames and
the proposed step 5 dust drawn over the cone (both mocks); `make_colossus_sweep_review.py --game` makes
`colossus_sweep_in_game.gif` (he takes the blow, he parries it, then slowed 3 times).
Wired on the owner's "Looks good, wire it" (the GIF showed the swing and the Sweep's dust): `rig_colossus.py --install` (89 frames;
the earth rim's seeds now follow the frame names, `SEED_BASE`, so the approved appearing stays pixel-identical), the dust
`fx_colossus_dust_1..8` by `import_pixelfx.py --install` (blunt-hit frames 7, 9 ... 21), `colossus_view.gd`: `COUNTS` (sweep_strike 4,
sweep_recover 2; recover frames spread over `RECOVER_HOLD`), the swing on `SWEEP_SWING` (-4, -2, 0, 4 ticks from the blow), the dust
(`sweep_dust`: 7 columns x 2 rows across the real cone, a column a tick later each, depth-sorted). Smoke: 89 body frames, a forced
Sweep plays its dust. `capture_sweep.gd -- --real` records the wired game: its swing is pixel-identical to the approved mock, the
dust differs only by depth (puffs north of its feet pass behind its arm); `colossus_sweep_wired.gif`.

## Known limits

- It faces the viewer (the concept's view) in every pose; it is not mirrored. Rigged cut-outs can look stiff; the owner judges.
- A nod shows the head's own top edge under the moss fringe (a thin line); small at game size.
