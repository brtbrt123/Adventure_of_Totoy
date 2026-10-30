# Codex task: the Runebound Warden, a new hard mob for the Hollow Trial (draft 2026-10-30)

Design and rules: `docs/PLAN_hollow_trial.md` (read "The new mob" and "The waves"). Claude builds the core side (`Tuning.MOBS[&"warden"]`, guard, chain, tests, events). **You build everything the player sees and hears:** the design, the sprites, the animations, the effects and the sounds. Stay in `presentation/`, `art/` and your tests; do not edit `core/` or `data/`. Owner approves the look on a contact sheet BEFORE you wire it (same workflow as the Woodland mobs: sheet first, then import).

## 1. Design (owner approves first)

A **Runebound Warden**: an old guardian of the Hollow, a knight made of root, bark and mossy stone. It must read at a glance as **harder than a Boar** and **different from every mob so far** (Mossling is small and round, Boar is low and wide, Stag is a big deer).

- Silhouette: upright, humanoid, about **24x32** px body in a **48x48** cell, feet anchor like the other mobs (`# anchor:` in each text grid). Broad shoulders, a slow heavy stance, one arm ending in a root-wrapped blade or a hooked root whip (the Lash comes from it).
- Colours: Totoy 36 only. Bark browns and mossy greens for the body, a stone-grey chestplate. **The rune in its chest is teal** (the same teal as the Hollow rune stones). **No gold and no red anywhere in the body or the idle glow**: gold and red are reserved for the combat cues (the telegraphs and hit effects).
- Two readable states of the rune, because the **guard is the gameplay**: **rune lit** (teal, bright, a few bright pixels around it) = guarded, hits do little; **rune dark** (dim, cracked look) = exposed, full damage. The player must see this from a distance in one frame.
- Deliver a contact sheet (8x, 4 frames per row, labelled) with the idle, the three attack poses, guarded, exposed and the defeat pose, before anything is imported. Pixel hygiene as always: hard alpha, palette only, `python tools/art/validate_art.py`.

## 2. Frames and animation (what the core will tell you)

Names: `warden_<state>_right_<n>` (n from 1), right-facing only, mirrored at runtime like the other mobs. Add the entry to the `STATES` table in `presentation/explore/mob_view.gd` (and to `presentation/arena/` only if mobs appear there; they do not). Table format is `[frame set, count, ticks per frame, loop]`.

| Core state / moment | Frame set | Frames | Notes |
|---|---|---|---|
| `idle` (dormant) | `idle` | 4-6 | slow breathing, rune pulses softly; dormant encounters use the simulation clock (see the Boar) |
| `alert` | `wake` | 4 | stands up, rune flares once |
| `chase` / `return` | `walk` | 6 | heavy, slow (speed 0.5): 6-7 ticks per frame |
| `windup` + attack **Rune Cleave** (gold) | `cleave_tell` | 4-5 | raises the blade high; the last frame holds (windup 40 ticks) |
| `strike` Cleave | `cleave_strike` | 3 | a wide downward arc, 6 ticks of damage |
| `windup` + attack **Root Lash** (red) | `lash_tell` | 4-5 | draws the whip back, root tendrils creep along the ground toward the hero (windup 44) |
| `strike` Lash | `lash_strike` | 3 | the whip extends in a straight line, 150 px |
| `windup` + attack **Spore Ring** (red) | `ring_tell` | 4-5 | crouches, rune brightens, spores rise (windup 56) |
| `strike` Ring | `ring_strike` | 3 | stamps; the ring bursts around it |
| `recover` | `recover` | 3-4 | after any attack; lowers its guard slightly |
| **guard hit** (a hit that was reduced) | `guard_hit` | 2 | rune flashes, small recoil, no stagger |
| `stagger` / **exposed** (after a parry) | `exposed` | 4 | knocked back, rune goes DARK, kneels or staggers; holds for the stun window |
| `hurt` (a hit while exposed) | `hurt` | 2 | |
| `dead` | `death` | 6-8 | rune fades out, the body falls apart into roots and moss |

**Interface (done in the core, `core/mob_field.gd`, numbers in `Tuning.MOBS[&"warden"]`):**
- Mob view (`ExploreSnapshot` mobs, from `MobField.mob_views`): `type` `warden`, `state` (`idle`, `alert`, `chase`, `windup`, `strike`, `recover`, `stagger`, `hurt`, `return`, `dead`), `state_ticks`, `exposed` (true while stunned), **`guarded`** (true while the rune guard is up, false when exposed or dead) and **`attack`** (while an attack winds up or strikes: `warden_cleave`, `warden_lash` or `warden_ring`; empty otherwise; `attack_id` is the attack in progress or next).
- The state is `stagger` after a parried Cleave (that is your `exposed` frame set; the stun lasts `Tuning.MOB_STAGGER_TICKS` = 90 ticks, then the guard returns).
- Guard-hit moment: the `attack_hit` event (target_id = the mob) carries **`guarded: true`** when the hit was reduced by the guard (damage 0.4x); an exposed hit has `kind` `counter` and no `guarded` key.
- Telegraph shapes: Cleave `cone` (gold, reach 46 + radius), Lash `line` (red, 150 long, 20 wide, the Warden does not move), Ring `circle` (red, reach 48, centred on the Warden itself, not on the hero). Windups: Cleave 40, Lash 44, Ring 56 ticks; strikes 6, 8 and 5 ticks.
- Chain: an unparried Cleave is followed by the Lash 12 ticks after its recovery starts, so a Lash can start right as the recover frames end; a parried Cleave ends the chain. Only one Warden winds up or strikes at a time.
Tell Claude if you need anything else in the snapshot; do not work around it.

