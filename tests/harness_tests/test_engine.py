"""End-to-end tests of the run loop with stub agents in a throwaway git repo (no real agent is ever called)."""
from __future__ import annotations

import argparse
import copy
import json
import os
import shutil
import stat
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO))

from harness import router  # noqa: E402
from harness.lib import engine, gitutil, logbook, tasks  # noqa: E402
from harness.lib.config import load_config  # noqa: E402

STUB = str(Path(__file__).resolve().parent / "stub_agent.py")
PASS = json.dumps({"verdict": "pass", "comments": [], "cannot_judge": ["looks"]})
FAIL = json.dumps({"verdict": "fail", "comments": [{"file": "core/new.gd", "line": 1, "issue": "wrong", "severity": "high"}], "cannot_judge": []})
CHECK_NO_BAD = [sys.executable, "-c",
                "import sys, pathlib; bad = pathlib.Path(sys.argv[1], 'tests', 'bad.txt'); "
                "print('bad.txt is present, remove it') if bad.exists() else None; sys.exit(1 if bad.exists() else 0)", "{worktree}"]


def _force_remove(func, path, _exc):  # git object files are read-only on Windows
    os.chmod(path, stat.S_IWRITE)
    func(path)


def stub_agent() -> dict:
    return {
        "executable": sys.executable,
        "builder_args": [STUB, "--role", "builder", "--model", "{model}", "--output-file", "{output_file}"],
        "reviewer_args": [STUB, "--role", "reviewer", "--model", "{model}", "--output-file", "{output_file}"],
        "uses_output_file": False, "retry_on": [], "retry_attempts": 1,
    }


