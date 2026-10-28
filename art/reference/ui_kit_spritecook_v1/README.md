# SpriteCook UI kit v1 (review only)

A fantasy HUD and menu kit made with the SpriteCook plugin's UI-kit workflow on 2026-10-28, converted to Totoy 36 pixel art and shown in five mockups over real captures. **Review only:** nothing in `art/src`, `art/build` or `presentation/` changed, and the owner approves the art.

Look at these first:

- `kit_sheet.png`: every part at 4x, plus the slots, socket and bars assembled at game size.
- `mockups/1_hud.png`, `2_dialogue.png`, `3_status.png`, `4_aspects.png`, `5_cards.png`: 1280x720 (320x180 x4, nearest-neighbour). `mockups/contact.png` puts all of them on one page.

## What is in the folder

| Path | What |
|---|---|
| `kit/*.png`, `kit/kit.json` | Each part at 1x in game pixels; `kit.json` holds sizes, 9-slice borders and source rectangles |
| `raw/concept_1.png`, `raw/sheet_1.png` | The SpriteCook downloads, untouched (2048x1152 concept, 2048x2048 transparent component sheet) |
| `raw/sheet_1_extraction.json` | SpriteCook's extraction rectangles and the names we gave the parts |
| `refs/style_collage.png` | The one style reference uploaded to SpriteCook |
| `concept_1_320x180*.png` | The concept converted to 320x180; it shows why frames needed a finer scale (see below) |
| `spritecook-assets.json` | SpriteCook asset IDs, SHA-256 prefixes and the credits each step cost |
| `style_reference.py`, `to_palette.py`, `build_kit.py`, `mockups.py` | The scripts that made everything here |

## How it was made

1. **Style reference.** `style_reference.py` puts the four captures the owner named into one 2560x1440 collage, each at its native pixel size: `woodland_view_170_260.png`, `current_village_layered.png`, `art/build/arena_hud2.png` and the portraits from `contact_portraits_dark.png`. The arena capture is cropped to the arena floor so the rejected flat teal HUD does not steer the style. The portrait labels are cropped off too. One collage instead of four uploads keeps the reference charge down.
2. **Concept.** `create_ui_kit` (HUD screen, 16:9, `gpt-image-2`, collage as style asset) took a brief of carved riveted bronze, set teal gems and teal rune accents, with no gold, no red and no text. One concept was generated (`count=1`), then selected.
3. **Component sheet.** `generate_ui_kit_component_sheets` was run with one sheet and focus notes listing every part with a game-pixel size and "frames 3-4 game pixels thick". The model behind it is `gpt-image-2.5-sunburst`.
4. **Extraction and finalize.** `extract_ui_kit_components` ran with an alpha threshold of 128, the same cut as our hard-alpha rule, so the soft glows around the fill strips do not merge them. It found 31 parts, with no merges and no duplicates. Its only flag was that the 9-slice borders were zero. `finalize_ui_kit` received a corrected list: our names, state groups (item_slot normal/locked/cooldown/empty, aspect_socket active/locked, button normal/pressed/disabled, tab selected/unselected) and 9-slice borders in sheet pixels. The kit is `complete` on SpriteCook with 31 component assets (IDs in `spritecook-assets.json`).
5. **Conversion to Totoy 36** (`to_palette.py`, used by `build_kit.py`):
   - **One cell per pixel.** Each source crop is cut into a grid of cells, one per game pixel. A cell is opaque when at least half of its inner pixels have alpha >= 128, otherwise fully transparent. "Inner" drops the outer 20% of the cell, where generated art smears across borders.
   - **Nearest colour.** The cell's colour is the most common palette colour among its opaque inner pixels, each pixel mapped to the nearest Totoy 36 colour in CIELAB. Gold `x`/`y` and red `z`/`A` are never chosen.
   - **Hue guards.** Strongly coloured pixels may only map within their own family. Gold glints become the bronze ramp, dark teal stays teal instead of stone grey, violet becomes lilac or ink instead of blue, and any red becomes rust brown.
   - **Self-check.** `check()` fails on any partial alpha or any off-palette or reserved colour.
6. **Sizes** (`build_kit.py`). The generated parts are not on one pixel grid: their scale varies from about 6 to 13 source pixels per game pixel. Converting them at their intended sizes made the bronze frames 1-2 px thin, close to the look the owner rejected. So:
   - **Frames** (panels, slot frame, troughs, ribbon, pillar, tabs, buttons, key badge) are converted at 6-9 source pixels per game pixel. That keeps about 3 px of bronze. They are then **9-sliced** to the size a screen needs: corners kept, edges and centre tiled, never stretched.
   - **Fixed objects** (medallion 40x44, Aspect sockets 28x31, level shield 18x21, icons 12-20 px) are converted at the size they are used at.
