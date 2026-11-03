# Progression plan: the village sequence and the stat points (DRAFT for the owner's review)

Status: a plan, nothing in this file is built yet. Written 2026-10-28 by Claude from the numbers in `core/tuning.gd` and the current flags in `data/dialogue/chapter1.json`. Everything marked **DECIDE** is the owner's call. Claude cannot judge whether the sequence is fun or the numbers feel fair; the numbers below are first guesses to be tuned in playtests.

## Decisions (owner, 2026-10-28)

- Order Mira, Tovan, Elder, Edda: **approved**. The Elder's basket errand and the closed east road: **approved**. Quests pay EXP and rewards that fit the task: **approved**. Stat points **option B**: **approved**.
- **Sprint** is the first Aspect, bound by Edda as the reward for the village tasks (it is the only Aspect that works without a boss, so it is usable in the woodland at once).
- Defaults I used for what was not answered (change any of them): abilities stay unlocked for good; 2 points per level; Vitality +6 health, Might +3 %, Agility -2 dash ticks (first 6 points) and +0.5 % speed; free respec in Lanternfen; level gap rule off; 95 village EXP.
- Built: quest data and gating, the new training order, the stat points and Sprint in exploration (`docs/architecture.md` "The village sequence, unlocks and stat points"). Codex task: `docs/CODEX_TASK_progression.md`.

## Part A. The village sequence (one task unlocks the next)

### A1. The rule

- The main chain is **Mira -> Tovan -> Elder -> Edda**. You cannot start a step before the one before it is finished. Talking to a main NPC too early gets a short "not yet" line that points at the right person (no new story, no flag).
- The two flavour villagers (child, worker) can be talked to any time; they never give tasks.
- Each combat ability **unlocks when the task that teaches it begins** (attack unlocks at the attack task, not before). Until then the key does nothing and the HUD shows that slot locked.
- A HUD **objective line** always names the current task and the person or place to go to (and a small marker over that NPC).
- The east road to the Woodland Approach is **closed until the chain is done**. Walking into it shows a line ("The rune gate holds. Finish your tasks in Lanternfen first.") instead of leaving.

### A2. The steps

| # | Who / where | Task | Unlocks | Reward | Flag set when done | Objective line shown |
|---|---|---|---|---|---|---|
| 0 | Intro cutscene, then the gate | none | walking only (no dash, no sword, no HUD) | | `intro_seen` | "Speak to Mira by the gate." |
| 1 | **Mira**, gate | Story talk: the broken key, the dark beacons, the map. She sends him to the smith. | Map / objective line | 10 EXP | `mira_done` (was `met_mira`) | "Visit Tovan at the forge." |
| 2a | **Tovan**, forge | Talk: he hands over the Black Katana (receipt popup). | the sword | Black Katana | `received_first_sword`, `met_tovan` | "Train at the post in the yard." |
| 2b | Training post, task 1 **Attack** | Hit the post 3 times. | **attack** (and the 3-hit combo) | 10 EXP | `lesson_attack` | "Strike the post three times." |
| 2c | task 2 **Dash** | Dash through the marked ring. | **dash** | 10 EXP | `lesson_dash` | "Dash through the ring." |
| 2d | task 3 **Parry** | Parry the post's gold wind-up. | **parry** | 10 EXP | `lesson_parry` | "Parry the gold warning." |
| 2e | task 4 **Dodge** | Dash out of the red warning (uses dash, so it comes after). | nothing new (red = dash) | 10 EXP | `lesson_dodge`, `training_done` | "Dash out of the red warning." |
| 2f | **Tovan** | Graduation talk. | | 10 EXP | `tovan_done` (was `tovan_graduated`) | "Speak to the Elder at the shrine." |
| 3 | **Elder**, shrine | Lore talk about the road and the rune gate, then a small errand: fetch the herb basket from the chest on the west lawn and bring it back. Teaches **interacting with an object**. | **item slot 1** (herbs, key 1) | 2 herbs, 15 EXP | `elder_done` | "Open the chest on the west lawn." then "Take the basket to the Elder." |
| 4 | **Edda**, hut door | Aspect lesson: open the menu (TAB) and equip an Aspect. She asks him to find the Thornback Stag in the forest. | **Aspect socket 1** (menu only for now) | 20 EXP | `edda_done` (was `lesson_aspect`) | "Follow the east road into the Woodland Approach." |
| 5 | East gate | The road opens when `edda_done` is set. | the exit | | `road_open` | |

