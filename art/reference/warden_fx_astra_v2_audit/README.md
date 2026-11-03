# Independent audit of Astra's Warden FX revision

Scope: original Warden design/body/FX/review files are protected. Astra authors the sibling `warden_fx_astra_v2` folder; the parent authors this audit folder. No runtime, core, data, art/src, atlas or scene wiring is part of the polish pass.

Run after Astra's exports exist:

```powershell
python art/reference/warden_fx_astra_v2_audit/audit.py
python tools/art/validate_art.py --build art/reference/warden_fx_astra_v2
```

`baseline_hashes.json` records 206 original files before Astra began writing. Do not regenerate it after the revision; `--baseline` is only for initial capture.

The audit compares native body pixels, body feet anchors, animation counts, attack timing, warning geometry, chain delay and exposed duration against V1. It checks compact effect sizes/anchors, Totoy36, hard alpha and absence of reserved combat colours in native FX. It reconstructs old/new effect canvases to report changed frames by family.

For every original preview GIF it expands held frames onto the same 50ms timeline, checks exact4x nearest scaling and unchanged total duration, and requires all reserved-colour warning pixels to match exactly. Exposed-state previews must keep the chest ROI free of bright teal highlights throughout the steady dark hold. Key attack/parry/catalogue previews must actually differ from V1.

`report.json` is produced only after all assertions pass. This establishes technical compatibility, not artistic quality. Owner judgement and later Godot integration/playtesting remain necessary; no full runtime harness or lighting/performance test is implied by this offline review. Astra account token cost is not exposed by the agent tool; this pass uses no SpriteCook credits or new external art assets.

## Completed review, 2026-10-31

V2 technical audit **PASS**: all 206 original files unchanged, 60 identical body frames, 106 compact effects, 11 unchanged clip durations, 35,940 warning-pixel samples preserved and the exposed chest kept dark. All 17 original FX families changed (99 original frames changed; the first empty Lash creep frame stays empty), plus six new contact-dust frames. Palette validator: 166 PNGs passed.

Owner then reported that the attacks were hard to see. Astra produced the targeted readability revision in `art/reference/warden_fx_astra_v3/`: pale 2-3-pixel strike cores with ink backing, clearer blade contact and larger Spore Ring clusters, with a short bounded impact flash. Ring recovery uses a separate subdued afterglow so the active flash does not persist after the dangerous phase. V2 remains preserved.

V3 independent audit and palette validator **PASS**: 114 native FX, 60 identical bodies, all 11 original clip durations, warning geometry/pixels and dark exposed hold preserved. Validator checked 215 PNGs including the native bodies/FX and comparison proofs. Run:

```powershell
python art/reference/warden_fx_astra_v2_audit/audit.py --new-root art/reference/warden_fx_astra_v3 --report art/reference/warden_fx_astra_v2_audit/report_v3.json
python tools/art/validate_art.py --build art/reference/warden_fx_astra_v3
python art/reference/warden_fx_astra_v2_audit/contrast.py
```

`contrast_v3.json` reports an objective luminance diagnostic on the same native busy ground: mean bright native pixels rose from 26.8 to47 for Cleave, 7.3 to409.2 for Lash and 28.5 to531.6 for Ring. This is not a substitute for owner judgement or an engine playtest. Native V2/V3 strike comparisons, 3x proofs and closeups were visually inspected; new artifacts live entirely in art/reference. No runtime/core/data/source-art changes or full gameplay harness run by this FX-only work. Graphify remains unavailable.
