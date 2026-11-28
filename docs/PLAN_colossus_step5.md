# Step 5: effects for the Colossus's six attacks kept from the arena (PLAN and progress)

Build step 5 of [[FINAL_SCENE_chapter1]]. After step 4 ([[PLAN_colossus_step4]], the body, the owner's "yeah its good for now",
2026-11-28) the owner asked "is all golem attacks and animation already goods and already have effects?": five attacks, the Briar
Ring and the appearing had their own effects; the six attacks kept from the arena (Gold Slam, Gold Combo, Red Stomp, Gold Sweep,
Red Shards, Red Charge) had only the arena's sounds, a shake and a plain dust puff on the heavy ones. Owner: "Effects first".

## Proposals (2026-11-28; all six wired the same day)

PixelFX (the owner's clone, MIT, commit 5294518) rendered in Totoy 36 with hard alpha by `tools/art/import_pixelfx.py`
(`--only <name>` renders just one now and keeps the other entries of `sources.json`), placed on each attack's REAL shape:

| Attack | Proposal | Source |
|---|---|---|
| Gold Slam | the floor cracks with the song's light, crescent shock fronts run out to the circle's edge (reach 48 for its 44 px circle), rocks erupt; the first second only (frames 1, 3 ... 29; its later dust column turns into dark lumps under hard alpha) | new: `impacts/ground-slam` in stone (`ground_slam/`) |
| Gold Combo | the same on each of its three circles as it strikes | same |
| Red Stomp | stone shards bursting round the middle of its ring (40 px apart) | approved `fx_colossus_shard` |
| Red Shards | stone shards racing out along its three lanes (as the Root Snare's thorns, 22 px apart) | approved `fx_colossus_shard` |
| Gold Sweep | **wired 2026-11-28** ("Looks good, wire it", with the reworked swing, [[PLAN_colossus_step4]]): pale dust puffs and clods across the cone (two rows), in the order the arm swings through it | new: `impacts/blunt-hit` in pale stone, past its flash and hit marks (frames 7, 9 ... 21; `dust_puff/`), installed as `fx_colossus_dust_1..8` |
| Red Charge | that dust where its feet pass along the lane, both sides | same |

Tried and dropped: the stone landing's dust (`fx_colossus_stone_land`) for the Sweep and Charge (its dotted shock ring read as
many little landings); `dust_puff` in dirt colours (too dark to see at night); two rings of shards for the Stomp (a forest of
spikes); `impacts/heavy-landing` (its dust rings vanish with hard alpha, found in 3b).

Pictures: `presentation/review/colossus_5/capture_5.gd` (windowed; the real fight with the proposals drawn over it as a labelled
MOCK) and `tools/art/make_colossus_5_sheet.py`: `presentation/review/colossus_5/colossus_5_effects.png`.

GIFs (the owner judges in motion: "can you send a gif with full effect even the gold mark", 2026-11-28): `capture_5.gd -- --gifs`
records each of the five from the REAL game (its gold or red warning, the body, the hits, the HUD) with the proposed effect drawn as
a MOCK, Totoy standing in the hit area; `make_colossus_5_sheet.py --gifs`: `colossus_5_<attack>.gif` (real speed, then the blow
slowed 3 times). They are 6 to 8 MB each (the night light changes every pixel; fewer colours barely help), so they may stay out of
git.

## Wired (2026-11-28, the owner's "Wire all five" after the GIFs)

- `import_pixelfx.py --install` adds `fx_colossus_slam_1..15` (ground-slam frames 1, 3 ... 29, cut to their common box, anchored on
  the impact point); every other effect reinstalls byte-identical. Atlas 2048x6572.
- `colossus_view.gd` records each blow as it lands (`landed()`, from the snapshot's warnings, parried or not) and draws it depth-sorted
  (`effect_items()`): `slam` on each Slam and Combo circle (15 frames, 4 ticks each), `stomp` shards round the middle of the ring
  (`STOMP_SPACING` 40), `shard_lane` shards along each Shards lane (`LANE_FIRST` 30, `LANE_SPACING` 22, a tick later each),
  `charge_dust` pale dust either side of the Charge's lane (`CHARGE_SIDE` 22) where its feet pass, plus the Sweep's dust from before.
  The arena's shake and dust puff on the heavy blows stay.
- `tests/smoke_colossus.gd` forces all ten attacks and checks each plays its effect; no effect frame is missing.
- `capture_5.gd -- --gifs --real` records the wired game: the same placement as the approved mocks, the only difference is depth
  (effects north of an actor's feet pass behind it), `presentation/review/colossus_5/colossus_5_mock_vs_wired.png`.

Every Colossus attack now has its own effect.
