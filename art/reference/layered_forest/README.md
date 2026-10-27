# Layered forest sources and presentation

The owner approved `forest_ground_only.png` and `forest_props_sheet.png` on 2026-10-27, including the single-board sign, the small bush-like fern and the gate width. The soft moonlit look, teal rune glow and moving fireflies were also approved that day.

The forest is now imported and rendered through the shared `forest_layered` scene. Read [INTEGRATION.md](INTEGRATION.md) for all padded sizes and anchors, lighting/state wiring, technical review, tests, captures and Claude's remaining middle-tree review-pose task.

- Runtime ground: `res://presentation/forest/forest_layered_ground.png` (480x288, Totoy36).
- Original generated ground: `forest_ground_only.png` (1619x971), preserved unchanged.
- Original generated prop sheet: `forest_props_sheet.png` (1536x1024), preserved unchanged.
- Approved extraction copies: `props/`; source geometry is authoritative in `data/props/prop_defs.json`.
- Import manifest: `import_manifest.json`; reproduction script: `prepare_assets.py` (run from the repository root).
- Final review: `review/final/review_summary.png`, `review/final/forest_night_fireflies.gif` and the individual PNGs/positions.
- Debug: 8/F10 forest_layered, G/F6 gate toggle, 7/F9 night lighting toggle. Chapter routes remain on the painted scenes.

## Generation provenance

Built-in imagegen received `art/reference/forest_route_target.png` for composition, `presentation/village/village_layered_ground.png` for ground texture and `art/reference/layered_pilot/review/glade_full.png` for prop scale/camera/palette style. The neutral sources leave moonlight, cast shadows and glow to presentation. A follow-up image edit removed the unwanted bottom trail spur; another darkened the two initially yellow-lit unlit pedestals. Originals are preserved above. Their approved scale and silhouettes are unchanged during import.

The source sign has one board rather than the prompt's two arrow boards, and the third fern slot resembles a bush. The owner accepted these source findings on 2026-10-27. No further generation or geometry change is authorized by this import.

Earlier painted-forest and glade night review PNGs/GIFs remain in `review/` as the prior approved-look record.
