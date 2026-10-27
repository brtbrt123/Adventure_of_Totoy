# Chapter 1 expansion — layered encounter-space draft

Owner request: more adventure, branching exploration and dedicated mob space; match the existing layered maps and game atmosphere. The owner approved this route on 2026-10-27 ("yes i approved"). The first area now has a review-only layered blockout; this is not a playable route or an approved enemy balance change. It supplements docs/CHAPTER1_PLAN.md without rewriting it.

## Proposed route
Lanternfen (existing) -> Woodland Approach (new, working name) -> Lantern Wood (existing forest puzzle) -> Root Hollow (new, working name) -> Stag Glade (existing) -> Colossus ruins (existing arena).

Keep village scale, approved glade arch/bush/path arrangement and boss arena. Add two connected forest areas rather than enlarge every existing prop. New world-size targets: 640x400 each; hero and props keep their current scale. These sizes are blockout targets, not promised play duration.

Woodland Approach: two separated fight clearings, a quiet trail between them, an optional abandoned camp with one additional encounter space, and a loop back to the main trail. First clearing introduces the existing design's Mossling; second reserves space for a Thornback Boar. Proposed populations remain for owner/core tuning, not fixed in this layout.

Lantern Wood: preserve the two-lantern root-gate puzzle and approved forest art. Keep puzzle interaction spots free of spawn zones. Use it as a quieter landmark between new combat areas. Avoid stacking mobs at transitions or on switches.

Root Hollow: a broad central clearing for a mixed encounter, a separate optional shrine clearing, a quieter fork and a return shortcut toward the village. Reserve a straight charge lane and a side escape loop for the design's Boar; Glowmoths belong at visible clearing edges rather than behind opaque canopies. The shrine's reward and shortcut unlock conditions need core implementation and owner review. No new mandatory boss is invented; the planned Stag and Colossus remain the main encounters.

## Layered construction and visual direction
- Ground: grass/dirt/stone only, at existing tile/character scale. Do not bake trees, bushes, rewards, mobs or collision into a single painting.
- Props: separate trees, roots, bushes, rocks, lanterns and ruins, each with feet anchors, base colliders and depth ordering through the existing PropsLayer system.
- Atmosphere: approved Totoy36 grass/dirt ramps, restrained teal rune light, warm lantern pockets and sparse fireflies. No reserved combat gold/red in environment art. Preserve the soft night look.
- Composition: dense vegetation on the perimeter, open readable dirt-and-grass fight floors; distinct camp, gate and shrine landmarks for navigation. Foliage frames the route without hiding attacks.
- Render/light/collision use the same authored placements. Tall canopies can cover travel routes, but avoid covering the central fight floor or attack approach lanes.

## Space reserved for mobs
Each main encounter reserves an approximately 180x112 obstacle-free center, plus escape space around it; optional encounter floors start around 144x96. These are draft minima to test with actual mob hitboxes and telegraphs. Do not count world-size alone as usable fighting space. Keep trunks, solid shrubs, chests and entrances outside those centers. Provide at least two clear exits around obstacles and a visible approach before activation. Spawn/leash/respawn/activation logic belongs to core, never presentation.

Mob placement must use safe stand points tested against authored colliders. Verify walking and dashing around every encounter, boar charge visibility, gold/red tell visibility, camera-edge approaches and return travel. Entry/checkpoint/NPC/puzzle safety distances must be validated using actual aggro rules; the blockout is not evidence those rules exist.

## Build order and ownership
1. Owner reviews the route diagram and encounter clearings.
2. Codex builds a layered art/blockout for Woodland Approach first, reusing compatible approved forest props; show full-map and gameplay-scale captures before producing the second area.
3. Claude supplies new scene IDs/routes/checkpoints/save compatibility, collision/shared-data integration, mob AI/spawns/leashes/rewards and shortcut state. Keep the current official route playable until replacement connections pass tests. Existing scene-routing smoke failures from migration must be addressed first.
4. Codex wires renderer/lighting/effects to the documented core snapshot/events and produces Root Hollow after the first area's scale works in playtest.
5. Test each connection, puzzle states, saves, encounters, shortcuts and HUD clearance, then full harness. Human judges exploration quality, visuals, pacing and difficulty; Claude cross-reviews the interface.

The existing chapter plan and unrelated architecture edit are untouched. No runtime assets, gameplay rules, routes or saves changed in this proposal.

## First blockout built after route approval

`woodland_approach.json` holds a 40x25 terrain grid (16px tiles), 31 separate approved forest props, and encounter annotations. `woodland_preview.gd` uses the real PropsLayer depth sorting, contact/cast shadows and forest EnvironmentLight material. The standing hero is a native-scale visual marker, not a controllable actor. There are no real mobs, transitions, loot or collision in this review renderer.

Review images: `woodland_full.png` (full world at 2x), `woodland_spaces.png` (reserved encounter rectangles), and three `woodland_view_*.png` files (320x180 gameplay framing at 4x). Terrain edges are deliberately coarse blockout tiles; art polish follows spatial review. The camp chest is a visible landmark prop only, not a reward implementation. Firefly placement is deferred until the final scene is registered; the current renderer shares the approved forest moonlight and warm prop lights.

Claude handoff: review-only proposed scene ID `woodland_approach_review` must not be added to save tables as-is. Choose/register the production ID, connect village -> new approach -> existing forest, supply valid entries/checkpoints, collision boundaries and prop bases, real encounter state/spawns/leash/returns and documented snapshot/events. Preserve legacy layered save migration and the sword grant. Proposed west/east stand points are (24,280) and (616,280); main encounter rectangles are (80,224,180,112) and (390,224,180,112), camp (248,80,144,96). Route and full movement/telegraph safety remain unverified until core integration.

Checks: Godot 4.7.2 headless import, `smoke_woodland_blockout.gd`, and windowed `capture_woodland.gd` pass. The smoke checks asset references, full map terrain coverage, separate prop loading and whole visible prop bounds outside all reserved fight floors. Full regression result is recorded in STATUS. No art sources/atlases changed; all tile and prop assets are reused at native size. Human judges scale, art direction and encounter feel; Claude cross-review remains pending.
