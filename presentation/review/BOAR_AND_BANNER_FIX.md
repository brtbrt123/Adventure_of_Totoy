# Boar feedback and level-up banner fix (2026-10-28)

Owner reported a stale/plain Boar charge and a level-up banner stuck after travel.

## Banner
The previous draw condition accepted negative elapsed ticks. ExploreCore resets tick on scene entry; a level-up tick from the previous scene could therefore display for a long time. HUD now explicitly clears gain/level/item timers on every core entry, also clears on scene/timeline changes in sync_combat, and requires0<=elapsed<duration. Banner duration stays65 simulation ticks (~1.08s while stepping). Tests cover visibility, expiry, future tick rejection, travel clearing and other flash resets.

## Boar presentation
The old effects only covered hit/stagger/death; windup and moving strike had no effects. Added boar_motion.gd cosmetic history using actual snapshot positions and state transitions: alternating rear hoof scrapes, launch dust, a fading-by-frame trail behind the real moving body, recovery skid, larger crash dust and impact. Windup's late two crouch frames alternate rather than holding still, and charge gallop cycles every8 ticks rather than16. All frames/effects are previously approved existing art, rendered at integer scale; no new art source or unapproved body redesign installed. No core/data or attack timing/speed/damage/reach/collider edits. Telegraph lane remains the core lane; nothing predicts contacts or applies damage.

Real encounter captures: art/reference/boar_feedback_20261028. Reproduce windowed tests/smoke_boar_feedback.gd -- --capture. The smoke also verifies no invented trail when stationary, trail expiry/reset, launch/crash state transitions, and real Boar windup/strike plus supplied charge sound. Snapshot position history is bounded and cleared on scene entry. Human must judge motion weight, dirt visibility/noise and collision/readability in play; no claim that fun or art feel was proved by tests.

Focused woodland polish and Boar feedback pass. Full harness passes: Python discovery, Godot import, core and every smoke including Boar feedback and the expanded woodland polish regression. Log: art/build/arena_boar_banner_full.log (ignored). Windowed real-encounter capture passes. No new art-source changes, so no atlas rebuild is required for this presentation-only pass. Captures show live charge/windup/recovery; the crash burst is covered with snapshot transition fixtures, not an asserted real-prop crash capture. Existing docs/architecture.md edit untouched. No push or merge. Claude cross-review pending.
