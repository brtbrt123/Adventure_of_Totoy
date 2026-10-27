# Playtest collision fixes — 2026-10-27

The owner explicitly authorized the required shared-data edits in chat, overriding the normal Codex/data folder restriction for these fixes.

- Removed `log_south` from the layered forest and `glade_log` from the layered glade. Their visual placements and generated colliders disappear together; the reusable source sprites remain intact.
- Expanded `forest_rocks` from a single lower collision strip to the central and side-rock ground footprints.
- Added circles at the exposed root flares of all three forest trees and the glade tree. The canopy still supports walking behind trees. A thin left-root tip uses a small circle so the existing northwest bush's walkable anchor stays clear.
- Moved `glade_antler` from (135,210) to (488,188), at the east edge between the bush and rock, clear of the Stag's start. It is now solid, with six circles following the main bone and upper branches.
- Added `arch_rocks_left` at (405,66), mirrored, and `arch_rocks_right` at (514,88), using the existing `glade_rock_2` sprite and solid footprints. They close the sides of the arch; the central passage and arena exit route remain walkable.

`smoke_playtest_collisions.gd` checks the removed forest log leaves no invisible obstacle, all three rock lobes block feet, changed solids resist walking and dash sweeps from eight directions, antlers are solid at the edge, and direct arch-side bypasses stop at the rocks. Existing glade tests verify the arch passage, both exits, and at least 80% Stag movement coverage (focused run: 91%). Forest puzzle smoke passes after the removals.

Full-map runtime PNGs and collider overlays are captured by `tests/capture_playtest_collisions.gd`. Art images, palette, and atlas sprites were not repainted or resized. Human playtesting still determines whether these footprints feel right.

Claude's concurrent middle-tree move, boundary changes, docs and core test were preserved; Claude committed them separately as 85de6e5 during this work. Only this playtest-fix diff will be committed; the ongoing chapter-plan edit stays untouched.

**PASS:** full background regression (`python -u harness/checks/run_tests.py --worktree .`): Python tests, import, core runner and all smoke suites. The final upper-antler branch adjustment was also checked by the eight-direction sweep smoke and all 13 layered-glade core tests (including both exit routes, open arch passage and 91% Stag movement coverage). Windowed captures completed without script or shader errors.
