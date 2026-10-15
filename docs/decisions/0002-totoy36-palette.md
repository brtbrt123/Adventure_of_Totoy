# 0002: Totoy 36 palette replaces DB16

Date: 2026-10-15 · Status: approved by the human · Supersedes the palette line of 0001

**Why:** the first DB16 placeholder tiles and a Codex redraw were judged "too flat and plain, repetitive, wrong style". The human supplied style references (a cozy top-down pixel look: desaturated olive grass, warm tan dirt, cool grey stone, soft close-toned blotches, props drawn as separate objects). Sampling the references showed ground colors such as olive `#a0b159`/`#818e4a`, tan `#765f47`/`#987959` and grey-green `#525b58`/`#6f7369`. DB16 has no such mid-tones, so no redraw could match the look.

**What:** a 36-color original palette in `art/palette.json`: ink and cream, 6-step ramps for grass, dirt, stone and water, 3 skin tones, 3 cloth accents, and 4 combat colors. Hues were informed by the references' ground colors; the palette is not copied from any game (the design doc asks for original art).

**Combat colors are reserved.** Gold (`x`, `y`) and red (`z`, `A`) belong to the parry and dodge language ("gold heavy attacks can be parried; red attacks must be dodged"). Keeping them out of the environment keeps the tells readable. Enforced: `reserved` in `palette.json`, and the validator rejects them in tiles. Sprites (enemies, effects, UI) may use them. Trade-off: red fruit and orange flowers like in the references must be muted in this game.

**Consequences:** symbols are now `0-9a-zA` instead of `0-9a-f`. The old placeholder sources were remapped one-to-one; Totoy's scarf became teal because red is reserved. The unmerged branch `agent/tile/terrain-redo` uses DB16 symbols and is obsolete. Palette changes need the human's approval.
