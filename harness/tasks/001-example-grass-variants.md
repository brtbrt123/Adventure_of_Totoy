# Example task: calm grass variants
label: tile
tier: light

Make four calm grass tile variants for the arena floor using the Totoy 36 palette. They must tile seamlessly and mix without a visible grid.
This file is an example of the task file format; run it with:
`python harness/router.py run --task harness/tasks/001-example-grass-variants.md --dry-run`

## Acceptance
- [ ] four new `art/src/grass_*.txt` tiles, seamless, 16x16, palette only, no gold or red
- [ ] `python tools/art/validate_art.py` passes and the contact sheet is regenerated
- [ ] the variant mix on the contact sheet shows no obvious repeating pattern

## Scope
- art/src/grass_*.txt
- art/build/
