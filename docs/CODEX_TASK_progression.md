# Codex task: the village sequence, locks, objective line and stat points (2026-10-28)

The owner approved `docs/PROGRESSION_PLAN.md` (order Mira, Tovan, Elder, Edda; abilities unlock when their task begins; tasks pay EXP and rewards; stat points option B; Sprint from Edda). Claude built the core and data side (read `docs/architecture.md` "The village sequence, unlocks and stat points" first). Stay in `presentation/`, `art/` and your tests; do not edit `core/` or `data/` (ask Claude). Send new art for the owner's review before installing it. Never merge to main.

## What the core now does

- Data `data/quests/chapter1.json`, 12 steps, 95 EXP. `snapshot.objective` {id, text, target, position} is the current task ({} when none). `snapshot.unlocked` {attack, dash, parry, item_slot_1, aspect_socket_1}. The core ignores a locked ability's input, so a locked key simply does nothing: your UI must say why.
- The training order changed: **attack, dash (through a ring), parry, dodge**. `snapshot.training` has `ring` {center, radius, active} and `hint` follows the new order.
- Events: `quest_completed` {step_id, exp, items}, `exp_gained`, `level_up` {level, max_hp, points}, `chest_opened` {object_id}, `exit_blocked` {exit_id, text}, `stat_spent`, `stats_reset`, `item_received` (now also kind `aspect`: Sprint from Edda).
- Stats: `snapshot.stats`, `stat_points_unspent`, `stat_caps`; intents `InputFrame.spend_stat` (`vitality`, `might`, `agility`) and `respec_stats` (free, only in the village). `hero.max_hp` already includes Vitality and level.
- Aspects: `snapshot.aspect_slots` [{slot, aspect, unlocked, usable}], `snapshot.owned_aspects`; `InputFrame.skill_pressed` 1-3 works only for an owned, unlocked, socketed Sprint (Edge fills on the road). Call `core.set_loadout(profile.weapon_id, profile.equipped_aspects)` on every core. Sprint is Edda's reward: save the `aspect_owned_sprint` flag as usual (story flags), and the menu may equip only `owned_aspects`.
- Saves: `profile.stats` (restore with `core.set_stats`), `profile.exp_total` (`core.set_exp`), `profile.inventory`, story flags. Save on `stat_spent`, `stats_reset`, `exp_gained`, `quest_completed`, `flag_set`.
- Debug jumps: set the story flag `debug_all_unlocked` in every debug jump (it unlocks every ability, opens the road and the Aspect sockets); otherwise a debug hero cannot dash or fight.

## Your jobs

1. **Objective line and marker.** A short line in the HUD with `objective.text` and a small marker (arrow or diamond) over `objective.position` (the NPC or object); hide it when `objective` is empty. Animate on `quest_completed` (a short "Task complete +10 EXP" toast, not blocking), and show the receipt for rewards through the existing popup.
2. **Locks.** Keys that are locked show the locked look (dimmed box with a small lock) on their HUD slot: dash, attack, parry, item slots (`unlocked`, `item_slots`, `aspect_slots`). Pressing a locked key shows a tiny "locked" hint, not a message box. Also the training cards: follow the new lesson order and draw the dash ring from `training.ring`.
3. **The east gate.** On `exit_blocked` show `text` as a short banner; the hero stays in the village.
4. **The chest.** Play the chest's open animation on `chest_opened` and a line ("The Elder's basket.").
5. **Intro to village.** The intro cutscene hands over to the village arrival (the intro task is separate).
6. **Character menu.** (TAB) Add a stats panel: the three stats with points, caps and effect text ("+6 max health a point", "+3 % damage", "shorter dash cooldown, a little faster"), `+` buttons that send `spend_stat`, the unspent points, and a Respec button (village only; send `respec_stats`). Show a "!" on the menu button while points are unspent. The Aspect tab lists only `owned_aspects` (others dimmed with a lock); equipping Sprint sets the flag `lesson_aspect` as today.
7. **Level-up.** The existing level-up banner now also says "+2 stat points".
8. **Tests and captures.** Update the smokes that assume the old village (`smoke_village_tutorial.gd`, the woodland smokes: they fight, so give them `debug_all_unlocked` or play the quest), add captures: objective line at several steps, locked HUD slots, the dash ring, the gate banner, the stats panel (spent and unspent). Run the full harness. Report what passed and what the owner must review.

## Please tell Claude if

A field you need is missing, the ring is in an awkward place (it is 52 px south of the post: `RING_OFFSET` in `core/training_yard.gd`), or a lock hides something the player can still use.

## Not judged by Claude

Everything about the look and feel: the sequence's pacing, the EXP and stat numbers, the texts.

## Smokes that fail now (full harness, everything else passes)

They encode the old village or old herb rules; give them `debug_all_unlocked` or play the quests: `smoke_explore_bot` (the village road is closed without it), `smoke_first_sword_receipt` (Tovan needs `met_mira` first), `smoke_layered_scenes` ("East exit requests woodland"), `smoke_village_tutorial` (new lesson order, ring, unlocks), `smoke_woodland_encounters` (fighting needs the unlocks), `smoke_woodland_polish` and `smoke_woodland_presentation` (the herb slot needs `unlocked_item_slot_1`).
