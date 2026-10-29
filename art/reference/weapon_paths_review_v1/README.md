# Weapon path effects: owner review v1

Requested: path/trail effects for every currently implemented weapon, sent in chat before integration.

**Owner approved runtime integration on 2026-10-29, then requested glow and particles.** The original concept loops below are preserved as source references. Runtime integration uses the shared hero-effects base for both arena and exploration; see `docs/WEAPON_PATHS.md` and `ingame/` for actual game captures. No core rules changed.

- `weapon_paths_review.gif`: Black Katana, Dual Daggers and Chain Scythe side by side, 4x nearest-neighbour, 3.84-second loop.
- `katana_paths.gif`, `daggers_paths.gif`, `scythe_paths.gif`: individual previews with the same loop duration.
- `combo_contact.png`: active poses from the first three combo swings.
- `frames/`: 40 transparent FX frames across all 10 combo swings (3 katana, 4 dagger, 3 scythe).
- `*_paths.png`: native effect sheets; columns are active poses 3/4 and two fading recovery frames, rows are combo swings.
- `paths.json`: source blade geometry per pose, feet-relative coordinates, native cell/anchor and preview timing.

Styles: pale cutting edge with a muted violet katana afterimage; shorter pale-blue dagger traces; broader spectral-teal scythe sweeps. No gold/red. Every visible trail pixel is fully opaque; the recovery dissolves by removing whole pixels. The old active segment lingers behind the new blade tip. Recovery afterimages stay at the last swing position.

The displayed character/weapon pixels are the existing game atlas, with its original painted effects retained. The proposed overlays sit behind it so the character and held blade remain visible. Ground and shadow are preview scenery, separate from the FX frames. No new body/weapon art is generated.

Rebuild: `python art/reference/weapon_paths_review_v1/build_review.py`.

Geometry comes from the original editable assets: the katana's actual mask/grip; the dagger importer's measured and leaned hand/blade-angle table; the scythe manifest's measured hands and original curved-blade geometry. Only existing helpers are imported; no original generator is edited or run to install assets. No external service or generation credits used.

Validation: all effect frames pass Totoy 36/no reserved colours/hard-alpha/unclipped checks. All four GIFs decode to the intended 3840 ms loop (GIF merges duplicate held frames). Active-pose contact sheet inspected. Preview cadence is deliberately slowed to 80 ms per sample; actual core swing timing, reach and damage are not changed or promised by these previews.

The third katana swing was corrected after owner feedback: its initial trace now takes the forward overhead route rather than the shortest rotation underneath the hands. `ingame/katana_alignment_v2.gif` shows the corrected in-game result. Native source pixels still use Totoy 36 and hard alpha; glow is a small additive runtime pass with capped, tick-driven sparks. Claude cross-review and owner playtest remain pending. Graphify is unavailable in this environment; no graph refresh claimed.
