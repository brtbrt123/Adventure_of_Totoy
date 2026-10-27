# Codex task: layered scene pilot (Stag glade), presentation and art side

Written by Claude Code, 2026-10-27. Read `AGENTS.md`, `docs/LAYERED_SCENE_PILOT.md` (why, the prompts, acceptance) and `docs/architecture.md` "Layered scenes" first. Claude's side (extractor, shared data format, core loader, tests) is done and pushed; yours uses it. Do not edit `core/`, `tools/` or `harness/`: write what you need in your notes.

## Inputs (the human supplies them)

`art/reference/layered_pilot/glade_ground_only.png` and `glade_props_sheet.png` (original images, not screenshots). If they are missing, stop and say so; do not invent art.

## Step 0: run the extractor (it is a command, not your job to rewrite it)

```powershell
python tools/art/extract_props.py --sheet art/reference/layered_pilot/glade_props_sheet.png --names <ids in reading order> --world-width 560
```

It writes `art/reference/layered_pilot/props/<id>.png` (cut-outs at world scale, hard alpha, palette-snapped, no gold/red), `props_contact.png` (base line cyan, colliders orange: look at it) and `data/props/prop_defs.json`. Names go in reading order (rows top to bottom, then left to right). If the cut-outs are wrong (merged or split props, pink fringe), tell Claude what the contact sheet shows; do not hand-edit `prop_defs.json` (Claude locks hand-tuned entries).

## Your work

1. **Ground:** convert `glade_ground_only.png` to the Totoy 36 palette at 560x336 into `presentation/forest/` (new file, for example `glade_layered_ground.png`; keep the painted glade untouched). Hard pixels, no reserved colours.
2. **Sprites:** turn each extracted PNG into an `art/src/<type>.txt` sprite (`# kind: sprite`, `# anchor: ax,ay` = the `anchor` in `prop_defs.json`; sizes must be multiples of 8, so pad with transparent rows/columns on the TOP and LEFT/RIGHT only, never below the base, and keep the anchor in sprite pixels correct after padding: tell Claude the padded size and anchor so the defs can be updated). Run validate, build, preview.
3. **Props layer:** `presentation/common/props_layer.gd`. Input: the placements from `PropScene.placements(scene, defs)` (id, type, feet, flip, size, anchor, image). Draw each sprite with its anchor on `feet` (mirror when `flip`), y-sorted with the actors by `feet.y` in the same draw list as `explore_scene.gd drawables()`. No occluder cut-outs. Soft actor shadow and scene tint must match the other scenes.
4. **Scene data:** `data/scenes/glade_layered_props.json` (format in `docs/architecture.md`): `size` [560, 336], the `outline` (walk the painted ground's edge; see `core/glade_layout.gd` for the painted glade's outline at 0.7 and reuse its shape), and `props[]` placements. If you need positions to look right, start from the painted glade's stones (`GladeLayout.STANDING_STONES_1X` times 0.7). Run `PropScene.validate` (a test already checks every `data/scenes/*_props.json`).
5. **Review captures:** the hero walking behind and in front of every prop (windowed capture like `tests/capture_depth_review.gd`; writes `art/build/arena_*.png`, delete afterwards unless the human wants them), plus a colliders overlay on the new scene.

## Hand back to Claude (do not do these yourself)

- Wiring a `glade_layered` scene into `core/scene_defs.gd` so the game can load it (obstacles from `PropScene.build`).
- Changing collider numbers (they come from the extractor; if a collider looks wrong, say which prop and what you see).
- The Stag fight-room rule (boss radius 20 reaching 80 % of the fight area) with the new layout.

## Acceptance (the human judges)

Looks as good as the painted glade or better; walking behind stones/roots/trunks is correct everywhere; no floor pixels over the hero; colliders line up with the visible bases; adding or moving a prop is a one-line data change.
