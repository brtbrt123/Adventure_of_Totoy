# Codex task: the village tutorial (2026-10-27)

Claude finished the core side: `docs/architecture.md` "Training post and the village tutorial" and "Dialogue and story flags" (do that task, `CODEX_TASK_dialogue.md`, first or together). The post teaches dash, attack, parry and dodge; presentation shows it. Never put rules in presentation: the core says what is taught, hit or parried.

## Your tasks (presentation/ and art/ only)

1. **Input in exploration.** `explore_scene.gd` builds the InputFrame: also send `attack_pressed` / `attack_held` (the fight's attack key), `parry_pressed` (the fight's parry key) and `aim` (as the fight does). The core ignores them outside the yard and before Tovan, so it is safe to always send them.
2. **Hero animation.** In the yard the hero can now be in the states `attack_windup/active/recovery`, `parry`, `parry_recovery`: use the fight's frames (`ArenaAnimation`). Parry spark and hit sparks: reuse the fight's effects on `parry_succeeded` (the payload has the same keys; `attacker_id` is 100).
3. **The post's warning.** `snapshot.telegraphs` holds the fight's `TelegraphSnapshot` (gold cone = parry it, red circle = dodge it). Draw it with the fight's telegraph drawing (same colours, same fill-up to `hit_tick`). The post itself needs a hit reaction (wobble or flash) on `training_post_hit` (`snapshot.training.since_hit` counts ticks since the last hit), and a swing pose or glow during the warning if you want one.
4. **Prompts.** `snapshot.training.hint` is `dash`, `attack`, `parry`, `dodge` or empty. Show one short, real-font line near the post for the hint, with the key names from the input map (for example "DASH: Space", "ATTACK 3 TIMES: left click (n/3)" using `training.hits`/`hits_needed`, "PARRY: press just before the GOLD hit", "DODGE: dash through the RED hit"). `training.lessons` has the four checks; a small checklist while `training.active` is nice. On `training_hero_hit` show "TRY AGAIN" (no damage); on `training_dodged` and when a lesson flag appears in `flag_set` show a short confirmation. When `training.done` is true show "TRAINING COMPLETE" once.
5. **Not awake yet.** Before `met_tovan` (`training.awake` false) the post does nothing: keep the current "look" hint.
6. **The other tutorial lines.** (a) A controls card the first time the village loads (move, dash, interact E, the menu Tab; the key names come from the input map), saved as the story flag `seen_controls` (`core.set_flag(&"seen_controls")`, then it is in `snapshot.story_flags` and the save). (b) When the character menu equips an Aspect, call `core.set_flag(&"lesson_aspect")` (Edda's follow-up reads it).
7. **Tests.** A smoke test in the village (painted and layered): set `met_tovan`, walk to the post, swing three times (the box/hint counts to 3), see the gold warning drawn, parry it, see the red warning and dash, check the four `lesson_*` flags and `training_done` in `snapshot.story_flags`, and that the saved profile has them (use the smoke tests' own save path).

## Do not

- Decide hits, parries or lesson completion in presentation, or edit `core/`. If you need something (a different timing, a pose hook, a lesson 5), describe it here for me.
