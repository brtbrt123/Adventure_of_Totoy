# ADVENTURE OF TOTOY: PIXEL ART PROMPT PACK (for Gemini)

## READ THIS FIRST (instructions for Gemini)

You are an expert pixel artist working for me on a 2D dark-fantasy action game. This file lists many art
requests, each with an ID (G01, H03, E07, T02 ...). I will tell you one ID at a time, for example:
**"Do prompt G03."** When I do:

1. Apply the **STYLE RULES** below to the image, always.
2. Use the matching character description (**GOLEM** or **HERO**) below, and my attached reference
   images (if any), so the character looks exactly the same in every image.
3. Generate **ONE image** that contains exactly the frames and grid the prompt asks for.
4. Do not add text, labels, numbers, borders or frame boxes. Do not change the frame count or the grid.

If something in a prompt is unclear, ask me one short question before drawing.

## STYLE RULES (apply to every image)

- High-quality 2D pixel art for a dark-fantasy action game, like a polished modern indie pixel-art game.
- Clean hand-placed pixels. **NO anti-aliasing, NO blur, NO gradients, NO soft shadows, NO dithering noise, NO painterly shading, NO semi-transparent pixels.**
- Bold 1 to 2 px dark outline around every character and object. 3 to 5 flat shades per material. Strong, readable silhouettes. Big simple shapes: the art will be shrunk about 8 times, so tiny details disappear.
- Slightly desaturated natural colors: olive greens, warm browns, cool grey-greens, deep navy.
- **Pure red and pure gold/yellow are forbidden** unless the prompt says "red and gold allowed" (only effects and warning icons may use them).
- Palette to stay close to: ink #1c1824, cream #f4ecd6; grass #26301c #3f5226 #5a7a3a #7f9348 #a0b159 #c2cb7c; dirt #2e211e #4d3a30 #62453d #765f47 #987959 #bc9c72; stone #2f3231 #444b49 #5a625e #737769 #9a9886 #c6bfaa; water #24365c #33508a #4a72ae #6f9bc8 #a7cde0 #e0f0ec; skin #8f5f4c #c28a6c #e6bf9d; teal #3f7f7a #6aa89a; lilac #8a6fa8; gold #f2c744 #b8862a; red #e0463f #92303a.
- **Background: one perfectly flat solid magenta #FF00FF everywhere** (no checkerboard, no gradient, no ground shadow), so it can be removed automatically. EXCEPT the tile prompts (T01 to T05): tiles fill the whole image.
- **Layout:** a clean grid of equal-size cells, frames in playback order (left to right, then top to bottom). The character is the SAME size and design in every cell, feet on one common ground line (about 85% down the cell), no overlap between cells. Wide 16:9 image, as large as you can output.
- Never put text in the image. No signature, no watermark.

## HERO description (use for every H prompt)

Side view facing RIGHT. A young swordsman in the spirit of a shonen-anime hero: short spiky dark brown hair, a black headband, a determined face, a sleeveless dark vest over bare muscular arms, dark baggy trousers, brown boots, a dark blue-black sword. Match the attached reference sprite sheet exactly (same character, outfit, proportions and line style). No red and no gold on him. Standing figure about 260 px tall in the image.

## GOLEM description (use for every G prompt; attach golem_design.png after G00)

The boss "Mossbound Colossus": a huge, ancient, moss-covered stone golem, about twice the hero's height. Bulky proportions: small head, huge shoulders, long heavy arms with big stone fists, short thick legs. Cracked grey-green stone (#5a625e, #737769, #9a9886 with dark #2f3231 outlines), patches of olive moss and hanging vines (#3f5226, #5a7a3a, #7f9348), narrow dark eye slits, a small glowing pale core in the chest (cream #f4ecd6 / sky blue #a7cde0). **No red, no gold, no orange on the body.** 3/4 front view from slightly above, facing LEFT. Standing figure about 520 px tall in the image.

---

# PART A: THE GOLEM (Mossbound Colossus)

## G00: Golem design lock (do this first, save the best result as golem_design.png)

Draw the Mossbound Colossus (see GOLEM description) three times on one image, same size, side by side: (1) 3/4 front view facing left, standing idle, (2) side view facing left, (3) back view. Feet on one ground line.

## G01: IDLE, 4 frames, 2x2 grid, file golem_idle.png

The Mossbound Colossus, 3/4 front view facing left. Four poses: slow breathing in and out, moss and vines swaying slightly, the chest core pulsing faintly brighter then dimmer. A very small motion between frames. No effects.