## 3. Effects (presentation only, no rules)

Use the shared hero/mob effect plumbing (`presentation/common/hero_fx.gd` and each scene's mob effects) and **the existing telegraph drawing for the shapes** (the core sends the gold or red shape and its timing; you do not invent hit areas).

- **Telegraphs.** Cleave: gold cone, reach 46. Lash: red line, 150 long and 20 wide, with the tendril creep along the ground during the windup. Spore Ring: red circle reach 48 that fills toward the strike. Same gold and red warning vocabulary as the Boar and the Stag.
- **Guard.** A teal rune glow with a soft light pool (like the Hollow stones, `local_lights.json` style) that is on while guarded. **Guard hit:** a small teal spark ring, the rune flashes. **Guard break** (the parry succeeds on a Cleave): a bright burst, the glow goes out, a few cracking-rune particles; add a short "exposed" cue (a dim rune and falling dust) for the whole stun.
- **Strikes.** Cleave: a pale arc trail (not gold, gold is the warning only). Lash: a thin pale line with root splinters. Spore Ring: an expanding ring of spores with a brief ground scorch that fades; in each case a hit on the hero uses the normal hit burst and shake.
- **Idle and ambient.** A faint teal glow breathing at the chest, a few drifting spores. **Defeat:** the rune's last flash, the body crumbles, moss and root fragments settle, the glow fades; drop (herb) uses the existing drop effect.
- **Wave presence** (for the trial): a subtle teal rim light on a Warden that arrives mid-wave so the player notices it appear. Keep it cheap: the road already runs many effects at once.
- Keep everything hard-alpha, palette-only for sprite effects; additive or shader glows are fine where the hero effects already use them. Do not add semi-transparent sprite edges.

## 4. Sounds (new cues; the owner listens and approves)

Same rules as the existing audio: files in `presentation/audio/`, entries in `presentation/audio/sources.json` and the README with honest credits (no false CC0), same ducking and levels as the existing cues; the owner cannot judge by waveform, so say which event got which file. Wire through `combat_audio.gd` and the explore scene's event handling.

| Cue | Event / moment | Character |
|---|---|---|
| `warden_wake.wav` | `mob_alerted` for a warden | a deep creak of wood and stone, rune hum rising |
| `warden_step.wav` (2-3 variants) | each walk footfall, quiet and rare (every second step) | heavy, wooden thud with a stone knock |
| `warden_cleave_tell.wav` | `attack_telegraphed` with `warden_cleave` | blade scraping up, a rising gold-warning layer (reuse `gold_warning.wav` under it) |
| `warden_cleave_strike.wav` | the strike frame | low whoosh and a wooden crack |
| `warden_lash_tell.wav` | `attack_telegraphed` with `warden_lash` | roots creaking and stretching (reuse `red_warning.wav` under it) |
| `warden_lash_strike.wav` | the strike frame | whip crack with splintering wood |
| `warden_ring_tell.wav` | `attack_telegraphed` with `warden_ring` | low hum swelling, spores hissing |
| `warden_ring_strike.wav` | the strike frame | a heavy stamp and a soft burst |
| `warden_guard_hit.wav` (2 variants) | a reduced hit on a guarded Warden | dull stone-and-bark clunk with a short teal chime; clearly **different from** `armor_hit` so the player hears that the hit was weak |
| `warden_guard_break.wav` | `mob_staggered` reason `parry` on a warden | a bright crack of the rune, then a falling-power hum; pairs with `perfect_parry.wav` |
| `warden_exposed_loop.wav` (optional) | during the stun | very quiet dying-hum under the music |
| `warden_death.wav` | `mob_defeated` | wooden collapse, stones settling, rune hum fading to silence |
| `trial_wave_start.wav`, `trial_wave_clear.wav` | the trial's wave banner (see the trial task later) | optional placeholders now |

Sound rules: the gold and red warnings must stay audible over everything else (they are the readability of the fight); keep Warden sounds below them in level; no sound should hide a telegraph. Never more than 2 Warden voices at once (the second Warden's cues are quieter).

## 5. Tests and captures

- A smoke test that every requested frame of `warden_*` exists (`tests/smoke_animation.gd` style) and that the `STATES` table covers every state the core can send.
- A capture of each attack with its telegraph, the guarded and exposed rune, and the death, saved as `art/build/arena_*.png` style or in `presentation/review/`; a GIF of one full Cleave-parry-exposed loop for the owner.
- Run the standard harness (Python, import, core, every smoke). Report what you ran and what you could not judge (look, feel and sound are the owner's call).

## Order

1. Design contact sheet to the owner (no import). 2. After approval: text-grid sources, `build_art.py`, contact sheet, `mob_view.gd` entry. 3. Effects and telegraphs. 4. Sounds. 5. Tests, captures, notes. The core side (Claude) lands in parallel; use the names above and tell Claude what is missing.
