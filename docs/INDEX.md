# Adventure of Totoy: vault index

Open the `docs/` folder as a vault in Obsidian. Start here; every note links onward. A new Claude session reads [[HANDOFF]] first.

## Start here
- [[HANDOFF]]: where we are, what is next, how the human works
- [[STATUS]]: the detailed log, newest first (trust `git log` over "NOT committed" labels)
- [[CHAPTER1_PLAN]]: what chapter 1 is and the six build steps

## The game and the rules
- [[GAME_DESIGN]]: the human's design (do not rewrite)
- [[architecture]]: the core/presentation interface, including "Layered scenes"
- [[HARNESS]]: the checks (the full test run, the art checks) and which to run for which change
- Decisions: [[0001-stage1-setup-choices]], [[0002-totoy36-palette]], [[0003-core-test-runner-and-preload]], [[0004-sharp-ui-text]], [[0005-384x216-fantasy-ui]]
- The working rules live in `CLAUDE.md` at the project root (not in the vault)

## Shared presentation
- [[ANIMATION_EDITING]]: edit every character animation in Godot (SpriteFrames in presentation/animations), repaint frames (art/overrides), the animation galleries
- [[WEAPON_PATHS]]: the blades' basic slash, drawn from the swing's hit area (reach and arc) and turned with the hero
- [[MOBILE_BLUEPRINT]]: proposal for a phone version (touch layout, HUD moved up, screen sizes, open questions)
- [[TAB_MENU]]: the TAB menu (HERO, GEAR, QUESTS): layout, scenes, controller, generator, rules, tests
- [[EFFECTS_REDO]]: the staff-style effects redo: every layer and its file, the generators, the captures, the image-generator accounts
- Project skills (`.claude/skills/`): totoy-art-pipeline, totoy-review-capture, totoy-session-close: the exact steps for art, captures and closing a session

## Work in progress
- [[CLAUDE_TASK_village_playtest_polish]]: roomier training yard, Tovan first sword/unarmed state and reward event (done; kept as the record)
- [[CLAUDE_TASK_explore_hud_values]]: open: Edge and Aspect timers in the road snapshot for the road HUD
- [[WARDEN_INTEGRATION]]: the Runebound Warden: look rules, the core interface presentation reads, effects, sounds and how the art got here
- [[GODOT_EDITABLE_PLAN]]: making props, maps, animations and effects editable in Godot; phase 1 renderer wiring still to do
- [[PLAN_hollow_trial]], [[PROGRESSION_PLAN]]: the Hollow Trial and the village progression plans
- [[LAYERED_SCENE_PILOT]]: floor painting plus separate props; prompts for the images
- [[LAYERED_VILLAGE_FOREST]]: redoing the village and forest as layered scenes (prompts, steps)
- [[FINAL_SCENE_chapter1]]: the chapter's final scene and boss (plan v2 with the owner's decisions): Rootcrown v2 (debug key Y, 2026-11-26) is built from the other forest scenes' own art at about the old arena's size, after the first build was rejected; next the redesigned Colossus
- [[STORY_ROAD_chapter1]]: draft story for the road from Lanternfen to the Stag Glade (follow the blue light); to be revised after the final-scene plan

## Art references
- [[ART_PROMPTS_GEMINI]], [[GEMINI_PROMPT_PACK]]
- Review images are in `previews/`

## Keeping this useful
- When you finish a piece of work, update [[STATUS]] and [[HANDOFF]], and add the new note here.
- Plain markdown only. Do not commit `.obsidian/` (it is ignored).
