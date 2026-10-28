# Progression art review first (2026-10-28)

Read AGENTS.md, newest STATUS, architecture village sequence contract, CODEX_TASK_progression. Owner explicitly requires new art review before installation. This is the art gate, not a claim of completed runtime progression jobs. No production code, core/data, tests, art/src or atlas changes in this stage. Existing docs/architecture.md edit preserved. No merge/push.

Review sheet: art/reference/progression_v1/review_raw.png. Reference1 was the existing village_chest, reference2 the approved copper/stone HUD. Proposed six chest phases, four teal objective arrows, four circular practice-ring highlights, lock/slot and stats-card style. Stat rows and values in sheet are illustrative; runtime reads snapshot stats/caps/points. Existing approved UI frames/locks can be reused; no new ability icon set is required.

## Corrections required during installation
Raw AI sheet has soft alpha/glow (0..254), not engine-ready. Remove soft halo and quantize to Totoy36 with hard alpha. Native objective marker16x16, ring exact28px diameter (radius14) centered in padded canvas; four phases never change actual reach. Chest frames require native alignment/perspective/body consistency against original40x32 chest, with headroom for lid and existing feet/ground anchor preserved. Don't replace existing closed art or alter shared colliders without explicit owner approval. Existing closed image is the production source; generated open states are style/pose candidates to reconcile to it. No raw generated backdrop or baked stat text is installed.

## Implementation order after approval
1 objective.text line/target marker; task-completed EXP toast/rewards.
2 attack/dash/parry/item/Aspect locks from snapshot; small locked hint; new training order and ring.
3 exit_blocked banner using event text.
4 chest_opened animation and Elder basket line.
5 preserve approved intro/arrival.
6 TAB stats/spend/respec, snapshot-owned Aspect filtering, set_loadout/set_stats on every core and saves from confirmed events.
7 level-up actual points label, +2 for current rules.
8 every debug jump debug_all_unlocked; update listed old smokes with proper quest or debug fixtures, captures, full harness.

## Review-stage checks / remaining
Confirmed source file loads and contains all requested design groups; source hash/dimensions/alpha recorded. No native pipeline/full harness run yet because these are uninstalled proposals and raw alpha is intentionally not claimed validated. All runtime jobs, focused tests, smoke fixes and final harness remain after owner art approval. Human judges look, ring visibility, chest design, pacing/texts. Formal Claude cross-review follows implementation.
