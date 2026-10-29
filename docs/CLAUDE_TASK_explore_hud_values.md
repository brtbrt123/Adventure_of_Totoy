# Exploration HUD snapshot values for Claude

The SpriteCook kit is integrated at 384x216. All meters must show authoritative snapshot values. The arena HUD already exposes Edge, cooldowns and active durations, but `ExploreSnapshot` currently exposes none of these for the road HUD.

Please extend the exploration snapshot/contract with the hero's current Edge and maximum, and each equipped Aspect's current cooldown and remaining active ticks (with duration/maximum where required to normalize the rings). Read existing player values; add no rules or balance changes. Specify reset and scene-transition behavior and add headless tests for Sprint use/cooldown and Edge regeneration. Update `docs/architecture.md` when the interface is agreed.

Then Codex can connect the road's teal bar and Sprint rings without inspecting mutable core internals. Currently the Edge bar is explicitly unavailable (`EDGE --`), and unavailable Aspect icons are dimmed using the existing slot `usable` flag. No fabricated resource amounts or timers are shown.

Presentation already handles health's delayed ghost segment, EXP interpolation, owned/unlocked slots and item counts from the existing snapshot.
