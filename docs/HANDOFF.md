# HANDOFF: Adventure of Totoy (rewritten 2026-10-22 for the next session)

Read this first, then `AGENTS.md` (the rules), then `docs/CHAPTER1_PLAN.md` (what we are building) and `docs/STATUS.md` (the detailed log, newest section first; entries labelled "NOT committed" may be older than the git history: trust `git log`).

## What this project is

A 2D top-down pixel-art action game in **Godot 4.7.2** (typed GDScript), 320x180 base resolution, private Windows build and portfolio piece. Design: `docs/GAME_DESIGN.md` (the human's document, do not rewrite it). Combat language: **gold heavy attacks can be parried, red attacks must be dodged**. Currently playable: a walkable Chapter 1 slice (village Lanternfen, forest route, Stag glade) and the **Mossbound Colossus** arena fight, with three weapons and eight aspects.

## Rules of the road (from the human)

- The human owns design, art approval, playtesting and **every merge to `main`** (they merge through a GitHub pull request). Never merge to `main` yourself.
- **Work split (the human confirmed 2026-10-22):** while Codex was out of usage Claude also edited `presentation/` and `art/` (a temporary override). **From the week of 2026-10-26, when both limits reset, go back to the normal split in `AGENTS.md`:** Claude Code owns `core/`, `tools/`, `harness/`, `docs/architecture.md`; Codex owns `presentation/`, `art/` (sprites, tiles, UI, effects, shaders) and extra tests; the human approves art and merges; each side reviews the other's diffs (pass/fail with file, line, severity, and what it cannot judge). If one side's task needs a change in the other's folder, describe it in the task notes instead of editing. Suggested split for the next work:
  - **Step 2 NPCs and dialogue:** Claude = dialogue data model and story flags (core), objective/quest state, save fields, tests; Codex = dialogue box renderer, portraits import, NPC interaction UI, typewriter text, sounds.
  - **Layered-scene pilot:** Claude = `tools/art` extraction/conversion scripts, prop data format shared by core and presentation, colliders-from-data in `core/*_layout.gd`, tests; Codex = prop sprites in `art/src`, `props_layer` rendering and depth sorting in presentation, shadows/tints, review captures.
  - **Occluder/collision cleanup:** Claude = collider data and layout tests; Codex = occluder art and drawing.
  - Codex starts without memory: it reads `AGENTS.md`, this file, `docs/CHAPTER1_PLAN.md`, `docs/STATUS.md`, `docs/architecture.md`.
- **Plain commit messages: NO Co-Authored-By / Claude attribution lines** (the human does not want "claude" as a GitHub contributor; history was rewritten once to strip them).
- Work branch: `agent/game/chapter1-dev` (renamed from `agent/art/gemini-import`). After every commit, push it to `origin` (https://github.com/brtbrt123/Adventure_of_Totoy, public). No force-push or history rewrite without asking.
- Short answers, honest reports (what ran, what passed, what was not verified). Show art to the human first and get approval before wiring it in. Ask before downloading files (name, source, licence, size).
- Do not stop a long test run: `python harness/checks/run_tests.py --worktree .` takes several minutes; run it in the background.

## How to run things (Windows)

```powershell
cd C:\Users\Admin\Desktop\Projects\Adventure_of_Totoy
play.bat                                                                   # the game (or: C:\Tools\Godot\Godot_v4.7.2-stable_win64.exe --path .)
$godot = "C:\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe"            # headless/scripts, not on PATH
python harness/checks/run_tests.py --worktree .                            # python tests + godot import + core tests + all smoke_*.gd
python tools/art/validate_art.py ; python tools/art/build_art.py ; python tools/art/preview_art.py
```

Controls: WASD move, SHIFT dash, left click attack, right click weapon active, Z/X/C aspects, SPACE parry, TAB character menu (Q/E tabs, ENTER equip), E interact, R restart, ESC back. Aim follows the movement direction (not the mouse). Debug: H or F1 colliders/overlay, 1-4 (or F2-F5) jump to village/forest/glade/arena, G (or F6) opens the forest root gate.

## What exists (all pushed unless STATUS says otherwise)

- **Core (`core/`, headless, deterministic):** player, boss (Colossus), three weapons (Black Katana buff, Dual Dagger Lightning Barrage, Chain Scythe Reaper's Coil), eight equippable aspects (Breaking Edge, Gale Cut, Moon Cleave, Spirit Lantern, Phantom Cut, Echo Step, Stone Ward, Sprint) in Z/X/C with a saved loadout, solid props with swept collision, an exploration simulation (`explore_core.gd`, scene graph in `scene_defs.gd`), scene layouts (`village_layout.gd` 0.7, `forest_layout.gd` 0.6, `glade_layout.gd` 0.7, `arena_layout.gd`). 300+ core tests with mutation checks.
- **Presentation:** arena renderer with following camera, cut-ins per weapon, HUD, character menu (stats/inventory/aspect picker), exploration scene renderer with fades, depth occluders, shared soft actor shadow, title screen (NEW GAME / CONTINUE / BOSS FIGHT).
- **Art pipeline:** text-grid sprites in `art/src`, generators in `tools/art/` (hero lean frames, weapon sets, effects, NPC sprites, scene grounds converted from the human's paintings into the Totoy 36 palette). Review art lives in `art/reference/` and `docs/previews/`.

## Chapter 1 build order (see `docs/CHAPTER1_PLAN.md`)

1. Scene manager and walking mode: **done**.
2. NPCs and dialogue (art approved: `art/reference/chapter1_characters_v2`): **next**.
3. Enemies: Mossling, Boar, Glowmoth (creature art approved: `art/reference/chapter1_creatures`).
4. Forest lantern puzzle (opens the root gate) and the Thornback Stag mini-boss (gives Sprint).
5. Cutscenes and ending (Colossus entrance, Edda's binding, beacon lighting with `art/reference/beacon_epilogue`, credits).
6. Polish, playtest, a short gameplay video.
When a step is finished, tell the human and ask whether to start the next one.

## Next session (written 2026-10-22 because the weekly usage limits of Claude and Codex were about to run out; both should reset around Monday 2026-10-26)

Start with a fresh clone of the state: `git status` and `git log` first. The last session ended in the middle of these items (check `docs/STATUS.md` top entries for what the last agents actually finished and what they flagged as NOT done):

1. **Uncommitted work may exist** on `agent/game/chapter1-dev`: the playtest fixes (depth occluders, soft shared actor shadow, solid stones/doors/gate), the glade pond and slab REMOVAL (human decision: the glade has only the five standing stones; the pond and flat slabs are painted out of the ground art), the tightening of the occluders (human feedback: the cut-outs include flat floor pixels that draw over the hero), the alternate debug keys (1-4, G, H), and this HANDOFF. Run `python harness/checks/run_tests.py --worktree .` (several minutes, run in the background), fix failures, commit with a plain message, push. Ask the human to merge to `main` through a pull request (their contribution graph only counts `main`).
2. **Occluder quality:** review `docs/previews/occluder_footprints_*.png` if the last agent produced them; every cut-out must contain only prop pixels (no ground). Playtest each scene (play.bat, NEW GAME) behind gate, trees, stones, pedestals, house; the human reports specifics.
3. **Layered-scene pilot (human's idea, the human generates the images later with Codex-era context):** floor painting and props as separate layers so depth and collision come from each prop. Plan, prompts and acceptance in `docs/LAYERED_SCENE_PILOT.md`. Wait for the human's images in `art/reference/layered_pilot/`, then build the pipeline (extract props, ground conversion, props layer, colliders from data, tests). Pilot scene: the Stag glade. If it feels better than the painted approach, use it for new scenes and decide about redoing the village and forest.
4. **Chapter 1 step 2: NPCs and dialogue** (dialogue box, portraits, NPC sprites are approved art in `art/reference/chapter1_characters_v2`; the NPC sprites are already imported, portraits and the dialogue UI are not): data-driven dialogue files, the dialogue box renderer, Mira/Tovan/Edda lines for the story beats in `docs/CHAPTER1_PLAN.md`, an objective line, E interaction. Then steps 3-6 as listed above.
5. **Stag fight room (open decision for the human):** with the five standing stones solid and the pond/slabs gone, a radius-20 boss reaches 63.1 % of the central fight area at the glade's 0.7 scale (the old 80 % rule is NOT met; test guards are set to the measured 0.62). It cannot pass north of the back stone (its base is 30 px from the edge). Options: smaller stone bases, a smaller Stag (radius 14-16), or making a stone walkable/removing one. 5 of 16 straight charges from the middle leave the ring.

How the human works: they send reference images/paintings and approve art from review images before anything is wired; they stop long-running commands they cannot see progress for, so say what you are doing and keep test runs in the background; they decide every merge.

## Known gaps and open questions

- Balance numbers (weapons, aspects, barrage and coil damage) are first guesses; the human has not tuned them.
- The menu painting's source and licence are unconfirmed (credits say "supplied by the owner"); the repo is public.
- Boss AI can stick behind pillars; the Stag fight room in the glade depends on the layout decisions in STATUS.
- `docs/GAME_DESIGN.md` is the human's: propose changes, do not rewrite.
