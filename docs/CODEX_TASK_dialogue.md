# Codex task: the dialogue box (2026-10-27)

Claude finished the core side; contract in `docs/architecture.md` "Dialogue and story flags". The lines in `data/dialogue/chapter1.json` are placeholders the owner will rewrite, so never copy their text into presentation. Nothing here switches the chapter route.

## Your tasks (presentation/ and art/ only)

1. **Input.** `explore_scene.gd` builds the InputFrame: keep `interact_pressed` on E and add Enter / Space as "next". Add a skip key and set `frame.skip_pressed`. While `snapshot.dialogue` is not empty, E / Enter go to the dialogue; the hero does not move (the core already ignores move and dash).
2. **Box.** Draw it from `snapshot.dialogue` when not empty: `speaker` (name plate), `portrait` (a name such as `mira`; list below), `text` typed out character by character, a "next" marker when the line is complete, `index + 1 / count` optional. Fits 320x180: lines are at most 110 characters (validated), so about three lines of the UI font. UI text is the real font (ADR 0004).
3. **Typewriter rule.** A press while the text is still typing finishes the typing and is NOT sent to the core; the next press is sent as `interact_pressed`. The skip key is sent at once.
4. **Replace the `...` bubble.** The placeholder bubble on `interact` (`BUBBLE_TICKS`) goes away for NPCs that have a conversation (the core now emits `dialogue_started` after `interact`); objects (sign, chest, door, dummy) keep their current behaviour until the next step.
5. **Save.** On `flag_set` (and `dialogue_ended`) copy `snapshot.story_flags` into `SaveProfile.story_flags` and save; when building the core for a scene (new game, CONTINUE, scene change, debug jump) call `core.set_story_flags(profile.story_flags)`. A new game already clears the flags (`reset_progress`).
6. **Portraits.** Names in the book: `mira`, `tovan`, `edda`, `elder`, `child`, `worker`. Use the existing NPC art or portraits where they exist; tell me which are missing (the book can point a line at another name via `portrait`).
7. **Tests.** A smoke test: talk to Mira in the village (painted and layered), advance through every line with E, check the box text equals `snapshot.dialogue.text` at every step, skip another conversation, check the flags in the saved profile (use the smoke tests' separate save path, never the player's save), CONTINUE restores the flags (Mira says her follow-up).

## Do not

- Put dialogue rules or text in presentation, or edit `core/` or `data/dialogue/`. If you need something from the core (a line's emotion, a choice, a callback on a line), describe it here for me.
