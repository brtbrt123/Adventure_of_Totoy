## Runtime integration (2026-10-30)

Owner explicitly requested integration ("wire them"). Installed60 native frames as mossling_play_idle_right_1..24 and boar_graze_idle_right_1..36, anchor32,40. Rebuild source installation with install.py, then standard validate/build/preview. Shared presentation/explore/mob_view.gd selects them in idle only,6 simulation ticks per frame (100ms at60Hz), using snapshot tick plus stable per-mob phase because dormant idle state_ticks remains zero. Simulation pause freezes poses. Alert/combat/return/hurt/death art remains original. Cosmetic hop offsets do not change core world positions or collision geometry.

ingame_idle.gif and ingame_contact.png show actual windowed renderer captures,7.2 seconds /4x native pixels, made with tests/capture_mob_idle.gd then compose_ingame.py. Tests: tests/smoke_mob_idle.gd covers dormant progression,all60 frames/anchors,wrapping,phase offsets and state interruption. Original review JSON and GIFs below remain source-stage records. No core/data or original generator edits. Graphify unavailable.

## Historical review notes

# Mob idle animations, owner review v1

Requested: Mosslings jumping around playfully; Thornback Boars eating on the ground. **Review only. No runtime sprite, state table, core movement or gameplay file changed.**

- `idle_review.gif`: both loops together, 7.2 seconds, nearest-neighbour at 6x.
- `mossling_idle.gif`: 24 frames at 100 ms, 2.4 seconds. Anticipation squash, two larger hops, leaf follow-through, landings and a small return hop. Preview includes a blink.
- `boar_idle.gif`: 36 frames at 100 ms, 3.6 seconds. Slowly lowers its snout to the grass, roots/nibbles, chews, briefly raises its head and flicks its tail. Hooves stay planted; the charge spines stay relaxed.
- `frames/`, `*_sheet.png`: native 64x48 transparent cells, anchor (32,40). `*_sheet_4x.png` enlarges the same cells for inspection. JSON records the timing and pose parameters.

Rebuild with `python art/reference/mob_idle_review_v1/build_review.py`. This reuses the original editable rigs from `tools/art/make_chapter1_creatures_art.py`, preserving the existing creature designs; the original tool is read only. No image generator, external service or credits used.

All 60 native frames are checked for Totoy 36, no reserved gold/red, fully opaque/transparent pixels and no clipped poses. Ground, grass and opaque shadow in GIFs are review scenery kept separate from the transparent frames. GIF text is a review label, not game art. Frame sheets inspected.

The little sideways hops are cosmetic offsets in this proposal. Approval of these previews does not add wandering, change mob positions or modify hitboxes. Integration would need to respect the existing core idle/movement contract and be reviewed separately.

Verification: art validate -> build -> preview passed. Fresh full harness passed Python, import, core and every smoke, including smoke_mob_idle; log art/build/arena_mob_idle_full_harness.log (ignored). All60 imported frames preserve every visible approved source pixel. Windowed captures complete; existing one-texture OpenGL shutdown leak still printed on capture exit, no capture script errors. No generation credits used.
