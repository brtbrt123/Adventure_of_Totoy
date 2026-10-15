# 0001: Stage 1 setup choices

Date: 2026-10-15 · Status: accepted by default, the human may overrule

- **Palette:** DawnBringer 16. Hex values read from the Lospec palette JSON (<https://lospec.com/palette-list/dawnbringer-16>) on 2026-10-15 and stored in `art/palette.json` with one symbol per color. The game design wants cozy and readable art with gold and red combat cues; DB16 has a gold (`e`) and a red (`6`).
- **Art tools live in `tools/art/`**, not in `art/`, so `art/` holds only art (sources, palette, generated output). Claude Code owns `tools/`.
- **Sprite source format:** text grids with a `# kind:` header; see `AGENTS.md` section 5.
- **Generated art is committed** (`art/build/`), so Godot works from a fresh clone without Python.
- **Atlas padding:** tiles use margin 1 and separation 2 with extruded edges, so a Godot `TileSetAtlasSource` can use them directly; sprites use a shelf-packed atlas with a 1px extruded border.
- **Renderer:** `gl_compatibility`, the safest choice for 2D pixel art and for a possible web build later. Revisit only if a shader needs more.
- **Seam check** is a heuristic (see `AGENTS.md`); the human judges the 3x3 repeat on the contact sheet.
- **Test framework:** none chosen. Recommendation is plain headless GDScript tests run with the console build, because it adds no addon. GUT and GdUnit4 are alternatives; compatibility with Godot 4.7.2 has not been checked. Ask before adding an addon.
