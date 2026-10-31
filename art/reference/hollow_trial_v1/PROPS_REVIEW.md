# Hollow Trial prop sheet — owner review pending

2026-10-31. Step2 authorized after ground approval. Branch `agent/codex/progression`; no merge. All assets below are review-only, under art/reference. The approved ground hash remains unchanged. No art/src, atlas, runtime scene/catalogue, core or data changes.

`props_raw.png` is the untouched transparent built-in imagegen output. Exact prompt/references are in PROPS_PROMPT.md. `prop_review/contact_sheet_props_2x.png` shows every palette-limited prop at the SAME2x game scale: altar dark/lit, chest closed/open, six rune-rock variants, four bushes, two root clusters, two ferns and two solid-trunk trees. Smaller decoration is intentionally much smaller than the trees. No runtime light halo or baked ground/shadow is in the sprite art.

`prop_review/native/` contains20 independent hard-alpha proposal PNGs. `prop_review/manifest.json` records inspected source crops, reduction scales, padded dimensions, feet anchors and suggested base dimensions. Altar states share64x48 canvas and anchor32,48; chest states share40x40 canvas and anchor20,40. Suggested bases44x20 and24x12 retain the brief. The generated state pairs are visually related but not pixel-identical bodies; final registration/state-swap polish must follow look approval. No collision certification is implied.

Reproduce/check:

```powershell
python -B art/reference/hollow_trial_v1/prepare_prop_review.py
python tools/art/validate_art.py --build art/reference/hollow_trial_v1/prop_review/native
```

PASS:20 native proposals, Totoy36 only, no reserved combat colours, alpha only0/255, paired canvas/anchor equality and approved-ground SHA unchanged. Project validator checked3669 existing sources plus20 proposal PNGs. Source alpha threshold244 and nearest-neighbour reductions follow the Root Hollow workflow; existing Lab palette snap is reused without changing tools. Bottom-row crops use actual inspected gutters because generated tree canopies did not respect equal-cell boundaries. Full trees and separate ferns were inspected after correcting those crops.

Not run: Godot import/captures, full harness, production atlas rebuild or collision/playthrough checks. Not yet built: runtime lights/glow, contact/cast-shadow masks, prop-source imports, registrations, placement or any trial UI/effects/audio. Those follow approved prop art; final normal/flipped cast masks must use the selected silhouettes as in Root Hollow. The existing root entry barrier is intended for reuse and is not regenerated here.

One built-in imagegen generation; no external API fallback or SpriteCook. No billing amount was supplied. Graphify remains unavailable (`No module named graphify`); no installation attempted. Human judges silhouette, materials, sizes, dark/lit readability, visual fit and eventual night/combat appearance. Automated palette/alpha checks do not establish visual quality. Waiting for prop-sheet approval before importing/wiring or sending final collider dimensions to Claude.
