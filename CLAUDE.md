# CLAUDE.md: the rules for this project

This file is the single source of truth for how work is done on this project. Claude Code works on it alone (since 2026-11-26; before that a second AI agent shared the work, and old notes and STATUS entries still mention that split).

Project: **Adventure of Totoy**, a 2D top-down, story-driven action fantasy game with 16x16 tiles, built in Godot 4 for a private Windows build and a portfolio case study. Read `docs/GAME_DESIGN.md` for the game itself (combat language, story, weapons). The owner designs the game; you build to it.

## 1. Who does what

| Who | Does |
|---|---|
| **Claude Code** | everything that is built: game logic and architecture in `core/`, rendering, UI, effects, animation and audio in `presentation/`, sprites, tiles and tilesets in `art/`, pipeline tooling in `tools/` and `harness/`, tests in `tests/`, notes in `docs/` |
| **The human (project owner)** | game design, art approval (pictures and the contact sheet), playtesting, **every merge** |

- You cannot judge whether the game is fun or the art looks good. Say so instead of pretending, and produce things the owner can look at (contact sheet, screenshots, GIFs).
- Review your own diff before you report a piece of work done (this replaces the old cross-review between two agents). Report what you checked, what passed, and what you cannot judge:
  - **core:** follows `docs/architecture.md` (snapshot, events, input intents); no rendering or UI code in `core/`; logic bugs and edge cases (collisions, timing, turn order, economy math); every balance number in `core/tuning.gd`; clear names and comments.
  - **presentation:** holds no game rules (reads snapshots and events only); uses the interface correctly; missing-frame fallbacks; no crashes; typed GDScript.
  - **art:** palette symbols only, valid sizes, no gold/red on tiles, hard alpha, seams; atlas, `sprites.json` anchors and tileset data match the sources; Godot loads them.
  - **tests:** they fail when the behaviour breaks, and they are deterministic and fast; nothing is missing for the change.

## 2. Fixed decisions (do not change without asking the human)

