# Thornback requested balance changes — review only

**Update:** owner subsequently approved wiring. Presentation is now installed; core gameplay changes still need Claude. See [LIVE_INTEGRATION.md](LIVE_INTEGRATION.md). The following describes the original offline review package, not a claim that the new combat rules are playable.

Owner request, 2026-10-30: slam range x2.5; faster charge; eight eruptions at different locations; heal 2% each second while any summoned Glowmoth survives.

Run `python art/reference/thornback_fx_review_v3/build_review.py` from the repository root. Pillow required. This only writes this reference folder. Uses the existing original creature rig and guarded Astra V2 helpers; preserves all approved Glowmoth GIFs and runtime sources.

## Review clips

- `revised_attacks.gif`: slam, charge and eight-site eruption, in order.
- `slam.gif`: reach 50 -> 125 pixels, cone half-angle unchanged at 0.95 radians; expanded ground shock follows the cone. Original 54/6/48-tick timing retained.
- `charge.gif`: **proposed** speed 4.4 -> 6.6 pixels/tick (1.5x); strike duration 36 -> 24 ticks to preserve 158.4-pixel travel. Original 56-tick tell and 40-tick recovery retained. Owner requested faster but did not specify a multiplier.
- `eruption.gif`: eight simultaneous individual warnings, radius 34 pixels; original 50/5/40 timing. The hero moves out of one warning into the gap. Locations are illustrative, not an installed encounter layout or collision-tested target selection.
- `moth_regeneration.gif`: five approved moths, illustrative kills, 50% initial HP; +2 percentage points at each second from 1s to 6s. Last moth dies at 6.6s; HP remains 62% until the loop ends at 9s. One fixed 2%-of-max rate, regardless of the surviving moth count. Moths vanish as simple kill markers, not a new approved death animation.

All stages are 384x216, GIFs nearest-neighbor 3x at 20fps sampling a 60Hz attack timeline. Scene pixels are opaque Totoy36. Gold/red are confined to combat warnings; healing and spirit effects use teal. Ground is an existing Root Hollow painting crop, for scale only. This is offline composition, **not a gameplay capture**. Native copied body poses and exact antler masks live in `sources/`. Rebuild source remains alongside outputs. V1/V2 outputs are unchanged.

## Checks and limits

`validation.json`: palette/hard-alpha checks for all native frames; lossless palette conversion of all GIF input frames; decoded GIF total durations; 8 unique eruption centres; healing stops after final kill; approved Glowmoth GIF SHA256 unchanged; original body-pose parity inherited from Astra helpers. Inspected `contact.png`, `motion_check.png`, and `regeneration_stopped.png` for scale, cue separation, poses and final healing state.

No core/data/presentation/runtime art installation in this pass. No Godot import, gameplay/collision check, full harness, or play-feel verification was run for these reference-only changes. Graphify is unavailable in this environment (Python reports no module named graphify); no code graph updated. Final balance, faster-charge multiplier, actual safe eruption placement, and art approval remain the owner's judgement. Claude handoff: `docs/CLAUDE_TASK_thornback_balance_v3.md`.

No SpriteCook generation or credits spent. Existing project art and procedural pixel-art rigs were reused; no new external asset licence introduced. Prior Astra helper generation was already completed in V2; this revision made no new Astra call.
