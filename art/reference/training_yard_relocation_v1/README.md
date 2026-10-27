# Roomier training yard and reward popup review

Review fixtures only; official scene data and core are untouched. Full task is `docs/CLAUDE_TASK_village_playtest_polish.md`.

- `village_layered_proposal.json`: dummy/object feet380,180; stand380,196.
- `roomier_yard.png`: proposed rendered position on open ground south of forge.
- `weapon_received.png`: sample receipt UI, not an actual inventory grant.
- `swing_effect.png` / `parry_effect.png`: imported combat effect assets in the proposal fixture.

`tests/capture_village_polish.gd` measures ring clearance then captures the proposal using the actual renderer. Headless mode only runs the geometry probe. The radius44 ring has32/32 free hero-radius6 sample points (current layered27/32). Painted candidate390,212 also has32/32 against current obstacles; it still needs matched collider/ground changes and full walking/dashing routes.

Human layout, audio and visual approval pending. The smaller training-card design was approved separately.
