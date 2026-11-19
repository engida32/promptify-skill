# Changelog

## Unreleased

### Added

- `scripts/lint_brief.py` and `tests/test_lint_brief.py`: a deterministic check of a saved brief
  against the skill's verification list. Structure is always enforced; falsifiers, question
  defaults, and quality-bar labels become errors once the brief is approved. Exit codes 0/1/2, with
  `--json` and `--strict`.

## 2.1.0 - 2026-11-14

### Added

- Approval frontmatter in `BRIEF.md`: `status`, `date`, `project`, `approved_by`. A brief stays
  `draft` until the user approves the exact file they have seen.
- Acceptance criteria, quality bars, and a one-line handoff prompt in the brief template.
- Project detection for common manifests and agent instruction files, with a missing-context gate.
- Quick-mode diagnosis table for pasted draft prompts, plus an explicit `go` closing gate.
- Host-neutral handoff: Hermes `plan` / `planning-with-files`, optional `agent-workflow`, or any
  user-chosen execution workflow.
- `--agents` installer target for shared `~/.agents/skills` scanners.
- Install manifest with SHA-256 hashes. Uninstall removes only matching files and leaves modified
  files alone.
- `scripts/sync_command.py` generates the OpenCode command from the canonical skill body and can
  fail CI when they drift.
- Python contract tests, installer tests, and a GitHub Actions workflow.

### Changed

- Removed `disable-model-invocation: true` so description-based skill selection can pick Promptify.
- The installer writes files atomically and records every installed path.
- Briefs are capped at 800 words and must not contain secrets or customer data.
- README and `TESTS.md` updated for the v2.1 contract.

## 2.0.0

- Initial brief-first release with `quick` and `kickoff` modes.
