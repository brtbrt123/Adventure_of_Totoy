# Runebound Warden — Astra FX v2

Review proposal only. All writes are contained in this folder. No runtime, original
art, art/src, art/build, core, data, tooling, harness or docs edits; no commit/push.
The owner decides whether the polish is approved. This is the existing code-native
Warden identity, not a new creature or image-generation result.

## Review first

- `all_attacks.gif`: Cleave, Lash and Ring at original timing.
- `cleave_parry_exposed.gif`: guard fracture and the dark exposed chest.
- `all_effects.gif`: all 17 original FX families with registered body poses.
- `contact_sheet_before_after.png`: same background, body pose and warning; left
  baseline, right polish. Full stage width retained.
- `contact_sheet_impact_detail_1.png`, `contact_sheet_impact_detail_2.png`: selected
  decoded GIF times, compared at exact 4x native pixels. Includes blade contact,
  rooted Lash, outward spores, guard break, exposed hold and death fragments.
- `contact_sheet_fx_families.png`: first/middle/last of all 18 native FX families,
  including the supplemental Cleave contact dust, at exact 2x native pixels.
- `contact_sheet_motion_all_attacks.png`, `contact_sheet_motion_guard_break_exposed.png`,
  `contact_sheet_motion_defeat.png`: temporal sample sheets, exact 2x native pixels.

## Changes

All 17 original FX families are polished and all100 frames regenerated:99 differ
pixel-for-pixel; the initial empty Lash creep frame deliberately remains empty.
Six supplemental `cleave_contact` frames bring the export to **106 FX PNGs in
18 families**.

| Effect | Polish |
|---|---|
| Rune / wake | Stepped emission beside the embedded chest glyph, rising angular glyph motes, no circular halo. |
| Idle / arrival | Sparse drifting spores, broken rim sections and settling foot dust. |
| Guard hit / break / hit burst | Short directional glints, broken glyph strokes, separate stone chips; fracture loses brightness as it falls. |
| Exposed | Desaturated sinking dust, no `u/o/p` bright rune colors. Opaque body is composited after FX, preserving the dark chest. |
| Cleave | Narrow pale layered trace of the approved hook path, smaller inner teal trail, low blade-contact chips and dust. Recovery uses separate contact dust instead of a stale strike arc. |
| Lash | Two intertwined root strands, bark highlights and small thorns. Both start at the moving hook; endpoint is feet+[148,-1], within reach150. Ground creep branches and then sheds short splinters. |
| Ring | Broken spore clusters charge and expand outward, then fade into irregular scorch fragments. Every native Ring FX pixel stays within radius48. |
| Death | Root slivers and shaded stone chips follow falling trajectories, settle and lose brightness; the body stays visible. |

## Preserved contract

The 60 `body/<state>/*.png` files are byte-for-byte copies of the approved native
body PNGs. Cells are 48x48, anchor20,44. No body pixel or pose was regenerated.
Seven original design PNGs and the baseline review artifacts are SHA256-protected
before and after generation; hashes are included in `manifest.json`.

Original stage256x176, feet66,108, 60Hz simulation, one review sample every3 ticks,
GIF50ms/20fps and exact nearest-neighbor4x remain. GIF encoders may coalesce identical
frames into longer durations; compare expanded50ms samples, not encoded indices.
The original timeline code is reused unchanged through an in-memory AST replacement
of only its scene compositor. Attack timings remain Cleave40/6/44, Lash44/8/40,
Ring56/5/44, chain12 and break+exposed90. All 11 baseline clip names are present:

`idle_wake_walk.gif`, `cleave.gif`, `lash.gif`, `ring.gif`, `all_attacks.gif`,
`guard_break_exposed.gif`, `cleave_lash_chain.gif`, `cleave_parry_exposed.gif`,
`defeat.gif`, `all_body_animations.gif`, `all_effects.gif`.

Gold/red remain exclusively in the original warning overlay: cone radius57 and
half-angle0.9, Lash150x20, Ring radius48. Warnings are drawn last with the original
coordinates and colors. Every FX uses opaque Totoy36 colors or fully transparent
pixels; no reserved x/y/z/A in body or FX assets. No blending or soft alpha.

## Native assets and use

`manifest.json` records `fx_assets[stem] = {size, anchor}`. Each image is at
`fx/<family>/<stem>.png`; dimensions are multiples of8 and at most256. Reconstruct
on the stage at `(66-anchor.x, 108-anchor.y)`. All106 compact images are checked
against their full native stage layer. `timeline.json` gives body frame, selected
FX frame and stage attachment offset per50ms sample. Indices in that file are
one-based. Rune glow, wake flare, guard hit and hit burst apply the recorded
rune-centroid offset; the other effects use the feet origin.

Layer order is ground/shadow, FX, unchanged opaque body, warning, review labels.
The catalogue displays Cleave/Lash effects with their matching strike pose and
death debris with its matching death pose. The original all-body clip stays intact.
The additional contact family is shown during Cleave recovery, and on the native
FX contact sheet; it does not extend the baseline all-effects clip duration.

## Rebuild and checks

From the project root, with Python3 and Pillow:

```powershell
python -B art/reference/warden_fx_astra_v2/build_review.py
python -B art/reference/warden_fx_astra_v2/make_detail_proof.py
```

The builder safely imports the guarded original rig, redirects its output path,
and disables bytecode writing. It checks body file equality, baseline hashes,
compact reconstruction, dimensions, palette, hard alpha and reserved-color
exclusion. The original encoder checks palette roundtrip and total GIF duration.
`build_checks.json` records the completed build checks, decoded clip-duration
comparison and inspected proofs. All11 GIF durations match the originals exactly.
The parent's independent audit lives outside this directory and additionally
checks decoded4x samples, exact warning-pixel parity, original-source integrity,
the stable exposed ROI and full clip schedules. Its results are reported by the
parent; no duplicate audit implementation is supplied here.

Graphify query was attempted before exploration and failed with
`No module named graphify`. No graph rebuild was attempted because the module is
unavailable and all writes must stay in this folder. No Godot import, art pipeline
build or full harness run: those would write outside the authorized review folder.

## Inspection and limits

The artist inspected the rendered before/after, attack motion, guard motion and
detail contact proofs. Body visibility, hook registration, dark exposed chest and
warning readability are review targets, not a claim that gameplay feel or final
art quality is approved. Palette and hard-edge rendering are intentional. Dust
and dormant spores are deliberately subtle on the textured forest ground.

This is an offline review: live renderer integration, real collisions, gameplay
feel, sound, and final owner approval remain outside this task. The FX draw no
new gameplay rules. Exact original timing is preserved even where a short strike
phase yields only two or three visible20fps samples.
