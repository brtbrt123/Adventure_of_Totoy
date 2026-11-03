# Runebound Warden — Astra V3 attack visibility

Owner feedback: V2 attacks disappeared against the busy ground. This version
prioritizes broad light/dark separation and readable attack silhouettes. Review
only; V1/V2 and all runtime/core/data files are untouched. No commit or push.

## Look here first

- `contact_sheet_attacks_native.png`: V2 left, V3 right, actual256x176 stages at
  native size, on the identical forest ground. Three attack rows.
- `contact_sheet_attacks_3x.png`: the same comparison at exact nearest-neighbor3x.
- `all_attacks.gif`: original three-attack sequence,20fps,4x.
- `compare_cleave_strike_2_closeup.png`: pale blade/contact flash at5x.
- `compare_lash_strike_2_closeup.png`: moving hook registration and live pale core.
- `compare_ring_strike_1_closeup.png`: luminous clusters plus bounded impact flash.
- `compare_ring_recovery_native.png`: bright strike flash already gone.

Each selected frame has a standalone `<key>_native.png`, `<key>_3x.png`, and a
V2/V3 pair named `compare_<key>_native.png`, `compare_<key>_3x.png`, and
`compare_<key>_closeup.png`. Keys are `cleave_strike_1`, `cleave_strike_2`,
`cleave_recovery`, `lash_strike_1`, `lash_strike_2`, `ring_strike_1`,
`ring_strike_2`, and `ring_recovery`. These are decoded/rendered native frame
comparisons, not transparent FX on a favorable empty background.

## What changed

| Attack | V3 readability correction |
|---|---|
| Cleave | Coherent3px pale tip-traced arc with5px ink backing and2px bright leading edge. Short cream contact chips only during active strike. Recovery retains V2 dust, never a stale arc. |
| Lash | Continuous3px pale live-strike core with2px white highlights and7px ink silhouette. Brown intertwined root edges remain; the core stays connected to the moving hook. Endpoint remains within reach150. |
| Spore Ring | Larger3px cream/pale-teal clusters with5px dark backing. A short full-boundary flash marks active impact. All pixels are clipped within radius48. Recovery switches immediately to separate subdued afterglow plus broken scorch. |

The pale colors are Totoy36 `p`, `o`, and cream `1`; backing is ink `0`.
Gold/red `x/y/z/A` are never used in FX/body. Hard alpha only. The body is
composited over FX and the original warning overlay is last. No brighter effects
were added to guard-break/exposed phases. V2's other effect families are retained.

## Files and unchanged contracts

- `body/<state>/*.png`:60 byte-identical approved48x48 bodies, anchor20,44.
- `fx/<family>/*.png`:114 compact native images across19 families. V2's106 assets
  plus8 `ring_afterglow` frames. All dimensions multiples of8 and at most256.
- `manifest.json`: unchanged expected keys, `fx_assets[stem]={size,anchor}`, source
  hashes, palette/timing/geometry metadata and V3 visibility notes.
- `timeline.json`:50ms sample body selection, FX selection and attachment offset.
- `build_checks.json`: build checks and all11 original clip-duration comparisons.
- `build_review.py`: reproducible generator, safely importing V2 read-only and
  redirecting both output paths before generation; bytecode writing disabled.

All11 original GIF names are supplied: `idle_wake_walk`, `cleave`, `lash`, `ring`,
`all_attacks`, `guard_break_exposed`, `cleave_lash_chain`, `cleave_parry_exposed`,
`defeat`, `all_body_animations`, `all_effects` (all `.gif`).

Stage256x176, feet66,108, GIF4x nearest,50ms/20fps. Approved body selection and core
timings are unchanged: Cleave40/6/44, Lash44/8/40, Ring56/5/44; chain12;
break+exposed90. Warnings retain cone57/half-angle0.9, Lash150x20, Ring48.
The new afterglow family is used during Ring recovery, without extending any clip.
Four unaffected GIFs are byte-copied only after complete expanded-frame equality
against newly rendered frames. Other clips are encoded from the new renders.

Reconstruct each FX layer at `(66-anchor.x,108-anchor.y)`; apply any attachment
offset listed in `timeline.json`. Body and warning layers remain in their original
order. The native assets are cosmetic and do not define collision geometry.

## Rebuild and verification

```powershell
python -B art/reference/warden_fx_astra_v3/build_review.py
```

Requires existing V1/V2 source folders, Python3 and Pillow. Builder checks all114
compact reconstructions, dimensions, hard alpha, Totoy36/no-reserved colors,
60 approved body copies, unchanged V1/V2 source hashes and all11 clip durations.
Original encoder verifies palette roundtrip. Parent independent V3 audit verifies
decoded4x scaling, exact warning pixels and stable exposed ROI separately.

The artist inspected the three active strikes at original native display size on
the busy ground (`first_native_strikes.png`), then the final native/3x and closeup
comparisons. Cleave has a distinct backed pale stroke, Lash a continuous bright
line, and Ring a visible bounded flash; owner approval remains required.

No live Godot run or runtime integration was performed. Graphify query failed
with `No module named graphify`; no graph or pipeline writes were made outside
this review directory. Parent audit status is reported separately. This is an
offline visibility correction, not a change to attack timing, range or gameplay.
