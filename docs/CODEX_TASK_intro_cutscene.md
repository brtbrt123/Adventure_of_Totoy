# Codex task: the New Game intro cutscene (2026-10-28)

The owner wants a story cutscene when New Game is clicked: what happened to the valley and how Totoy ends up at Lanternfen's gate. Claude wrote the data and the rules; you build the scene and the art. Stay in `presentation/` and `art/`. Do not edit `core/` or `data/` (ask Claude for changes). Send the panel art for the owner's review before installing it. Never merge to main.

## What exists (core and data)

- `data/cutscenes/intro.json`: the cutscene `intro`, 7 beats, each `{id, art (placeholder panel id), effect (fade_in, slow_zoom, pan_down, flash), hold (ticks at 60/s, how long it stays after the text is shown), sound (cue id, empty for now), lines (1-3 caption lines)}`; `music` `intro_theme`; `skippable` true; `flag` `intro_seen`. The text is PLACEHOLDER drafted from the design docs; the owner rewrites it (readable copy: `docs/CUTSCENE_intro.md`). Read it through `core/cutscene_book.gd` (`default_book()`, `beats(book, &"intro")`, `flag_of`, `is_seen`); `validate()` already checks the limits (110 characters a line, 3 lines a beat, 12 beats).
- The flag: when the cutscene ends or is skipped, add `intro_seen` to the profile's `story_flags` and save. NEW GAME clears flags (`SaveProfile.reset_progress`), so it plays on every New Game; Continue never plays it.

## Your jobs

1. **Flow.** New Game: reset progress (as now), play the `intro` cutscene, then start `village_layered` at entry `arrival` as now. Skip (Escape or the dialogue skip key, shown on screen) ends it at once; the flag is set either way. A `--skip-intro` style switch or the smokes' existing start meta must still bypass it so the other smokes do not wait.
2. **The scene.** A full-screen panel per beat: the beat's picture with its `effect`, the caption lines under it in the shared dialogue/card style with the typewriter reveal (first press completes the text, second press goes to the next beat; it also advances by itself after `hold` ticks once the text is complete), fades between beats and a fade into the village. Music `intro_theme` and an optional per-beat `sound`; keep the village music for after.
3. **The last beat leads into the game.** The final beat is the rune gate opening; hand over to the village arrival (Totoy walking in through the gate) without a hard cut.
4. **Art, for review first.** Seven panels at the game's 320x180 (or a larger source scaled with the project palette rules, same pixel-art style as the maps): night of lights with six beacons, the dark hills with one lit, the Heartloom, strange weather over the valley, Totoy waking on a road with the broken key, Lanternfen's lantern seen from above, the rune gate. Ids are in `intro.json` (`intro_01_night_of_lights` ... `intro_07_the_rune_gate`). Totoy appears unarmed (he gets the sword from Tovan). Use the approved hero look; no reserved combat gold/red in the scenery.
5. **Tests and captures.** A smoke: New Game plays the intro, skipping sets the flag and starts the village, finishing it does the same, Continue does not play it, New Game after a finished game plays it again. Captures of every beat. Run the full harness. Report what passed and what the owner must review.

## Not judged by Claude

The story text, the art, the pacing and the music.
