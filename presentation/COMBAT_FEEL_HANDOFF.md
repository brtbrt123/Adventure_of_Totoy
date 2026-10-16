# Sword combo presentation and combat feedback

Built against core commit 42b6326 and docs/architecture.md, Sword combo (player). No core edits.

## Implemented

- Every attack phase reads combo_index 1-3 and chooses hero2_attack1/2/3. Phase frames 1-2, 3-4 and 5-6 are spread over that swing's current-state duration from SWING_WINDUP_TICKS, SWING_ACTIVE_TICKS and SWING_RECOVERY_TICKS. No timing numbers are duplicated in presentation. Frame selection is stateless: changes in state or combo index take effect immediately; idle grace never selects attack art.
- Swing-three confirmed hits get a larger spark, slightly longer shake and heavier sound. Counter hits retain their own event-based effect. Successful parry has distinct early/perfect cues and different spark intensity. Brief contact flashes stay local.
- Contact points are visual offsets from the authoritative event position to the body/weapon, instead of painting sparks under the target's feet. Stored event origins, hit decisions, telegraphs and actor world positions remain unchanged.
- Ten event cues from CC0 recordings by StarNinjas, artisticdude and Kenney cover swings, armored hits, finisher/counter hits, early/perfect deflects, posture breaks, player damage, dash and red/gold warnings. No audio from commercial games. Credits, original source recordings, hashes and mixing edits are in presentation/audio/. Three armor-hit and two swing variants alternate. Eight playback voices; same-tick shard warnings deduplicate. Headless runs verify routing but skip audible playback. Restart stops all sounds and clears deduplication.

## Core follow-up for the requested deflect-driven duel

The current perfect parry instantly fills boss posture and clears its attack. Normal attacks add little posture; the existing boss spends long periods winding up and recovering. Presentation feedback alone cannot change that exchange.

Propose to the human before changing game design: timed sequences of gold strikes that can be deflected individually; posture pressure accumulated across attacks and deflects rather than an automatic break on every perfect parry; clear retaliation after a blocked player combo; short defined defensive-cancel windows and input buffers; posture recovery that responds to recent pressure and/or health; a distinct payoff when posture finally breaks. Preserve red dodge-only attacks and exact snapshot warning/hit geometry. Any simulation hit-stop must come from core with documented input-buffer behaviour; presentation must not freeze the simulation independently or hide dangerous ticks behind a frozen render.

This follows the attack/deflect/posture emphasis described in the publisher's [Sekiro mechanics guide](https://support.activision.com/sekiro/articles/sekiro-shadows-die-twice-game-mechanics), adapted to Totoy's gold/red rules. These are proposals, not implemented game rules or a claim that the game now feels like Sekiro.

## Verification and human review

smoke_combo_presentation checks every phase boundary of every swing from tuning, real buffered recovery-to-windup chains, all three confirmed hits and the heavier finisher cue, idle grace, early/perfect parry audio and a real counter. smoke_animation exercises all 18 attack frames during real core lifetimes. smoke_effects verifies hit-contact placement and event-to-audio routing. `python harness/checks/run_tests.py --worktree .` passed: Python tests, Godot import, core tests and every smoke suite. Art validator and PCM asset checks also passed.

Windowed --capture saves arena_combo_hit_1/2/3, early_deflect, perfect_parry and counter screenshots. Human listening, timing/feel and fun still require playtesting. Cross-review by Claude is still pending under the earlier disclosure-approval restriction; do not claim it passed. Nothing is merged.

## Recorded audio replacement

The human rejected the procedural cues. All active sound files now derive from downloaded CC0 recordings; no oscillator synthesis remains in this set. Original selected recordings and creator credits are retained. See presentation/audio/README.md and sources.json for the per-cue layers and processing. preview.wav gives a short listening comparison; perceived quality and fit remain the human's decision. No core changes.

Recorded-set validation: Godot import, windowed combo/parry playback fixture and `python harness/checks/run_tests.py --worktree .` all pass. All 14 processed WAVs have bounded peaks and faded endpoints; the 18 retained source recordings match their saved SHA-256 hashes. Human listening approval and the previously blocked Claude cross-review remain pending.
