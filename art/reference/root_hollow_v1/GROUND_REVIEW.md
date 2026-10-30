# Root Hollow ground approval package (2026-10-30)

Step 1 only. Ground proposal is temporarily installed at presentation/forest/root_hollow_layered_ground.png so the real renderer and the F12 debug-jump handler can show it. No core/, data/, outline, props or lighting tuning changed. Props remain unapproved blockout assets and are hidden in the capture fixture only. Do not start the 12-prop sheet before owner approval.

- ground_raw.png: untouched built-in imagegen output. Four attached references and exact prompt in GROUND_PROMPT.md. One generation; service did not return a billing amount.
- prepare_ground.py: resize raw to 640x400, then use existing Lab snap and cleanup from tools/art/make_arena_ground_from_reference.py with dimensions overridden. The task's make_forest_ground_from_reference.py and the woodland importer's make_village_ground_from_reference.py are missing in this checkout; neither was recreated or modified. No reserved combat colours, opaque Totoy36 pixels only.
- ground_full_2x.png: complete palette-converted 1280x800 map, nearest-neighbour.
- gameplay_{central,shrine,pocket,combat}_4x.png: actual windowed explore_scene renderer with night lighting, mobs and HUD. 320x180 native centre crop at 4x. Ground-only fixture clears prop_placements after scene loading, retaining scene lighting. Combat capture includes a live Boar red charge telegraph.
- ground_renderer_comparison.png: Woodland / Forest / proposed Root Hollow, each at the same 2x world scale. Individual 4x neighbour captures also included.
- Reproduce captures: Godot console --path . --script res://tests/capture_root_hollow_ground.gd. Uses the same jump_to handler as F12, advances its transition, isolated save in art/build; no real user input or normal save changes. Then run compose_ground_review.py.

Limitations: visual style and final ground approval belong to the owner. This is not the finished populated scene. No physical F12 key press or manual route playthrough claimed. OpenGL captures complete but the process reports one static texture RID leak on exit; no script error in successful capture run. The exact walkable outline was not changed or re-traced. Palette audit and 58 Stag source/PNG/atlas dimensions, bytes, alpha, colours and anchor checks pass. See CROSS_REVIEW.md for Claude's changed presentation/art review.

Validation: python tools/art/validate_art.py passed (3094 sources, 3098 built PNGs); full python -u harness/checks/run_tests.py --worktree . passed Python, Godot import, all core tests and every smoke. Log: art/build/arena_hollow_full_harness.log (ignored). No core/data changes. No atlas rebuild needed for the standalone ground; no sprite source or atlas change in this proposal.
