# Chapter 1 characters v2: NPC sprites, interactables, portraits, dialogue UI (for review)

Status: **draft for the human's review. Nothing is wired in.** No file in `core/`, `tests/`, `presentation/`,
`art/src` or `art/build` was touched, and nothing is committed. `art/reference/chapter1_creatures/` (approved) is
untouched. This replaces the rejected v1 in `art/reference/chapter1_characters/` (left in place for comparison).

Regenerate everything (Pillow only, deterministic: two runs give byte-identical files):

```powershell
python tools/art/make_chapter1_characters_v2.py
```

Every atlas pixel is a Totoy 36 colour with hard alpha; gold (`x`, `y`) and red (`z`, `A`) are never used (the script
checks the three atlases at the end and prints `atlases checked`).

## Supplied vs derived

| Item | Supplied by the human | Derived by the script |
|---|---|---|
| NPC poses | Mira x3, Tovan x3, Edda x3, Village Elder, Village Child, Village Worker, cropped from `chapter1_cast_target.png` | every animation frame (see below) |
| Interactables | Training Dummy, Old Chest closed + open, Healing Herbs, both Lanterns, from the cast sheet | lantern glow frames 2-4, dummy hit frames |
| Portraits (neutral) | Mira (from `chapter1_dialogue_scene_target.png`), Totoy, Tovan, Edda, Elder, Child, Worker (`chapter1_portraits_target.png`), Edda staff (`chapter1_portrait_edda_staff_target.png`) | - |
| Portrait expressions | - | happy, worried, serious for Mira, Totoy, Tovan, Edda (pixel edits of the supplied neutral) |
| Dialogue UI | look only: the box in `chapter1_dialogue_scene_target.png` | all pieces are drawn by code in that style |

"Derived" never means redrawn: frames and expressions only move, copy or recolour pixels that already exist in the
converted supplied art (rows shifted, leg blocks nudged, eye pixels closed with the surrounding skin colour, brow
pixels moved, mouth-line pixels bent, the staff fragment stepped one palette step brighter). I compared each derived
frame with its source at 4x (`expressions_check_4x.png`, `contact_npcs_*.png`, `compare_cast.png`); variants that put
light streaks on the faces were discarded and the edit rules changed until none were left.

## How the conversion works

1. **Cut-out:** a generous crop per figure; the flat panel and the drop shadow are flood-filled from the crop border
   (panel colour, or a darker teal-tinted shadow); Edda's cyan staff halo and the lanterns' warm light halo are removed
   by region growing in small colour steps. Loose blobs are dropped: hard alpha.
2. **Scale:** one scale for the whole cast, 2.5 source px per game px, so relative sizes stay as on the sheet. Lanczos
   with premultiplied alpha, after a light unsharp mask and +25 % contrast, +35 % saturation (without that the sage
   coats and teal scarves fall into the brown and stone ramps).
3. **Palette:** nearest colour in Lab (lightness weighted), reserved colours excluded; colours used by fewer than 2 % of
   a sprite's pixels are folded into the nearest frequent one; lone-pixel cleanup and a 4-neighbour smoothing pass;
   a 1 px ink outline on the silhouette edge where the edge pixel is lighter than the ink (like `import_reference.py`).
4. **Eyes:** the downscale averages the 1-2 px eyes of the cast sheet into the skin, so the pixels where the SOURCE
   has dark pixels inside the face get the ink back (detected on the source, not placed by hand).
5. **Portraits:** each panel interior is measured on the plot's black axis spines (six-panel sheet: 216 px per 88
   source px; Edda staff: 194x203, slightly stretched), area-averaged back to 88x88, +35 % contrast (spreads the narrow
   painted skin range over q/r/s), Lab snap, cleanup, background flood-filled to transparent (step-wise for the
   panel's soft glow; Totoy's dark hair is protected by the panel's teal tint; Edda staff's cyan halo removed), ink
   edge on the silhouette. Mira: the 89x89 window inside the teal line of the scene target.

## 1. NPC sprites (`npc_sprites_v2.png` / `.json`)

