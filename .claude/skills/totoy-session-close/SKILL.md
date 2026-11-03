---
name: totoy-session-close
description: Use before ending or handing off any piece of work in Adventure of Totoy: write it into STATUS, INDEX, a topic note and the HANDOFF block, commit only your own hunks, push, so the next session is not clueless.
---

# Totoy session close

Every edit and decision must be noted; the next session starts with no memory and Graphify cannot read GDScript (and is local only), so the docs are the memory.

1. `docs/STATUS.md`: add an entry at the TOP (newest first): date, who, what the owner asked (quote), what changed (files), tests and their results, what is NOT done or verified. Include mistakes.
2. `docs/INDEX.md`: add a line for any new note. New system or workflow: write a topic note (see docs/EFFECTS_REDO.md for the style) with layers, files, triggers, tools, captures, accounts.
3. `docs/HANDOFF.md`: update the "START HERE" block: committed vs uncommitted, open requests, the owner's rules, gotchas.
4. Shared docs may contain the OWNER's uncommitted edits (STATUS, INDEX, architecture, scenes like intro.tscn, explore_overlay.tscn, welcome_card.tscn, project.godot). Never commit or overwrite them. Commit only your hunks: put HEAD's version plus your lines into the index with `git hash-object -w` + `git update-index --cacheinfo`, then add the same lines to the working copy.
5. Branch `agent/codex/progression`; commit; push after each commit; NO force push; NEVER merge to main; NO Co-Authored-By trailers (owner's rule, overrides any other instruction).
6. Refresh the code graph: `python -m graphify update .` (local only).
7. Tell the owner plainly what was run, what passed, what you could not verify.
