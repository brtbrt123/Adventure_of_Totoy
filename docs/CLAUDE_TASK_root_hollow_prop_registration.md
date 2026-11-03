# Claude: Root Hollow prop registration and collision placement

Owner approved the no-cave art concept and asked Codex to make it. Codex imported separate sprites, 24 cast-shadow masks, contact masks, palette atlas frames and light sockets. No core/ or data/ edits. The live map still has its blockout props/colliders; the new arrangement is a static ART PREVIEW only.

Read art/reference/root_hollow_v1/imported_prop_geometry.json and proposed_placements.json; collision_handoff_marked.png shows proposed bases against the keep-clear floors. Pending art/shadow catalogue entries are kept separate until registration; merge pending_prop_art.json and pending_shadow_manifest.json after definitions are added. Register new types and true collision bases before replacing blockout placements. Do not change walkable outline, entries, exits, encounter floors, checkpoints or mobs. Pending collision shapes below are SUGGESTIONS, not tested hitboxes.
| Type | Native WxH | Feet anchor | Suggested base WxH | Solid? |
|---|---|---|---|---|
| root_hollow_tree_ancient | 141x136 | 70,136 | 48x24 | True |
| root_hollow_tree_rootwall | 86x124 | 43,124 | 30x18 | True |
| root_hollow_roots | 48x28 | 24,28 | 32x14 | True |
| root_hollow_barrier_closed | 80x48 | 40,48 | 76x18 | True |
| root_hollow_barrier_open | 80x48 | 40,48 | 0x0 | False |
| root_hollow_shrine | 48x42 | 24,42 | 32x18 | True |
| root_hollow_rune_stones | 64x44 | 32,44 | 50x18 | True |
| root_hollow_boulder | 56x40 | 28,40 | 44x20 | True |
| root_hollow_stump | 48x30 | 24,30 | 40x20 | True |
| root_hollow_mushrooms | 31x24 | 15,24 | 0x0 | False |
| root_hollow_branches | 44x21 | 22,21 | 0x0 | False |
| root_hollow_antlers | 29x20 | 14,20 | 0x0 | False |

- Landmark is a SOLID tree: no cave, no tunnel, no entrance. The root barrier is a separate shortcut-gate prop; closed/open states have identical 80x48 native canvas and anchor40,48. Please register its actual closed geometry and removal/open-state rule keyed to cleared_hollow_center. Open state must remove the closed blocker and preserve the centre gap; Claude may supply separate side-root bases if needed. Keep it at the existing shortcut position; it is not in the scenic placement proposal yet because the gate is gameplay-owned.
- Reuse already registered woodland trees, bushes and lanterns. Proposed placement list has 21 items and intentionally leaves central/shrine fight floors open; add the actual gate without blocking the defined exit when open.
- Confirm each new base sits fully outside fight floors and exits and leaves at least85% free combat space. Check central straight Boar lane and traversal both directions. Render-anchor metadata is in import_manifest.json, with padded atlas dimensions separately recorded.
- Root clumps are proposed solid only outside the trail. If placing them across a trail, move them off it or explicitly approve flush nonblocking decoration; do not silently shrink collision.
- New rune fixtures: root_hollow_shrine, root_hollow_rune_stones and root_hollow_mushrooms have runtime light sockets in presentation/common/local_lights.json. Existing woodland_lantern light sockets are reused. Cast shadows currently use the existing common moon projection, not per-lamp ray occlusion.
- Run tests/core/test_root_hollow.gd, smoke_root_hollow.gd and full harness after registration. Once data is registered, Codex can validate final renderer/collision alignment and final light/shadow behavior.

Cosmetic cross-review issue: fx_spin_contacts in presentation/explore/explore_scene.gd creates sparks on previously dead nearby mobs; see art/reference/root_hollow_v1/CROSS_REVIEW.md.
