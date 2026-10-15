# AGENTS.md: shared rules for every AI agent on this project

This file is the source of truth for **Claude Code** and **Codex**. It is self-contained: you do not need any other file to know the rules. `CLAUDE.md` only points here.

Project: **Adventure of Totoy**, a 2D top-down, story-driven action fantasy game with 16x16 tiles, built in Godot 4 for a private Windows build and a portfolio case study. Read `docs/GAME_DESIGN.md` for the game itself (combat language, story, weapons). The owner designs the game; you build to it.

## 1. Roles

| Who | Builds | Reviews | Must not edit |
|---|---|---|---|
| **Claude Code** | game logic and architecture in `core/`, `docs/architecture.md`, refactors, save system, pipeline tooling in `tools/` and `harness/` | Codex's diffs: use of the core/presentation interface, naming, atlas and tileset data correctness, whether Godot can load the assets, script bugs | `presentation/`, `art/` (unless the human overrides) |
| **Codex** | sprites and tiles (text grids in `art/src/`), animations, tilesets, UI (HUD, menus), effects, shaders, extra tests in `tests/` | Claude Code's diffs: logic bugs, edge cases (collisions, turn order, economy math), missing tests, unclear code | `core/` (unless the human overrides) |
| **The human (project owner)** | game design, art approval on the contact sheet, playtesting, **every merge** | everything | n/a |

- If your task needs a change in the other agent's folder, **do not make it**. Describe it in your task notes or final message.
- Neither agent can judge whether the game is fun or the art looks good. Say so in reviews instead of pretending. Produce things the human can look at (contact sheet, screenshots).
- Cross-review: whoever builds, the other reviews. A review ends with a clear `pass` or `fail` plus concrete comments (file, line, issue, severity) and a list of what you cannot judge.

## 2. Fixed decisions (do not change without asking the human)

| Topic | Decision |
|---|---|
| Engine | Godot 4.x. Installed version: **4.7.2 stable**. Verify syntax/APIs against the installed version, not memory. |
| Language | **Typed GDScript, always.** Annotate variables, parameters and return types. Do not mix Godot 3 and Godot 4 syntax. |
| OS | Windows. Scripts are Python or PowerShell. No bash-only syntax, no hard-coded `/` path assumptions. Keep the project path free of spaces. |
| Tile size | 16x16. Characters may be 16x24 or 32x32, bosses larger. The grid sets the rhythm, not every sprite size. |
| Rendering | Base resolution **320x180**, window default 1280x720, nearest-neighbor filtering, **integer scaling only**, stretch mode `viewport`. No smoothing, no fractional scaling. Renderer: `gl_compatibility`. |
| Transparency | Fully transparent or fully opaque pixels only. No semi-transparent edges. |
| Palette | One fixed palette in `art/palette.json` (DawnBringer 16, hex values verified against Lospec). Every sprite and tile may only use these colors. |
| Version control | Git. One branch per task, named `agent/<label>/<slug>`. **Nothing merges automatically. Never merge to `main` yourself.** |

## 3. Architecture: two layers with a hard boundary

- `core/`: Claude Code's area. Game loop, state, rules, entities, save system. **No rendering and no UI code**, no `Sprite2D`, `Control`, `AnimationPlayer`, `Camera2D`, audio playback, etc. It must be runnable and testable headless.
- `presentation/`: Codex's area. Rendering, UI, animation, effects, audio playback. It reads game state and sends input/events to the core. **It holds no game rules.** The core decides hits, damage, parry results and timing; presentation only draws what the core says.

The two layers talk through the interface documented in `docs/architecture.md` (read-only state snapshot, events, input intents). Build against that document. If it is missing something you need, say so in your task notes; do not work around it.

## 4. Project layout

```
AGENTS.md  CLAUDE.md  PROJECT_BRIEF.md  project.godot  .gitignore  .gitattributes
docs/            vault of plain markdown (also an Obsidian vault)
  GAME_DESIGN.md   the game (human-owned)
  architecture.md  core/presentation interface
  ROUTING.md  HARNESS.md  STATUS.md  decisions/
core/            game logic (Claude Code)
presentation/    visuals and UI (Codex)
art/
  palette.json     the one palette
  src/             sprite sources, text grids (*.txt)
  build/           generated PNGs, atlases, tileset.tres, contact_sheet.png (committed)
tools/art/       build_art.py, validate_art.py, preview_art.py, artlib.py
tests/           tests (Python art tests now; Godot headless tests later)
harness/         later: router, checks, prompts, logs (see docs/HARNESS.md)
```

## 5. Art pipeline (Codex works here)

Sprites are **text grids** in `art/src/<name>.txt`. One character per pixel; each character is a palette symbol from `art/palette.json` (`0`-`9`, `a`-`f`); `.` is transparent. File header lines:

```
# kind: tile        (or: sprite)
# seamless: true    (optional, tiles only: checks that the tile repeats without a visible seam)
```

Other lines starting with `#` that are not `key: value` headers are comments. The file name (without `.txt`) is the sprite name. Frame naming convention for animation: `<entity>_<state>_<direction>[_<frame>]`, for example `totoy_idle_down`, `totoy_walk_down_2`.

Rules the validator enforces:
- tiles are exactly 16x16; sprites have width and height that are multiples of 8 (max 256);
- all rows have the same width; every symbol is in the palette; PNG outputs contain only fully opaque palette colors or fully transparent pixels;
- tiles marked `seamless: true`: every color pair touching across the wrapped edge must also touch somewhere inside the tile. (This is a heuristic. It catches hard seams, not every mismatch; the human judges the 3x3 repeat on the contact sheet.)

Commands (run from the project root):

```powershell
python tools/art/validate_art.py          # exits non-zero with a clear message on any problem
python tools/art/build_art.py             # PNGs, tiles.png/json + tileset.tres, sprites.png/json (1px extruded border)
python tools/art/preview_art.py           # art/build/contact_sheet.png at 8x for the human to approve
python -m unittest discover -s tests -v   # validator tests
```

Always run validate, then build, then preview after changing art, and commit the regenerated `art/build/` together with the sources. Needs Python 3 and Pillow (`pip install pillow`). Weak spots to plan for: consistent multi-frame characters and seamless tiles on the first attempt. Expect several rounds; the human approves art.

Godot loads `art/build/tileset.tres` (margin 1, separation 2, 16x16) and `art/build/sprites.png` with frame rectangles from `art/build/sprites.json`.

## 6. Running Godot

Use the **console** build for headless or scripted runs, because the regular build does not reliably print to a terminal on Windows:

```powershell
godot_console --version
godot_console --headless --path . --quit        # opens the project; expect no errors
```

(Until the executables are on PATH as `godot` and `godot_console`, use the full path to `Godot_v4.7.2-stable_win64_console.exe`.) No test framework is chosen yet; do not add an addon (GUT, GdUnit4, ...) without asking the human.

## 7. Working rules

- Verify tool and CLI behavior on this machine (`--help`, version output) before relying on memory. Do not guess facts you can check. If something is ambiguous, ask the human.
- Stay inside your folders. Keep changes small and committed in logical steps.
- Do not use flags that skip all permission checks. Do not put secrets (`.env`, keys) in files, commits or prompts.
- Never delete branches or worktrees without asking.
- Report honestly: what you ran, what passed, what you could not verify.
- Future sessions start with no memory. Read `docs/STATUS.md` first; update it when you finish a piece of work.
- The router, review loop, CI and Graphify are later stages (`docs/ROUTING.md`, `docs/HARNESS.md`). Do not build them unless asked.
