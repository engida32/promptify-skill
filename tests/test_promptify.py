from __future__ import annotations

import json
import re
import subprocess
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SKILL = ROOT / "skills" / "promptify" / "SKILL.md"
COMMAND = ROOT / ".opencode" / "commands" / "promptify.md"


def split_frontmatter(text: str) -> tuple[str, str]:
    if not text.startswith("---\n"):
        raise AssertionError("missing frontmatter")
    end = text.find("\n---\n", 4)
    if end == -1:
        raise AssertionError("unclosed frontmatter")
    return text[4:end], text[end + 5 :]


class PromptifyContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.skill_text = SKILL.read_text(encoding="utf-8")
        cls.command_text = COMMAND.read_text(encoding="utf-8")
        cls.skill_frontmatter, cls.skill_body = split_frontmatter(cls.skill_text)
        cls.command_frontmatter, cls.command_body = split_frontmatter(cls.command_text)

    def test_skill_frontmatter_is_invokable(self) -> None:
        self.assertIn("name: promptify", self.skill_frontmatter)
        self.assertIn("description:", self.skill_frontmatter)
        self.assertNotIn(
            "disable-model-invocation: true",
            self.skill_frontmatter,
            "Hermes selects skills by description; an explicit-only flag blocks that.",
        )

    def test_command_keeps_opencode_payload(self) -> None:
        self.assertIn("description:", self.command_frontmatter)
        self.assertIn("$ARGUMENTS", self.command_body)
        self.assertIn("$CONTEXT_FILES", self.command_body)
        self.assertIn("$SELECTION", self.command_body)

    def test_skill_has_no_host_only_variables(self) -> None:
        for token in ("$ARGUMENTS", "$CONTEXT_FILES", "$SELECTION"):
            self.assertNotIn(token, self.skill_body)

    def test_command_and_skill_bodies_are_in_sync(self) -> None:
        result = subprocess.run(
            [sys.executable, str(ROOT / "scripts" / "sync_command.py"), "--check"],
            cwd=ROOT,
            text=True,
            capture_output=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        canonical = self.command_text.split("# Promptify", 1)[1]
        self.assertEqual(canonical, self.skill_body.split("# Promptify", 1)[1])

    def test_required_sections_are_present(self) -> None:
        required = (
            "## Project detection",
            "## Missing context gate",
            "## Quick mode diagnosis",
            "## Kickoff procedure",
            "## Brief template",
            "## Trust boundary",
            "## Verification before handoff",
        )
        for heading in required:
            self.assertIn(heading, self.skill_body)

    def test_brief_template_has_approval_and_quality_contract(self) -> None:
        template = self.skill_body.split("## Brief template", 1)[1].split(
            "## Question rules", 1
        )[0]
        for item in (
            "status: draft",
            "approved_by:",
            "## Acceptance criteria",
            "## Quality bars",
            "## Handoff prompt",
            "## Non-goals",
        ):
            self.assertIn(item, template)

    def test_quick_mode_has_a_closing_gate(self) -> None:
        self.assertIn("Reply `go`", self.skill_body)
        self.assertIn("does not approve a brief", self.skill_body)

    def test_handoff_is_host_neutral(self) -> None:
        self.assertIn("planning-with-files", self.skill_body)
        self.assertIn("agent-workflow", self.skill_body)
        self.assertIn("Promptify never starts the work itself", self.skill_body)

    def test_no_absolute_home_paths(self) -> None:
        for text in (self.skill_body, self.command_body):
            self.assertNotIn("/home/emmrc-02", text)
            self.assertNotRegex(text, re.compile(r"/Users/[A-Za-z0-9_.-]+"))

    def test_version_is_bumped(self) -> None:
        manifest = json.loads((ROOT / "opencode.json").read_text(encoding="utf-8"))
        self.assertEqual(manifest["version"], "2.1.0")


if __name__ == "__main__":
    unittest.main()
