# Layered scene pilot: ground painting + separate props (draft, 2026-10-22)

## Why

The village, forest and glade are single flat paintings converted to the Totoy palette. Collision is hand-placed circles and
"walk behind" is hand-cut occluder pieces (`presentation/common/depth_occluders.json`). It works, but every prop costs manual
work and the cut-outs sometimes include floor pixels. The human's idea: paint the FLOOR separately from the PROPS (layers),
so each prop is its own sprite with a base line. Depth sorting and collision then come from the prop automatically.

## Pilot scene: the Stag glade

Compare the pilot with the painted glade (`presentation/forest/stag_glade_ground.png`, `core/glade_layout.gd`). If it feels
better, use it for new scenes and decide later whether to redo the village and forest.

## Art the human generates (three AI images, same chat so the style stays consistent)

Download the ORIGINAL images (not screenshots) into `art/reference/layered_pilot/` as `glade_ground_only.png`,
`glade_props_sheet.png` and, optionally, `glade_scale_guide.png`.

### 1. Ground only

```text
Pixel art game environment, 16-bit style with a limited palette, 3/4 top-down view (slightly angled, like a classic action RPG), crisp hard pixels, no anti-aliasing, no blur, no gradients. Aspect ratio 1.69:1 (about 837x496). A sacred forest glade, VIEWED AS EMPTY GROUND ONLY: short green grass with patches of darker moss, a few bare earth patches, small flowers and grass tufts, fallen leaves, a faint ring-shaped worn path of paler grass in the middle (a circle about 55% of the image width, where nothing grows), one dirt trail entering from the bottom-left edge toward the middle, and a second narrower trail leaving at the top-right edge. The outer edges fade into dark forest floor with dense dark green undergrowth and root shadows (flat painted ground, no trunks, no canopies). ABSOLUTELY NO props or objects standing on the ground: no trees, no stones, no bushes, no logs, no stumps, no statues, no ruins, no characters, no creatures, no UI, no text, no watermark, no frame. Only flat ground texture, lighting and soft painted shadows. Cool teal light falling in the middle, darker toward the edges. Keep the middle clearing very readable and bright.
```

### 2. Prop sheet on magenta

```text
Pixel art game prop sheet, same 16-bit pixel art style, same palette and lighting as the previous forest glade image, 3/4 top-down view. Aspect ratio 1.69:1. Every object is drawn on its own, fully separated from the others, on a perfectly FLAT solid magenta background (#FF00FF), with at least 40 pixels of empty magenta between objects. NO ground, NO grass, NO cast shadows on the background, NO background elements, no text, no labels, no characters. Each object is complete with a clean, crisp, dark outline and moss details so it can be cut out and placed on a ground. The objects: five tall ancient standing stones with a glowing teal rune on each (different heights and shapes, each about 1.6 times the height of a standing adult person), three smaller weathered stones with moss, a large old tree trunk with thick roots seen from a 3/4 top-down angle (about 3 times the height of a person), a smaller dead tree stump, a fallen mossy log lying on the ground, a thorny bush with lilac-purple thorns (knee to waist high on a person), two other bushes and fern clumps, a root arch (a gateway formed by two thick tree roots curving over an opening, about 2 times the height of a person, with a dark opening in the middle), an antler bone shed lying on the ground, small rocks and a few mushrooms. Everything drawn at the SAME SCALE as if a standing adult person is about 50 pixels tall in the 837x496 image. Do not draw the person.
```

### 3. Scale guide (optional)

```text
Use the same pixel art style as before. On a flat solid magenta background, draw ONE standing stone with a glowing teal rune, ONE tree trunk, ONE bush, and next to them a plain flat grey rectangle exactly 50 pixels tall and 20 pixels wide labelled nothing, only as a size reference for an adult person. Draw the rectangle in a flat grey (#808080) with no outline. The stone should be 80 pixels tall, the trunk 150 pixels tall, the bush 30 pixels tall, in an 837x496 image. Keep all objects on the magenta background with no ground and no shadows.
```

If magenta bleeds into the outlines, ask for a pure green screen (#00FF00) instead.

## What to build (Claude, when the images exist)

1. `tools/art/make_layered_ground.py`: convert the ground-only image to the Totoy palette at the glade world size (560x336), like `make_forest_ground_from_reference.py` (same Lab snap, no reserved colours, hard pixels).
2. `tools/art/extract_props.py`: chroma-key the magenta (tolerance for anti-aliased edges, reject pink fringe), split the sheet into connected components, one PNG per prop (hard alpha, palette-snapped, same scale factor as the ground: AI image width 837 -> world 560, factor about 0.67), write a manifest (name, size, base line = bottom of the opaque pixels, base anchor x).
3. `presentation/common/props_layer.gd` + a data file per scene (`presentation/forest/glade_props.json`: prop id, position of the base anchor, optional flip): draws every prop y-sorted with the actors by its base y (automatic walk-behind), no occluder cut-outs needed.
4. Colliders from the props: a default collider circle (or two) at each base derived from the sprite's base width; per-prop overrides; `core/glade_layout.gd` builds its obstacles from the same data so core and presentation never disagree (the core must stay headless: share the data file, no sprites in core).
5. Tests: every prop sprite hard-alpha and palette-only, collider at the base, hero cannot enter any prop from 8 directions, draw order behind/in front, determinism. A review render of the glade with props, colliders and the hero (shadow, tint) in the real game loop.
6. Keep the Stag fight room rule (boss radius 20 reaches at least 80 percent of the central area) with the new layout.

## Acceptance (human judges)

Looks as good as the painted glade or better; walking behind stones/roots/trunks is correct everywhere; no floor pixels over the hero; collisions line up with the visible bases; adding or moving a prop is a one-line data change.
