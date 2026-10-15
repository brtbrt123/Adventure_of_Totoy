# Art request for Gemini: sprites, tiles and effects for Adventure of Totoy

How to use this: generate **one sheet per prompt**, always attach the same style reference images (your hero sheet `art/reference/hero_sheet.jpg` and portrait `hero_portrait.jpg`) so the style stays consistent, and paste the **Master style block** at the start of every prompt. Save each result as a PNG (not a screenshot) in `art/reference/` using the file name given at the end of each prompt. I (Claude Code) then extend `tools/art/import_reference.py` to cut, shrink and snap them to our palette. Plan for 2 to 3 regenerations per sheet: Gemini will drift on frame consistency.

## What the game needs to know (so the art fits)

- Top-down-style action game, **320x180 screen, 16x16 tiles**, shown with crisp pixels. Everything you generate gets shrunk about 8x, so draw **bold, simple shapes with strong dark outlines**; tiny details disappear. Faces, hair, big silhouettes and clear poses survive.
- Hero is about **30 px tall in game**, the golem about **60 to 70 px** (2x the hero), tiles 16 px.
- Reserved colors: **gold and red are only for combat warnings and effects**. The hero, the golem body and the environment must NOT use pure red or gold (the golem's glow/crystals are cream, sky-blue and teal; red and gold only appear in the effect sheets).
- Palette (we snap to it, so stay close): ink #1c1824, cream #f4ecd6; grass #26301c #3f5226 #5a7a3a #7f9348 #a0b159 #c2cb7c; dirt #2e211e #4d3a30 #62453d #765f47 #987959 #bc9c72; stone #2f3231 #444b49 #5a625e #737769 #9a9886 #c6bfaa; water #24365c #33508a #4a72ae #6f9bc8 #a7cde0 #e0f0ec; skin #8f5f4c #c28a6c #e6bf9d; teal #3f7f7a #6aa89a; lilac #8a6fa8; gold #f2c744 #b8862a; red #e0463f #92303a.

## Master style block (paste at the top of EVERY prompt)

```
Style: high-quality 2D pixel art for a dark-fantasy action game, like a polished modern indie
pixel-art game (clean hand-placed pixels, NO anti-aliasing, NO blur, NO gradients, NO soft
shadows, NO dithering noise, NO semi-transparent pixels). Bold 1-2 px dark outline around every
character and object, 3 to 5 flat shades per material, strong readable silhouettes, slightly
desaturated natural colors (olive greens, warm browns, cool grey-greens, deep navy).
Pure red and pure gold/yellow must NOT appear unless the prompt says so.
Background: perfectly flat solid magenta #FF00FF everywhere (no checkerboard, no shadows on the
ground, no gradient), so it can be removed automatically.
Layout: a clean grid sheet. Every cell is exactly the same size. One animation per row, frames
left to right, in playback order. The character is the SAME size and the SAME design in every
cell, feet on one common ground line (about 85% down the cell), horizontally centered unless the
move needs more room. Frames must not touch or overlap neighbouring cells. NO text, NO labels,
NO numbers, NO borders, NO watermarks, NO frame boxes.
```

## Sheet 1: Hero extras (side view, facing right) `hero_extra_sheet.png`

Attach the existing hero sheet as the design reference: same character, same outfit, same proportions and line style.

```
[Master style block]
Reference: the attached sprite sheet (same hero: spiky dark hair, black headband, sleeveless
dark vest, dark trousers, brown boots, dark sword). Draw NEW rows for the same hero, side view
facing right, 6 columns x 5 rows, each cell 400x400 px:
Row 1: IDLE, 6 frames, calm breathing with the sword held low (slow subtle motion).
Row 2: WALK, 8 frames, smooth full walk cycle (contact, down, passing, up, mirrored), sword in
       the right hand held low.
Row 3: HURT, 3 frames: flinch backwards, head snapped back, back to guard.
Row 4: VICTORY, 6 frames: wipes the blade, spins it, plants it in the ground, confident grin.
Row 5: DASH, 4 frames: low forward lunge, body horizontal, sword trailing behind, then a
       skidding stop (no motion lines, no effects).
No slash arcs, no sparks, no dust, no speed lines in any frame (effects come in separate sheets).
```

## Sheet 2: Hero attack combo (side view) `hero_attack_sheet.png`

```
[Master style block]
Same hero as the reference. Side view facing right, 6 columns x 4 rows, cell 520x400 px.
Row 1: ATTACK 1 (horizontal slash), 6 frames: crouch and draw back, windup, fast slash through,
       follow-through, recovery, back to guard.
Row 2: ATTACK 2 (rising slash), 6 frames.
Row 3: ATTACK 3 (big two-handed overhead finisher), 7 frames.
Row 4: PARRY, 6 frames: raise sword, guard stance, hold with small recoil, deflect, snap back,
       reset. Blade only, no sparks or flashes.
No slash arcs, no sparks, no motion blur, no effects. Only the character and the sword.
```

## Sheet 3: Golem body animations (the big one) `golem_sheet_1.png` and `golem_sheet_2.png`

The golem is the **Mossbound Colossus**: a huge ancient stone guardian covered in moss, vines and roots, cracked grey-green stone body, small glowing pale cream/sky-blue core in the chest, heavy fists, broken mossy shoulder armor, a blocky stone face with two narrow dark eye slits. Viewed from a **3/4 front view, slightly from above, facing LEFT** (we mirror it for right). It is about 2x the height of the hero. **No red, no gold, no orange anywhere on the body**: cracks and glow are cream (#f4ecd6), sky-blue (#a7cde0) and teal (#6aa89a).

```
[Master style block]
Draw the boss "Mossbound Colossus": a huge, ancient, moss-covered stone golem, bulky
proportions (small head, huge shoulders, long heavy arms with big stone fists, short thick legs),
cracked grey-green stone (#5a625e, #737769, #9a9886 with dark #2f3231 outlines), patches of
olive moss and hanging vines (#3f5226, #5a7a3a, #7f9348), small glowing pale core in the chest
(cream/sky blue), narrow dark eye slits. 3/4 front view from slightly above, facing LEFT.
Same design, same size and same colors in EVERY cell. Feet on the ground line.
Sheet 1: 8 columns x 5 rows, cell 800x800 px (the golem about 600 px tall):
Row 1: IDLE, 6 frames, slow breathing, moss swaying, core pulsing faintly.
Row 2: WALK, 8 frames, slow heavy stomping steps.
Row 3: SLAM (both fists raised overhead then slammed down), 8 frames: lean back, fists up,
       hold at the top, drop, fists on the ground, hold, recover, stand.
Row 4: SWEEP (one huge arm swung horizontally from behind to the front), 8 frames: pull the
       arm far back, wind up, swing through, follow through, recover.
Row 5: STOMP (lifts one leg and both fists, then slams the ground), 7 frames.
Sheet 2: 8 columns x 5 rows, same cell size:
Row 1: CHARGE, 8 frames: digs in and leans forward, crouches, explosive lunge pose x3 (body
       almost horizontal, shoulder forward), skid to a stop.
Row 2: BEAM (the chest core charges and fires), 8 frames: chest opens a little, core glows
       brighter, arms spread, hold the firing pose x3, close up, recover.
Row 3: STAGGERED (posture broken), 6 frames: knocked back, slumped on one knee, head down,
       core cracked and glowing bright cream (this reads as "hit me now").
Row 4: HURT, 3 frames: small flinch when hit, and ROAR (phase 2) 6 frames: rears up, chest
       pounding, fists raised, moss shaking off.
Row 5: DEATH, 10 frames: staggers, cracks spread across the stone, core goes dark, falls
       apart into rocks and moss, last frame is a low pile of rubble with a dim core.
No effects: no slash arcs, no shockwaves, no dust, no beams, no sparks. Only the golem.
```

## Sheet 4: Golem effects `golem_effects_sheet.png`

Here red and gold ARE allowed (they are combat warnings and hits).

```
[Master style block, but red and gold ARE allowed in this sheet]
Effect sprites for the boss fight, no characters. Grid 8 columns x 6 rows, cell 400x400 px, each
effect centered in its cell:
Row 1: SLAM SHOCKWAVE, 8 frames: a ring of cracked earth and dust expanding outward from the
       center (stone-grey and cream dust, dark cracks), fading at the end.
Row 2: STOMP RING, 8 frames: a flat circular shockwave ring expanding, with a bright red edge
       (#e0463f with dark red #92303a) and a cream core, fading.
Row 3: SWEEP ARC, 6 frames: a huge curved arm-swing smear (crescent), stone-grey with a cream
       highlight edge, growing then fading.
Row 4: DUST AND DEBRIS, 8 frames: puff of dust (cream and grey) and small flying rock chips and
       moss bits.
Row 5: CHARGE TRAIL, 6 frames: horizontal dust cloud trail with rock chips behind a rushing
       boss, fading.
Row 6: GROUND CRACK DECALS, 6 separate variants: dark crack patterns on the ground (crater
       from a slam, ring cracks from a stomp, long cracks from a charge), grey-black, transparent
       background.
```

## Sheet 5: Beam and impact effects `fx_beam_hit_sheet.png`

```
[Master style block, red and gold allowed]
Grid 8 columns x 6 rows, cell 400x400 px:
Row 1: LASER BEAM START (muzzle flash), 6 frames, horizontal beam origin, bright cream core,
       red glow rim, flickering.
Row 2: LASER BEAM BODY, 4 frames, a horizontal beam segment 400 px long that tiles
       seamlessly left to right (cream core, red body, dark-red outer edge), slight flicker.
Row 3: LASER BEAM END (impact on ground), 6 frames: red burst with cream core and sparks.
Row 4: HIT SPARK (normal), 6 frames: short white-cream burst with a few sky-blue sparks.
Row 5: COUNTER HIT, 8 frames: big white-cream burst with gold streaks and radial lines.
Row 6: PARRY CLASH (perfect parry), 8 frames: bright metal clash with gold and cream sparks,
       expanding ring and radial lines.
```

## Sheet 6: Hero effects `fx_hero_sheet.png`

```
[Master style block, gold allowed for sparks]
Grid 8 columns x 5 rows, cell 400x400 px, effects only (no characters):
Row 1: SWORD SLASH SMALL (horizontal crescent), 6 frames, dark navy crescent with a white-blue
       edge, growing then fading.
Row 2: SWORD SLASH BIG (large two-handed arc), 7 frames, wider and brighter.
Row 3: RISING SLASH (arc going up), 6 frames.
Row 4: DASH SPEED LINES, 6 frames: horizontal thin streaks (cream and sky blue) and a short
       dust puff at the feet.
Row 5: DAMAGE FLASH helper: a plain white circle burst, 5 frames, and a small heal sparkle, 5
       frames (teal and cream).
```

## Sheet 7: Warning icons and UI `ui_sheet.png`

```
[Master style block, red and gold allowed in the warning icons]
Grid of separate UI pieces on the magenta background, each in its own cell:
- WARNING ICON GOLD: a diamond with a small exclamation mark (gold #f2c744, dark gold outline),
  2 frames pulsing.
- WARNING ICON RED: a triangle with an exclamation mark (red #e0463f, dark red outline), 2 frames.
- PLAYER PROFILE FRAME: a round portrait frame (ornate dark navy vine-like ring with small
  leaves, 64x64 px design size) plus a long horizontal health-bar frame that wraps from it with
  the same vine ornament (about 192x24 px design size), like the reference.
- BOSS BAR FRAME: a long thin horizontal bar frame with small corner ornaments and a small "BOSS"
  tag chip.
- ICONS: Edge icon (a small blade, lilac), Dash icon (a small boot with speed lines, sky blue),
  Parry icon (crossed blades), each 32x32 design size, with a dark outline.
No text anywhere except the word BOSS on the tag.
```

## Sheet 8: Arena tiles `tiles_arena_sheet.png`

Tiles must be **seamless** (repeat without a visible seam). Ask for a big grid and expect to redo it a few times.

```
[Master style block]
Top-down view (slightly from above) seamless ground tiles for a forest-ruins boss arena, drawn
at 256x256 px per tile (they will be shrunk to 16x16, so keep the shapes big and bold). Sheet:
8 columns x 6 rows of 256x256 tiles, NO gaps between tiles, each tile must tile seamlessly with
itself on all four sides:
Row 1: GRASS, 8 variants: base olive grass with soft darker and lighter patches, small tufts, a
       few tiny pale flowers; one plain quiet variant, the others with different details.
Row 2: DIRT PATH, 8 variants: warm brown packed earth with lighter dusty patches, pebbles, thin
       cracks.
Row 3: STONE FLOOR (ancient ruined flagstones), 8 variants: irregular grey-green flagstones,
       light top edges, dark gaps, moss in the gaps, some cracked.
Row 4: WATER, 8 variants: calm blue water with gentle ripples and a few light sparkles.
Row 5: DAMAGED GROUND, 8 variants: stone floor with deep cracks and rubble (used after the
       golem slams), and 4 variants of mossy stone.
Row 6: TRANSITIONS: grass-to-dirt edges (4 directions) and grass-to-water shoreline edges (4
       directions), each tile with the transparent/magenta part where the other terrain goes.
No red or gold. No objects, no characters, no text.
```

## Sheet 9: Arena props and walls `props_sheet.png`

```
[Master style block]
Props for a mossy forest-ruins arena, top-down 3/4 view, each on its own cell, 8 columns x 4
rows, cell 400x400 px, props centered with their base at the bottom:
Row 1: round bushes (3 variants), small trees (3 variants), a big mossy boulder, a tree stump.
Row 2: ruined stone pillars (3 variants, one broken), a fallen pillar, a stone altar, a stone
       arch piece.
Row 3: flowers and tall grass clumps (pale flowers, no red/gold), mushrooms, small rocks, a
       signpost, a lantern post with an unlit lantern.
Row 4: ARENA WALLS: straight mossy stone wall segments (horizontal, vertical, 4 corners), 2
       tileable wall tops, and a cliff-edge piece.
No red, no gold (the lantern is unlit).
```

## Hand-back checklist (what I need from you)

1. The sheets as PNG files named exactly as above, put into `art/reference/` (tell me when they are there).
2. For each sheet, tell me which version you picked if you generated several.
3. Anything Gemini changed from the brief (different cell size, different frame count) so I can adjust the import.

## Tips for better results with Gemini

- Generate one **row** at a time if a full sheet comes out inconsistent, then ask Gemini to "match the previous image exactly", and I will stitch the rows together.
- If the golem or hero changes design between sheets, re-attach the best frame and say "same character exactly, same colors and proportions".
- Ask for a **bigger canvas** instead of more detail: huge and simple shapes shrink well; fine texture does not.
- If it paints a checkerboard or a gradient background anyway, ask again for "flat solid #FF00FF background"; I can also remove a checkerboard (as I did for your first sheet).
- Check that the gold and red appear only in the effect and warning sheets.