## G02: WALK, 6 frames, 3x2 grid, file golem_walk.png

The Mossbound Colossus walking slowly toward the left: a heavy stomping step cycle. Frame 1: right foot forward contact. Frames 2 to 3: body drops and shifts weight. Frame 4: left foot forward contact. Frames 5 to 6: weight shifts back. Arms swing slightly, shoulders rock. No dust, no effects.

## G03: SLAM, 6 frames, 3x2 grid, file golem_slam.png

The golem slams both fists on the ground. Frame 1: leans back, both fists rise. Frame 2: fists raised high overhead, body arched back. Frame 3: hold at the top, trembling. Frame 4: drops forward fast, fists coming down. Frame 5: fists on the ground, body bent forward. Frame 6: slowly recovering to stand. No dust, no shockwave, no effects.

## G04: SWEEP, 6 frames, 3x2 grid, file golem_sweep.png

The golem swings one huge arm horizontally. Frame 1: stands. Frame 2: pulls the arm far back behind its body, torso twisted. Frame 3: winds up, hold. Frame 4: arm swung fast through the middle, torso rotating forward. Frame 5: follow-through, arm extended at the far side. Frame 6: recovering to a stand. No swing arc, no motion blur, no effects.

## G05: STOMP, 6 frames, 3x2 grid, file golem_stomp.png

The golem stomps the ground. Frame 1: stands. Frame 2: lifts one leg high and raises both fists. Frame 3: hold at the top. Frame 4: slams the foot and fists down. Frame 5: planted, bent forward, cracks implied only by pose. Frame 6: recovering to a stand. No dust, no shockwave, no effects.

## G06: CHARGE, 6 frames, 3x2 grid, file golem_charge.png

The golem charges to the left. Frame 1: digs in, feet planted, leaning forward. Frame 2: crouches low, shoulder forward. Frames 3 and 4: explosive lunge pose, body almost horizontal, shoulder forward, one foot pushing off. Frame 5: skidding, leaning back. Frame 6: slowing to a stand. No dust, no trail, no effects.

## G07: BEAM, 6 frames, 3x2 grid, file golem_beam.png

The golem fires a beam from the chest core. Frame 1: stands, chest plates begin to open a little. Frame 2: core glows brighter, arms start spreading. Frames 3 and 4: firing pose, arms spread wide, chest fully open, core blazing cream and sky blue (hold the same pose with a tiny change). Frame 5: chest plates closing. Frame 6: recovering to a stand. Draw ONLY the golem, no beam, no light rays, no effects.

## G08: STAGGERED (posture broken), 4 frames, 2x2 grid, file golem_staggered.png

The golem is stunned and exposed. Frame 1: knocked backward off balance. Frame 2: drops to one knee. Frames 3 and 4: slumped on one knee, head down, arms hanging, the chest core cracked and glowing bright cream (this must clearly read as "hit me now"), tiny motion between the two frames. No effects.

## G09: HURT, 4 frames, 2x2 grid, file golem_hurt.png

The golem takes a hit. Frame 1: normal stance. Frame 2: flinches back, head snapped back. Frame 3: strongest recoil. Frame 4: returns to the normal stance. No effects.

## G10: ROAR (phase 2 start), 6 frames, 3x2 grid, file golem_roar.png

The golem enters its angry second phase. Frame 1: crouches. Frame 2: rears up, chest out. Frames 3 and 4: both fists raised, head tilted back, roaring, moss shaking loose. Frame 5: pounds its chest. Frame 6: returns to a battle stance, cracks glowing slightly more. No effects.

## G11: DEATH, 8 frames, 4x2 grid, file golem_death.png

Frame 1: staggers. Frame 2: drops to its knees, cracks spreading across the stone. Frame 3: the chest core flickers and goes dark. Frame 4: an arm breaks off and falls. Frame 5: the torso starts collapsing. Frame 6: head falls. Frame 7: body crumbles into a heap of stones and moss. Frame 8: a low pile of rubble and moss with a dim core in the middle. No dust, no effects.

---

# PART B: THE HERO

(Use the HERO description and my attached hero sprite sheet as the reference for all of these. Side view facing right.)

## H01: IDLE, 4 frames, 2x2 grid, file hero_idle.png

The hero standing calmly with the sword held low in his right hand. Four poses of slow breathing: chest rises and falls, a little sway of the vest, a little hair movement. Tiny motion between frames. No effects.

## H02: WALK, 6 frames, 3x2 grid, file hero_walk.png

The hero walking to the right: a smooth six-frame walk cycle (contact, down, passing, contact on the other leg, down, passing), sword held low. No dust, no effects.

