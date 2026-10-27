# Recorded combat cues

Replaces the rejected procedural sound set. All active cues now derive from downloaded CC0 recordings by StarNinjas, artisticdude and Kenney. See LICENSES and sources.json for credits, exact source files, hashes and mixing/pitch edits. Original selected recordings are retained in sources/; unused download archives live only in the ignored .godot cache.

The processed cues are 44.1 kHz mono 16-bit PCM, trimmed to remove leading silence, with bounded peaks and faded tails. Three armor-hit variations and two swing variations alternate during gameplay. Early deflect uses a shorter clash; perfect parry uses a longer clash with a low metal impact. Counter, posture break and damage use recorded impact layers. Warnings use subdued foley instead of synthetic beeps.

preview.wav plays: swing, ordinary hit, early deflect, perfect parry, heavy counter, posture break. There is a pause between cues. Human listening approval is still pending; waveform checks do not establish that the sound fits the game.

## Golem strikes and boss music

All six boss patterns now sound at live snapshot hit_tick, including misses: slam/combo share a heavy slam, stomp has a deeper impact, sweep a broad whoosh, charge a rushing impact, and shards a beam burst. Multiple shard lines share one cue; combo impacts sound separately. Interrupted tells produce no delayed strike. Perfect parry now includes Brian MacIntosh's recorded metallic clang; early deflect has a shorter metal clash.

Heavy Boss Battle 1 by MintoDog (CC0) loops during combat, fades out on the result, and restarts from the beginning on retry. Music is mixed below effects at -18 dB and briefly ducks to -25 dB for major impacts/parries. These are presentation timing/mixing choices; no core rules changed.

battle_mix_preview.wav is an illustrative 12-second offline mix of the track and new cues, not a gameplay recording (runtime ducking is not included). Human listening approval remains necessary. Source credits and hashes are retained in sources.json and LICENSES.

Follow-up: the human found the beam sound inconsistent. golem_beam.wav now layers swish-3 with impactMining_002, removing the sword-clash recording. The earlier battle_mix_preview.wav documents the previous mix; listen to the individual golem_beam.wav for the current beam cue.


Aspect VFX integration: skill_started now plays preparation cues (Breaking Edge: swing, Gale Cut: dash, Moon Cleave: restrained warning foley). On skill_released (deduplicated by attack_id), distinct release keys play swing_2, swing and golem_sweep respectively. Moon release briefly ducks music. Confirmed attack_hit events retain impact sounds and heavier Moon sparks; a whiff has a release but no fabricated impact. Interrupted windups never schedule a release. These routes reuse the credited processed recordings, with no additional downloads or licence changes.


Readability follow-up: Moon preparation now uses the recorded posture_break layer at 0.7 pitch and 5 dB lower gain, creating a longer, lower charge distinct from its full-strength break use. Moon release is pitched to0.8 and Breaking Edge release to1.15; every other cue restores pitch1.0 on voice reuse. Breaking Edge confirmed hits use the heavier impact recording. No new sources or licences.


Dedicated skill release mixes (2026-10-17): skill_gale_release layers dash and the broad sweep whoosh; skill_moon_release layers beam rush, a slowed sword swing and a quiet resonant impact tail; skill_breaking_release layers a sharp swing and metallic clash. All derive from the already credited processed CC0 recordings. sources.json records gains/pitches and normalization. Each mono44100Hz/16-bit WAV peaks below0.86 with faded endpoints. Release cues play 2dB above the old mix and all three briefly duck music. Moon preparation is now only2dB below base instead of5dB. skill_release_preview.wav demonstrates X, C, Z in that order. Human listening approval remains necessary.


## Village practice and Lanternfen Evening (2026-10-27)

`presentation/explore/village_audio.gd` reuses the same credited recorded `swing`, `armor_hit`, `perfect_parry` and `deflect` cues during practice, plus subdued gold/red warnings. Whiffs swish only on the snapshot's active transition; confirmed training-post/parry events choose contact cues. No synthesized replacement of the approved combat recordings.

`music/lanternfen_evening.wav` is an original 26.667-second instrumental loop at 72 BPM: sparse plucked mallet notes over warm sustained chords, no percussion. It was synthesized locally, with no third-party melody or downloaded audio; the score, instrumentation and rendering settings are recorded in `music/lanternfen_evening.score.json`. Stereo PCM, 32 kHz, 16 bit, peak 0.6 before runtime gain; circular voice tails/reflections for continuous looping. Runtime mix is -26 dB with short ducking to -32 dB on parries/strong cues. Only village scenes enable it; it fades away in the forest/glade. Human listening approval remains pending.
