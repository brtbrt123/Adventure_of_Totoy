# Plan: the Hollow Trial (draft 2026-10-30, owner idea, not built)

A dead-end room off the top of Root Hollow. An altar in the middle, a chest beside it. The hero presses the altar to start a trial: **3 waves of mobs, each harder**. Survive all 3 and the altar lights up; the chest then opens and gives **an Aspect** (which one: the owner decides).

## Open decisions (owner)

1. **Which exit. Decided by the owner:** there is **no village shortcut any more**. Root Hollow's upper-left exit (the `shortcut` exit at the top edge, x 36-72, behind the root-knot barrier) now leads to the trial room instead of the village. It keeps its rule: the root knot opens when the central fight is cleared (`cleared_hollow_center`), so the trial is optional and comes after the Hollow. Consequences for Claude: retarget that exit to `root_hollow_trial_layered` (entry `south`), rename the exit and the shut text ("A knot of roots seals the way north. Clear the hollow first."), remove the village's `return` entry and the Hollow-to-village route from the tests and docs (`test_root_hollow.gd`, route tests, `docs/architecture.md`), keep the village save/migration safe, and update the chapter overview image note. The root-knot barrier art stays as the gate.
2. **Which Aspect** is the reward (needs an id, a name, an effect, art).
3. **Failure.** Proposal: dying sends the hero to the Hollow checkpoint as today; the altar resets and the trial can be tried again (no mob is left, no reward lost).
4. **New mob.** Decided: the trial gets a new hard mob, the Runebound Warden (below). The Stag is not used.

## The room (scene `root_hollow_trial_layered`)

About 560x336 like the glade, one entry at the bottom, **no other exit**. A wide round arena floor, with a **clear fight floor of about 300x200 around the altar** (nothing on it hides an attack). Trees along the edges, bushes and many glowing rocks (teal rune light as in the Hollow shrine) around the rim; the chest stands behind the altar. The altar is a two-state prop (dark, lit), the same way the root barrier is a flag-keyed pair. Needs: ground painting, a few new props (altar dark/lit, chest closed/open or reuse the forest chest), colliders, lighting. Art and wiring are Codex's; the map data, colliders and rules are Claude's.

## The trial rules (core, new `core/trial.gd` + ExploreCore hooks)

- Press **E** at the altar: a short warning, then wave 1 spawns around the rim (never inside the 8 px of the hero, never on a prop).
- The next wave starts a few seconds after the last mob of a wave dies (a short breath, herbs still usable). No leaving: the entry closes while a wave is alive.
- Mobs use the normal AI, tells and parry/dash rules, with the pack rule raised: **up to 4 attackers at a time** (3-4 mobs attack together instead of 2).
- Dead hero: trial resets (see decision 3). Win: flag `cleared_hollow_trial`, the altar lights, the chest opens once (`chest_opened`-style), reward event `item_received` kind `aspect`, saved.

## The new mob: Runebound Warden (`warden`)

The Stag stays the glade's mini-boss and is **not** in the trial. The trial gets its own hard mob. Mossling and Boar are melee rushers; the Warden is the first mob that mixes a guard, a ranged line and an area attack, so it asks for a different answer.

Look (Codex draws it): a root-and-stone knight, about 24x32, moss on bark plates, a teal rune glowing in the chest (the same rune light as the Hollow stones). Sprites needed: idle, walk, three attack windups and strikes, guard hit (blocked), exposed (stunned, rune dark), hurt, defeat.

Numbers (first guess, `Tuning.MOBS[&"warden"]`): level 3, HP 140, speed 0.5 (slower than the hero), radius 18 (11 until the detailed art, 2026-10-31), aggro 120, exp 45, herb drop 0.8.

