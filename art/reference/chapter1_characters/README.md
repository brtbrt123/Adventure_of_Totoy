# Chapter 1 characters: NPC sprites, dialogue portraits, dialogue UI (v1, for review)

Status: **draft for the human's review. Nothing is wired in.** No file in `core/`, `tests/`, `presentation/`, `art/src` or
`art/build` was touched, and nothing is committed. The mob and creature art is a separate deliverable
(`art/reference/chapter1_creatures/`).

Regenerate (Pillow only, deterministic: two runs give byte-identical files):

```powershell
python tools/art/make_chapter1_characters_art.py
```

Every pixel is a Totoy 36 colour with hard alpha. Gold (`x`, `y`) and red (`z`, `A`) are not used anywhere (the script
asserts this on every pixel and re-checks the three atlases at the end). Warmth comes from the dirt, skin and cream ramps.

## 1. NPC world sprites (`npc_sprites_v1.png` / `.json`)

Right-facing side view like the hero; left is the mirror around the anchor (same convention as `hero2_*`).
Cells are **32x40**. The anchor is the feet: `ax` = the hip column, `ay` = 36, one row under the soles (the hero uses
the same rule). Adults are about 29-31 px tall (Totoy is about 33 px with his hair), the child about 22 px.

| Character | States (frames) | Look |
|---|---|---|
| `mira` | idle 4, walk 6, talk 3 | mapmaker: auburn hair to the shoulders, blue coat, teal scarf with a tail, ink-stained dark gloves, a satchel on the back hip with a rolled map sticking out, a brass compass (dirt_6, not gold) on the belt |
| `tovan` | idle 4, walk 6, talk 3 | smith: broad, cropped dark hair, short full beard, linen shirt, leather apron, bare heavy forearms, a hammer hanging at the belt, soot on the apron |
| `edda` | idle 4, walk 6, talk 3 | Aspect keeper: elder, silver hair with a bun, green shawl with a leaf and feather charm, lilac long dress, slightly stooped, a walking staff topped with a teal fragment that glows on the breath and lifts on the talk gesture |
| `villager_child` | idle 4, walk 6 | small, big head, messy hair, green tunic, a lantern whose glass flickers between frames |
| `villager_farmer` | idle 4, walk 6 | older man, wide straw hat (the widest silhouette), grey mustache, cream shirt, blue overalls |
| `villager_basket` | idle 4, walk 6 | woman with a lilac headscarf, teal dress with a cream apron, a basket of greens and plums on the hip |

Suggested names (the JSON keys): `npc_<name>_<state>_right_<n>`, `n` from 1, for example `npc_mira_talk_right_2`.
Suggested ticks per frame at 60 ticks/s (presentation decides): idle `20, 12, 20, 6` (frame 4 is the blink; holding
frame 1 longer or picking the blink at random also works), walk `7` each, talk `9` each.

- Idle: the upper body sinks 1 px on frames 2-3 (breathing), frame 4 blinks.
- Walk: contact, down, passing for each foot; hips drop 1 px on the contact frames; the near arm swings against the
  near leg; skirts sway; satchel, hammer, lantern and basket bob.
- Talk: the near hand rises in a small open gesture over 3 frames, the mouth opens on frames 1 and 3 (Edda lifts her
  staff instead and the fragment glows).

How it is made: hand-drawn head and torso grids per character, procedural legs, arms, skirts and held props (a small
rig in the script), one ink outline pass, and an ink line where the near arm crosses the body (like the hero).

## 2. Dialogue portraits (`portraits_v1.png` / `.json`)

64x64 busts facing right (toward the text), hard alpha, a 1 px ink outline on every piece, light from the upper left
(the same as the world sprites: highlight rim on top/left edges, shadow on bottom/right and under hair and chins).

- `totoy`, `mira`, `tovan`, `edda`: **five** expressions each, `neutral`, `happy`, `worried`, `serious`, `surprised`
  (the request allowed "serious/surprised" as one; both exist so the dialogue data can pick). Happy uses closed
  smiling eyes and a blush; worried tilts the brows and adds a small sweat drop (water_5); serious lowers the lids and
  angles the brows; surprised opens the eyes and the mouth.
- `villager_child`, `villager_farmer`, `villager_basket`: `neutral` only.
- Names: `portrait_<name>_<expression>`, for example `portrait_mira_worried`.
- Totoy follows the HUD portrait (`art/reference/hero_portrait.jpg`): dark spiky hair, black headband with tails,
  tanned skin, bare shoulders, dark sleeveless vest over a warm brown shirt, a strap across the chest, determined
  brows in neutral. It is pixel art, not the painted reference.

