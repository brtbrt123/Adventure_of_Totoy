"""Unit tests for the harness routing logic: labels, tiers, ownership, review parsing, logs, tasks, safety."""
from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO))

from harness.lib import labels, logbook, ownership, review, runner, tasks, tiers  # noqa: E402
from harness.lib.config import load_config  # noqa: E402

CFG = load_config()


class LabelTests(unittest.TestCase):
    def test_explicit_label_always_wins(self) -> None:
        choice = labels.pick_label("make three grass tile variants", "logic", CFG)
        self.assertEqual((choice.label, choice.source), ("logic", "explicit"))

    def test_keywords_pick_the_label(self) -> None:
        self.assertEqual(labels.pick_label("redraw the grass tile variants", None, CFG).label, "tile")
        self.assertEqual(labels.pick_label("add a hud health bar", None, CFG).label, "hud")
        self.assertEqual(labels.pick_label("write a shader that ripples", None, CFG).label, "shader")

    def test_path_hints_add_weight(self) -> None:
        # the keyword picks refactor; the core/ hint adds weight to it (and to its core-owned siblings only slightly)
        choice = labels.pick_label("refactor the code in core/", None, CFG)
        self.assertEqual(choice.label, "refactor")
        self.assertGreater(choice.scores["refactor"], choice.scores["logic"])

    def test_a_path_alone_cannot_pick_between_sibling_labels(self) -> None:
        with self.assertRaises(labels.LabelError):
            labels.pick_label("change core/ so the boss waits longer", None, CFG)

    def test_nothing_matched_asks_the_human(self) -> None:
        with self.assertRaises(labels.LabelError):
            labels.pick_label("do something nice", None, CFG)

    def test_ties_ask_the_human(self) -> None:
        with self.assertRaises(labels.LabelError):
            labels.pick_label("shader menu", None, CFG)

    def test_unknown_explicit_label_is_refused(self) -> None:
        with self.assertRaises(labels.LabelError):
            labels.pick_label("anything", "not-a-label", CFG)

    def test_bugfix_is_resolved_by_path_or_refused(self) -> None:
        self.assertEqual(labels.pick_label("fix the crash in core/boss.gd", None, CFG).label, "bugfix-core")
        self.assertEqual(labels.pick_label("fix the glitch in presentation/arena/hud.gd", "bugfix", CFG).label, "bugfix-presentation")
        # without an explicit label, a bug in a HUD file routes as hud (same builder, reviewer and folders)
        self.assertEqual(labels.pick_label("fix the glitch in presentation/arena/hud.gd", None, CFG).label, "hud")
        with self.assertRaises(labels.LabelError):
            labels.pick_label("fix the bug", "bugfix", CFG)

    def test_every_rule_has_checks_and_models(self) -> None:
        for label, rule in CFG["rules"].items():
            self.assertIn(label, CFG["label_checks"], label)
            if rule["builder"] != "human":
                for tier in CFG["tiers"]:
                    self.assertTrue(tiers.model_for(rule["builder"], tier, CFG))


class TierTests(unittest.TestCase):
    def test_default_start_tier_comes_from_the_label(self) -> None:
        self.assertEqual(tiers.start_tier("tile", "one grass tile", None, CFG), "light")
        self.assertEqual(tiers.start_tier("logic", "add a timer", None, CFG), "standard")
        self.assertEqual(tiers.start_tier("arch", "new interface", None, CFG), "heavy")

    def test_risky_words_bump_one_tier_and_explicit_wins(self) -> None:
        self.assertEqual(tiers.start_tier("tile", "tile for the boss arena", None, CFG), "standard")
        self.assertEqual(tiers.start_tier("tile", "tile for the boss arena", "light", CFG), "light")
        with self.assertRaises(tiers.TierError):
            tiers.start_tier("tile", "x", "ultra", CFG)

    def test_escalation_moves_up_and_stops_at_the_top(self) -> None:
        self.assertEqual(tiers.next_tier("light", CFG), "standard")
        self.assertEqual(tiers.next_tier("standard", CFG), "heavy")
        self.assertEqual(tiers.next_tier("heavy", CFG), "heavy")

    def test_ladder_models(self) -> None:
        ladder = tiers.ladder("codex", "light", 3, CFG)
        self.assertEqual([t for t, _ in ladder], ["light", "standard", "heavy"])
        self.assertEqual([m for _, m in ladder], ["gpt-6-luna", "gpt-6.1-sol", "gpt-6-astra"])

    def test_logic_reviews_are_heavy(self) -> None:
        self.assertEqual(tiers.review_tier("logic", CFG), "heavy")
        self.assertEqual(tiers.review_tier("tile", CFG), "standard")


