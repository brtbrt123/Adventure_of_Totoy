# 0003: plain headless test runner, preload instead of class_name in core/

Date: 2026-10-15 · Status: accepted by default (the human did not object), may be overruled

- **Test framework:** a ~40-line runner (`tests/run_tests.gd`) plus a small base class (`tests/test_case.gd`). No addon, so no third-party code and no Godot-version compatibility question (GUT and GdUnit4 were not checked against 4.7.2). Revisit if the suite needs mocking, parameterized tests or reports.
- **Checked that the tests can fail:** temporarily removing the perfect-parry window and the dash i-frames made the matching tests fail; the constants were restored.
- **`core/` references scripts with `preload` constants, not `class_name`.** `class_name` needs the editor's global class cache, which does not exist in a fresh clone running `--headless --script`; preloads always resolve. Presentation may use the same pattern.
- **Events are `GameEvent` objects with a `data` dictionary**, not one typed class per event. It keeps the interface small while it is still changing; the payload keys are documented in `docs/architecture.md`.
- **All balance numbers live in `core/tuning.gd`** so the human can tune feel in one file.
