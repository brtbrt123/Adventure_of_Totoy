# Warden Cleave: show its complete hit range

2026-10-31. Owner asked why the Cleave did not match its range. The V3 effect followed the physical blade's hook tip, but core hits a larger feet-centred cone. The small attached trail alone did not communicate that area.

This revision keeps Astra's attached blade trail and adds a separate, brief **ground impact sweep** covering the full existing cone. Core defines reach46 plus Warden radius11: warning/hit radius57, half-angle0.9 radians. No range, damage, body, warning or attack-timing change.

## Review

- `cleave.gif`: corrected windup, active strike and recovery.
- `cleave_strike_1_3x.png`: first sampled active strike, at exact3x pixels.
- `cleave_windup_3x.png`: original gold warning for comparison.
- `contact_sheet_range_before_after_native.png`: V3 left, range correction right; windup, two active samples and recovery.
- `all_attacks.gif`: same complete sequence with Lash and Ring retained.

The full outer sweep appears on the first active frame, so the visual does not imply that damage only happens when the decorative inner ripple reaches a target. There is no sweep during windup, parry/exposure or recovery. FX remain behind the unchanged opaque body and the original warning is drawn last. Pale/teal pixels only; no gold/red native FX or semi-transparent edges.

## Assets and verification

Six new `fx/cleave_range/` compact native images have individual sizes/anchors in `manifest.json`. All six are rasterized directly against `r<=57` and `abs(atan2(y,x))<=0.9`, and all include the exact (57,0) endpoint. The blade's elevated attached trail is a separate layer; its pixels are not ground-range indicators. Total120 native FX,60 unchanged bodies. Original V1/V2/V3 files preserved.

```powershell
python -B art/reference/warden_cleave_range_v4/build_review.py
python tools/art/validate_art.py --build art/reference/warden_cleave_range_v4
python art/reference/warden_fx_astra_v2_audit/audit.py --new-root art/reference/warden_cleave_range_v4 --report art/reference/warden_fx_astra_v2_audit/report_v4.json
```

Generator checks: exact cone containment/reach, compact reconstruction, unchanged sources/body pixels, palette/hard alpha and unchanged clip duration. Independent audit checks unchanged warning pixels and timing, body anchors and dark exposed chest. Native/3x range stills were inspected against the windup and recovery. These are offline review compositions, not Godot captures; no runtime/source-art/core/data edit or full gameplay harness. Owner approval and later engine checks are required.

When wiring, the sweep must follow the actual core telegraph's centre, direction, size and half-angle. The frozen review values must not become a second gameplay rule in presentation. No new model or external-art generation was needed for this geometric correction; Astra V3 visuals are reused.
