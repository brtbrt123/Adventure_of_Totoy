# Runebound Warden animation and effects review

2026-10-31. Owner requested all animations and effects after the design sheet. **Generated for motion/effect review; not installed in gameplay.** Original seven design PNGs are unchanged.

## Watch

- `idle_wake_walk.gif`: breathing, chest pulse, wake and heavy walk cycle in place.
- `all_attacks.gif`: Rune Cleave, Root Lash and Spore Ring, each with its warning and recovery. Also supplied separately as `cleave.gif`, `lash.gif`, `ring.gif`.
- `cleave_lash_chain.gif`: un-parried Cleave followed by Lash after the 12-tick recovery delay.
- `cleave_parry_exposed.gif`: Cleave tell, parry fixture, broken guard, dark rune and guard restoration. Guard-break onset plus subsequent dark hold total 90 ticks.
- `guard_break_exposed.gif`: guarded pulse, reduced-damage hit recoil, guard break, exposure and restoration.
- `defeat.gif`: rune's last flash, dark collapse, crumbling root/stone clusters and settling debris.
- `all_body_animations.gif`: all 14 body sets in sequence, with slower keyframe holds, including hurt and recovery.
- `all_effects.gif`: all 17 effect families individually demonstrated. Existing herb-drop pickup treatment is reused later, not re-authored here. No audio was requested or generated.

GIFs are **4x nearest-neighbour**, on an existing Root Hollow ground crop, using a native 256x176 review stage. These are offline compositions, not Godot gameplay captures. The larger review stage keeps the entire 48-pixel warning circle and 150-pixel line visible. Attacks sample a 60Hz timeline every 3 ticks (20fps); short 2-tick keyframes may be skipped in a GIF, and transitions can appear up to 2 ticks late. `all_body_animations.gif` shows every authored keyframe more slowly. Merged identical GIF frames retain their full duration.

## Native bodies: 60 frames

| Set | Frames | Purpose |
|---|---:|---|
| idle | 6 | Guarded breathing and chest pulse |
| wake | 4 | Heavy rise and rune flare |
| walk | 6 | Alternating rooted steps; core owns translation/speed |
| cleave_tell / cleave_strike | 5 / 3 | Raise hooked blade, downward cut |
| lash_tell / lash_strike | 5 / 3 | Retract root arm, extend the Lash |
| ring_tell / ring_strike | 5 / 3 | Crouch, charge and stamp |
| recover | 4 | Lower blade and reset stance |
| guard_hit | 2 | Small recoil and brighter rune |
| exposed | 4 | Dark cracked rune, unsteady posture |
| hurt | 2 | Exposed recoil |
| death | 8 | Dark collapse and breakup; includes a deliberate hold |

All native body PNGs: `body/<set>/warden_<set>_right_<n>.png`, **48x48**, feet anchor **(20,44)**, right-facing. Each state also has a labelled 8x contact sheet with at most four poses per row. Runtime should mirror around the feet anchor.

## Native effects: 100 frames / 17 families

Rune glow, ambient spores, wake flare, wave-arrival rim, guard-hit sparks, guard-break burst, exposed dust, Cleave arc, Lash ground creep, Lash strike, Lash splinters, Ring charge, Ring burst/spores, ground scorch, death flash, death debris and generic hit burst.

Native files are under `fx/<family>/`. Each is cropped to whole-pixel bounds with dimensions rounded to multiples of 8, retaining its feet anchor inside the canvas; **individual sizes/anchors are recorded in `manifest.json`**. The generator reconstructs each full-stage effect from its compact PNG to assert pixel/anchor parity. Blank fade endpoints are 8x8. Do not assume every FX image has the same anchor or size.

The Cleave trail traces the rig's hook tip around the actual blade pivot. The Lash starts at the animated hand/hook and ends at the 150-pixel reach measured from the feet. Chest FX in the previews follow the visible rune's centroid. There are no baked red/gold pixels in native body or effect assets; combat warning colours exist only in the composed preview layer.

## Timing and later wiring

Read from the current core definitions: Cleave 40/6/44 ticks, Lash 44/8/40, Ring 56/5/44; Cleave cone radius 57 includes the 46 reach plus 11 mob radius, half-angle0.9; Lash150x20; Ring radius48. These numbers are review choreography copied from core, not new presentation rules. Runtime must draw warnings from actual telegraphs.

Use snapshot `attack` for `warden_cleave`, `warden_lash`, `warden_ring`; `guarded` decides rune state. `attack_hit.guarded` triggers a short weak-hit cue. That cue must not interrupt/replace an ongoing windup or strike: show the spark effect during attacks, reserve body recoil for non-attacking poses. `stagger` selects exposed; core owns its 90-tick duration. Core death duration should proportionally select the eight death frames. Do not add damage, spawning, collision or timing rules in presentation.

## Rebuild and checks

```powershell
python art/reference/warden_v1/animate_review.py
python art/reference/warden_v1/inspect_animation_review.py
python tools/art/validate_art.py --build art/reference/warden_v1/animation_review
```

PASS:60 body and100 FX PNGs, Totoy36, hard alpha, no reserved body/FX colours, native dimensions divisible by8 and <=256, unclipped limb transforms, canonical rig reconstruction, compact-FX reconstruction, GIF palette round-trip/durations and unchanged original design hashes. Independent exported-file audit also confirms all11 decoded GIFs use exact4x pixel blocks, anchors fit native FX canvases, exposed/hurt/death bodies have no bright rune pixels, and the guard-break/hold window totals90 ticks. Validator also reads the existing3534 art/src grids without changing them. Contact sheets and representative motion samples were inspected for silhouette, feet, trail registration, cue bounds and rune states. `manifest.json` records counts, timing, anchors, trace pivots and design hashes; `export_audit.json` records decoded durations. Two compact body-overview sheets supplement the14 per-state contact sheets.

Animation method: a deterministic articulated pixel rig repositions parts of the approved design; effects are authored as palette pixels. No new imagegen/SpriteCook call, credits or external asset licence introduced. No source art import, atlas rebuild, `mob_view.gd`, core/data change or Godot run in this pass. No full harness/runtime/performance/collision or audio checks. Final look, perceived weight, smoothness and combat readability need owner judgement; real-renderer verification follows approved integration. Graphify query unavailable (`No module named graphify`).
