# Intro cutscene art review first (2026-10-28)

User explicitly requested Astra. gpt-6-astra handled composition/continuity art direction and visually reviewed all seven generated panels. Built-in imagegen produced the raster images. No core/data/runtime/tests/docs edits in this stage; existing docs/architecture.md edit untouched. Nothing installed. Owner explicitly requires review BEFORE installation.

## Selected art
art/reference/intro_cutscene_v1/raw contains full-resolution generated sources named exactly like the seven intro.json art IDs. native contains opaque320x180 Totoy36 previews excluding all four reserved combat colours. review_contact.png shows the full sequence at2x nearest size. manifest.json records source filenames/hashes, captions, effects and conversion. check_review.py checks seven data IDs, native dimensions/alpha/palette/reserved exclusion and source hashes.

1. Exactly six beacons lit over the valley.
2. Same six tower positions, only upper-right ridge beacon lit; compact Lanternfen now matches later shots.
3. Failed living root/stone loom, no villain or cause revealed. New Heartloom design is a proposal.
4. One continuous landscape with frost, rain, dry leaves, altered boar and unfamiliar road.
5. Unarmed approved-look Totoy wakes with short broken ring-handled key. New key design is a proposal.
6. Lanternfen landmarks from approved village: gate, spreading tree, forge/cottage, lantern, shrine, rune stone. Wooden gate now CLOSED before last beat.
7. Same unarmed hero/key at familiar rectangular stone gate, wood door OPEN inward; clear path into village.

## Astra review
PASS for technical continuity after correcting large-town drift in1/2 and the prematurely open gate in6. Counts/locations, unarmed identity and gate states consistent; no spoiler seen. This is not owner art approval or a gameplay cross-review.
Human review: dark shot2 readability, broken key tip at native scale, new Heartloom/key concepts, panel6 secondary forge/window lights despite caption one lantern, mood and character rendering. Keep caption card within lower~18percent in7 to avoid boots. Native reduction: area BOX, shadow gamma0.82 before fixed-palette nearest quantization, no dither. Raw AI sources themselves are not palette-validated; only native previews are. Actual caption/transition motion remains untested.

## Next after owner approval
Implement typed presentation cutscene using CutsceneBook.default_book/beats/flag_of/is_seen. New Game resets progress, routes through intro, completes/skips to village_layered arrival with intro_seen saved either way. Escape/dialogue skip shown, first advance finishes reveal, second changes beat, auto hold after reveal, fades and approved pan/zoom. Continue bypasses. Test start metadata/--skip-intro bypasses. No story text rewrite or core/data change. Music intro_theme has no supplied dedicated asset yet; do not pretend there is a recording—choose an existing suitable approved source or raise the need.
Then focused smoke for start/skip/finish/Continue/new-New-Game and existing smoke bypass updates (tests only as explicitly requested in handoff), captures every actual beat, full harness. Those runtime jobs and post-install tests are deliberately pending the explicit art gate. Review-stage checks cannot claim the intro is playable.

No merge/push. No production atlas rebuild: nothing entered art/src or runtime yet.