**Total village EXP: 95** (Mira 10, five Tovan tasks 50, Elder 15, Edda 20; see B3). The hero leaves Lanternfen at level 3.

### A3. What changes in the game (so the owner can judge the work)

Core (Claude), data first:
- `data/quests/chapter1.json`: the steps above as data (`id`, `requires` flags, `giver`, `objective` text, `target` NPC or object id, `unlocks`, `reward {exp, items}`, `done_flag`). One validator, like the dialogue book.
- `ExploreSnapshot.objective` ({text, target id, position}) and `ExploreSnapshot.unlocked` ({attack, dash, parry, item_slot_1, aspect_socket_1}). The HUD locks read it.
- Input filter in `ExploreCore`: attack, dash, parry, herbs and Aspect equip are ignored until their unlock flag exists (`unlocked_attack`, `unlocked_dash`, ...). The training yard teaches in the new order **attack, dash, parry, dodge** (today it is dash, attack, parry, dodge).
- Dialogue: every main NPC gets a "not yet" entry for each earlier step missing (the dialogue book already picks by flags, so this is data only, about 8 new lines; the 60-line budget has room, today 47).
- A gated exit (`requires` flag on the exit row; blocked line event) and an openable chest object (event `item_received` once, flag).
- Debug: a flag `debug_all_unlocked` (the debug jumps set it) so every scene stays testable.

Presentation (Codex), after the data exists: objective line and NPC marker, locked HUD slots, blocked-exit message, the yard's new order. A task file will follow once the owner approves this plan.

### A4. Open questions for A

1. **DECIDE:** is the order Mira, Tovan, Elder, Edda right, with Edda last? Or Edda before the Elder?
2. **DECIDE:** does an unlocked ability stay unlocked for good (my proposal), or only inside the yard until Tovan finishes?
3. **DECIDE:** the Elder's errand (fetch the basket from the west chest). Other idea: the Elder asks him to light the shrine lantern (teaches interact, no new object needed).
4. **DECIDE:** the east road closed until Edda (my proposal), or open after Tovan so a strong player can skip the Elder and Edda?
5. **DECIDE:** should quests pay EXP (my proposal, 95 in the village) or only fights?
6. The Aspect socket unlock is only a menu equip today (Aspect skills are not usable against mobs yet): is that acceptable for Chapter 1, or should the Aspect lesson wait until skills work in the woodland?

## Part B. Stats and balance

### B1. What the numbers are now (all in `core/tuning.gd`)

| | Value |
|---|---|
| Hero | 100 HP, radius 6, walk 1.0 px/tick, dash 6 ticks, 8 i-frames, cooldown 40 ticks, parry window 14 ticks (perfect 6) |
| Katana combo | 3 swings, 10 / 12 / 20 damage (x`damage_mult`), 19 / 18 / 29 ticks each, one full combo about 1.1 s for 42 damage |
| Armored boss | takes 25 % from normal hits (2.5 / 3 / 5), x4 while the posture is broken; posture is the real damage route |
| Herb | heals 35, slot 1 |
| Level (built) | levels 1-10; each level above 1: +10 max HP and +5 % damage (automatic); EXP to next: 30, 50, 80, 120, 170, 230, 300, 380, 470 |
| Mossling | Lv 1, 30 HP, 10 EXP, gold lunge 12 damage, 40 % herb drop |
| Boar | Lv 2, 70 HP, 25 EXP, red charge 20 damage, 60 % herb drop |
| Colossus | 380 HP, posture 100; slam 30 (gold), sweep 20 (gold), combo 25, red shards and a charge 28 |

What this means in play (level 1, no stat points): a Mossling dies to one full combo; a Boar to two; the hero survives 8 Mossling lunges or 5 Boar charges before dying; the Colossus is 5 slams.

### B2. Do we want stat points? Two options

**Option A (built today): automatic growth.** Every level gives +10 max HP and +5 % damage. Simple, nothing to explain, no menu. The hero is the same at a given level for every player. Risk: no choices, so levels feel passive.

**Option B (proposed): automatic base plus points to spend.** Every level gives a small automatic gain so a player who ignores the menu is fine, and **2 stat points** to spend in the character menu (TAB). Three stats, each modest (the design says stat boosts stay small; learning the attacks is the real power):