- **Guard.** Hits do only about 40 % damage while the rune glows. A successful **parry of a gold attack** knocks the guard down: the Warden is stunned and exposed (full damage, the rune is dark) for the same window as other mobs. So you cannot just trade blows; you must parry it.
- **Rune Cleave** (gold, cone, reach 46): windup 40, strike 6, damage 20. Parry it. Opens most chains.
- **Root Lash** (red, line, 150 px long, 20 wide): windup 44, strike 8, damage 18. Dash across it. The only ranged threat in the Hollow, so you cannot kite it.
- **Spore Ring** (red, circle around itself, reach 48): windup 56, strike 5, damage 22. Dash out of it. Chosen when the hero is within its reach, so standing next to it is punished.
- **Chain.** After a Cleave that is not parried, it follows with a Lash within 12 ticks. A parried Cleave ends the chain.
- Pack rule: Wardens count as attackers like any mob; at most one Warden attacks at a time even when the cap is 4.

Core work: a `guard` damage multiplier and a "chain" follow-up in `core/mob.gd` / `mob_field.gd`, three attack rows in Tuning, tests (guard reduces damage, parry breaks guard, chain only after an unparried Cleave, one Warden attacking at a time, deterministic with a seed).

## The waves (first numbers, tuned by play; Mossling 30 HP, Boar 70, Warden 140)

| Wave | Mobs | What it asks of the player |
|---|---|---|
| 1 | 4 Mossling + 1 Boar | learn the pressure: parry the gold lunges, dash the first charge |
| 2 | 3 Mossling + 2 Boar + **1 Warden**, then 2 more Mossling after 10 s | the first guard: parry the Warden's Cleave while the rest rush |
| 3 | **2 Wardens** + 3 Boar + 4 Mossling in two groups, one Warden arriving 8 s later | two Wardens never attack together, but their lines and rings overlap the boar charges: the hardest wave, the player must prioritise |

Hard on purpose: mobs in a wave wake together, boars charge across the whole floor, the Wardens' guards make careless fighting slow and costly. Limits that keep it fair: every attack stays telegraphed (gold or red), no wave spawns on top of the hero, herbs drop (Mossling 40 %, Boar 60 %, Warden 80 %) so a good run can heal, and the trial can be retried.

## Build order

1. Claude: the Warden mob (Tuning, guard, chain, tests), map data (outline, entry, one exit in the Hollow, checkpoint, trial encounter markers), `core/trial.gd` (waves, spawn points, win/lose), `ExploreCore` flag/chest/reward hooks, tests (wave progression, no spawn near the hero, lose and retry, reward once, save/load), contract in `docs/architecture.md`, a Codex task note.
2. Codex: Warden sprites, ground painting, altar and chest props, wave banner ("WAVE 2"), altar lit effect, chest-open effect and reward card, lighting.
3. Owner: confirm the Warden's name and look, pick the Aspect, play and say if it is hard enough; numbers are first guesses and are not judged.

Note: this room should be built as a map **scene** (`presentation/maps/*.tscn` + baker) once the phase 2 migration lands; until then it is a normal `data/scenes` file.

## Layout fixed (2026-10-31)

Scene `hollow_trial_layered`, 512x352, entered from Root Hollow's upper-left exit at its bottom edge (x 228-284), dead end. Altar at (256, 180), chest at (256, 136), fight floor [112, 92, 288x184], twelve spawn points on the rim (all at least 109 px from the entry and 122 px from the altar, 57 px apart). Exact numbers: `docs/previews/hollow_trial_v1/layout.json`, guide `walkable_guide.png`. Codex's art and presentation task: `docs/CODEX_TASK_hollow_trial.md`.

## Core built (2026-10-31, Claude)

`core/trial.gd` + a managed encounter in `core/mob_field.gd` + ExploreCore hooks; the room `hollow_trial_layered` is registered with stand-in props (forest pedestal as the altar, forest chest, rune stones, rim trees, the root knot at the entry); Root Hollow's upper-left exit now leads here (the village's `return` entry stays: the Woodland uses it). Tests: `tests/core/test_hollow_trial.gd` (10). Still open: the ground painting and real props (Codex), the chest's Aspect (owner; a 3-herb placeholder for now), the presentation wiring (Codex), the feel and numbers (owner, by play).

## Chest on top of the altar (owner, 2026-10-31)

The chest sits on the altar's top (prop `trial_chest`, feet (256, 181), one pixel in front of the altar). There is one object, the altar: E there starts the trial before a win and opens the chest after it. Layout and guide updated.
