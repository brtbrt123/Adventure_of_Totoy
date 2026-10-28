# Compact UI v1 — owner review only

Nine Godot screenshots are in `art/reference/ui_compact_v1/`; `contact_sheet.png` contains all nine. None of this is installed or connected to live UI. Only this new review folder and the new reference folder were written.

## Proposal

- One upper-left contextual card replaces the full-width objective, separate training prompt and lower checklist. Its four small progress marks remain inside the same card. The relevant training key appears there only.
- Remove all three persistent Shift / LMB / Space action cards. Village exploration has no combat strip: only its contextual task and a small TAB button, with `!` for unspent points.
- Combat gets one 24-pixel-high bottom strip with small weapon/item/Aspect icons, thinner health/dash tracks and a thin EXP line along the bottom edge. Edge remains `--`: the current exploration snapshot does not expose its value. No invented resource value is shown.
- Dialogue uses one 54-pixel-high card and a smaller Mira portrait. The welcome is message-only; the removed controls tutorial is not reintroduced.
- Item receipts and level gains share one top-right notice position. Recommend a single queue: show only one notice at a time, briefly, without stacking. Generic gate/task messages can use this same message style, with text wrapping.
- TAB separates Stats, Aspects and Bag. Stats have one clear value/cap and plus button per row, brighter effect copy, available points and village Respec. Aspects distinguish the owned/equipped Sprint from locked discoveries and locked sockets. Bag groups items beside the selected item's explanation.

## Dimensions (320x180 native canvas)

| Element | Size | Coverage |
| --- | --- | --- |
| Single-line objective | 158x29 | 8.0% |
| Training card | 158x37 | 10.1% |
| Combat strip | 306x24 | 12.8%, plus thin EXP line |
| Dialogue | 296x54 | 27.8%, versus old 35.0% |
| Welcome | 200x60 | 20.8%, versus old 50.0% |
| Item / level notice | 106x30 | 5.5%, one at a time |
| TAB panel | 276x145 | 69.5%, versus old 86.6% |

The contextual card wraps at 142 pixels and grows by 9 pixels per extra row, accommodating longer objectives without becoming a full-width banner. Body copy is 8–9 native pixels, supporting labels 7, and tiny socket/review labels 6. Text uses the existing real font at window resolution. These are proposals for human readability review, not accessibility guarantees.

## Screens and fixture truth

1. `01_training.png`: real village, approved armed hero and real active dash ring. Core receives the first three quest-completion flags and 20 EXP. Only the current dash lesson is described; no lower duplicate checklist.
2. `02_woodland.png`: real woodland and first encounter after 35 normal idle simulation ticks. Core receives the completed village flags, Sprint ownership, 95 EXP and two herbs. Hero/mobs/HP/unlocks/telegraphs come from the actual snapshot. Existing mob bars are unchanged in this review; combat warning lanes remain untouched.
3. `03_dialogue.png`: real village and unarmed arrival hero. Mira portrait is the existing approved asset; displayed text is the existing second `mira_intro` line. This is a static layout fixture, not a running conversation.
4. `04_welcome.png`: the same arrival state, with only welcome text, Find Mira and Begin.
5. `05_item_receipt.png`: first ten quest flags, 75 EXP and two herbs set through core fixture APIs. The receipt is a static example of the Elder's two-herb reward, with the actual next Edda objective.
6. `06_level_toast.png`: completed village fixture at 95 EXP, level 3, four total unspent points. The notice shows the two points for one level gain; it does not claim only two total points remain.
7. `07_stats.png`: same level-3 fixture, zero spent stats, four unspent points, 110 max HP. Menu figure is the current approved hero frame at native scale; weapon label derives from the snapshot ID.
8. `08_aspects.png`: Sprint owned and assigned to Z; X/C sockets remain locked. Other Aspect icons are dimmed and locked. Sprint duration, cost and cooldown match current core tuning.
9. `09_bag.png`: actual fixture inventory contains two herbs. Katana is the equipped weapon. Empty slots make no claims about additional ownership.

The fixture values are seeded for review rather than earned by playing the whole quest chain. Buttons, tab changes and queue timing are not implemented; this is a read-only visual proposal. World assets are the real current assets, not generated replacements. Small UI icons are resampled once in memory to an integer native raster with nearest-neighbour filtering; source images are untouched. The gameplay canvas and hero render at the normal integer 4x scale.

## Technical preview checks

**PASS:** the final windowed Godot run returned exit 0, printed `UI COMPACT REVIEW OK`, and saved all nine 1280x720 captures plus the contact sheet. `art/reference/ui_compact_v1/checks.json` records 89 text measurements with no width failures. No script or rendering errors remain. The machine's root certificate-store warning remains unrelated to rendering. Final images were inspected for visible clipping, intended content, current hero, notification separation and controls removal.

Reproduce from the project root:

```powershell
& 'C:\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe' --path . --script res://presentation/review/ui_compact_v1/capture_review.gd
```

The script clears persistence before creating its own exploration instance, so the real save is not modified. It does not edit core, shared data, existing tests, live presentation or the art pipeline. No Git mutation was performed.

The owner judges appearance and readability. Runtime navigation, touch targets, long localization strings, notification duration and gameplay feel still need implementation/testing after approval. The parent agent's full harness covers the separate functional progression checkpoint; this preview pass does not replace that verification.
