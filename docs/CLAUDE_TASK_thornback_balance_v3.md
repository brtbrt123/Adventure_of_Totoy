# Thornback balance and summon rules — core implementation needed

2026-10-30. Owner approved the V3 previews by saying "wire them and tell me if claude need to do something". Presentation wiring is installed; **core gameplay changes below are still needed**. Use the reviewed 1.5x charge speed and preserved travel as the accepted implementation target. Eruption coordinates in review images remain illustrative, never registered gameplay positions.

Review: `art/reference/thornback_fx_review_v3/revised_attacks.gif` and `moth_regeneration.gif`. Existing summon reveal: `art/reference/thornback_fx_review_v2/summon/chant_summon_five.gif`.

## Explicit owner requirements

1. Slam reach x2.5. Existing reach 50 becomes 125. Keep warning geometry exactly equal to the actual hit region; no presentation-only enlarged range. No change requested to cone half-angle, damage, windup or recovery.
2. Faster charge. Reviewed target: 1.5x, 4.4 -> 6.6 pixels/tick, reducing strike 36 -> 24 ticks to preserve existing total travel 158.4. Preserve warning duration and width. Test swept collision at increased speed against props, hero and thin obstacles; avoid tunnelling and duplicate contacts. The previously reviewed `fx_spin_contacts` fix is separate hero presentation behavior; retain it.
3. Eight eruption locations instead of one. Each distinct damage site needs its own matching warning before commitment. Preview uses simultaneous roots, unchanged radius 34 and 50/5/40 phase timings. Preview sites are intentionally illustrative; core must select valid distinct sites in the actual arena, respect walkability/props/exits, and preserve escapable gaps. Do not copy the static preview coordinates into encounter data. Final timing/targeting policy needs owner review if different from the preview.
4. New chant attack glows the horns then summons exactly five Glowmoths. No runtime summon state was installed by these art passes. Define the attack state/timing/cooldown and emit pose/FX/spawn events through the established interface; presentation must not spawn rules-bearing mobs.
5. While **any of that Stag's summoned moths remains alive**, heal **2% of the Stag's maximum HP each second total**. Do not multiply the rate by moth count or count unrelated ambient Glowmoths. At current max HP260 this is 5.2 HP/second; retain fractional accumulation rather than rounding each tick to zero. Clamp at max, stop on final moth death/despawn, boss death, encounter reset or unload; no resurrection. Preview assumes max HP for the percentage and one-second heal ticks; owner can adjust this interpretation.

Track summoned moths by caster/encounter identity, not merely a global mob type count. Resolve same-tick final-moth death and healing deterministically. Core owns health changes and summon membership; expose read-only live-summon count/healing state and healed amount events so presentation can show links, +HP and antler pulses. If multiple summon waves can coexist, specify whether they share one fixed heal condition; never accidentally stack the percentage rate.

## Validation requested before wiring is called complete

- Slam exact 125 reach and warning/hit parity at boundary and across facing angles.
- Faster charge distance/duration and swept collisions; no hits beyond warned region.
- Eight distinct, valid root sites with all eight warnings matching actual hit areas; target lock and repeat-seed behavior.
- Exactly five valid summons per cast; spawn locations validated without trapping player or blocking exits.
- One/five survivors give identical 2% max-HP-per-second healing; last death stops it; unrelated moths do not activate it; fractional HP, cap, dead boss, despawn and reset cases.
- Full core harness and affected presentation smoke tests; real renderer checks after approved integration.

## Installed presentation contract

`presentation/explore/creature_effects.gd` is synchronized on scene entry and every snapshot in the shared Explore renderer, cleared on transition/rewind, with ground effects below actors/props and horns immediately after their own body in y-sort. No scene-id restriction. It reads all Stag-owned `stag_roots` telegraphs individually; provide **eight TelegraphSnapshots with unique IDs and their real committed centres**, sharing the Stag owner ID. They remain cached briefly for recovery visuals and are discarded on cancellation/death. The existing TelegraphView draws every warning directly from core geometry. Slam shock reads the exact cone size/direction/half-angle; no visual-only 125-pixel override.

`MobView` now has approved `glowmoth` idle/move/shot/hurt/death poses. Use the existing idle/alert/chase/return/windup/strike/recover/hurt/dead snapshot state vocabulary. `stag_summon` attack ID selects 28 chant frames in windup, then 10 release frames in strike/recover. Proposed non-damaging progress fields on its mob dictionary: `cast_start_tick` and `cast_release_tick` (absolute simulation ticks). The chant follows their interval proportionally. **Do not invent a damaging TelegraphSnapshot for this chant.** These fields, or a proper cast-progress snapshot agreed with Codex, need to be emitted/documented by core.

Optional dictionary fields already consumed by presentation: `summoner_id` on each Glowmoth (Stag mob ID), and `regen_active: bool` on the Stag. These are an **interface proposal for Claude to implement/document**, not fields currently emitted by core. Healing links render only when core explicitly reports regen_active and a live moth names that caster. Green healing pulses use actual snapshot HP increases; presentation never computes the 2% heal. Encounter resets/despawns must invalidate membership. No permanent light node or fake mob is created by the FX renderer.

344 approved native body/effect sprites were imported through `art/reference/thornback_fx_review_v3/install_approved.py`; standard atlas/contact sheets rebuilt. Orb/trail/pop assets are included, but a real Glowmoth projectile snapshot/event interface is **still missing**; ranged-orb travel/hits and their rendering contract need Claude/Codex follow-up rather than a presentation-owned projectile simulation. Five real spawned moth positions must come from core; the preview's fixed five positions are never used at runtime.

Codex did not edit core/, data/, tools/ or harness/. Existing concurrent runtime changes belong to their authors. Real renderer captures of existing attacks and separately labelled eight-root/chant/moth fixtures are under `art/reference/thornback_fx_review_v3/live/`. Fixtures verify presentation, not actual eight-root/summon/healing gameplay. See `LIVE_INTEGRATION.md` there for final checks and limits. Claude cross-review of the presentation diff remains requested.
