# Claude task: village playtest follow-ups (2026-10-27)

The owner explicitly chose **prepare the core tasks for Claude**, not a Codex core override. Owner requests: a roomier dummy area, boss-like slash/parry effects and sounds, quiet village music, an unarmed first arrival, and item/weapon receipt popups. Owner confirmed **Tovan gives the first sword before training**. Keep the normal role split. Codex has not edited core/tools/shared runtime scene data for this work.

## Already done by Codex

- Compact training cards are approved (upper-left 184x29 prompt, lower-right 134x29 two-column checklist).
- `presentation/explore/practice_view.gd` draws existing imported slash/parry/hit/flash assets. Swing sounds follow the observed attack-active transition; contact/parry sounds follow confirmed core events. `village_audio.gd` shares the existing credited combat recordings and runs original `lanternfen_evening.wav` quietly in village scenes, fading outside them. Full harness regression passed; the expanded tutorial smoke verifies shared audio/slash and reward queue behavior. This is wired into exploration and available for playtesting now.
- `presentation/explore/reward_popup.gd` is a non-modal queued receipt view; `Explore.show_reward(receipt)` is the presentation entry point. It waits while controls/dialogue/menu/fade blocks it. Payload example `{kind: &"weapon", name: "Black Katana", icon: "ui_weapon_sword_1", quantity: 1}`. Generic item example `{kind: &"item", name: "Healing Herb", quantity: 2}`. Those examples are TEST FIXTURES, not actual grants. The view currently has no live reward-event hook because core has no confirmed grant event. Do not pretend the sample popup means inventory was granted.
- Unarmed hero: built-in ImageGen produced `art/reference/hero_unarmed_v1/unarmed_sheet_raw.png`. 18 palette-only, hard-alpha review grids (6 idle/6 walk/6 dash; all right-facing) and `unarmed_contact_6x.png` are in that folder. Same Totoy identity/outfit, no sword/hilt/sheath. NOT installed in art/src or runtime: human approval and the core's unarmed state must precede integration. Existing generated hero2_* frames are unchanged.

## 1. Move the training yard, with matched drawing/collision

Layered proposal is `art/reference/training_yard_relocation_v1/village_layered_proposal.json`: dummy prop and dummy object feet **(380,180)**, stand **(380,196)**. Current placement is (345,118). Candidate is on open ground south of the forge; the nearby NPCs and other props are unchanged. Do not promote the fixture until the owner selects it.

Painted candidate feet **(390,212)** (1x coordinate roughly (557,303), rounded at scale0.7). Candidate stand **(390,228)**. At the current painting's scale the old dummy is (328,148); its SOLIDS_1X circle and the `TRAINING_DUMMY` / `TRAINING_DUMMY_1X` constants must move consistently. Update scaled tests and the training object/stand via SceneDefs. The old painted dummy and old depth occluder must also be removed before shipping; coordinate the ground/occluder art with Codex rather than moving invisible collision alone. Claude owns the painting generator in tools; a clean generated output can be delivered for Codex to install. Avoid a duplicate post.

Measured by `tests/capture_village_polish.gd --headless`: 32 samples on a radius44 ring about the training center, hero radius6, include scene boundaries, props and NPCs. Layered old **27/32**, proposed **32/32**. Painted candidate **32/32** against current obstacles. This is a local clearance probe, NOT a full route/dash/collider audit. New dummy colliders, full 96px yard, route accessibility, quest NPC interactions and exit routes still need Claude's tests after promotion. Painted base is deliberately separate from layered because the maps differ.

Windowed fixture capture: `tests/capture_village_polish.gd`; screenshots in the same proposal folder: `roomier_yard.png`, `weapon_received.png`, `swing_effect.png`, `parry_effect.png`. Only the review instance's data is replaced; official runtime scene data stays untouched.

## 2. Tovan's first sword and unarmed arrival

Core should expose a truthful, saved first-sword grant. Before the first Tovan handover, the hero is unarmed; after it, katana art and training are available. Do not infer ownership solely from presentation. Suggested contract: a saved `received_first_sword` story flag plus an explicit unarmed/armed value in ExploreSnapshot. Pick and document the exact field/API in architecture; Codex will consume it. If choosing a new `hero.visual_id`, coordinate ArenaAnimation handling (it currently uses visual_id `totoy` to enter hero logic).

- Put Tovan's handover text/data and flag/grant in core/data, keeping the owner's dialogue budget and placeholder-text convention. Completing/skipping/rehousing the conversation must have deliberate, deterministic semantics.
- The first sword is given **before training**, not as its graduation reward.
- Prevent duplicate inventory grants and duplicate receipts when talking again, reloading, changing scenes or continuing. Decide legacy-save migration for players who already met Tovan (avoid trapping their tutorial). NEW GAME resets the grant.
- Audit pre-grant menu/equip/attack behavior so unarmed appearance is backed by actual core state; presentation must not invent inventory restrictions. Boss-fight debug/direct mode should retain its current armed loadout.
- Restore proper combat snapshot values: `ExploreCore.snapshot()` currently hard-codes `hero.combo_index = 1` around line251. Copy the player's actual combo index and locked swing speed so subsequent swing poses/effects match resolved combat. This is the previous P2 review finding.

## 3. Real reward event for the receipt view

Add/document a core event for a successful item/weapon grant (for example `item_received` with stable reward ID, kind, item ID, quantity and display name). Emit it ONLY when the saved inventory/flag change actually occurs. No event for loading existing inventory. Rendering icon keys should be mapped by presentation from item/weapon ID rather than putting atlas data in core. Codex then adapts it to `Explore.show_reward`.

The sample name "Black Katana" is a UI fixture, not an owner decision to rename/rebalance the first sword; use the existing weapon definition or confirm any new weapon design.

No automatic live handover popup is wired yet. The queued view/capture/smoke are ready; this event is the missing integration piece.

## Acceptance / review

Core stays headless. Test fresh/legacy save, grants once, skip/end semantics, scene transitions, pre-grant restrictions, post-grant training and correct combo snapshot. Validate new dummy routes walking/dashing and no old collider/duplicate rendering. Run full harness after the final integration, and cross-review Codex presentation diff with pass/fail. Human judges the roominess, audio/music mix, hero identity/motion and UI appearance; technical tests cannot establish those.
