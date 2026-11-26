# Harness: the checks

`harness/checks/` holds the scripts that check a piece of work. Each exits 0 on success and non-zero on failure, and prints plain-text errors. Run them from the project root.

```powershell
python harness/checks/run_tests.py --worktree . --timeout 400   # the full test run: several minutes, run it in the background
python harness/checks/validate_art.py --worktree .              # the art validator
python harness/checks/build_art.py --worktree .                 # build + validate + contact sheet
```

- `run_tests.py`: Python tests (`python -m unittest discover -s tests`), Godot import, `tests/run_tests.gd` (the core tests), then every `tests/smoke_*.gd` except the capture scripts that need a window. Each Godot run has a hard time limit; on a timeout the whole process tree is killed. Godot runs use a throwaway save (`TOTOY_SAVE_PATH=user://harness_check_save.json`), never the owner's save.
- The Godot executable is the installed console build (`C:\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe`, in `_common.py`); set `HARNESS_GODOT` to use another one.
- `tests/harness_tests/test_checks.py` tests the shared helpers (time limit, Godot path).

Which checks fit which change:

| Change | Run |
|---|---|
| art (`art/src`, generators) | validate, build, preview (CLAUDE.md section 5), Godot import, then the full run |
| core rules, interface, save | the core tests, then the full run |
| presentation, UI, effects | the related smokes, a real capture for the owner, then the full run |
| docs only | nothing |

## History

From 2026-10-16 to 2026-11-26 the harness also had a router, a runner and a review loop that sent each task to one of two AI agents (Claude Code or Codex) by label, checked folder ownership and had the other agent review the diff. It was removed on 2026-11-26 when Claude started working on the project alone; the code is in git history before that date (`harness/router.py`, `harness/lib/`, `harness/config.json`, `docs/ROUTING.md`). The original plan is in `PROJECT_BRIEF.md` (Appendices B, C and F).

## Knowledge tools

- **Obsidian:** `docs/` is the vault (home: [[INDEX]]). Plain markdown; machine-specific Obsidian settings are not committed.
- **Graphify:** installed; `python -m graphify update .` builds `graphify-out/` (gitignored). It covers `tools/`, `harness/` and the docs, not GDScript or art. See the graphify section of `CLAUDE.md`.