**64 or 96?** I recommend **64x64** and did not make a 96 set. At 320x180, 64 px is about a third of the screen height:
the face is about 30 px wide and the eyes 6 px, readable at 1x, and the portrait plus its 72x72 frame sit beside a
3-line box without covering the scene (see the mockups). A 96 portrait would be more than half the screen height and
push the box into the middle of the play area. If the human wants bigger faces anyway, the portrait code is
parametric shapes and can be re-tuned for 96, but it is not a free rescale.

## 3. Dialogue UI (`dialogue_ui_v1.png` / `.json`)

Drawn with the same layers as `presentation/arena/ui_panel.gd` `draw_panel` (ink edge, accent line, ink, bevel,
ink fill, 5x5 corner gems) in the `menu` theme (lilac accent `v`, cream gems), so it matches the character menu.

| Piece | Size | Notes |
|---|---|---|
| `ui_dialogue_box` | 232x56 | 9-slice margins 8; text area for 3 lines (Pixelify Sans 9, 12 px line step) |
| `ui_dialogue_nameplate` | 72x16 | notched ends with gems; overlaps the box top; Cinzel 900 name, centred; 9-slice 6 |
| `ui_dialogue_portrait_frame` | 72x72 | the 64x64 portrait goes into the window at (4,4); dark backdrop with a soft disc |
| `ui_dialogue_next_1..3` | 8x8 | "press ENTER" arrow: bright, down 1 px, dim (suggested ticks 18, 10, 10) |
| `ui_dialogue_choice` | 8x8 | teal marker in front of the selected choice |
| `ui_dialogue_choice_bar` | 64x8 | highlight behind the selected choice, repeat horizontally |

Layout at 320x180 (in the JSON as `layout_320x180`): portrait frame at (8,100), box at (80,116), name plate at
(88,106), first text line at (90,128), next arrow at (298,160). Body text is mixed case (easier to read in sentences
than the all-caps menu text); the name is in capitals like the menu titles. Text is drawn at window resolution with
the project fonts (decision 0004), as in the mockups.

## Files

| File | What |
|---|---|
| `npc_sprites_v1.png/.json` | NPC atlas, one row per character, 32x40 cells, frames with `ax`/`ay` |
| `portraits_v1.png/.json` | 23 portraits at 64x64 |
| `dialogue_ui_v1.png/.json` | UI pieces at 1x, 9-slice margins, layout, font notes |
| `preview_contact_dark.png`, `preview_contact_grass.png` | NPC frames at 4x, labelled |
| `portraits_contact_dark.png`, `portraits_contact_grass.png` | all portraits at 4x, labelled |
| `dialogue_ui_4x.png` | the UI pieces at 4x |
| `npc_<name>.gif` | each NPC at 4x on grass: idle x3, walk x3, talk x4 (villagers idle + walk), at the suggested ticks |
| `npc_lineup_game_scale_1x.png`, `_4x.png` | Totoy and all six NPCs on a flat-colour path at 320x180 (the readability check) |
| `dialogue_mockup_1x.png`, `dialogue_mockup_4x.png` | Mira talking, 3 lines, next arrow (1x has 1x text, only for layout) |
| `dialogue_mockup_choice_4x.png` | Mira happy, a question and two choices with the marker and bar |
| `dialogue_next_blink.gif` | the next arrow blinking in the mockup (2x) |

The village in the mockups is flat colour on purpose (no background art was requested).

## Known limits and what I could not judge

- Whether the characters look charming and match the human's taste: only the human can judge that.
- The NPC near arm is the same colour as the sleeve or torso and disappears in some idle frames (Mira, Edda); Tovan's
  bare forearm reads as a light column over his apron. The hammer at his belt is small and dark at 1x.
- The walk is a simple 6-frame cycle with procedural legs; it has not been seen in game at real speed next to the
  hero (only in the GIFs).
- On the dark contact sheet the ink outlines merge with the background (the same is true for the hero); the grass
  sheet and the line-up show the in-game case.
- Portraits: faces are 3/4 right only; mouths sit near the jaw edge (a 3/4 convention), which makes the surprised
  "o" read small; Edda's hair can still read a little like a cap at 1x.
- Pixel art written by code: expect a round of feedback (proportions, colours, expressions) before anything goes
  into `art/src`.