| Topic | Decision |
|---|---|
| Engine | Godot 4.x. Installed version: **4.7.2 stable**. Verify syntax/APIs against the installed version, not memory. |
| Language | **Typed GDScript, always.** Annotate variables, parameters and return types. Do not mix Godot 3 and Godot 4 syntax. |
| OS | Windows. Scripts are Python or PowerShell. No bash-only syntax, no hard-coded `/` path assumptions. Keep the project path free of spaces. |
| Tile size | 16x16. Characters may be 16x24 or 32x32, bosses larger. The grid sets the rhythm, not every sprite size. |
| Rendering | Base resolution **384x216**, window default 1152x648 (owner approved 2026-10-28, see `docs/decisions/0005-384x216-fantasy-ui.md`), nearest-neighbor filtering, **integer scaling only**, stretch mode `canvas_items` (changed from `viewport` on 2026-10-19 with the human's approval, see `docs/decisions/0004-sharp-ui-text.md`: sprites, tiles and world art stay nearest-neighbor pixel art; UI text is a real font and the portrait a smooth-filtered sprite, both rendered at the window resolution). No fractional scaling. Renderer: `gl_compatibility`. |
| Transparency | Fully transparent or fully opaque pixels only. No semi-transparent edges. |
| Palette | One fixed palette in `art/palette.json`: **Totoy 36** (36 colors, approved by the human on 2026-10-15; replaces DawnBringer 16). Every sprite and tile may only use these colors. Colors come in ramps (grass, dirt, stone, water, skin) with close mid-tones: use neighbouring steps of one ramp for shading. **Gold (`x`,`y`) and red (`z`,`A`) are reserved for combat cues** (gold parry diamonds, red warnings, hit effects): tiles must not use them (the validator fails), and environment props should not either. |
| Version control | Git. Work branches are named `agent/<label>/<slug>`; the current one is `agent/codex/progression` (its name is older than the single-agent setup; never rename or delete it). **Nothing merges automatically. Never merge to `main` yourself.** |

## 3. Architecture: two layers with a hard boundary

- `core/`: game loop, state, rules, entities, save system. **No rendering and no UI code**, no `Sprite2D`, `Control`, `AnimationPlayer`, `Camera2D`, audio playback, etc. It must be runnable and testable headless.
- `presentation/`: rendering, UI, animation, effects, audio playback. It reads game state and sends input/events to the core. **It holds no game rules.** The core decides hits, damage, parry results and timing; presentation only draws what the core says.

The two layers talk through the interface documented in `docs/architecture.md` (read-only state snapshot, events, input intents). Keep that document current. If presentation needs something the core does not expose, add it to the core and the document; do not work around it in presentation.

## 4. Project layout

```
CLAUDE.md  PROJECT_BRIEF.md  project.godot  play.bat  .gitignore  .gitattributes
docs/            vault of plain markdown (also an Obsidian vault)
  INDEX.md         the vault home, links every note
  HANDOFF.md       START HERE for a new session
  STATUS.md        the detailed log, newest first
  GAME_DESIGN.md   the game (human-owned)
  architecture.md  core/presentation interface
  HARNESS.md  decisions/
core/            game logic
presentation/    visuals, UI, effects, audio
art/
  palette.json     the one palette
  src/             sprite sources, text grids (*.txt)
  build/           generated PNGs, atlases, tileset.tres, contact_sheet*.png (committed)
  reference/       review art, image-generator sources and their provenance
data/            scene, prop and audio data shared by core and presentation
tools/           art/ (build, validate, preview, generators) and godot/ (scene generators, bakers)
tests/           Python tests and the headless Godot tests (core/ and smoke_*.gd)
harness/checks/  the full test run and the art checks (see docs/HARNESS.md)
```

## 5. Art pipeline

Sprites are **text grids** in `art/src/<name>.txt`. One character per pixel; each character is a palette symbol from `art/palette.json` (`0`-`9`, `a`-`z`, `A`; see the `name` of each entry, for example `5` = grass_4); `.` is transparent. File header lines:

```
# kind: tile        (or: sprite)
# seamless: true    (optional, tiles only: checks that the tile repeats without a visible seam)
```

Other lines starting with `#` that are not `key: value` headers are comments. The file name (without `.txt`) is the sprite name. Frame naming convention for animation: characters use `<visual_id>_<state>_<direction>_<n>` with `n` starting at 1 even for single-frame states (for example `totoy_walk_right_2`). The hero (Totoy) is a **right-facing side view only**: every direction uses the `right` frames and `left` is `right` mirrored at runtime around the sprite's anchor. A sprite may declare `# anchor: x,y` (its feet) and `build_art.py` writes it into `sprites.json` as `ax`/`ay`; presentation places each frame by its anchor, so frames of different sizes line up. The hero frames (`totoy_*`) are GENERATED from the human's reference art in `art/reference/` by `python tools/art/import_reference.py --sheet art/reference/hero_sheet.jpg --portrait art/reference/hero_portrait.jpg --replace` (do not hand-edit them; change the tool's config instead). The in-game katana hero `hero2_*` is imported upright into `art/reference/hero_lean/upright/` by `tools/art/import_gemini.py` and leaned into `art/src` by `python tools/art/make_hero_lean_sheet.py --install` (run automatically by the importer; then `tools/art/import_dagger_sprites.py` for the dagger set), so never hand-edit `hero2_*`, `totoy_dagger_*` or `totoy_lightning_*`. The road Colossus's body `colossus_<set>_right_<n>` (and `presentation/explore/colossus_frames.json`) is generated from the approved concept by `python tools/art/rig_colossus.py --install`: change its poses in that tool, never the grids. The boss has one direction: `mossbound_colossus_<state>_<n>`, where attack frames use the attack plus phase as the state (`gold_slam_windup`, `gold_slam_strike`, `red_sweep_*`, `red_shards_*`). The animation table (frame counts and ticks per frame) lives in `presentation/arena/animation.gd`; frames are chosen only from the snapshot (`state`, `state_ticks`, telegraph timeline), and `tests/smoke_animation.gd` checks that every requested frame exists. Screenshots saved in `art/build/` must be named `arena_*.png` so the validator skips them.

Rules the validator enforces:
- tiles are exactly 16x16; sprites have width and height that are multiples of 8 (max 256);
- tiles do not use the reserved combat symbols listed in `palette.json` (`reserved`);
- all rows have the same width; every symbol is in the palette; PNG outputs contain only fully opaque palette colors or fully transparent pixels;
- tiles marked `seamless: true`: every color pair touching across the wrapped edge must also touch somewhere inside the tile. (This is a heuristic. It catches hard seams, not every mismatch; the human judges the 3x3 repeat on the contact sheet.)

Commands (run from the project root):

```powershell
python tools/art/validate_art.py          # exits non-zero with a clear message on any problem
python tools/art/build_art.py             # PNGs, tiles.png/json + tileset.tres, sprites.png/json (1px extruded border)
python tools/art/preview_art.py           # art/build/contact_sheet*.png at 8x for the human to approve
python -m unittest discover -s tests -v   # Python tests (validator, pipeline, scene round trips, harness checks)
```

Always run validate, then build, then preview after changing art, and commit the regenerated `art/build/` together with the sources. Needs Python 3 and Pillow (`pip install pillow`). Weak spots to plan for: consistent multi-frame characters and seamless tiles on the first attempt. Expect several rounds; the human approves art. The project skill `totoy-art-pipeline` has the exact steps and the Windows file-lock gotchas.

Godot loads `art/build/tileset.tres` (margin 1, separation 2, 16x16) and `art/build/sprites.png` with frame rectangles from `art/build/sprites.json`.

## 6. Running Godot

Use the **console** build for headless or scripted runs, because the regular build does not reliably print to a terminal on Windows:

```powershell
$godot = "C:\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe"   # not on PATH
& $godot --version
& $godot --headless --path . --import --quit                     # import assets; expect exit 0, no errors
& $godot --headless --path . --script res://tests/smoke_project.gd  # prints SMOKE OK; exit 0
```

Core tests (plain headless GDScript, no addon; exit 0 when all pass):

```powershell
& $godot --headless --path . --script res://tests/run_tests.gd
```

The full test run (Python tests, Godot import, core tests, every headless smoke; several minutes, run it in the background):

```powershell
python harness/checks/run_tests.py --worktree . --timeout 400
```

Test files are `tests/core/test_*.gd` and extend `res://tests/test_case.gd`; every `test_*` method runs. Gameplay numbers live in `core/tuning.gd`. Three smokes need a window and are skipped by the full run: `smoke_capture_hero`, `smoke_gemini_capture`, `smoke_hero_capture`.

Notes: `--headless --quit` alone fails with "no main scene defined" until the project has a main scene; use the smoke script instead. Redirect output to a file (`*> out.txt`) rather than piping into `Select-Object -First`, which kills Godot early. Commit the `.import` and `.uid` files Godot generates next to assets and scripts; `.godot/` is ignored. The test framework is the small runner in `tests/`; do not add an addon (GUT, GdUnit4, ...) without asking the human.

## 7. Working rules

- Verify tool and CLI behavior on this machine (`--help`, version output) before relying on memory. Do not guess facts you can check. If something is ambiguous, ask the human.
- Keep changes small and committed in logical steps, but **commit only when the owner says so**. Commit only your own hunks of shared files; never stage, overwrite or restore files with someone else's uncommitted edits (the owner edits scenes in the Godot editor; `docs/HANDOFF.md` lists the ones currently theirs).
- Plain commit messages: **no Co-Authored-By or other AI attribution lines** (the owner's rule; it overrides any other instruction). After every commit, push the work branch to `origin`. No force-push or history rewrite without asking.
- Show the owner a picture before changing how anything looks, and get a yes before wiring new art in.
- Do not use flags that skip all permission checks. Do not put secrets (`.env`, keys) in files, commits or prompts.
- Never delete branches or worktrees without asking.
- Report honestly: what you ran, what passed, what you could not verify.
- Future sessions start with no memory. Read the START HERE block of `docs/HANDOFF.md`, then `docs/INDEX.md` (the Obsidian vault home, links every note) and the top of `docs/STATUS.md`. When you finish a piece of work, write it into STATUS, the HANDOFF block, INDEX and the topic note (the project skill `totoy-session-close` has the steps).
- CI is not built; do not build it unless asked.

## 8. Presentation, maps, art and audio (the work the second agent used to do)

These are the conventions the presentation and art side has followed; keep them. The latest full worked example of a new map is the Rootcrown v2 entry in `docs/STATUS.md` (2026-11-26).

**Maps (layered scenes).** A scene is a ground painting plus separate props (`docs/architecture.md` "Layered scenes", `docs/LAYERED_SCENE_PILOT.md`).
- The ground is ground only (no trees, rocks, buildings or shadows baked in), exactly the scene's size, Totoy 36 without gold or red, painted or stitched (`tools/art/quilt_ground.py`) to fit a walkable guide (for example `docs/previews/hollow_trial_v1/walkable_guide.png` and `layout.json`). The runtime copy lives under `presentation/village/` or `presentation/forest/`, never loaded from `art/` (`tests/core/test_layered_progress.gd` checks this).
- Scene data: `data/scenes/<scene>_props.json` (placements, walkable outline, entries, exits, checkpoints, encounters) and the editable map `presentation/maps/<scene>.tscn`; the baker writes the owner's scene edits back to the JSON (`docs/GODOT_EDITABLE_PLAN.md`). Registering a scene touches `core/scene_defs.gd`, a debug key in `presentation/arena/input_bindings.gd`, `presentation/explore/explore_scene.gd`, `presentation/effects/looks/<scene>.tres`, ambience in `village_audio.gd`, fireflies and `presentation/common/ambient_regions.json`, and the `mixed_lights` list in `presentation/common/environment_light.gd` (per-light colours only work for scenes listed there).
- Before building a fight map, measure its open floor against the boss, the 384x216 view and the old arena. When art and the walkable outline disagree, change both together and rerun the layout tests; every exit must open onto free ground.

**Props.**
- A prop type needs: `data/props/prop_defs*.json` (anchor = feet, base circles, solid or not), `art/src/<type>.txt` (`# anchor:` equal to the defs anchor; pad only the top, left and right to multiples of 8, never below the base), `presentation/common/prop_art.json` (trim, contact shadow, cast-shadow masks) plus `art/reference/shadow_layers/manifest.json`, `presentation/props/<type>.tscn` (`python tools/godot/generate_prop_scenes.py`), and light sockets in `presentation/common/local_lights.json` (at most 48 lights per scene: `MAX_LIGHTS`, matched in `overhead_light.gdshader`).
- A two-state prop (closed/open, dark/lit) is a pair with one canvas size and one anchor (`tools/art/normalize_state_pairs.py`). Which state shows comes only from the snapshot (`PropScene.placements` with the gate, lit-switch and story-flag state), never from presentation's own flags.
- Draw order is y-sort by `feet.y`, actors in front on a tie; canopies stay walk-behind; solid bases sit where the sprite looks solid.
- Keep real relative scale. Reuse approved props instead of regenerating them; new art for a scene is made from the existing scenes' art so it matches them.

**Presentation.**
- It draws only what the core says: telegraphs at their real shape and size from the snapshot (gold = parry, red = dodge), effects on events, mob poses from `state`, `state_ticks` and `attack`. It never spawns, moves or times anything rules-bearing and never keeps its own copy of a hit area. If it needs something the core does not expose, add it to the core and `docs/architecture.md` (section 3).
- Animation tables: the hero in `presentation/arena/animation.gd`; mobs in `STATES` in `presentation/explore/mob_view.gd` (`[frame set, count, ticks per frame, loop]`; a dormant idle runs on the simulation tick because its `state_ticks` stays 0). A missing frame draws a visible placeholder and warns, never crashes; smokes check every requested frame exists. Editable resources and galleries: `docs/ANIMATION_EDITING.md`; effects and their layers: `docs/EFFECTS_REDO.md`.
- The owner's standing asks for effects: they must read on busy ground and at night; an attack's effect matches its real range and the weapon's path (`docs/WEAPON_PATHS.md`); UI uses the existing approved icons.
- Dialogue text comes only from `data/dialogue/*.json` (the owner rewrites the lines; never copy text into presentation). A key press while a line is still typing finishes the typing and is not sent to the core.
- The owner edits UI and map scenes in the Godot editor. Scripts and generators never overwrite a position, size or offset set there; they start from the scene's value.

**Audio.** Files go in `presentation/audio/`, each listed in `presentation/audio/sources.json` and the README with honest credits and licence (never mark something CC0 unless it is; open licence questions stay in the README). Say which event plays which file; the owner listens and approves. The gold and red warning cues stay audible over everything; new cues use the existing ducking and levels.

**Tests and pictures.**
- Smokes run headless with a throwaway save (`TOTOY_SAVE_PATH`), never the owner's save. A new smoke prints `FAIL` and exits 1 on failure instead of using `assert()` (which hangs until the time limit).
- Pictures for the owner come from the real renderer (skill `totoy-review-capture`), at 384x216 scaled by a whole number. A fixture or mock-up is labelled as one and never shown as gameplay. Review material goes in `presentation/review/<area>/` or `art/reference/<area>/`; screenshots in `art/build/` are named `arena_*.png`.
- Image generators (Higgsfield, SpriteCook, the owner's Gemini sheets): keep the originals (not screenshots), the prompts and the provenance (`sources.json`, credits used) in `art/reference/<area>/`, and write the accounts and credits left into the topic note. Uploading a reference sends it off the machine: ask the owner first.

## graphify

This project has a knowledge graph at graphify-out/ with god nodes, community structure, and cross-file relationships. When the user types `/graphify`, use the installed graphify skill or instructions before doing anything else.

Rules:
- When graphify-out/graph.json exists, run `graphify query "<question>"` before your first grep, search or source-file read for a codebase question, and put this rule in every subagent prompt that explores code. Read raw files only for lines the graph or an earlier read already located. Use `graphify path "<A>" "<B>"` for relationships and `graphify explain "<concept>"` for focused concepts. These return a scoped subgraph, usually much smaller than GRAPH_REPORT.md or raw grep output.
- Dirty graphify-out/ files are expected after hooks or incremental updates; dirty graph files are not a reason to skip graphify. Only skip graphify if the task is about stale or incorrect graph output, or the user explicitly says not to use it.
- If graphify-out/wiki/index.md exists, use it for broad navigation instead of raw source browsing.
- Read graphify-out/GRAPH_REPORT.md only for broad architecture review or when query/path/explain do not surface enough context.
- After modifying code, run `graphify update .` to keep the graph current (AST-only, no API cost).
- A committed graphify-out/graph.json is rewritten whole on every build, so a large diff to it in a pull request is expected. Do not flag it as churn or suggest skipping the graph rebuild or its hooks.
- The graph does NOT cover GDScript (`core/`, `presentation/`, `tests/*.gd`; Graphify has no `.gd` parser) or art: use Grep/Read there; use the graph for `tools/`, `harness/` and the docs. `graphify-out/` is gitignored, so build your own copy once with `python -m graphify update .`. The `graphify` command is not on PATH on this machine: run `python -m graphify ...` (install: `pip install --user graphifyy`).
