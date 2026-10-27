# Playtest collision fixes — 2026-10-27

The owner explicitly authorized the required shared-data edits in chat, overriding the normal Codex/data folder restriction for these fixes.

- Removed `log_south` from the layered forest and `glade_log` from the layered glade. Their visual placements and generated colliders disappear together; the reusable source sprites remain intact.
- Expanded `forest_rocks` from a single lower collision strip to the central and side-rock ground footprints.
- Added circles at the exposed root flares of all three forest trees and the glade tree. The canopy still supports walking behind trees. A thin left-root tip uses a small circle so the existing northwest bush's walkable anchor stays clear.
- Moved `glade_antler` from (135,210) to (488,188), at the east edge between the bush and rock, clear of the Stag's start. It is now solid, with six circles following the main bone and upper branches.
- Added `arch_rocks_left` at (394,88), mirrored, and `arch_rocks_right` at (506,88), using the existing `glade_rock_2` sprite and solid footprints. They close the sides of the arch; the central passage and arena exit route remain walkable.

`smoke_playtest_collisions.gd` checks the removed forest log leaves no invisible obstacle, all three rock lobes block feet, changed solids resist walking and dash sweeps from eight directions, antlers are solid at the edge, and direct arch-side bypasses stop at the rocks. Existing glade tests verify the arch passage, both exits, and at least 80% Stag movement coverage (focused run: 91%). Forest puzzle smoke passes after the removals.

Full-map runtime PNGs and collider overlays are captured by `tests/capture_playtest_collisions.gd`. Art images, palette, and atlas sprites were not repainted or resized. Human playtesting still determines whether these footprints feel right.

Claude's concurrent middle-tree move, boundary changes, docs and core test were preserved; Claude committed them separately as 85de6e5 during this work. Only this playtest-fix diff will be committed; the ongoing chapter-plan edit stays untouched.

**PASS:** full background regression (`python -u harness/checks/run_tests.py --worktree .`): Python tests, import, core runner and all smoke suites. The final upper-antler branch adjustment was also checked by the eight-direction sweep smoke and all 13 layered-glade core tests (including both exit routes, open arch passage and 91% Stag movement coverage). Windowed captures completed without script or shader errors.


## Arch alignment correction

The owner spotted the left boulder inside the arch. The primary cause was `PropsLayer.draw`: Godot flips a negative-width texture rectangle while keeping its draw origin, but the renderer also advanced the x origin by the sprite width. Mirrored props therefore appeared one full sprite width to the right of their anchored collision/shadow footprint. Removed that extra translation. `capture_prop_mirror.gd` verifies the actual GPU-rendered pixels of both facings share their anchored bounds (not just the rectangle math).

The two side boulders now share y=88, at x=394 (mirrored) and x=506, outside the doorway and adjacent to the root feet. The corrected preview is `alignment/arch_side_rocks.png`. The primary passage, both exits and Stag movement coverage remain subject to the glade tests. This renderer correction also aligns other mirrored props with their existing colliders.

Alignment verification: actual windowed `capture_prop_mirror.gd` passed its mirrored-pixel/bounds comparison; versioned runtime/collider captures completed without script or shader errors. Focused glade tests (13/13), the side-bypass/footprint smoke and final import passed. Full background regression result follows below.

**Alignment regression: PASS.** Full background Python/import/core/all-smoke regression completed with every suite exiting 0.


## Owner's upper-right arch and narrow approach

Moved the arch to feet (508,62), fully within the 560x336 world at the upper-right trail exit. Replaced the two added side boulders with the approved solid tall-bush sprite: left (444,62), right (536,80). Added a connected left vegetation bank at (412,78), (438,100) and (462,110). Its foliage covers the broad dirt edge and forms a narrow lane into the arch; ground art is unchanged. All bushes use shared solid prop footprints, not presentation collision rules.

A temporary test-only plug in the arch opening makes the arena exit unreachable, proving there is no path around either side. Without the plug, both exit routes, walking and dashing through the arch, and 91% Stag fight-area coverage pass the layered-glade tests. The direct foot-approach check now only drives from valid scene positions: the arch's outer-right side lies beyond the world boundary after this move.

Final runtime/collider images: `narrow_final/`; detail: `narrow_final/arch_preview.png`. Reproduce with `capture_playtest_collisions.gd -- --narrow-final`. The owner can judge foliage density and the visual width of the approach from these captures.

**Upper-right approach verification: PASS.** Full background regression completed with every suite exiting 0. The final connected-bank placement also passed all 13 focused layered-glade core tests and the art/placement contract test. Runtime captures completed without script/shader errors.