| Stat | Per point | Cap | What it is for |
|---|---|---|---|
| **Vitality** | +6 max HP | 10 | survive mistakes |
| **Might** | +3 % damage (also against armored bosses) | 10 | faster fights |
| **Agility** | dash cooldown -2 ticks (40 -> 28 at 6 points), walk +0.5 % | 6 for the dash part | more dashes in a red pattern |

- Automatic per level: +5 max HP. Level up still heals to full.
- Points: 2 per level from level 2 (18 in total at level 10; 8 at level 5, which is where Chapter 1 ends).
- Respec: free at any Lanternfen checkpoint (the village menu), so experiments are cheap.
- The HUD shows a small "!" on the menu button while points are unspent.
- No defence stat on purpose: damage soaking would undermine "gold = parry, red = dodge".

Examples at level 5 (8 points, +20 automatic HP): all Vitality = 168 HP (a Colossus slam then takes 5.6 hits instead of 4.0 with the automatic gain only); all Might = +24 % damage; balanced 3 / 3 / 2 = 138 HP, +9 % damage, dash cooldown 36. The spread between builds stays under about 20 % so no build breaks a fight.

**DECIDE:** A or B? (Recommendation: B, with the numbers above as the starting point.)

### B3. EXP budget and the expected level

Cumulative EXP needed: L2 30, L3 80, L4 160, L5 280, L6 450, L7 680.

| Milestone | EXP from it | Total | Expected level |
|---|---|---|---|
| Village tasks (A2) | 95 | 95 | **3** |
| Woodland west (3 Mosslings) | 30 | 125 | 3 |
| Woodland camp (2 Mosslings, optional) | 20 | 145 | 3 |
| Woodland east (2 Boars) | 50 | 195 | **4** |
| Lantern Wood fights (proposal: 2 Mosslings + 1 Boar + puzzle EXP 20) | 65 | 260 | 4 |
| Thornback Stag mini-boss (proposal 60) | 60 | 320 | **5** |
| Colossus (proposal 100) | 100 | 420 | 5 |

So the hero meets the Colossus at **level 5** with 8 points spent (B). A player who skips the optional camp is still level 4 at the Stag; one who clears everything is level 5.

### B4. Difficulty targets to tune against (playtest, not facts)

| Fight | Hero level | A decent player should lose | Too easy if | Too hard if |
|---|---|---|---|---|
| 3 Mosslings, west | 3 | 15 - 25 HP | under 5 HP | dies or needs a herb |
| Camp ambush | 3 | 15 - 25 HP | | |
| 2 Boars, east | 3 - 4 | 30 - 45 HP | no charge ever lands | dies twice |
| Stag | 4 - 5 | about half of the health bar | | |
| Colossus | 5 | the whole bar once, a second try wins | first try wins easily | a third try needed |

**Level gap rule (optional, DECIDE):** a mob 2 or more levels above the hero hits 10 % harder per level of gap; 2 or more levels below, 10 % softer. Keeps early areas safe to grind a little and stops over-levelling from deleting the Colossus. Off by default.

### B5. What changes in the game for Part B

If Option B is chosen: `SaveProfile` gets the three stats and the unspent points (optional fields, old saves start at zero); `ExploreCore` exposes them in the snapshot and applies them (`hero_max_hp`, `damage_mult`, dash cooldown); the character menu gets a stats panel and a respec button (Codex draws it, Claude supplies `spend_point(stat)` and `respec()`); new tests for the maths and the save. If Option A stays: nothing to build, only the numbers in B3.

### B6. Open questions for B

1. **DECIDE:** Option A or B (and the three stats: do you want a different set, for example a Focus stat for Edge and Aspect cooldowns once Aspects work in exploration)?
2. **DECIDE:** points per level (2 proposed) and the per-point strengths.
3. **DECIDE:** respec free at Lanternfen, or a cost?
4. **DECIDE:** the level gap rule on or off.
5. Is level 5 at the Colossus the intended power level, or should the first chapter end at level 4 (cut the Lantern Wood fights) or 6 (more EXP)?
6. The EXP for the forest fights, the Stag and the Colossus are guesses; those fights are not built yet.

## Suggested order of work after approval

1. Claude: quest data, objective and unlock snapshot, input filter, gated exit, openable chest, the training order change, "not yet" dialogue, tests. Then a Codex task for the objective line, locks, exit message and the yard prompts.
2. Claude (if Option B): stat points core and save. Codex: stats panel in the menu.
3. Claude: forest and Stag encounter data once the EXP table is approved.
