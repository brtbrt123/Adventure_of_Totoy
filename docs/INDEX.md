# Adventure of Totoy: vault index

Open the `docs/` folder as a vault in Obsidian. Start here; every note links onward. Agents: read [[HANDOFF]] first.

## Start here
- [[HANDOFF]]: where we are, what is next, how the human works
- [[STATUS]]: the detailed log, newest first (trust `git log` over "NOT committed" labels)
- [[CHAPTER1_PLAN]]: what chapter 1 is and the six build steps

## The game and the rules
- [[GAME_DESIGN]]: the human's design (do not rewrite)
- [[architecture]]: the core/presentation interface, including "Layered scenes"
- [[ROUTING]] and [[HARNESS]]: who builds what, checks and the review loop
- Decisions: [[0001-stage1-setup-choices]], [[0002-totoy36-palette]], [[0003-core-test-runner-and-preload]], [[0004-sharp-ui-text]], [[0005-384x216-fantasy-ui]]
- The rules for agents live in `AGENTS.md` at the project root (not in the vault)

## Work in progress
- [[CLAUDE_TASK_village_playtest_polish]]: roomier training yard, Tovan first sword/unarmed state and reward event; Codex presentation ready
- [[LAYERED_SCENE_PILOT]]: floor painting plus separate props; prompts for the images
- [[CODEX_TASK_layered_pilot]]: Codex's side of the pilot
- [[LAYERED_VILLAGE_FOREST]]: redoing the village and forest as layered scenes (prompts, who does what)

## Art references
- [[ART_PROMPTS_GEMINI]], [[GEMINI_PROMPT_PACK]]
- Review images are in `previews/`

## Keeping this useful
- When you finish a piece of work, update [[STATUS]] and [[HANDOFF]], and add the new note here.
- Plain markdown only. Do not commit `.obsidian/` (it is ignored).
