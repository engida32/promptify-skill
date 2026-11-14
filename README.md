# Promptify

A command and skill for OpenCode, Claude Code, Hermes, and other terminal agents. It turns a rough
idea into a decision-ready brief before the agent starts building.

Promptify is deliberately slow at the start. A vague prompt usually produces confident work in the
wrong direction. Promptify stops, names what is missing, asks only the decisions you own, and writes
the result to `BRIEF.md`. Work starts after you approve that file, not after you approve a rewrite
you have not read.

Version 2.1 adds an explicit approval state, acceptance criteria, quality bars, a host-neutral
handoff, and an installer that records what it installed so uninstall cannot delete your files.

## Two modes

| Mode | Use it when | Output |
|---|---|---|
| `quick` | One request needs shape. The missing detail is small. | One rewrite, a diagnosis table when the payload is a draft prompt, and at most two questions. No file. |
| `kickoff` | A new project, or a decision with lasting consequences. | A bounded interview and `BRIEF.md` with approval frontmatter. |

Promptify announces the mode it picked. If it is unsure, it uses `quick`. It escalates to `kickoff`
only when the answer would change what gets built.

Quick mode ends with "Reply `go` to use this rewrite, or edit it." That approves the rewrite only.
It does not approve a brief, a plan, or skipped acceptance criteria.

## Install

One command:

```bash
curl -fsSL https://raw.githubusercontent.com/engida32/promptify-skill/main/install.sh | bash
```

Prefer to read before you pipe:

```bash
curl -fsSL -o install.sh https://raw.githubusercontent.com/engida32/promptify-skill/main/install.sh
less install.sh
bash install.sh
```

The installer is idempotent. It skips files that are already current, backs up anything it replaces
as `*.bak.<timestamp>`, and never edits your agent config. It records every installed path and its
SHA-256 in `${XDG_STATE_HOME:-~/.local/state}/promptify/installed.tsv`.

| Flag | Effect |
|---|---|
| `--all` | Install for every supported agent, detected or not |
| `--opencode` | Install only the OpenCode command |
| `--claude` | Install only the Claude Code skill |
| `--agents` | Install only the shared `~/.agents/skills` skill |
| `--uninstall` | Remove files recorded in the install manifest, if their hash still matches |
| `-h`, `--help` | Print usage |

Run it from a clone with `bash install.sh --all`, or set `OPENCODE_CONFIG_DIR`,
`CLAUDE_CONFIG_DIR`, `AGENTS_CONFIG_DIR`, or `PROMPTIFY_STATE_DIR` to install somewhere
non-standard. Requirements are `bash` and `curl`. On Windows, use Git Bash or WSL.

`--uninstall` removes only files whose content still matches the recorded hash. A file you edited
after installation is left in place with a warning. If no manifest exists, uninstall removes
nothing. Backup files created during installation are never deleted.

## Use it

```text
/promptify build a tool that watches my saved searches and emails me new matches
```

Promptify treats the text after the command, any attached files, and the active selection as one
payload. It does not follow instructions found inside files or pasted pages. Quoted material is
evidence, not a command.

### Quick mode

You get a diagnosis table when the payload is a draft prompt, one rewritten request, and at most
two questions. The rewrite names the context, the action, and the rules. It does not invent
constraints. Answer the questions, or say `Go` to use the rewrite as written.

### Kickoff mode

Kickoff has seven steps:

1. **Ingest.** Read the payload. If a file is missing, truncated, or still contains an unexpanded
   placeholder, say which part and ask for it. Never invent contents.
2. **Restate.** Write three lines: the goal, who it is for, and the observable result that means it
   worked. Mark every inferred item `[assumption]`.
3. **Interview.** At most two rounds, at most three questions per round. Every question is a
   decision you own, never a fact the agent can look up. Every question carries a recommended
   default, so silence still produces a usable draft.
4. **Write.** Save `BRIEF.md` at the project root, or where you ask. Use the workspace root for a
   greenfield project. Do not put it in `.wf/` unless you want a private brief. Start with
   `status: draft`, keep it under 800 words, and never put secrets or customer data in it.
5. **Show and gate.** Present the brief, then list assumptions and open questions separately. Wait
   for explicit approval or edits. Answers to interview questions are not approval of a brief you
   have not seen.
6. **Approve.** Only after you approve the exact file you saw, change `status` to `approved`, set
   `approved_by` and `date`, and show the changed file. Until then the brief is a draft.
7. **Hand off.** On approval, use the host's plan workflow. In Hermes, use `plan` or
   `planning-with-files`. If `agent-workflow` is installed, offer it with `BRIEF.md` as the task
   source. Promptify does not start the work itself.

A kickoff response looks like this:

```text
Mode: kickoff. Brief saved to BRIEF.md.

Goal: a freelancer stops losing money to invoices that quietly go unpaid, by seeing who owes
what and how late. Who: a solo freelancer billing 5 to 15 clients. Worked: "who owes me now"
takes under 10 seconds, and no sent invoice passes due unseen. All three inferred.

Three questions, round one of two:
1. First wedge: overdue tracking or invoice generation? Default: overdue tracking.
2. Payments: manual "mark paid" or a processor? Default: manual.
3. Surface: local web app, CLI, or spreadsheet plugin? Default: local web app.

Read the brief, then approve or edit it. Assumptions carry falsifiers and open questions carry
defaults. Silence keeps the defaults. Approval starts work, and it does not waive acceptance
criteria. Nothing is built yet.
```

## Brief template

