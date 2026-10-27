# Lanternfen layered source art (2026-10-27)

The human approved the ground and both selected prop sheets on 2026-10-27.
Approval covers their visual direction; palette, scale and extraction checks remain.

Built-in ImageGen originals, generated using the painted Lanternfen village and
the human-approved layered glade as style references. Prompt source:
`docs/LAYERED_VILLAGE_FOREST.md`, village sections 1–3. The human asked Codex to
generate these sources. Nothing here is wired into gameplay.

- `village_ground_only.png`: west/east dirt road, central crossroads and inset
  flagstones, north forge yard, moss lawns and southern path; empty floor only.
- `village_props_a.png`: rune gate, cottage, forge station, two trees, shrine,
  stone pillar and lantern post, all separated on magenta.
- `village_props_b.png`: 25 small props in reading order, as in the prompt sheet
  (including an additional mushroom variation in the last cell).

Prompts requested the approved glade's pixel grain, olive grass, warm muted browns,
weathered grey stone, small teal runes and cream/peach lights. Ground prompt
explicitly excluded standing objects. Both sheet prompts required complete
isolated silhouettes, pure #FF00FF background, wide gutters, no floor, no exterior
shadow, no characters or labels, and person-relative sizes. Sheet B correction:
change only row 2 column 2 from an open barrel to a closed planked-lid barrel;
preserve every other object and the magenta background.

These are generated source images, not exact Totoy 36 assets. Palette conversion,
hard-alpha extraction, edge/fringe validation and scale review beside the 34 px
hero remain. The world target is 571x336; doors should read around 39 px high.
Choose sheet scales from actual extracted sizes, not the requested AI scale.

For Claude: extract the two sheets separately with unique village type names and
merge the definitions as documented. The forge includes its adjacent workbench
and anvil; avoid placing another copy on top of it. The gate's door leaf is angled
into part of the passage; verify a clear hero-size route with tuned pillar/door
colliders. Preserve magenta holes between branches and inside the gate. If fringe
cleanup loses silhouettes, request a green-key revision and update the extractor
key intentionally. No claim that these sources are ready for runtime import.

Art approval, scale, lighting and the final in-game match belong to the human.
No runtime regression was needed for these inactive reference PNGs.

## Presentation integration

The approved sources are now imported and rendered in the review scene (debug 5/F7). See INTEGRATION.md for the 31 padded sizes/anchors, runtime ground paths for Claude, ten walking review captures, tests and remaining ownership. The painted village and main route remain available.
