# Codex task: wire in the owner's sounds (2026-10-27)

The owner decided to use the sounds they made or brought, not the downloaded CC0 candidates. They are in `data/audio/owner_sounds/` (`sources.json` has their origin; licence still to be confirmed by the owner, see below). Move or copy what you use into `presentation/audio/` the way the existing cues are, add the entries to `presentation/audio/sources.json` and the README, and keep the credits honest (do not mark them CC0). Human listening approval is still pending for all of them: the owner cannot judge them by waveform either, so use the same ducking and levels as the existing cues and tell the owner which events got which file.

## Where each sound goes

| File | Event / moment | Notes |
|---|---|---|
| `electric_shock.mp3` | start of the Dual Dagger lightning skill (`lightning_barrage_started`) | the owner chose it for this; it is about 5 s long: play only the first 1.5-2 s with a fade, or ask the owner to trim it in Audacity |
| `lightning_barrage_hum.wav` | under the barrage while it runs (`lightning_barrage_started` to `lightning_barrage_ended`), quiet | 2.8 s: loop or play once, your call |
| `lightning_blink.wav` | each `lightning_blink` | short |
| `lightning_crack.wav` | each `lightning_strike` (the finisher) | |
| `sprint_whoosh.wav` | `sprint_started` | |
| `echo_place.wav` | `echo_placed` | quiet source, already normalised |
| `echo_recall.wav` | `echo_recall` | |
| `ward_raise.wav` | `ward_raised` | |
| `ward_release.wav` | `ward_released` | duck music like the other heavy impacts |
| `phantom_cut.wav` | `phantom_cut_started` | |
| `chain_coil.wav` | `reaper_coil_started` | the hook, drag and spin keep the existing cues |
| `aspect_bind.wav` | an Aspect equipped in the character menu (`aspect_equipped`), also Edda's lesson | |
| `root_gate_open.wav` | `gate_changed` with `gate_open` true (forest and forest_layered) | 2.9 s |
| `lantern_light.wav` | `switch_lit` | |
| `chest_open.wav` | the chest interaction (`interact` with target `chest`) | |
| `lesson_complete.wav` | a `lesson_*` or `training_done` `flag_set` in the village practice | |
| `try_again.wav` | `training_hero_hit` | |
| `night_forest_ambience.wav` | loop under the forest and glade (`forest`, `forest_layered`, `glade`, `glade_layered`), very low | 20 s: the loop seam is NOT checked; test it and crossfade or retime if it clicks. Fade it out in the village, like the village music does the other way |
| `beacon_light.wav` | reserved for the beacon epilogue, not used yet | |
| `stag_growl.wav`, `stag_charge.wav`, `stag_defeat.wav` | reserved for the Stag fight (not built yet) | |
| `mossling_hit.wav` | reserved for the Mossling (not built yet) | |

Dialogue typewriter blip: `data/audio/cc0/dialogue_blip.ogg` (Kenney tick, CC0; the owner did not like the generated one). Play it quietly on each typed character, no more often than every 2-3 characters, and not on spaces; the next-line press can stay silent or reuse it. Credit Kenney in `presentation/audio/sources.json`.

## Notes

- Everything here is 44.1 or 48 kHz stereo 16-bit WAV, peaks 0.6-0.9; the loud ones are not clipped.
- Do not edit `core/`. If an event you need does not exist (the chest has no "opened" event, only `interact`), say so in your notes.
- Open for the owner: confirm the ElevenLabs plan's licence, and the source and licence of `electric_shock.mp3` (a YouTube download), or have you replace it with `lightning_barrage_hum.wav` before a release.