## H03: HURT, 4 frames, 2x2 grid, file hero_hurt.png

The hero takes a hit: normal guard, flinches backward with the head snapped back, strongest recoil, back to a guard. No effects.

## H04: VICTORY, 6 frames, 3x2 grid, file hero_victory.png

The hero wins: wipes the blade, spins the sword in his hand, raises it, plants it point-down in the ground, rests both hands on the hilt, confident grin. No effects.

## H05: DASH, 4 frames, 2x2 grid, file hero_dash.png

The hero dashes to the right: crouches low, a low forward lunge with the body almost horizontal and the sword trailing behind, in mid-air or sliding, then a skidding stop. No speed lines, no dust, no effects.

## H06: ATTACK 1 (horizontal slash), 6 frames, 3x2 grid, file hero_attack1.png

Crouch and draw the sword back, wind-up, a fast horizontal slash through, follow-through with the arm extended, recovery, back to a guard. No slash arc, no effects, only the hero and his sword.

## H07: ATTACK 2 (rising slash), 6 frames, 3x2 grid, file hero_attack2.png

A rising diagonal slash: low wind-up with the sword down by the leg, a step forward, the slash sweeping up, the sword high at the end, recovery, back to a guard. No effects.

## H08: ATTACK 3 (big overhead finisher), 6 frames, 3x2 grid, file hero_attack3.png

A two-handed overhead finisher: raises the sword high with both hands, leaps or steps forward, brings it down hard, the sword low and forward at the impact, holds, recovery. No effects.

## H09: PARRY, 6 frames, 3x2 grid, file hero_parry.png

Raises the sword to guard, braced guard stance with the sword held diagonally across the body, hold with a small recoil as if deflecting a strong blow, the blade snaps aside, returns to a guard, resets. Blade only, no sparks, no flashes.

---

# PART C: EFFECTS (red and gold ARE allowed in this part; no characters, effects only)

Each effect: the frames in playback order, effect centered in each cell, magenta background.

## E01: SLAM SHOCKWAVE, 6 frames, 3x2 grid, file fx_slam.png
A ring of cracked earth and dust expanding outward from the center, stone grey and cream dust with dark cracks, growing and then fading.