class EngineCase(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = Path(tempfile.mkdtemp(prefix="harness_test_"))
        self.repo = self.tmp / "repo"
        for folder in ("core", "presentation", "docs", "tests", "art"):
            (self.repo / folder).mkdir(parents=True)
            (self.repo / folder / "keep.txt").write_text("x\n", encoding="utf-8")
        for args in (["init", "-q", "-b", "main"], ["config", "user.email", "t@example.com"], ["config", "user.name", "test"],
                     ["add", "-A"], ["commit", "-q", "-m", "base"]):
            gitutil.git(args, self.repo)
        self.plan_path = self.tmp / "plan.json"
        os.environ["STUB_PLAN"] = str(self.plan_path)
        self.cfg = copy.deepcopy(load_config())
        self.cfg["worktrees_dir"] = str(self.tmp / "worktrees")
        self.cfg["agents"] = {"claude": stub_agent(), "codex": stub_agent()}
        self.cfg["checks"] = {"default": [], "godot": [CHECK_NO_BAD], "art": []}
        self.cfg["label_checks"] = {label: ["godot"] for label in self.cfg["rules"]}
        self.cfg["agent_timeout_seconds"] = 60
        self.log = self.repo / "harness" / "logs" / "runs.jsonl"
        self.said: list[str] = []

    def tearDown(self) -> None:
        os.environ.pop("STUB_PLAN", None)
        shutil.rmtree(self.tmp, onerror=_force_remove)

    def plan(self, builder: list[dict], reviewer: list[dict] | None = None) -> None:
        self.plan_path.write_text(json.dumps({"builder": builder, "reviewer": reviewer or [{"output": PASS}]}), encoding="utf-8")

    def run_task(self, text: str, label: str, tier: str | None = None) -> engine.RunOutcome:
        task = tasks.from_text(text)
        start = tier or self.cfg["rules"][label]["tier"]
        return engine.run_task(task, label, start, self.cfg, self.repo, self.log, None, self.said.append)

    def calls(self) -> list[dict]:
        path = Path(str(self.plan_path) + ".calls.jsonl")
        return [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines()] if path.exists() else []

    def builder_models(self) -> list[str]:
        return [c["model"] for c in self.calls() if c["role"] == "builder"]


class RunLoopTests(EngineCase):
    def test_a_clean_pass_commits_on_a_branch_and_never_merges(self) -> None:
        self.plan([{"write": {"core/new.gd": "extends RefCounted\n"}}])
        outcome = self.run_task("add a helper to the core", "logic")
        self.assertEqual(outcome.result, "pass")
        self.assertTrue(gitutil.branch_exists(self.repo, outcome.branch))
        self.assertTrue(outcome.branch.startswith("agent/logic/"))
        self.assertEqual(gitutil.git(["branch", "--show-current"], self.repo).strip(), "main")
        self.assertFalse((self.repo / "core" / "new.gd").exists(), "main checkout is untouched")
        self.assertTrue((Path(outcome.worktree) / "core" / "new.gd").exists())
        log = gitutil.git(["log", "--format=%B", "-1"], Path(outcome.worktree))
        self.assertIn("Harness-Run:", log)
        self.assertEqual(self.builder_models(), ["claude-sonnet-5-5"])
        runs = logbook.read_runs(self.log)
        self.assertEqual((len(runs), runs[0]["result"], runs[0]["rounds_used"]), (1, "pass", 1))

    def test_a_failed_check_escalates_to_the_next_tier(self) -> None:
        self.plan([{"write": {"tests/t.py": "x", "tests/bad.txt": "x"}}, {"delete": ["tests/bad.txt"]}])
        outcome = self.run_task("add a test file", "tests")
        self.assertEqual(outcome.result, "pass")
        self.assertEqual(self.builder_models(), ["gpt-6-luna", "gpt-6.1-sol"])  # light, then standard (codex ladder)
        self.assertEqual(outcome.rounds[0]["outcome"], "checks_failed")
        builder_calls = [c for c in self.calls() if c["role"] == "builder"]
        self.assertNotIn("FEEDBACK FROM THE PREVIOUS ROUND", builder_calls[0]["prompt"])
        self.assertIn("FEEDBACK FROM THE PREVIOUS ROUND", builder_calls[1]["prompt"])
        self.assertIn("bad.txt is present, remove it", builder_calls[1]["prompt"], "the check's own error text is fed back as it is")

    def test_the_prompt_names_the_owned_folders_and_the_rules(self) -> None:
        self.plan([{"write": {"core/a.gd": "1"}}])
        self.run_task("add a helper to the core", "logic")
        prompt = [c for c in self.calls() if c["role"] == "builder"][0]["prompt"]
        self.assertIn("core/, docs/", prompt)
        self.assertIn("Do NOT run `git commit`", prompt)
        self.assertIn("AGENTS.md", prompt)
        reviewer_prompt = [c for c in self.calls() if c["role"] == "reviewer"][0]["prompt"]
        self.assertIn("ONLY one JSON object", reviewer_prompt)
        self.assertIn("core/a.gd", reviewer_prompt, "the reviewer sees the diff")

    def test_an_ownership_violation_is_retried_on_the_same_tier(self) -> None:
        self.plan([{"write": {"presentation/oops.gd": "x"}}, {"delete": ["presentation/oops.gd"], "write": {"tests/ok.py": "x"}}])
        outcome = self.run_task("add a test", "tests")
        self.assertEqual(outcome.result, "pass")
        self.assertEqual(outcome.rounds[0]["outcome"], "ownership")
        self.assertEqual(self.builder_models(), ["gpt-6-luna", "gpt-6-luna"], "same tier: not a capability problem")

    def test_a_reviewer_fail_then_pass_escalates_one_tier(self) -> None:
        self.plan([{"write": {"core/a.gd": "1"}}, {"write": {"core/a.gd": "2"}}], [{"output": FAIL}, {"output": PASS}])
        outcome = self.run_task("add a helper", "logic")
        self.assertEqual(outcome.result, "pass")
        self.assertEqual(len(outcome.rounds), 2)
        self.assertEqual(self.builder_models(), ["claude-sonnet-5-5", "claude-opus-5-5"])

    def test_invalid_review_json_is_retried_once_then_counts_as_a_fail(self) -> None:
        self.plan([{"write": {"core/a.gd": "1"}}, {"write": {"core/a.gd": "2"}}],
                  [{"output": "looks fine"}, {"output": "really fine"}, {"output": PASS}])
        outcome = self.run_task("add a helper", "logic")
        self.assertEqual(outcome.rounds[0]["outcome"], "review_unparseable")
        self.assertEqual(outcome.result, "pass")
        self.assertEqual(len([c for c in self.calls() if c["role"] == "reviewer"]), 3)

    def test_exhausting_the_rounds_escalates_to_the_human_and_keeps_everything(self) -> None:
        self.plan([{"write": {"core/a.gd": "1"}}], [{"output": FAIL}])
        outcome = self.run_task("add a helper", "logic")
        self.assertEqual(outcome.result, "escalated")
        self.assertEqual(len(outcome.rounds), 3)
        self.assertTrue(gitutil.branch_exists(self.repo, outcome.branch))
        self.assertTrue(Path(outcome.worktree).exists())
        self.assertEqual(logbook.read_runs(self.log)[0]["result"], "escalated")
        self.assertTrue(any("ESCALATED" in line for line in self.said))

    def test_a_timeout_counts_as_a_failure_and_escalates(self) -> None:
        self.cfg["agent_timeout_seconds"] = 1
        self.plan([{"sleep": 20}, {"write": {"tests/t.py": "x"}}])
        outcome = self.run_task("add a test", "tests")
        self.assertEqual(outcome.rounds[0]["outcome"], "timeout")
        self.assertEqual(outcome.result, "pass")
        self.assertEqual(self.builder_models(), ["gpt-6-luna", "gpt-6.1-sol"])

    def test_no_changes_is_a_failed_round(self) -> None:
        self.plan([{"print": "I did nothing"}, {"write": {"tests/t.py": "x"}}])
        outcome = self.run_task("add a test", "tests")
        self.assertEqual(outcome.rounds[0]["outcome"], "no_changes")
        self.assertEqual(outcome.result, "pass")

    def test_the_daily_heavy_cap_stops_instead_of_downgrading(self) -> None:
        self.cfg["max_heavy_runs_per_day"] = 0
        self.plan([{"write": {"core/a.gd": "1"}}])
        outcome = self.run_task("add a helper", "logic", tier="heavy")
        self.assertEqual(outcome.result, "escalated")
        self.assertIn("daily cap", outcome.message)
        self.assertEqual(self.calls(), [], "no agent was run")

    def test_a_sandbox_that_cannot_start_is_not_escalated_to_a_bigger_model(self) -> None:
        self.cfg["agents"]["codex"]["retry_on"] = ["helper_unknown_error"]
        self.cfg["agents"]["codex"]["retry_attempts"] = 2
        self.plan([{"print": "Failed to create unified exec process: helper_unknown_error: setup refresh had errors"}])
        outcome = self.run_task("add a test", "tests")
        self.assertEqual(outcome.result, "escalated")
        self.assertEqual([r["outcome"] for r in outcome.rounds], ["sandbox_failed"] * 3)
        self.assertEqual(self.builder_models(), ["gpt-6-luna"] * 6, "same light model every round (2 attempts each): an environment problem")
        self.assertIn("sandbox", outcome.message)
        self.assertIn("close the Codex desktop app", outcome.message)

    def test_check_names_in_the_log_are_readable(self) -> None:
        self.plan([{"write": {"tests/t.py": "x"}}])
        outcome = self.run_task("add a test", "tests")
        names = list(outcome.rounds[0]["checks"])
        self.assertEqual(names, ["godot: -c"])

    def test_worktrees_are_not_nested_when_the_harness_runs_from_a_worktree(self) -> None:
        linked = self.tmp / "linked"
        gitutil.git(["worktree", "add", "-b", "linked-branch", str(linked)], self.repo)
        self.assertEqual(gitutil.main_repo_root(linked), self.repo.resolve())
        self.assertEqual(gitutil.main_repo_root(self.repo), self.repo.resolve())
        self.cfg["worktrees_dir"] = "../task_worktrees"  # relative, like the shipped config
        self.plan([{"write": {"tests/t.py": "x"}}])
        task = tasks.from_text("add a test")
        outcome = engine.run_task(task, "tests", "light", self.cfg, linked, self.log, None, self.said.append)
        self.assertEqual(outcome.result, "pass")
        self.assertEqual(Path(outcome.worktree).parent, (self.repo.parent / "task_worktrees").resolve(),
                         "next to the main checkout, not inside the linked worktree's parent twice")

    def test_cleanup_removes_a_finished_worktree_but_keeps_the_branch(self) -> None:
        self.plan([{"write": {"core/new.gd": "x"}}])
        outcome = self.run_task("add a helper", "logic")
        self.assertTrue(Path(outcome.worktree).exists())
        code = router.cmd_cleanup(argparse.Namespace(yes=True), self.cfg, self.repo)
        self.assertEqual(code, 0)
        self.assertFalse(Path(outcome.worktree).exists())
        self.assertTrue(gitutil.branch_exists(self.repo, outcome.branch), "the branch is never deleted")


class RouterCliTests(unittest.TestCase):
    def run_cli(self, *args: str) -> subprocess.CompletedProcess:
        return subprocess.run([sys.executable, str(REPO / "harness" / "router.py"), *args], capture_output=True, text=True,
                              encoding="utf-8", cwd=str(REPO))

    def test_dry_run_prints_the_plan_and_changes_nothing(self) -> None:
        before = gitutil.git(["branch", "--list"], REPO)
        result = self.run_cli("run", "make three grass tile variants", "--dry-run")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        for expected in ("label:     tile", "builder:   codex", "gpt-6-luna", "dry run"):
            self.assertIn(expected, result.stdout)
        self.assertEqual(gitutil.git(["branch", "--list"], REPO), before)

    def test_human_labels_run_no_agent(self) -> None:
        result = self.run_cli("run", "tune the boss", "--label", "balance")
        self.assertEqual(result.returncode, router.EXIT_HUMAN)
        self.assertIn("human decides", result.stdout)

    def test_an_unclear_task_asks_for_a_label(self) -> None:
        result = self.run_cli("run", "do something nice", "--dry-run")
        self.assertEqual(result.returncode, router.EXIT_USAGE)
        self.assertIn("--label", result.stderr)


if __name__ == "__main__":
    unittest.main()
