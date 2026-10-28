# Woodland polish — art review first (2026-10-28)

Owner instruction: "Send ART FOR REVIEW FIRST ... before installing it." This folder and art/reference/woodland_polish_v1 contain review sources/captures only. No installed HUD, bindings, mob renderer, save behavior, art/src or art/build atlas has changed. Core/data/tools/harness/docs remain untouched. d4ac13a supersedes the earlier missing-level/unlock-field concern: the new snapshot fields and events now exist.

## Review images (art/reference/woodland_polish_v1)

- hud_snapshot.png: proposed layout over the actual forest, reading d4ac13a level, HP, item count and mob level. Armed slot1 ready, slot2 and all exploration Aspects locked. A visual-only '--' marks the missing Edge value; no value copied from an idle loadout core. This is a standalone capture, not installed gameplay.
- hud_proposal.png: labelled fixture HP74/140, level5 and55% EXP. hud_gain.png shows the short level-up plate and gauge glint. hud_down.png shows the dimmed down state; hud_locked.png is the unknown/missing-data fallback fixture.
- slots.png: new16px bound broad-leaf herb, ready/locked item and Aspect looks, key/count badges, event-driven consume flash. The unlocked Aspect example is a style reference, not an exploration unlock.
- gauges.png: 0/25/50/95/100% and top-level full/MAX. Real integration reads snapshot.level/exp/exp_to_next, with exp_to_next0 meaning full.
- mob_bars_100/55/15.png: teal normal and wider lilac stronger plates, type/level and neutral grey HP ghost. Lower placement in the sheet is the unknown-level fallback. Fixture hero level5. Runtime comparison must use both real levels, never assume a stronger enemy.
- numbers.png: cream normal hits, larger cyan counters, lilac hero damage with minus/ink plate, green heal. No reserved combat gold/red in plain numbers. The merger example sums event-reported hits, not calculated damage; heal text will use event.healed, which may be below35 at the health cap.
- effects_a/b.png: six-frame heal, alert, hit, parry, crash dust, stagger stars, death puff and exposed-mark strips. Gold is used only for parry sparks. Native grids have hard alpha; main UI uses the current game's teal frame and real pixel-font system.
- drop.png: brief herb icon/glint at mob_dropped.position, followed by the existing item_received receipt. No manual-pickup rule or delayed inventory grant is proposed.
- states_mossling/boar.png: all11 state rows. Existing body art is preserved; combinations/timing and effect overlays are proposed. Boar recovery rises from its crouch; Mossling stagger uses a dazed pose plus stars. These are contact sheets, not proof of live combat timing. Animation polish and event-based installation follow owner art approval.

## Remaining interface note for Claude

The new progression/slot/mob-level contract is present, including use_item_slot, exp_gained/level_up/mob_dropped, snapshot.exp_total and profile.exp_total. Earlier level/unlock gaps are resolved. One full-HUD detail remains: ExploreSnapshot exposes dash_cooldown_ticks but no authoritative current/max Edge meter. Please expose Edge/current maximum (or an exploration HudSnapshot) before that bar is populated; the review uses a neutral unavailable marker in actual-snapshot mode. A dash cooldown maximum would also keep the full HUD view self-contained. No fake Edge value is derived from the loadout core.

## Installation plan after art review

1. Full HUD only for nonempty snapshot.encounters; hide in village. Read item_slots/aspect_slots.unlocked exactly, absent -> locked. Move numeric1/2 off debug jumps (keep F-key jumps) and send use_item_slot1/2; remove new-client reliance on use_herb_pressed.
2. Read the new progression snapshot; animate presentation-only EXP display and level-up flash/banner/sound from events. hero.max_hp remains the source for HP maximum. Restore core.set_inventory(profile.inventory) and core.set_exp(profile.exp_total) on every entry; save both actual snapshot values on relevant events, keeping killed_* flags.
3. Event-driven merged floating text with outlined pixel font, target/style buckets and a brief rise/fade. No amount inferred from an animation or keypress. Keep mob plates above actual frame bounds, avoid neighboring sprite heads/plates, and retain ghost HP only as presentation history.
4. Install approved effect grids through the art pipeline; consume glow/slot flash only on item_used, drop glint only on mob_dropped, warning geometry remains the exact core TelegraphSnapshot. The lane is maximum reach, the moving mob body is actual contact; do not create a new hit area from sprite pixels.
5. Update the older woodland encounter smoke to one west herb drop plus30 EXP, saved EXP, level-up/max HP, slot locks/key intents, persistent killed_* flags and no reward reroll. Add snapshots/captures for damage merge, all bars/fills/states/down and full route/village suppression. Run focused checks and a full harness after installation.

## Checks at review stage

Windowed Godot4.7.2 captures pass with no script errors. Two review-source tests pass:50 valid native text grids, six frames per effect, hard palette/alpha semantics and reserved colours only in parry. New art is deliberately outside art/src and no production atlas was rebuilt. Baseline full harness: Python, import, core and every suite except smoke_woodland_encounters pass. That unchanged suite has the two documented old fixed-herb assertions (it expects2, d4ac13a gives1 west drop plus EXP). Log: art/build/arena_woodland_polish_baseline.log (ignored). Full gameplay polish is NOT implemented or claimed passing; the baseline cannot verify an uninstalled polish implementation. Review approval and subsequent implementation/testing remain outstanding. Human judges aesthetics, motion, legibility and combat/audio feel; Claude cross-review follows implementation. Nothing merges automatically.
