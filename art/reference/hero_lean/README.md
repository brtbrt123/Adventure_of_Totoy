# Hero lean set (approved, in game)

Status: **approved by the human on 2026-10-20 and imported.** The in-game katana frames `art/src/hero2_*` are now the leaning frames, and the dagger and Lightning sets (`totoy_dagger_*`, `totoy_lightning_*`) are built on the same leaning bodies. Idle and victory stay upright.

## Pipeline

```powershell
python tools/art/import_gemini.py [--only Hero_Walk,...]    # hero2 sheets -> art/reference/hero_lean/upright/ (UPRIGHT), then runs the lean step
python tools/art/make_hero_lean_sheet.py --install           # lean step: upright/ -> art/src/hero2_*.txt (+ review files here; --no-review skips them)
python tools/art/import_dagger_sprites.py                    # dagger + lightning sets from the same leaned bodies
python tools/art/validate_art.py; python tools/art/build_art.py; python tools/art/preview_art.py
```

- `upright/hero2_*.txt` (48 files) are the upright frames exactly as imported. They are the lean step's input and the backup of the old in-game frames (byte-identical to `git show ac97509:art/src/hero2_*`). `import_gemini.py` writes hero2 sheets here, not to `art/src`. A re-import was checked: it reproduces these files byte for byte and the lean step gives the same `art/src` frames.
- `art/src/hero2_*` are generated (header says so). **Do not hand-edit them.** Change `POSES` / `FIXES` in `make_hero_lean_sheet.py` and re-run.
- The script uses Pillow only and no randomness, so running it twice gives identical files.

## Files here (review aids)

| File | Contents |
|---|---|
| `upright/` | the upright input frames (see above) |
| `hero_lean_sheet.png` / `.json` | every frame at 1x in labelled rows, with the rects, feet anchors and lean parameters |
| `grids/hero2lean_*.txt` | review copies of the frames (the game uses `art/src/hero2_*`) |
| `contact_old_vs_new_dark.png`, `contact_old_vs_new_grass.png` | 4x, OLD upright left, NEW leaning right, one row per state, ground line at the feet |
| `game_scale_preview.png` | a 320x180 scene at game resolution, scaled 4x |
| `preview_old_vs_new.gif`, `preview_old_vs_new_realtime.gif` | walk, katana combo and dash at half speed and at game speed |

In-game review sheets of all three sets: `docs/previews/hero_lean_ingame_{katana,dagger,lightning}.png` (+ `_grass`), GIFs `docs/previews/hero_lean_ingame_{katana,dagger}_combo.gif` (4x, half speed, OLD vs NEW).

## Frames (frame counts as in `presentation/arena/animation.gd`)

| State | Frames | Lean (deg) | Notes |
|---|---|---|---|
| idle | 4 | 0 | upright, unchanged |
| walk | 6 | 21 | Head and shoulders about 5 px ahead of the hips, hips 1.5 px forward and 1 px lower. Stride 1.3x at the feet, but 1.1x on the passing frames 3 and 6 (legs together; the wide stride fattened the thighs into a block). |
| dash | 4 | 8, 8, 8, 24 | 1-3 were already a horizontal sprint; 4 (brake) leans 24 |
| attack1 | 6 | 10, 12, 14, 18, 18, 10 | thrust frames keep the arm and blade horizontal while the torso tips |
| attack2 | 6 | 10, 12, 16, 14, 12, 10 | rising cut |
| attack3 | 6 | 12, 14, 16, 18, 16, 10 | the slam folds over the front knee; the blade tip may touch the ground row |
| parry | 6 | -5 (6: -3) | braced, weight slightly back |
| hurt | 4 | -5, 0, 0, -3 | recoil mostly unchanged |
| victory | 6 | 0 | upright, unchanged |
| dagger attack4 (dagger only) | 6 | 8, 6, 18, 21, 16, 10 | `DAGGER_POSES`: twin finisher on borrowed bodies (parry_3, victory_3, attack3_3-5, attack1_6); gather and raise with the weight forward, then fold deeper than the katana slam |

Anchors are the feet points; the feet rows are on the same row as before for every frame of all three sets (checked by script, old vs new). Sizes are multiples of 8.

## Method

A pose-aware warp, not a whole-frame shear:

1. Each frame is split into the katana (water_1/2 pixels plus their own ink outline) and the body; body pixels hidden by the blade are in-painted.
2. The body gets one continuous warp around an auto-detected hip pivot: the head translates in whole pixels with the neck (the face never rotates), the torso rotates by the lean angle (blended to 0 over 6 rows above the hip), the legs widen the stride and bend at the knee with the feet planted.
3. The blade moves rigidly with the grip.
4. RotSprite-style sampling: Scale2x x3, inverse warp, one palette symbol per pixel. No blur, no new colours.
5. Clean-up: pinholes filled, orphan pixels removed, then (new at import) body colours exposed on the silhouette edge are re-inked with the importer's own outline rule and lone 1-px ink spurs are dropped. This closes the outline breaks on rotated diagonals.
6. The dagger importer uses `Frame.map_point` / `Frame.turn_at` to carry its hand points (measured on the upright frames) through the warp, so the daggers sit in the leaned fists.

## Known limits

- The arms are not re-animated: in the walk they keep the original small swing and rotate with the torso.
- The dash has no hair streaming.
- Some 1-px roughness remains where the warp stretches thick areas; walk 3/6 thighs are narrower now but still read as a mass at 4x. Minor at 1x.
- The faint blade fragment at the top-left of katana attack1_5 and parry_5 comes from the source frames (the dagger set drops it).
- Whether it looks and feels right in motion is the human's call.
