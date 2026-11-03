# HANDOFF: Adventure of Totoy (current checkpoint 2026-11-02)

> **START HERE for the next session (Claude, 2026-11-03).** We are debugging the game from the first scene: the owner reports visual errors, Claude fixes functional bugs and shows a picture before changing how anything looks.
>
> **Done and committed on `agent/codex/progression` (never merge to `main`):** the village cleanup of 2026-11-03, see the top of [[STATUS]]. The hero no longer auto-walks after the intro; Edda's hut has no knock; the village standing stone glows blue (the village scene now uses per-light colours); the gate, walls and fence were tried and removed from the village scene (the owner did not like them). The wall and fence art/types stay in the project unused (`tools/art/make_village_walls.py`, Higgsfield cut-outs in `art/reference/village_wall_fence_v1/`).
> - Open: the objective still reads "Speak to Mira by the gate." (owner said leave it). A boot icon, dagger and dark capsules once seen in the village were fixed by the owner themselves; the cause was never found.
> - The effects redo in the Star Staff's style (phases 1-4), the mobile blueprint (`docs/MOBILE_BLUEPRINT.md`), the white-haze fix and the real-input playthrough (`presentation/review/playthrough/capture_start.gd`) are from 2026-11-02 and in STATUS.
>
> **Working rules this owner holds:**
> - The owner points out visual problems; Claude chases functional bugs (console errors, broken flow).
> - Show the owner a picture before changing how something looks.
> - Never touch the owner's uncommitted scenes: `intro.tscn`, `dialogue_box.tscn`, `explore_overlay.tscn`, `aspect_socket.tscn`, `scene_ribbon.tscn`, `welcome_card.tscn`, `result_panel.tscn`, plus `project.godot`. Ask before committing them.
> - Commit only your own hunks of shared docs (STATUS, INDEX).
> - No Co-Authored-By lines. Push after each commit.
>
> **Gotchas:**
> - The Godot editor is often open. It locks `art/build` files (Errno 22: retry), and it deletes and recreates `art/build/contact_sheet_*.png.import`. Restore those with `git checkout HEAD --`.
> - `tools/godot/generate_prop_scenes.py` also reformats the `presentation/props/hollow_trial_*.tscn` scenes. Restore those after running it.
> - Three smokes only pass with a window: `smoke_capture_hero`, `smoke_gemini_capture`, `smoke_hero_capture`.
> - A village light colour is only used when the scene is in the `mixed_lights` list in `presentation/common/environment_light.gd`.
> - Image generation: Higgsfield (`nano_banana_2_1`, 1.5 credits per image, about 25 left); SpriteCook is on the free tier with 1 credit.

> **START HERE for the new Codex chat (2026-10-31):** read [[WARDEN_INTEGRATION]] and [[CODEX_NEXT_SESSION_warden]]. Owner authorized wiring after requesting a 2.5x body. Warden now has60 installed enlarged poses,75 attached FX, actual-core-geometry floor effects and13 recorded sound cues. Runtime review media is in `presentation/review/warden/`. See the integration note for final test status. Claude cross-review remains pending because its OAuth session expired. Trial room/waves/rewards remain separate. Branch `agent/codex/progression`; preserve the dirty worktree and never merge main.

> **Thornback / Glowmoth update (2026-10-31):** Claude has finished the core mechanics, real orb projectile and presentation/particle follow-ups. Older "core still needs" entries are obsolete. Read [[CROSS_REVIEW_thornback_v3]] and newest STATUS. Most recent healing polish is `13ba25a4`: fewer motes, placed beside the Stag, once-per-second pulse and smaller glow. Preserve it when touching shared creature FX.

> **Mob idles (2026-10-30):** approved Mossling hopping and Boar grazing are installed globally in mob_view.gd, with60 new sprites. Idle selection uses simulation tick (dormant state_ticks stays zero),6 ticks/frame and per-mob phase; alert/combat unchanged. Full harness passes; live GIF and rebuild instructions in art/reference/mob_idle_review_v1/.

> **Root Hollow (2026-10-30):** Claude registered live colliders/placements/gate in ad118e0f; Codex finished Root Hollow-only exposure, teal pools and nearest-practical projected cast shadows. Ancient/root-wall canopy y-sort is preserved. Live gate/depth/route/warning captures and PASS cross-review: presentation/review/root_hollow_final/REVIEW.md. Full harness passes. Local shadows use a soft parallel-ray mask approximation, not physical volumetric occlusion; owner judges appearance.

