# 0004: Sharp UI text (stretch mode canvas_items)

Date: 2026-10-19. Decided by the human (chosen from three options in chat).

**Problem.** With stretch mode `viewport` the whole game, text included, was rendered at 320x180 and scaled 4x. The HUD letters were a 3x5 pixel bitmap font and the profile portrait a 25x25 pixel image, so menus, names, numbers and the portrait looked blurry and chunky at 1280x720.

**Decision.** Keep the 320x180 logical resolution, integer scaling and nearest-neighbor filtering for all pixel art, but change `display/window/stretch/mode` from `viewport` to `canvas_items`. Everything is still positioned in 320x180 "game pixels"; the canvas is now rendered at the window resolution, so:
- text (title, menus, names, stats, cooldowns) is a real font (Godot's built-in fallback font, emboldened, with an outline) and is sharp at any window size;
- the round portrait is cut from the owner's original high-resolution portrait (`art/reference/hero_portrait.jpg`) and drawn smooth-filtered behind the frame (the palette-bound 48 px copy stays for the fallback);
- lines, polygons and circles drawn by code (beams, warnings, effect arcs) are no longer stair-stepped at 320x180 but drawn at window resolution; sprites, tiles and frames are unchanged.

**Consequences.** Windowed screenshots saved by the smoke/capture scripts are now window-sized (1280x720) instead of 320x180. `tests/smoke_project.gd` checks the new setting. Rejected: raising the base resolution to 640x360 (much larger rework) and only enlarging the bitmap lettering (still pixelated). Not done: a SubViewport that keeps even the code-drawn world effects on the 320x180 grid; revisit if the smoother effects clash with the pixel art.
