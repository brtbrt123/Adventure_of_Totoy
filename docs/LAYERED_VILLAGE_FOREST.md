# Layered village and forest: plan and prompts (2026-10-27)

The Stag glade proved the layered method (floor painting + separate prop sprites: depth order and collision come from each prop, see `docs/LAYERED_SCENE_PILOT.md`, `docs/architecture.md` "Layered scenes"). The human decided to redo the **village (Lanternfen)** and the **forest route** the same way, because their flat paintings cannot be fixed completely: the occluder cut-outs hold floor pixels and some colliders do not match the art.

Order: **village first** (worst case), then the forest. Each scene is one chat with the image generator so the style stays consistent; give it the painted target as a style reference (`art/reference/lanternfen_village_target.png`, `art/reference/forest_route_target.png`) AND the glade's approved result (`art/reference/layered_pilot/glade_full.png` in `review/`) so the new scenes match the glade.

## Who does what

| Who | Work |
|---|---|
| **Human** | Generates the images below, saves the ORIGINALS (not screenshots) into `art/reference/layered_village/` and `art/reference/layered_forest/`, approves the look. |
| **Codex** | Palette conversion of the ground, cleaning the prop sprites into `art/src`, drawing the scene with `props_layer.gd`, the debug jump key, review captures (exactly as for the glade). |
| **Claude** | Runs `tools/art/extract_props.py` (use `--merge --prefix village`), writes `data/props/prop_defs.json` entries (hand-tuned, locked) and `data/scenes/<scene>_props.json` (placements, outline, entries, exits, checkpoints, NPC stand points), tests, and the extra scene-format fields these two scenes need: NPCs and interactables (the village), the forest's root gate with an open and a closed state. |