> **Basic attack slash (2026-11-02):** the blades' slash is drawn from the swing's hit area (reach and arc from core/weapons.gd, turned to the hero's facing) by `presentation/common/swing_arc.gd`, through the shared `hero_fx.gd` base in both arena and exploration. Future hero renderers must call `draw_hero_back`; see [[WEAPON_PATHS]]. It replaced the pose-traced trail frames of 2026-10-29.

> **UI update (2026-10-29):** owner approved switching the base view to 384x216 and installing the SpriteCook bronze/teal kit with existing game icons. See decision [[0005-384x216-fantasy-ui]], newest STATUS and live captures in `presentation/review/ui_kit_live/`.

> **Current owner direction (2026-10-27): the clean glade arch/bush/path layout is APPROVED ("yes thats good"). See [CODEX_NEXT_SESSION.md](CODEX_NEXT_SESSION.md) and newest STATUS. Preserve the uncommitted CHAPTER1_PLAN.md edit. Older forest/redo task lists below are historical.**

> **Latest Codex work (2026-10-27): village tutorial + prerequisite dialogue presentation implemented; review captures in `art/reference/tutorial_review_v1/`. See newest STATUS for verification and the P2 core snapshot combo finding for Claude. Glade arch remains approved.**

> **Village playtest follow-up:** owner chose Claude for core changes. See [CLAUDE_TASK_village_playtest_polish.md](CLAUDE_TASK_village_playtest_polish.md): proposed roomier yard, Tovan first-sword grant, unarmed state, real reward event, combo snapshot fix. Codex has live practice VFX/audio/music; receipt card and unarmed/yard assets are review/integration fixtures. Compact training cards are approved. See newest STATUS.**

Read this first, then `AGENTS.md` (the rules), then `docs/CHAPTER1_PLAN.md` (what we are building) and `docs/STATUS.md` (the detailed log, newest section first; entries labelled "NOT committed" may be older than the git history: trust `git log`).

## What this project is

A 2D top-down pixel-art action game in **Godot 4.7.2** (typed GDScript), 384x216 base resolution, private Windows build and portfolio piece. Design: `docs/GAME_DESIGN.md` (the human's document, do not rewrite it). Combat language: **gold heavy attacks can be parried, red attacks must be dodged**. Currently playable: a walkable Chapter 1 slice (village Lanternfen, forest route, Stag glade) and the **Mossbound Colossus** arena fight, with three weapons and eight aspects.

## Rules of the road (from the human)

- The human owns design, art approval, playtesting and **every merge to `main`** (they merge through a GitHub pull request). Never merge to `main` yourself.
- **Work split (the human confirmed 2026-10-22):** while Codex was out of usage Claude also edited `presentation/` and `art/` (a temporary override). **From the week of 2026-10-26, when both limits reset, go back to the normal split in `AGENTS.md`:** Claude Code owns `core/`, `tools/`, `harness/`, `docs/architecture.md`; Codex owns `presentation/`, `art/` (sprites, tiles, UI, effects, shaders) and extra tests; the human approves art and merges; each side reviews the other's diffs (pass/fail with file, line, severity, and what it cannot judge). If one side's task needs a change in the other's folder, describe it in the task notes instead of editing. Suggested split for the next work:
  - **Step 2 NPCs and dialogue:** Claude = dialogue data model and story flags (core), objective/quest state, save fields, tests; Codex = dialogue box renderer, portraits import, NPC interaction UI, typewriter text, sounds.
  - **Layered-scene pilot:** Claude = `tools/art` extraction/conversion scripts, prop data format shared by core and presentation, colliders-from-data in `core/*_layout.gd`, tests; Codex = prop sprites in `art/src`, `props_layer` rendering and depth sorting in presentation, shadows/tints, review captures.
  - **Occluder/collision cleanup:** Claude = collider data and layout tests; Codex = occluder art and drawing.
  - Codex starts without memory: it reads `AGENTS.md`, this file, `docs/CHAPTER1_PLAN.md`, `docs/STATUS.md`, `docs/architecture.md`.
- **Plain commit messages: NO Co-Authored-By / Claude attribution lines** (the human does not want "claude" as a GitHub contributor; history was rewritten once to strip them).
- Current work branch: `agent/codex/progression` (older branches named elsewhere below are historical). After every commit, push it to `origin` (https://github.com/brtbrt123/Adventure_of_Totoy, public). No force-push or history rewrite without asking.
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

Start with `git status` and `git log`. Open items from the last session (check the top entries of `docs/STATUS.md` for what the last agents finished and what they flagged as NOT done):

1. **State at the end of the last session (2026-10-22): everything was committed and pushed on `agent/game/chapter1-dev` with all tests green** (commit `0672a20`: 60 depth occluders, the soft shared actor shadow, solid stones/doors/gate, the glade pond and slabs REMOVED from the ground art by the human's decision, alternate debug keys 1-4, G, H, the HANDOFF and LAYERED_SCENE_PILOT docs). Check `git status` to be sure, run `python harness/checks/run_tests.py --worktree .` (several minutes, in the background) and ask the human to merge to `main` through a pull request (their contribution graph only counts `main`).
2. **Occluder quality (PARTLY DONE; human feedback: cut-outs include flat floor pixels that draw over the hero):** `tools/art/make_depth_occluders.py` now cleans occluders automatically and `tools/art/preview_occluder_footprints.py` writes before/after images (`docs/previews/occluder_footprints_<scene>.png`, occluder pixels in magenta). Cleaned and checked: the five glade stones, forest signpost, lantern post, both pedestals, east mossy rock, all 14 arena occluders. NOT cleaned (hand shapes only, cleanup switched off): all 27 VILLAGE occluders (dark props share the floor colours, the cleanup erased trunks, dummy, barrels and gate pillars; the old 3 px edge trim was dropped so the village cut-outs hold slightly MORE floor than before), the forest root-gate pieces and mossy stone, the glade root arch. To continue: draw finer hand shapes for the village props the hero walks behind (gate pillars, dummy, barrels, stump, pile, both trees, shrine) or give the cleanup a per-occluder list of colours that are never floor; verify with the footprint images and `tests/capture_depth_review.gd`; run Godot's import after every rebuild. The layered-scene pilot (item 3) may make most of this obsolete for new scenes.
3. **Layered-scene pilot (human's idea, the human generates the images later with Codex-era context):** floor painting and props as separate layers so depth and collision come from each prop. Plan, prompts and acceptance in `docs/LAYERED_SCENE_PILOT.md`. Wait for the human's images in `art/reference/layered_pilot/`, then build the pipeline (extract props, ground conversion, props layer, colliders from data, tests). Pilot scene: the Stag glade. If it feels better than the painted approach, use it for new scenes and decide about redoing the village and forest.
4. **Chapter 1 step 2: NPCs and dialogue** (dialogue box, portraits, NPC sprites are approved art in `art/reference/chapter1_characters_v2`; the NPC sprites are already imported, portraits and the dialogue UI are not): data-driven dialogue files, the dialogue box renderer, Mira/Tovan/Edda lines for the story beats in `docs/CHAPTER1_PLAN.md`, an objective line, E interaction. Then steps 3-6 as listed above.
5. **Stag fight room (open decision for the human):** with the five standing stones solid and the pond/slabs gone, a radius-20 boss reaches 63.1 % of the central fight area at the glade's 0.7 scale (the old 80 % rule is NOT met; test guards are set to the measured 0.62). It cannot pass north of the back stone (its base is 30 px from the edge). Options: smaller stone bases, a smaller Stag (radius 14-16), or making a stone walkable/removing one. 5 of 16 straight charges from the middle leave the ring.

How the human works: they send reference images/paintings and approve art from review images before anything is wired; they stop long-running commands they cannot see progress for, so say what you are doing and keep test runs in the background; they decide every merge.

## Known gaps and open questions

- Balance numbers (weapons, aspects, barrage and coil damage) are first guesses; the human has not tuned them.
- The menu painting's source and licence are unconfirmed (credits say "supplied by the owner"); the repo is public.
- Boss AI can stick behind pillars; the Stag fight room in the glade depends on the layout decisions in STATUS.
- `docs/GAME_DESIGN.md` is the human's: propose changes, do not rewrite.
