# Recorded combat cues

Replaces the rejected procedural sound set. All active cues now derive from downloaded CC0 recordings by StarNinjas, artisticdude and Kenney. See LICENSES and sources.json for credits, exact source files, hashes and mixing/pitch edits. Original selected recordings are retained in sources/; unused download archives live only in the ignored .godot cache.

The processed cues are 44.1 kHz mono 16-bit PCM, trimmed to remove leading silence, with bounded peaks and faded tails. Three armor-hit variations and two swing variations alternate during gameplay. Early deflect uses a shorter clash; perfect parry uses a longer clash with a low metal impact. Counter, posture break and damage use recorded impact layers. Warnings use subdued foley instead of synthetic beeps.

preview.wav plays: swing, ordinary hit, early deflect, perfect parry, heavy counter, posture break. There is a pause between cues. Human listening approval is still pending; waveform checks do not establish that the sound fits the game.