class OwnershipTests(unittest.TestCase):
    def test_inside_outside_and_generated(self) -> None:
        changed = ["core/boss.gd", "docs/STATUS.md", "presentation/arena/hud.gd", "core/boss.gd.uid", "art/build/sprites.png"]
        bad = ownership.owned_violations(changed, ["core/", "docs/"], CFG["always_allowed"])
        self.assertEqual(bad, ["presentation/arena/hud.gd"])

    def test_windows_paths_and_dotfiles(self) -> None:
        self.assertEqual(ownership.owned_violations(["core\\player.gd"], ["core/"]), [])
        self.assertEqual(ownership.owned_violations([".gitignore"], ["core/"]), [".gitignore"])

    def test_prefix_is_a_folder_not_a_substring(self) -> None:
        self.assertEqual(ownership.owned_violations(["core_extra/x.gd"], ["core/"]), ["core_extra/x.gd"])


class ReviewTests(unittest.TestCase):
    def test_parses_json_inside_fences_and_prose(self) -> None:
        text = 'Here you go:\n```json\n{"verdict": "pass", "comments": [], "cannot_judge": ["looks"]}\n```\nthanks'
        parsed = review.parse_review(text)
        self.assertEqual(parsed["verdict"], "pass")
        self.assertEqual(parsed["cannot_judge"], ["looks"])

    def test_invalid_output_is_none(self) -> None:
        self.assertIsNone(review.parse_review("looks good to me"))
        self.assertIsNone(review.parse_review('{"verdict": "maybe"}'))
        self.assertIsNone(review.parse_review('{"verdict": "pass", "comments": "no"}'))

    def test_last_object_wins(self) -> None:
        text = '{"verdict": "fail", "comments": []} then {"verdict": "pass", "comments": []}'
        self.assertEqual(review.parse_review(text)["verdict"], "pass")

    def test_comments_are_formatted_for_the_builder(self) -> None:
        review_data = {"verdict": "fail", "comments": [{"file": "core/x.gd", "line": 3, "issue": "bad math", "severity": "high"}]}
        self.assertIn("core/x.gd:3 bad math", review.format_comments(review_data))


class LogAndTaskTests(unittest.TestCase):
    def test_log_round_trip_and_heavy_count(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "logs" / "runs.jsonl"
            logbook.append_run(path, {"run_id": "a", "rounds": [{"tier": "light"}, {"tier": "heavy"}, {"tier": "heavy"}]})
            logbook.append_run(path, {"run_id": "b", "rounds": [{"tier": "standard"}]})
            self.assertEqual(len(logbook.read_runs(path)), 2)
            self.assertEqual(logbook.heavy_rounds_today(path), 2)

    def test_task_file_parsing(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "001-grass.md"
            path.write_text("# Three grass tiles\nlabel: tile\ntier: light\n\nMake them calm.\n\n## Acceptance\n- [ ] validator passes\n- [x] three files\n\n## Scope\n- art/src/grass_*.txt\n", encoding="utf-8")
            task = tasks.from_file(path)
            self.assertEqual((task.title, task.label, task.tier), ("Three grass tiles", "tile", "light"))
            self.assertEqual(task.acceptance, ["validator passes", "three files"])
            self.assertEqual(task.scope, ["art/src/grass_*.txt"])
            self.assertIn("Make them calm.", task.description)


class SafetyTests(unittest.TestCase):
    def test_forbidden_flags_are_refused(self) -> None:
        agent = {"executable": "x", "builder_args": ["--dangerously-skip-permissions"], "reviewer_args": []}
        with self.assertRaises(ValueError):
            runner.build_command(agent, "builder", "m", Path("."), Path("out.txt"))
        agent = {"executable": "x", "builder_args": ["-s", "danger-full-access"], "reviewer_args": []}
        with self.assertRaises(ValueError):
            runner.build_command(agent, "builder", "m", Path("."), Path("out.txt"))

    def test_the_shipped_config_contains_no_forbidden_flags(self) -> None:
        for name, agent in CFG["agents"].items():
            for role in ("builder", "reviewer"):
                runner.build_command(agent, role, "m", Path("."), Path("out.txt"))  # raises on a forbidden flag

    def test_reviewers_are_read_only(self) -> None:
        self.assertIn("read-only", CFG["agents"]["codex"]["reviewer_args"])
        self.assertIn("plan", CFG["agents"]["claude"]["reviewer_args"])


if __name__ == "__main__":
    unittest.main()
