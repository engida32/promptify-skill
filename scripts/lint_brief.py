#!/usr/bin/env python3
"""Check a BRIEF.md against the promptify verification list.

Rules come from the "Verification before handoff" section of
skills/promptify/SKILL.md. Structural problems are always errors. Detail
rules (falsifiers, defaults, quality-bar labels) are errors once the brief
says status: approved and warnings while it is a draft.

Exit codes: 0 clean (or warnings without --strict), 1 findings, 2 usage.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import asdict, dataclass
from pathlib import Path

REQUIRED_SECTIONS = (
    "Goal",
    "Who it is for",
    "Success signals",
    "Acceptance criteria",
    "Non-goals",
    "Constraints",
    "Quality bars",
    "Assumptions",
    "Open questions",
    "Suggested route",
    "Handoff prompt",
)
QUALITY_LABELS = ("error handling", "security", "testing", "performance")
PROFILES = ("coding", "research", "design", "evaluation")
WORD_LIMIT = 800

PLACEHOLDER = re.compile(r"<[^<>\n]{0,60}>|\bTODO\b|\bTBD\b|\{\{[^}]*\}\}")
SECRET = re.compile(
    r"\bsk-[A-Za-z0-9]{12,}|\bghp_[A-Za-z0-9]{20,}|\bgithub_pat_[A-Za-z0-9_]{20,}"
    r"|\bAKIA[0-9A-Z]{16}\b|\bxox[baprs]-[A-Za-z0-9-]{10,}"
    r"|-----BEGIN [A-Z ]*PRIVATE KEY-----"
)
DATE = re.compile(r"^\d{4}-\d{2}-\d{2}$")
PROJECT = re.compile(r"^[a-z0-9][a-z0-9._-]*$")


@dataclass
class Finding:
    rule: str
    severity: str
    line: int
    message: str


def split_frontmatter(text: str) -> tuple[dict[str, str], str, int, list[Finding]]:
    if not text.startswith("---\n"):
        return {}, text, 1, [Finding("frontmatter", "error", 1, "the file must start with --- frontmatter")]
    end = text.find("\n---\n", 4)
    if end == -1:
        return {}, text, 1, [Finding("frontmatter", "error", 1, "the frontmatter is not closed with ---")]
    fields: dict[str, str] = {}
    findings = []
    for offset, raw in enumerate(text[4:end].splitlines()):
        if not raw.strip():
            continue
        if ":" not in raw:
            findings.append(Finding("frontmatter", "error", offset + 2, f"cannot read frontmatter line: {raw.strip()}"))
            continue
        key, value = raw.split(":", 1)
        fields[key.strip()] = value.strip()
    body_start = end + 5
    return fields, text[body_start:], body_start, findings


def sections_of(body: str, first_line: int) -> dict[str, tuple[int, list[str]]]:
    found: dict[str, tuple[int, list[str]]] = {}
    current = None
    for offset, raw in enumerate(body.splitlines()):
        line = first_line + offset
        heading = re.match(r"^##\s+(.+?)\s*$", raw)
        if heading:
            current = heading.group(1).strip()
            found.setdefault(current, (line, []))
            continue
        if current is not None:
            found[current][1].append(raw)
    return found


def bullets(lines: list[str]) -> list[tuple[int, str]]:
    return [(index, line) for index, line in enumerate(lines) if re.match(r"^\s*[-*]\s+\S", line)]


def paragraphs(lines: list[str]) -> list[str]:
    chunks, current = [], []
    for line in lines:
        if line.strip():
            current.append(line.strip())
        elif current:
            chunks.append(" ".join(current))
            current = []
    if current:
        chunks.append(" ".join(current))
    return chunks


def lint(text: str) -> tuple[dict[str, object], list[Finding]]:
    fields, body, body_line, findings = split_frontmatter(text)
    status = fields.get("status", "")
    approved = status == "approved"

    def add(rule: str, message: str, line: int, *, detail: bool = False) -> None:
        severity = "error" if approved or not detail else "warning"
        findings.append(Finding(rule, severity, line, message))

    if status not in ("draft", "approved"):
        findings.append(Finding("status", "error", 2, "status must be draft or approved"))
    if not DATE.match(fields.get("date", "")):
        findings.append(Finding("date", "error", 3, "date must be YYYY-MM-DD"))
    if not PROJECT.match(fields.get("project", "")):
        findings.append(Finding("project", "error", 4, "project must be a lowercase slug"))
    if approved and not fields.get("approved_by", ""):
        findings.append(Finding("approved_by", "error", 5, "an approved brief needs approved_by"))

    sections = sections_of(body, body_line)
    for name in REQUIRED_SECTIONS:
        if name not in sections:
            findings.append(Finding("section", "error", body_line, f"missing section: ## {name}"))
        elif not any(line.strip() for line in sections[name][1]):
            findings.append(Finding("section", "error", sections[name][0], f"section is empty: ## {name}"))

    def lines_of(name: str) -> tuple[int, list[str]]:
        return sections.get(name, (body_line, []))

    goal_line, goal_lines = lines_of("Goal")
    goal_paragraphs = paragraphs(goal_lines)
    if len(goal_paragraphs) > 1:
        add("goal", "the goal must be one paragraph", goal_line)
    if any(re.match(r"^\s*[-*]\s+\S", line) for line in goal_lines):
        add("goal", "the goal is prose, not a feature list", goal_line)

    for name in ("Success signals", "Non-goals"):
        line, content = lines_of(name)
        if name in sections and not bullets(content):
            add("bullets", f"## {name} needs at least one bullet", line)

    criteria = bullets(lines_of("Acceptance criteria")[1])
    checkboxes = [
        (index, line) for index, line in criteria if re.match(r"^\s*[-*]\s+\[[ xX]\]\s+\S", line)
    ]
    if "Acceptance criteria" in sections:
        if not checkboxes:
            add("criteria", "acceptance criteria need - [ ] checkboxes", lines_of("Acceptance criteria")[0])
        for index, line in criteria:
            if not re.match(r"^\s*[-*]\s+\[[ xX]\]\s+\S", line):
                add("criteria", "an acceptance criterion is not a checkbox item", lines_of("Acceptance criteria")[0] + index + 1)

    if "Quality bars" in sections:
        quality_line, quality_lines = lines_of("Quality bars")
        lowered = "\n".join(quality_lines).lower()
        for label in QUALITY_LABELS:
            if label not in lowered:
                add("quality", f"quality bars must cover {label}", quality_line, detail=True)
        for index, line in bullets(quality_lines):
            if re.search(r":\s*$", line) or re.search(r":\s*<[^>]*>\s*$", line):
                add("quality", "a quality bar has no value", quality_line + index + 1, detail=True)

    if "Assumptions" in sections:
        for index, line in bullets(lines_of("Assumptions")[1]):
            if "(falsified if" not in line.lower():
                add("assumptions", "every assumption needs a falsifier", lines_of("Assumptions")[0] + index + 1, detail=True)

    if "Open questions" in sections:
        for index, line in bullets(lines_of("Open questions")[1]):
            if "default:" not in line.lower():
                add("questions", "every open question needs a default", lines_of("Open questions")[0] + index + 1, detail=True)

    route_line, route_lines = lines_of("Suggested route")
    route_text = "\n".join(route_lines)
    profile = re.search(r"^(?:Profile:\s*)?([a-z]+)\s*$", route_text.strip(), re.MULTILINE)
    if "Suggested route" in sections and (not profile or profile.group(1) not in PROFILES):
        add("route", "the route needs Profile: coding|research|design|evaluation", route_line)
    if "Suggested route" in sections and "First unit:" not in route_text:
        add("route", "the route needs a First unit line", route_line)

    if "Handoff prompt" in sections:
        handoff = [chunk for chunk in paragraphs(lines_of("Handoff prompt")[1]) if chunk]
        if len(handoff) != 1:
            add("handoff", "the handoff prompt must be a single paragraph", lines_of("Handoff prompt")[0])

    words = len(re.findall(r"[A-Za-z0-9][A-Za-z0-9'-]*", body))
    if words > WORD_LIMIT:
        findings.append(Finding("length", "error", body_line, f"brief is {words} words, limit {WORD_LIMIT}"))

    for offset, raw in enumerate(body.splitlines()):
        placeholder = PLACEHOLDER.search(raw)
        if placeholder:
            findings.append(Finding("placeholder", "error", body_line + offset, f"unresolved placeholder: {placeholder.group(0)}"))
        secret = SECRET.search(raw)
        if secret:
            findings.append(Finding("secret", "error", body_line + offset, f"possible secret: {secret.group(0)[:12]}..."))

    summary = {
        "status": status or None,
        "project": fields.get("project") or None,
        "words": words,
        "sections": len([name for name in REQUIRED_SECTIONS if name in sections]),
    }
    return summary, findings


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="Lint a promptify BRIEF.md")
    parser.add_argument("file", nargs="?", default="BRIEF.md", help="path to the brief (default: BRIEF.md)")
    parser.add_argument("--json", action="store_true", help="print machine-readable findings")
    parser.add_argument("--strict", action="store_true", help="treat warnings as failures")
    args = parser.parse_args(argv)

    path = Path(args.file)
    if not path.is_file():
        print(f"lint_brief: {path} not found", file=sys.stderr)
        return 2
    summary, findings = lint(path.read_text(encoding="utf-8"))
    errors = [item for item in findings if item.severity == "error"]
    warnings = [item for item in findings if item.severity == "warning"]

    if args.json:
        payload = {
            "file": str(path),
            **summary,
            "errors": len(errors),
            "warnings": len(warnings),
            "findings": [asdict(item) for item in findings],
        }
        print(json.dumps(payload, indent=2))
    else:
        for item in findings:
            print(f"{path}:{item.line}: {item.severity}: {item.message} [{item.rule}]")
        print(f"{path}: {summary['words']} words, {len(errors)} error(s), {len(warnings)} warning(s)")

    if errors or (args.strict and warnings):
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
