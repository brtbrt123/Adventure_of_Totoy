# Intro presentation implementation

The owner approved the seven panels before this implementation. Runtime integration is presentation-only; the existing cutscene book provides all narration, beat order, hold durations and story-flag identity.

## Behaviour

- Fixed 60 Hz stepping. Text reveals at 38 characters/second. First next press reveals the caption, second begins the next beat. The hold counter starts only after reveal completes.
- Each interbeat fade takes 12 ticks out and 12 ticks in. Skip is accepted during either fade. Completion/skip saves the book's flag immediately and only once, loading the latest profile so record/loadout changes are preserved. The final 18-tick fade hands over to exploration's incoming fade.
- Arrival metadata selects `village_layered` / `arrival` and requests `intro_arrival`. The exploration integration sends 18 ordinary downward movement intents through the core after its fade, then opens the controls card.
- Captions use the shared teal card and case-preserving real font. Current draft captions fit the 32-pixel bottom card. Stable full-text wrapping prevents words moving while they reveal; longer future captions can expand the card upward.
- Quiet looping original intro music, one restrained cue per relevant beat, forest ambience during weather/road. A nonempty data sound cue overrides the presentation default. No per-character sounds or narration voices.

## Pixel-grid decision

Native panels draw at scale 1. Overscan panels use a 320x180 source region with integer offsets and no texture scaling. `pan_down` advances downward across the overscan. `slow_zoom` deliberately uses a four-pixel horizontal focal drift instead of fractional scaling, which would violate the project's integer-only rendering rule. Caption text and card never move with the art. The final gate uses its native panel so it retains the approved framing.

## Verification

Installed engine reports Godot 4.7.2 stable. Headless import completed with no script parse errors. The sandbox blocked writing editor settings outside the workspace and reported the machine's certificate-store warning.

`tests/smoke_intro_cutscene.gd` passes, including actual title callbacks, skip/finish persistence and exactly-once handover, Continue bypass, subsequent New Game replay, reveal/hold ordering, interbeat fades, sound override, current-caption bounds, integer crops, fresh-profile preservation and real exploration arrival movement/controls timing. It redirects saves to `res://art/build/arena_intro_smoke_save.json`, deletes the fixture and restores the previous save environment/metas; it never writes the real player save. Final focused execution returned exit 0 with `INTRO CUTSCENE SMOKE OK`; only the machine certificate-store warning remained.

Parent agent owns final windowed captures, full harness and integration reporting. Music mix, pacing, caption readability at the owner's window size and movement feel need human playtesting. Claude cross-review remains separate. No core/data/docs/tools/harness edits or Git mutations were made by this subagent.