Sizes: village world **571x336** (the hero is 34 px tall, a door about 39 px), forest **480x288**. The human judges the prop scale on the contact sheet (the glade's first extraction was too big and was redone at `--world-width 400` for a 1619 px sheet; expect to pick the width per sheet).

## Village

### 1. Ground only

```text
Pixel art game environment, same 16-bit style, palette and lighting as the reference image (use its layout of paths and clearings) and as the previous forest glade. 3/4 top-down view, crisp hard pixels, no anti-aliasing, no blur. Aspect ratio 1.7:1. A small fantasy village square at dusk, VIEWED AS EMPTY GROUND ONLY: a dirt road entering from the west edge and running east to the east edge, a crossroads in the middle with a worn flagstone patch, a dirt yard in the north-middle, a mossy lawn in the north-east and the south-west, a narrow dirt path leaving to the south, grass tufts, small flowers, fallen leaves, flat flagstones set into the road. The outer edges fade into dark forest floor and dense dark undergrowth (flat painted ground, no tree trunks, no canopies). ABSOLUTELY NO objects standing on the ground: no buildings, no walls, no gate, no trees, no stumps, no barrels, no crates, no stones that stand up, no statues, no signs, no lamps, no characters, no creatures, no UI, no text, no frame. No red or gold colours anywhere (reserved for combat). Flat ground texture and soft painted light only; warm lantern glow can lie on the road as flat light.
```

### 2. Prop sheet A: large props (on magenta)

```text
Pixel art game prop sheet, same 16-bit pixel art style, palette, camera angle and lighting as the previous village ground image. Every object is drawn on its own, fully separated, on a perfectly FLAT solid magenta background (#FF00FF), at least 40 pixels of empty magenta between objects. NO ground, NO grass, NO cast shadows on the background, no text, no labels, no characters. Each object is complete with a clean dark outline, ready to be cut out. Same scale for all: an adult person would be 50 pixels tall (do not draw the person). The objects: (1) a rune gate: two carved stone pillars with glowing teal runes and a lintel across the top, with a wooden door leaf standing open to one side, about 3 times a person tall, with an open walkway between the pillars; (2) a timber-framed cottage seen from the front-left with a thatched mossy roof, glowing windows and a wooden door; (3) a stone forge with a chimney and a glowing orange fire opening; (4) a very old tree with a thick twisted trunk and roots, with a small hanging lantern on a branch; (5) a second big old tree trunk with roots; (6) a small stone shrine with a hooded figure statue; (7) a tall free-standing stone pillar; (8) a wooden lamp post with a hanging lantern. No red anywhere.
```

### 3. Prop sheet B: small props (on magenta)

```text
Same style, camera, palette and lighting. A second prop sheet on a perfectly flat magenta (#FF00FF) background, objects separated by at least 40 px, no ground, no shadows, no text, same scale as sheet A (adult person 50 px tall, not drawn). The objects: an iron anvil on a tree-stump base; a wooden tool bench with tools; a straw training dummy on a post; a wooden shelf with jars; four different wooden barrels (two single, one with a lid, one tipped over); two wooden crates; a stack of crates and barrels; a pile of mossy rocks; a tree stump; two flat lying stone slabs (one tilted); a small rubble pile of grey stones (NOT red); a wooden treasure chest with iron bands, closed; two bushes; two fern clumps; a few small mushrooms; a wooden bucket; a coil of rope. No red anywhere.
```

NPC people are NOT props (they are the approved NPC sprites). Doors and the training dummy stay interactable through the scene data.

## Forest route

### 1. Ground only

```text
Pixel art game environment, same 16-bit style, palette and lighting as the reference image (keep its layout) and as the previous forest glade and village. 3/4 top-down view, crisp hard pixels, no anti-aliasing. Aspect ratio 1.67:1. A mossy forest route, EMPTY GROUND ONLY: a dirt trail entering at the left edge, widening into a first clearing, narrowing between roots into a second clearing with flowers, then a narrow trail climbing to the top edge, and a short dead-end trail to the east; moss, grass tufts, fallen leaves, roots lying flat in the ground, dark undergrowth and root shadows toward the edges (flat painted ground, no trunks, no canopies). ABSOLUTELY NO standing objects: no trees, no logs, no signs, no pedestals, no gates, no stones that stand up, no chests, no lanterns, no characters, no UI, no text, no frame. No red or gold colours.
```

### 2. Prop sheet on magenta

```text
Same style, camera, palette and lighting as the previous forest images. A prop sheet on a perfectly flat magenta (#FF00FF) background, objects separated by at least 40 px, no ground, no shadows, no text, adult person 50 px tall (not drawn). The objects: a wooden signpost with two arrow boards; TWO identical stone lantern pedestals, unlit (a carved stone pillar with an empty lantern bowl on top); the same pedestal lit (glowing teal flame), once; a wooden lantern post; a big root gate CLOSED (thick living roots woven across a doorway between two trunks, about 2.5 times a person tall); the SAME root gate OPEN (roots parted, a clear walkway between); a mossy standing stone; a second mossy rock with a root growing over it; three big trees with thick roots (different shapes); two fallen mossy logs; a stump; a wooden treasure chest, closed; two thorn bushes with lilac thorns; two bushes; three fern clumps; glowing blue-teal flowers; small rocks and mushrooms. No red anywhere.
```

## Checklist for the extractor (Claude, per sheet)

```powershell
python tools/art/extract_props.py --sheet art/reference/layered_village/village_props_a.png --names <ids in reading order> --world-width <chosen> --merge --out art/reference/layered_village/props
```

Then: look at `props_contact.png` (base line cyan, colliders orange), tune the colliders by hand, set `"locked": true`, write the placements from the painted layout (`core/village_layout.gd` and the occluder table give where each thing stood: reuse those positions so the scene keeps its layout), build the outline, run the preview (`tools/art/preview_layered_glade.py` is the model; it will take a scene argument), write the tests. Acceptance as for the glade, plus: every interactable (door, chest, dummy, signpost, pedestals, gate) is still usable from in front; the forest's gate blocks when closed and opens for the hero when open.
