# Recorded combat cues

Replaces the rejected procedural sound set. All active cues now derive from downloaded CC0 recordings by StarNinjas, artisticdude and Kenney. See LICENSES and sources.json for credits, exact source files, hashes and mixing/pitch edits. Original selected recordings are retained in sources/; unused download archives live only in the ignored .godot cache.

The processed cues are 44.1 kHz mono 16-bit PCM, trimmed to remove leading silence, with bounded peaks and faded tails. Three armor-hit variations and two swing variations alternate during gameplay. Early deflect uses a shorter clash; perfect parry uses a longer clash with a low metal impact. Counter, posture break and damage use recorded impact layers. Warnings use subdued foley instead of synthetic beeps.

preview.wav plays: swing, ordinary hit, early deflect, perfect parry, heavy counter, posture break. There is a pause between cues. Human listening approval is still pending; waveform checks do not establish that the sound fits the game.

## Golem strikes and boss music

All six boss patterns now sound at live snapshot hit_tick, including misses: slam/combo share a heavy slam, stomp has a deeper impact, sweep a broad whoosh, charge a rushing impact, and shards a beam burst. Multiple shard lines share one cue; combo impacts sound separately. Interrupted tells produce no delayed strike. Perfect parry now includes Brian MacIntosh's recorded metallic clang; early deflect has a shorter metal clash.

Heavy Boss Battle 1 by MintoDog (CC0) loops during combat, fades out on the result, and restarts from the beginning on retry. Music is mixed below effects at -18 dB and briefly ducks to -25 dB for major impacts/parries. These are presentation timing/mixing choices; no core rules changed.

battle_mix_preview.wav is an illustrative 12-second offline mix of the track and new cues, not a gameplay recording (runtime ducking is not included). Human listening approval remains necessary. Source credits and hashes are retained in sources.json and LICENSES.

Follow-up: the human found the beam sound inconsistent. golem_beam.wav now layers swish-3 with impactMining_002, removing the sword-clash recording. The earlier battle_mix_preview.wav documents the previous mix; listen to the individual golem_beam.wav for the current beam cue.