Cells **32x40**, anchor **(16, 37)** = feet (centre of the soles, one row under them, the hero's rule). Facing: the
cast sheet draws 3/4 views turned slightly right; they are used as `right`, `left` = mirror around `ax` (like
`hero2_*`). Names `npc_<name>_<state>_right_<n>`. Heights: Mira 32, Tovan 31, Edda 31, Elder 28, Worker 30, Child 23
(Totoy `hero2_idle_right_1` is 34 with his hair).

| NPC | States (frames) | Built from |
|---|---|---|
| mira | idle 4, walk 6, talk 3, compass 1 | idle/walk: pose 1; talk: pose 3 (pointing); compass: pose 2 |
| tovan | idle 4, walk 6, talk 3, anvil 1 | idle/walk: pose 1 (hammer); talk: pose 2 (arms crossed); anvil: pose 3 with the anvil |
| edda | idle 4, walk 6, talk 3, cane 1 | idle/walk: pose 2 (staff); talk: pose 3 (open hand); cane: pose 1 |
| elder, child, worker | idle 4, walk 6 | their single pose |

Suggested ticks at 60/s (also in the JSON): idle `24, 14, 14, 8` (2-3 breathe: upper body down 1 px; 4 = blink;
Edda's staff fragment brightens on the breath), walk `7` x6 (contact, down, passing, contact, down, passing: the leg
block is split at the feet centre and nudged 1 px, the body bobs 1 px), talk `10, 8, 10` (2: mouth pixel darkened;
3: Mira's pointing arm rises 1 px, Edda's fragment glows, Tovan's upper body dips 1 px).

**Interactables** (same atlas, anchor = bottom centre): `obj_dummy_1`, `obj_dummy_hit_1..2` (top leans 1 px back and
forth, ticks 4, 4), `obj_chest_closed_1`, `obj_chest_open_1`, `obj_herbs_1`, `obj_lantern_1..4` (hanging lantern),
`obj_lantern_post_1..4` (post with lantern); lantern loop ticks `12, 10, 12, 10` (normal, glass one step brighter,
normal, one step dimmer).

## 2. Portraits (`portraits_v2.png` / `.json`)

**88x88 for every character, drawn at scale 0.5** (44 game px) in the socket window. Why: the painted portraits are
native 88x88 and in the target box the portrait is about 42 game px with a visibly finer pixel grain than the world.
With stretch mode `canvas_items` (decision 0004) a 0.5 scale gives exactly 2 window px per portrait pixel at the
default 1280x720 and 3 at 1920x1080, so it stays integer and sharp; the box stays at the target's proportions (68 game
px tall). At a 3x window (960x540) it would be 1.5 px per pixel: there, draw at scale 1 or round to 1x/2x (question 3).
The 64/80/96 game-pixel options from the first brief would make the box 40-55 % of the screen height; not built.

- `portrait_<name>_neutral` for mira, totoy, tovan, edda, elder, child, worker; `portrait_edda_staff` (Edda raising
  the glowing staff: for lines where she uses her Aspect power or explains binding).
- `portrait_<name>_{happy,worried,serious}` for mira, totoy, tovan, edda (derived).
- Background: transparent; the socket window is ink. Totoy's portrait is for dialogue only; the hero sprite is
  unchanged.

**Drop-in for new or replacement portraits** (one command; a single plot panel is detected on its axis spines, a
plain painting is used whole):

```powershell
python tools/art/make_chapter1_characters_v2.py --portrait NAME PATH
```

It writes `portraits_extra/portrait_NAME_neutral.png` (88x88) and rebuilds the atlas and sheets; a name that already
exists replaces that neutral. Expressions are not made automatically for a new image: the face rectangles in `FACES`
must be measured for it first. Per-image options (halo removal, protecting dark hair, excluding greens) live in
`PORTRAIT_SOURCES`.

## 3. Dialogue UI (`dialogue_ui_v2.png` / `.json`)

1x game pixels for 320x180; layout, colours, fonts and ticks are in the JSON (`layout_320x180`).

| Piece | Size | Notes |
|---|---|---|
| `ui_dlg_box` | 240x68 | stone pillars (11 px) with a teal rune channel, wooden beams, ink text inset. 9-slice margins left/right 11, top/bottom 12; tile the edges; the rune channel repeats every 11 px |
| `ui_dlg_socket` | 50x50 | ink + stone ring, thin teal line with rounded corners; window (3, 3, 44, 44) for the 88 px portrait at 0.5 |
| `ui_dlg_nameplate` | 60x13 | stone plate, etched corners, green pointer; name area (3, 3, 50, 7); name drawn by the game (Cinzel 700, colour `7`) |
| `ui_dlg_badge` | 38x11 | empty key badge (lilac rim); icon at (2, 2), "ENTER" text at (15, 3) drawn by the game |
| `ui_dlg_icon_gamepad`, `ui_dlg_icon_key` | 11x7, 9x7 | badge icons for pad / keyboard |
| `ui_dlg_choice_arrow_1..2` | 6x7 | teal chevron, frame 2 nudged 1 px (ticks 20, 20) |
| `ui_dlg_next_1..3` | 5x8 | the 'next' triangle that sits in the right pillar's bottom slot: bright, dim, bright down 1 px (ticks 24, 12, 12) |
| `ui_dlg_moss_tl`, `_tr`, `_bl` | 24x22, 24x20, 26x14 | moss overlays for the corners (draw over the box, under the plate) |

Text: body Pixelify Sans 9 game px (the project size; colour `1` with an ink shadow), selected choice `o`, dim choice
`h`, wrapped to 156 px. Layout: box (40, 110), socket (52, 119), plate (54, 104), text (110, 121), line step 11,
badge (229, 169), next arrow (272, 168).

## Files

| File | What |
|---|---|
| `npc_sprites_v2.png/.json` | NPC + interactable atlas: frames with `ax`/`ay`, states with frame counts and ticks |
| `portraits_v2.png/.json` | 20 portraits at 88x88, `supplied` / `derived` lists |
| `dialogue_ui_v2.png/.json` | UI pieces, 9-slice margins, layout, colours, fonts, ticks |
| `contact_npcs_dark.png`, `contact_npcs_grass.png` | all NPC and object frames at 4x, labelled |
| `contact_portraits_dark.png`, `contact_portraits_grass.png` | all portraits at 2x pixels (= 4x game scale at their 0.5 display scale) |
| `expressions_check_4x.png` | supplied neutral next to the derived expressions, 4x |
| `dialogue_ui_4x.png` | UI pieces at 4x |
| `npc_<name>.gif` | each NPC at 4x on grass: idle x3, walk x3, talk x4, at the suggested ticks |
| `obj_lantern_post.gif`, `dialogue_next_blink.gif` | the lantern glow loop and the next-arrow blink |
| `lineup_game_scale_1x.png`, `_4x.png` | Totoy (`hero2_idle_right_1`), the six NPCs and the objects at game scale |
| `dialogue_mockup_mira_4x.png`, `_mira_1x.png` | Mira with two choices (1x: layout only, the portrait is subsampled to 44 px and text is 1x) |
| `dialogue_mockup_totoy_4x.png`, `_tovan_4x.png`, `_edda_staff_4x.png` | a Totoy line (keyboard badge), Tovan (serious), Edda with the staff portrait |
| `compare_target_vs_ours.png` | the target scene beside our Mira mockup at 1280x720 |
| `compare_box_closeup.png` | the same game rectangle of the box, target over ours |
| `compare_portraits.png` | each supplied painting (resampled to 88) beside its conversion |
| `compare_cast.png` | each cast pose (smooth downscale) beside the hard pixel-art conversion |

The mockup village is flat colour on purpose (not the painting).

## Village scene note (S1)

The dialogue scene target also shows the look of Lanternfen (3/4 view, forest edge, hanging lanterns, stone-and-timber
hut, barrels, a rune gate with teal glyphs, flagstone path). It is **not converted**. It is a candidate reference for
scene S1, but it needs a clean painting without the characters and the dialogue box before a conversion like the
arena's (`make_arena_ground_from_reference.py`) is possible.

## Known limits

- 2.5x downscale: at 28-32 px the faces are 1-2 eye pixels; clothing detail (Mira's satchel strap, Tovan's hammer,
  Edda's hands) blurs into 2-3 colour blocks. The sage coats read grey-brown (the palette has no sage).
- Walk cycles are procedural nudges of a standing pose (legs shift 1 px, body bobs): readable as walking, not a real
  stride. Robed characters (Edda, Worker) mostly sway at the hem. Not seen in game.
- Talk mouths are a single pixel; on some poses (Tovan in the beard, Worker) it is barely visible.
- Healing Herbs is the weakest object: the small white and blue flowers merge into the leaves.
- Totoy's portrait expressions are subtle: his brows are hidden under the fringe and headband in the supplied
  painting, so only the eyes and mouth change. Edda's are subtle too (soft painted features).
- Portrait colour: the painted skin is compressed into q/r/s; some soft gradients became flat bands.
- Moss overlays are generated tufts, simpler and less lush than the painted moss in the target.
- The mockups use Pixelify 9 px for the body text (project rule); the target's text is smaller and narrower, so our
  question wraps to two lines.

## What I could not judge

Whether the characters, portraits and the box look good and match your taste; whether the animation reads in motion
in the game (only GIFs were seen); readability at 3x windows.

## Questions for the human

1. Portrait display: 88x88 at half scale (as built, matches the target) or a different size?
2. Body text: keep Pixelify 9 game px (wraps more than the target) or allow a smaller dialogue size (e.g. 8)?
3. At window sizes where 0.5 is not integer (3x), draw portraits at 1x scale, or lock the window to even multiples?
4. Tovan's anvil pose and Mira's compass and Edda's cane poses are single frames: wanted as states, or drop them?
5. Should NPCs face left as well by mirroring (like the hero), or do you want separate left/up/down views later?
6. Name plate colour: pale green (`7`) like the target, or cream?
7. Herbs: accept the converted version, or supply a larger/cleaner reference for the pickup?
8. When will the clean Lanternfen painting (without characters and UI) come for scene S1?
