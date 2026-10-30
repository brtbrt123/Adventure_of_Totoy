# Thornback existing attacks: richer FX / Astra sidecar

REVIEW ONLY. No summoning, runtime installation, gameplay edits or changed body poses.
Rebuild: `python art/reference/thornback_fx_review_v2/build_attacks_astra.py`.

- Gold slam: horn-bound teal/ice pulse, contour light, moving antler echoes, planted-hoof dust, short impact rays, double broken shockwave and ballistic rubble.
- Red charge: horn pulse, sparse spirit wisps and antler trails, repeated hoof dust; existing obstacle-crash ending with directional pale burst, stone chips and ground dust. Boulder/path are preview choreography.
- Red roots: existing phase2 gesture reused as an art proposal only, horn pulse, hoof tremor, local branching spirit veins, existing root silhouette with lit wood vein, erupting clods and rising motes. One target/root; no new mechanics.

Four GIFs (three isolated and one combined), native 288x144 stage enlarged exactly 4x nearest, 20fps. `contact_sheet.png` rows are slam/charge/roots; columns are mid tell / late tell / sampled mid-strike / first sampled recovery / later recovery. `stills/` has those 15 panels at4x. `layers/` contains back, horn, front and warning PNGs for EVERY frame; `bodies/` contains unchanged right-facing poses, `horn_masks/` the visible antler/shard ownership masks. Body/horn anchor is36,62; stage layers anchor0,0. All frame placements and exact source tick values live in `manifest.json`. Only hard alpha and Totoy36, including review composition. Gold/red occur only in warning layers; no blur, additive blending or semitransparency. Body pixels are protected from front FX; actual horn pixels receive glow; warning outlines are composited last and audited. Slam impact is registered to the lowest pixel of the existing second strike antler pose; the burst starts on that pose's source tick.

Source phase ticks remain slam54/6/48, charge56/36/40, roots50/5/40 at60Hz.20fps samples tick0,3,6...: boundaries not divisible by3 display up to2 ticks late, explicitly recorded rather than changing gameplay lengths. Reset pause is review spacing. Effects in recovery are cosmetic; they do not imply lingering damage.

`validation.json`: source palette/binary-alpha, exact uninstrumented-rig body parity, horn registration, reserved-colour isolation, visible warning integrity, preserved full36-entry GIF palettes, ALL decoded GIF pixels against authored frames, and total encoded durations PASS. Hashes confirm the rig and pre-existing Glowmoth/Stag review files remained unchanged. The prior build_review.py is never imported. No credits or image generation used.

Graphify query failed (No module named graphify). No runtime harness or Godot capture: integration, collision alignment, timing feel and in-engine lighting remain unverified. Owner judges aesthetics/motion; cross-review and approval are pending. Representative panels must be inspected separately with view_image after building.