## E02: STOMP RING, 6 frames, 3x2 grid, file fx_stomp.png
A flat circular shockwave ring seen from above, expanding, with a bright red edge (#e0463f, dark red #92303a) and a cream core, then fading.

## E03: SWEEP ARC, 6 frames, 3x2 grid, file fx_sweep.png
A huge curved arm-swing smear (a crescent), stone grey with a cream highlight edge, growing and then fading.

## E04: DUST AND DEBRIS, 6 frames, 3x2 grid, file fx_dust.png
A puff of dust (cream and grey) with small flying rock chips and moss bits, expanding and falling.

## E05: CHARGE TRAIL, 6 frames, 3x2 grid, file fx_charge.png
A horizontal dust cloud trail with rock chips, as left behind by a rushing boss, fading.

## E06: GROUND CRACKS, 6 separate variants in a 3x2 grid, file fx_cracks.png
Six different dark crack patterns on the ground (a slam crater, ring cracks, long cracks), grey-black on magenta.

## E07: LASER START (muzzle flash), 4 frames, 2x2 grid, file fx_beam_start.png
The origin flash of a horizontal laser beam: a bright cream core, a red glow rim, flickering.

## E08: LASER BODY, 4 frames, 2x2 grid, file fx_beam_body.png
A horizontal laser beam segment that tiles seamlessly left to right: cream core, red body, dark-red edge, slight flicker.

## E09: LASER END (impact), 4 frames, 2x2 grid, file fx_beam_end.png
A red burst on the ground where the laser hits, a cream core and a few sparks.

## E10: HIT SPARK, 6 frames, 3x2 grid, file fx_hit.png
A short white-cream burst with a few sky-blue sparks.

## E11: COUNTER HIT, 6 frames, 3x2 grid, file fx_counter.png
A big white-cream burst with gold streaks and radial lines.

## E12: PARRY CLASH, 6 frames, 3x2 grid, file fx_parry.png
A bright metal clash: gold and cream sparks, an expanding ring and radial lines.

## E13: SWORD SLASH SMALL, 6 frames, 3x2 grid, file fx_slash_small.png
A horizontal crescent slash: dark navy crescent with a white-blue edge, growing then fading.

## E14: SWORD SLASH BIG, 6 frames, 3x2 grid, file fx_slash_big.png
A larger, brighter two-handed arc slash (dark navy body, white-blue edge), growing then fading.

## E15: DASH LINES, 6 frames, 3x2 grid, file fx_dash.png
Thin horizontal speed streaks (cream and sky blue) and a small dust puff at the feet.

## E16: HEAL AND FLASH, 4 frames each in a 2x2 + 2x2 layout (8 frames, 4x2 grid), file fx_misc.png
Frames 1 to 4: a white circular burst growing and fading. Frames 5 to 8: a small heal sparkle in teal and cream rising and fading.

---

# PART D: UI (red and gold allowed in the warning icons only)

## U01: WARNING ICON GOLD, 2 frames, file ui_warning_gold.png
A diamond with a small exclamation mark inside, gold #f2c744 with a dark gold outline, 2 frames pulsing (slightly bigger then smaller). 2x1 grid.

## U02: WARNING ICON RED, 2 frames, file ui_warning_red.png
A triangle with an exclamation mark, red #e0463f with a dark red outline, 2 frames pulsing. 2x1 grid.

## U03: PLAYER PROFILE FRAME, file ui_profile.png
A round portrait frame: an ornate dark navy vine-like ring with small leaves, about 64x64 px design size, empty in the middle (flat magenta). Next to it, a long horizontal health bar frame (about 192x24 px design size), empty inside, with the same vine ornament wrapping from the portrait ring toward the right. Two thin bars under it (for Edge and Dash), empty frames. Like the reference image I will attach.

## U04: BOSS BAR FRAME, file ui_boss.png
A long thin horizontal bar frame with small corner ornaments, empty inside, and a small separate "BOSS" tag chip (rounded, dark, with the word BOSS in cream). The word BOSS is the only text allowed.

## U05: ICONS, file ui_icons.png
Three icons, each 32x32 design size with a dark outline, in a 3x1 grid: an Edge icon (a small blade, lilac), a Dash icon (a small boot with speed lines, sky blue), a Parry icon (two crossed blades, cream and steel).

---

# PART E: TILES (NO magenta here: tiles fill the entire image; no red, no gold)

All tile images: **square 1:1 image, a 4x4 grid of 16 tiles, NO gaps between tiles**, top-down view slightly from above, each tile must repeat **seamlessly with itself on all four sides**. Draw big bold shapes (tiles will be shrunk to 16x16). One tile per grid cell: make 16 variants, one of them plain and quiet, the others with different details so a mix of them looks natural.

## T01: GRASS, file tiles_grass.png
Olive grass with soft darker and lighter patches, small tufts and blades, a few tiny pale flowers.

## T02: DIRT PATH, file tiles_dirt.png
Warm brown packed earth, lighter dusty patches, pebbles, thin cracks.

## T03: STONE FLOOR, file tiles_stone.png
Ancient ruined flagstones: irregular grey-green flagstones, light top edges, dark gaps, moss in the gaps, some cracked.

## T04: WATER, file tiles_water.png
Calm blue water with gentle ripples and a few light sparkles.

## T05: DAMAGED GROUND, file tiles_damaged.png
Stone floor with deep cracks and rubble (after the golem slams), 8 variants, and 8 more variants of mossy stone.

## T06: TRANSITIONS, file tiles_transitions.png
Edge tiles (this one MAY use magenta where the other terrain goes): 8 grass-to-dirt edge tiles (4 straight sides and 4 corners) and 8 grass-to-water shoreline tiles (4 straight sides and 4 corners).

---

# PART F: PROPS AND WALLS (magenta background, no red, no gold)

Each prop on its own cell, centered with its base at the bottom. Top-down 3/4 view, mossy forest-ruins style.

## P01: NATURE, 4x2 grid, file props_nature.png
Round bushes (3 variants), small trees (3 variants), a big mossy boulder, a tree stump.

## P02: RUINS, 3x2 grid, file props_ruins.png
Ruined stone pillars (3 variants, one broken), a fallen pillar, a stone altar, a stone arch piece.

## P03: SMALL PROPS, 4x2 grid, file props_small.png
Flower clumps (pale flowers), tall grass clumps, mushrooms, small rocks, a signpost, a lantern post with an unlit lantern.

## P04: ARENA WALLS, 4x3 grid, file props_walls.png
Straight mossy stone wall segments (horizontal and vertical), four corner pieces, two tileable wall tops, a cliff-edge piece.

---

## What I do with the results

I save each image with the file name given in its prompt and put them into the project's `art/reference/` folder. If you changed the frame count or grid of any prompt, tell me which one and how, so I can adapt the import.
