# harness/

The project's check scripts. Each exits 0 on success and non-zero on failure, with plain-text errors. See `docs/HARNESS.md`.

- `checks/run_tests.py`: the full test run (Python tests, Godot import, `tests/run_tests.gd`, every headless `tests/smoke_*.gd`).
- `checks/validate_art.py`: the art validator.
- `checks/build_art.py`: build, validate and the contact sheet.
- `checks/_common.py`: the time-limited runner and the Godot path (`HARNESS_GODOT` overrides it).