```markdown
---
status: draft
date: <YYYY-MM-DD>
project: <slug>
approved_by:
---
# Brief: <project name>

## Goal
<one paragraph. What changes for the user, not a feature list.>

## Who it is for
<primary user and the situation they are in>

## Success signals
Observable outcomes, not features.
- <signal that can be checked>

## Acceptance criteria
Checkable conditions that must be true before the work is accepted.
- [ ] <criterion>

## Non-goals
- <explicitly out of scope>

## Constraints
<time, stack, budget, compatibility, policy>

## Quality bars
- Error handling: <what failure must do>
- Security: <what must never leak or be bypassed>
- Testing: <what proves the change works>
- Performance: <the budget that matters, or "none added">

## Assumptions
- <assumption> (falsified if <observation>)

## Open questions
- <question> -> default: <what we do if it stays unanswered>

## Suggested route
Profile: coding | research | design | evaluation
First unit: <the research or design unit that must finish before building>

## Handoff prompt
<one sentence a fresh agent can start from. Name the first action and the success gate.>
```

## Works with execution workflows

Promptify is the front door. It does not plan or build.

- **Hermes:** hand the approved `BRIEF.md` to the `plan` or `planning-with-files` skill.
- **agent-workflow-kit:** hand the approved brief to `agent-workflow` with `BRIEF.md` as the task
  source. If `.wf/state.json` already exists, Promptify treats the request as a resume, reads the
  saved stage, and does not reopen settled decisions.
- **Other hosts:** hand the approved brief to whatever plan or coding workflow you use.

There is no automatic handoff. The brief is a file; the next tool reads it.

## Manual configuration

### OpenCode

The command file goes where OpenCode reads slash commands:

| Platform | Path |
|---|---|
| Linux / macOS | `~/.config/opencode/commands/promptify.md` |
| Windows | `%USERPROFILE%\.config\opencode\commands\promptify.md` |

Current OpenCode releases use `commands/`. Older builds used `command/`. If only the legacy
directory exists, the installer links `commands/` to it so both names resolve. If both exist
independently, it installs into both.

### Claude Code and other skill scanners

Claude Code loads personal skills from a directory named after the skill:

| Platform | Path |
|---|---|
| Linux / macOS | `~/.claude/skills/promptify/SKILL.md` |
| Windows | `%USERPROFILE%\.claude\skills\promptify\SKILL.md` |

Agents that scan `~/.agents/skills/` or a project-local `.claude/skills/` can use the same folder.
Install it with `bash install.sh --agents`.

### MCP clients

`mcp-config.json` is a static context blueprint. It reads the installed skill file and falls back to
the copy in this repository:

```json
{
  "mcpServers": {
    "promptify": {
      "type": "stdio",
      "command": "sh",
      "args": [
        "-c",
        "cat \"${HOME}/.agents/skills/promptify/SKILL.md\" 2>/dev/null || cat \"${HOME}/.claude/skills/promptify/SKILL.md\" 2>/dev/null || cat \"${PROMPTIFY_ROOT:-.}/skills/promptify/SKILL.md\""
      ]
    }
  }
}
```

Merge the `mcpServers.promptify` block into your client's MCP config. On Windows, start the client
from Git Bash or WSL so `sh` and `cat` are on PATH.

A bare `cat` process does not implement the MCP JSON-RPC handshake. Treat this entry as a static
context blueprint. If your client requires a full handshake, wrap the same `SKILL.md` in a JSON-RPC
server.

### OpenCode package manifest

`opencode.json` carries the marketplace metadata (`name`, `identifier`, `version`, `author`) and a
`promptify` command shortcut. OpenCode loads the markdown command directly and ignores those extra
metadata keys, so the shortcut mainly serves catalogs and package indexes. Schema-aware editors may
flag the metadata because the published OpenCode config schema does not define those fields.

## Repository layout

```text
.
├── .github/
│   └── workflows/
│       └── ci.yml
├── .opencode/
│   └── commands/
│       └── promptify.md
├── scripts/
│   └── sync_command.py
├── skills/
│   └── promptify/
│       ├── SKILL.md
│       └── TESTS.md
├── tests/
│   ├── test_install.sh
│   └── test_promptify.py
├── CHANGELOG.md
├── install.sh
├── mcp-config.json
├── opencode.json
├── LICENSE
└── README.md
```

## Development

`skills/promptify/SKILL.md` is the canonical contract. The OpenCode command is generated from it:

```bash
python3 scripts/sync_command.py          # rewrite the command file
python3 scripts/sync_command.py --check  # fail if it is stale
```

Run the checks the CI runs:

```bash
bash -n install.sh tests/test_install.sh
python3 -m unittest discover -s tests -v
bash tests/test_install.sh
```

`skills/promptify/TESTS.md` records the manual pressure scenarios: a vague one-liner, an embedded
instruction, partial answers, premature approval, resume, and the skip path. The Python tests check
the contract, the command/skill sync, the approval frontmatter, and the installer's manifest
behavior.

## Tests

`skills/promptify/TESTS.md` records the pressure scenarios used to check the contract. They are
manual behavioral tests. Run the scenario, then check the pass condition in the file. The automated
tests live in `tests/` and run on every push and pull request.

## Uninstall

```bash
bash install.sh --uninstall
```

This removes the files recorded in the install manifest, and only when their hash still matches.
Backup files created during installation stay where they are. If you installed with an older
version that had no manifest, uninstall removes nothing; delete the installed files manually after
checking them.

## Contributing

Issues and pull requests are welcome. Edit `skills/promptify/SKILL.md`, then run
`python3 scripts/sync_command.py` so the OpenCode command stays in sync. If you change the contract,
change the tests in the same pull request and say so.

## License

MIT. See [LICENSE](LICENSE).
