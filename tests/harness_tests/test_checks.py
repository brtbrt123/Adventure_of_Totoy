"""Unit tests for the shared helpers of the check scripts in harness/checks/ (no Godot run)."""
from __future__ import annotations

import importlib.util
import os
import sys
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
CHECKS = REPO / "harness" / "checks"


def _load_common():
    spec = importlib.util.spec_from_file_location("harness_checks_common", CHECKS / "_common.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


common = _load_common()


class RunLimitedTests(unittest.TestCase):
    def test_returns_the_exit_code_and_the_output(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            code, out = common.run_limited([sys.executable, "-c", "print('hello'); raise SystemExit(3)"], Path(tmp), 30)
        self.assertEqual(code, 3)
        self.assertIn("hello", out)

    def test_a_timeout_kills_the_process_and_says_so(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            code, out = common.run_limited([sys.executable, "-c", "import time; time.sleep(30)"], Path(tmp), 1)
        self.assertEqual(code, -1)
        self.assertIn("TIMEOUT", out)


class GodotPathTests(unittest.TestCase):
    def test_the_environment_variable_wins(self) -> None:
        old = os.environ.get("HARNESS_GODOT")
        os.environ["HARNESS_GODOT"] = "C:/elsewhere/godot.exe"
        try:
            self.assertEqual(common.godot_path(), "C:/elsewhere/godot.exe")
        finally:
            if old is None:
                os.environ.pop("HARNESS_GODOT", None)
            else:
                os.environ["HARNESS_GODOT"] = old

    def test_the_default_is_the_installed_console_build(self) -> None:
        old = os.environ.pop("HARNESS_GODOT", None)
        try:
            self.assertTrue(common.godot_path().endswith("Godot_v4.7.2-stable_win64_console.exe"))
        finally:
            if old is not None:
                os.environ["HARNESS_GODOT"] = old


class ScriptsTests(unittest.TestCase):
    def test_the_check_scripts_exist_and_no_dispatch_code_is_left(self) -> None:
        for name in ("run_tests.py", "validate_art.py", "build_art.py", "_common.py"):
            self.assertTrue((CHECKS / name).exists(), name)
        self.assertFalse((REPO / "harness" / "router.py").exists())
        self.assertFalse((REPO / "harness" / "lib").exists())


if __name__ == "__main__":
    unittest.main()
