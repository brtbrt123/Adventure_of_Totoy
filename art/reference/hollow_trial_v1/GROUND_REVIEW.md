# Hollow Trial ground approval package (step 1 only)

2026-10-31, `agent/codex/progression`. Owner requested ground-only work and approval before props. All new files are in this art/reference folder. Existing dirty work is preserved; no main merge.

## Painting

- `native/hollow_trial_ground.png`: final512x352 opaque Totoy36 proposal, using20 non-reserved palette colours. Not installed in any runtime scene.
- `ground_full_2x.png`:1024x704 nearest-neighbour full painting for owner approval.
- `fight_floor_3x.png`: enlarged crop of the actual288x184 fight-floor rectangle.
- `contact_sheet_layout_registration.png`: separate annotated comparison with the original layout outline and fight-floor boundary; annotations never enter the painting.
- `ground_raw.png`: untouched selected built-in imagegen output. `ground_raw_v1.png` preserves the first generation. Exact generation and targeted correction prompts are in `generation_prompt.txt` and `revision_prompt.txt`.

References: `docs/previews/hollow_trial_v1/walkable_guide.png` and `layout.json` for geometry; Root Hollow's installed ground for the main texture/style reference; forest ground for secondary style. The first generation tapered too early in the lower half. A targeted imagegen edit expanded the lower clearing, removing dense ground grass from the required fight floor. The corrected registration proof was visually inspected. Floor textures are dirt, worn short grass and a few flush mossy flagstones; no altar/chest, trees, bushes, glowing rocks or other separate props. Guide flat colours, labels and markers are absent from the painting.

The painted margin is naturally irregular around the guide polygon; this is visual registration, not a replacement collision outline. Dense outer texture is ground grass/moss, not a source of colliders. Final prop occlusion and room lighting are later stages. Neutral albedo is retained for runtime night lighting; no baked light pools, warning cues or prop shadows were added.

## Reproduction/checks actually run

```powershell
python -B art/reference/hollow_trial_v1/prepare_ground.py
python tools/art/validate_art.py --build art/reference/hollow_trial_v1/native
```

PASS:512x352,180224 fully opaque pixels,20 palette colours,zero off-palette pixels,zero reserved combat colours. Project validator:3669 current sprite sources plus this1 final PNG pass. `validation.json` records raw, layout, guide and painting hashes. Palette preparation reuses Root Hollow's existing Lab snap/cleanup helper in `tools/art/make_arena_ground_from_reference.py`, with dimensions overridden locally; tools are unchanged. The raw high-resolution generation is preserved separately from the palette-limited deliverable.

Built-in imagegen was used twice (one generation, one geometry correction); no external API fallback or SpriteCook was used, and the service supplied no billing amount. `python -m graphify query ...` and update are unavailable (`No module named graphify`). No package installed.

Not run: Godot import/render captures, full gameplay harness, collision or warning-readability checks. No sprite atlas rebuild/contact-sheet pipeline is needed for this standalone ground proposal; no atlas or runtime texture was changed. No props, lighting, effects, sound, core or data work was performed. This stops at the requested ground approval gate.

Human judgement pending: visual appearance, match with the neighbouring map, the feel of the available fighting space, and readability under actual night lighting and combat effects. The image and registration proof allow review; automated palette checks do not establish art appeal or play feel. Await owner approval before the prop sheet.
