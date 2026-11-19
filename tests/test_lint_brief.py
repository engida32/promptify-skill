from __future__ import annotations

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LINTER = ROOT / "scripts" / "lint_brief.py"

BRIEF = """---
status: {status}
date: 2026-11-19
project: saved-search-digest
approved_by: {approved_by}
---
# Brief: Saved search digest

## Goal
Let one person stop checking saved searches by hand and get a daily digest of new matches, so a
listing that fits is seen the morning it appears.

## Who it is for
A single user with saved searches on sites they already visit every morning.

## Success signals
- The digest arrives every morning for seven days in a row.
- No listing appears in two consecutive digests.

## Acceptance criteria
- [ ] A digest is produced from the configured saved searches.
- [ ] Duplicates are dropped across one digest.
{extra_criteria}

## Non-goals
- No bidding or automatic purchase.
- No credentials past the first sign in.

## Constraints
One laptop, read-only access, no stored credentials, nothing beyond the $0 tier.

## Quality bars
- Error handling: a failed source logs a warning and the digest still ships.
- Security: no credentials in the brief, logs, or the digest.
- Testing: a fixture run proves duplicate removal.
- Performance: the digest builds in under ten seconds.

## Assumptions
- The user checks email before 9am (falsified if the digest is opened after noon).
{extra_assumption}

## Open questions
- Which two sources first -> default: the two already open each morning.
{extra_question}

## Suggested route
Profile: coding
First unit: a fixture that turns two saved searches into one digest.

## Handoff prompt
Build the digest for the two default sources and stop when the fixture run shows no duplicates.
"""


def render(**overrides: str) -> str:
    values = {"status": "approved", "approved_by": "engida32", "extra_criteria": "", "extra_assumption": "", "extra_question": ""}
    values.update(overrides)
    return BRIEF.format(**values)


class LintBriefTests(unittest.TestCase):
    def run_lint(self, text: str, *args: str) -> tuple[int, dict]:
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "BRIEF.md"
            path.write_text(text, encoding="utf-8")
            result = subprocess.run(
                [sys.executable, str(LINTER), str(path), "--json", *args],
                capture_output=True,
                text=True,
            )
        return result.returncode, json.loads(result.stdout or "{}")

    def rules(self, payload: dict, severity: str = "error") -> set[str]:
        return {item["rule"] for item in payload.get("findings", []) if item["severity"] == severity}

    def test_a_complete_approved_brief_is_clean(self) -> None:
        code, payload = self.run_lint(render())
        self.assertEqual(code, 0, payload)
        self.assertEqual(payload["errors"], 0)
        self.assertEqual(payload["warnings"], 0)
        self.assertEqual(payload["status"], "approved")
        self.assertEqual(payload["sections"], 11)

    def test_a_draft_is_judged_on_structure_only(self) -> None:
        text = render(status="draft", approved_by="").replace(" (falsified if the digest is opened after noon)", "")
        code, payload = self.run_lint(text)
        self.assertEqual(code, 0, payload)
        self.assertEqual(payload["errors"], 0)
        self.assertIn("assumptions", self.rules(payload, "warning"))

        strict_code, _ = self.run_lint(text, "--strict")
        self.assertEqual(strict_code, 1)

    def test_an_approved_brief_needs_a_falsifier_on_each_assumption(self) -> None:
        text = render().replace(" (falsified if the digest is opened after noon)", "")
        code, payload = self.run_lint(text)
        self.assertEqual(code, 1)
        self.assertIn("assumptions", self.rules(payload))

    def test_an_approved_brief_needs_a_default_on_each_question(self) -> None:
        text = render().replace(" -> default: the two already open each morning.", "")
        code, payload = self.run_lint(text)
        self.assertEqual(code, 1)
        self.assertIn("questions", self.rules(payload))

    def test_a_placeholder_is_an_error(self) -> None:
        code, payload = self.run_lint(render(extra_criteria="- [ ] <criterion>"))
        self.assertEqual(code, 1)
        self.assertIn("placeholder", self.rules(payload))

    def test_a_secret_is_an_error(self) -> None:
        code, payload = self.run_lint(render(extra_assumption="- The key sk-abcdefghijklmnop1234 is read only."))
        self.assertEqual(code, 1)
        self.assertIn("secret", self.rules(payload))

    def test_a_missing_section_is_an_error(self) -> None:
        text = render().replace("## Constraints\nOne laptop, read-only access, no stored credentials, nothing beyond the $0 tier.\n", "")
        code, payload = self.run_lint(text)
        self.assertEqual(code, 1)
        self.assertIn("section", self.rules(payload))

    def test_acceptance_criteria_need_checkboxes(self) -> None:
        text = render().replace("- [ ] A digest is produced from the configured saved searches.", "- A digest is produced from the configured saved searches.")
        code, payload = self.run_lint(text)
        self.assertEqual(code, 1)
        self.assertIn("criteria", self.rules(payload))

    def test_an_approved_brief_needs_an_approver(self) -> None:
        code, payload = self.run_lint(render(approved_by=""))
        self.assertEqual(code, 1)
        self.assertIn("approved_by", self.rules(payload))

    def test_the_goal_must_be_prose(self) -> None:
        text = render().replace(
            "Let one person stop checking saved searches by hand and get a daily digest of new matches, so a\nlisting that fits is seen the morning it appears.",
            "- A digest\n- Saved searches",
        )
        code, payload = self.run_lint(text)
        self.assertEqual(code, 1)
        self.assertIn("goal", self.rules(payload))

    def test_frontmatter_is_validated(self) -> None:
        text = render().replace("date: 2026-11-19", "date: 19/11/2026").replace("project: saved-search-digest", "project: Saved Search")
        code, payload = self.run_lint(text)
        self.assertEqual(code, 1)
        self.assertEqual({"date", "project"}, self.rules(payload))

    def test_the_route_must_name_a_profile(self) -> None:
        text = render().replace("Profile: coding", "Profile: delivery")
        code, payload = self.run_lint(text)
        self.assertEqual(code, 1)
        self.assertIn("route", self.rules(payload))

    def test_a_brief_over_the_word_limit_is_an_error(self) -> None:
        filler = "\n".join(["Additional context that runs long."] * 200)
        code, payload = self.run_lint(render(extra_criteria=f"- [ ] A long criterion {filler}"))
        self.assertEqual(code, 1)
        self.assertIn("length", self.rules(payload))

    def test_a_missing_file_exits_two(self) -> None:
        result = subprocess.run([sys.executable, str(LINTER), "/nonexistent/BRIEF.md"], capture_output=True, text=True)
        self.assertEqual(result.returncode, 2)


if __name__ == "__main__":
    unittest.main()