7. **Four mechanical clean-ups**, nothing redrawn by hand:
   - The icons were drawn inside framed tiles. They are cut from the tile interiors and their ink backing is cleared.
   - The level pillar came pre-filled with violet. Its tube is emptied to ink, because the game draws the fill.
   - The active socket's sample rune is cleared, so the Sprint icon (or any Aspect) can sit in it.
   - The locked button's padlock is cleared, so the button 9-slices at any width and carries a dimmed label next to `icon_padlock`.
8. **Assembly.** The four item-slot states are assembled at 24x24 from the slot frame plus the floor, padlock or cooldown sweep. `aspect_socket_sprint` is the open socket with the Sprint icon.
9. **Mockups** (`mockups.py`). These reuse the layout, `Canvas`, sprites, portraits and pixel font of `tools/art/ui_concept_claude.py` (Claude's v3 concept):
   - **UI layer.** Every UI pixel is a kit part placed at 320x180 and scaled x4 with nearest-neighbour.
   - **Text.** Words are Cinzel rendered at window resolution, like the game (decision 0004). Numbers and key letters use the crisp pixel font, because Pixelify Sans makes 5, Z and C look like S, 2 and O.
   - **Portraits** are the 88x88 portraits smooth-filtered to 44 px (50 px on the Status screen).
   - **Backgrounds.** The woodland captures are used as-is (already 4x). The village and glade captures are not 16:9, so they are cropped to 16:9 and smoothly scaled.
   - **Game effects, not UI art.** The dimming veils, sprite shadows and the red charge lane on the HUD.

## Credits and cost

The SpriteCook account is on the free plan (40 credits every 30 days).

| Step | Credits |
|---|---|
| Collage upload, kit creation, concept selection | 0 |
| Concept, 1 image, `gpt-image-2` 2K medium | 7 |
| Component sheet, 1 sheet, `gpt-image-2.5-sunburst` 2K medium (14 + 8 for the concept as reference) | 22 |
| Extraction and finalize | 0 |
| **Total** | **29** (11 left) |

## Licence and visibility

From SpriteCook's pricing page (https://www.spritecook.ai/pricing, read 2026-10-28):

- Commercial use is included on every plan, including Free, and no credit to SpriteCook is required.
- SpriteCook's Terms of Service and the terms of the AI model providers also apply. The models here are OpenAI's GPT Image models. The full Terms of Service were not reviewed; read them before shipping.
- **Visibility:** free-plan generations appear in SpriteCook's public gallery, and private assets need a paid plan. Checked with `get_asset_metadata`:
  - The concept and the component sheet are `is_public: true`.
  - The concept shows a scene that closely resembles the game's village.
  - The uploaded collage is private (`is_public: false`).

## Rebuild

From the project root. `-P` keeps the script and working folders off the import path, so nothing next to a download can be imported. `-I` would also hide the per-user site-packages that hold numpy on this machine.

```powershell
python -P art/reference/ui_kit_spritecook_v1/style_reference.py   # refs/style_collage.png
python -P art/reference/ui_kit_spritecook_v1/build_kit.py         # kit/, kit_sheet.png
python -P art/reference/ui_kit_spritecook_v1/mockups.py           # mockups/
```

Everything rebuilds from `raw/` without SpriteCook. Only a new concept or sheet costs credits.

## For the owner to judge (I cannot)

- **Bronze.** Totoy 36 has no true bronze, so the bronze reads as warm copper-brown (dirt and skin ramps). Does it feel like carved bronze?
- **Frames at 1x.** Panels and slots carry about 3 px of bronze with set gems. The Aspect sockets and the medallion ring are thinner (about 2 px). Chunky enough, or still too fine?
- **Large panel corners.** The ornaments are big (30x20 px), which crowds content near the corners. Keep them, or ask for a quieter large frame?
- **Icons at game size.** The herb is busy at 14 px, and Sprint reads as a teal arrow.
- **Single violet.** The palette has one violet, so the EXP fill is flat.
- **Colours.** The health fill is leaf green with a grey ghost (red stays reserved). Edge is teal.
- **Busy HUD?** Whether the HUD feels too busy at 320x180: about 30% of the bottom edge plus the left pillar.
- **Overall fit.** Whether this look fits the woodland, village and arena art better than the Astra flat-teal UI and Claude's v3 drawn concept.

## Not done, and known limits

- **Not in the game.** No engine run, no `art/src` grids, no validator run on these files, because the project validator covers `art/src` and `art/build`. If the owner approves, the presentation agent would rebuild the parts as text grids (`to_palette.py --txt` writes them) and integrate them.
- **Minimum sizes.** 9-slice frames can't be smaller than their corners: the large panel's minimum is 60x40, other panels 20x20.
- **Kit gaps.** The kit has no plus or arrow glyphs and no divider. The mockups use the pixel font's `+` and one small teal triangle for "next" in the dialogue.
- **Fixes cost credits.** Another concept costs 7 credits; another sheet or a sheet edit about 22. Anything beyond the 11 credits left needs a paid plan (Starter is $8/month for 800 credits).
