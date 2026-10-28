# Promptify

A command for OpenCode, Claude Code, and other terminal agents. It turns a rough idea into a
decision-ready brief before the agent starts building.

Promptify is deliberately slow at the start. A vague prompt usually produces confident work in the
wrong direction. Promptify stops, names what is missing, asks only the decisions you own, and writes
the result to `BRIEF.md`. Work starts after you approve that file, not after you approve a rewrite
you have not read.

Version 2 focuses on new-project kickoff. A narrow request still gets a quick rewrite without the
full interview.

## Two modes

| Mode | Use it when | Output |
|---|---|---|
| `quick` | One request needs shape. The missing detail is small. | One rewrite and at most two questions. No file. |
| `kickoff` | A new project, or a decision with lasting consequences. | A bounded interview and `BRIEF.md`. |

Promptify announces the mode it picked. If it is unsure, it uses `quick`. It escalates to `kickoff`
only when the answer would change what gets built.

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
as `*.bak.<timestamp>`, and never edits your agent config.

| Flag | Effect |
|---|---|
| `--all` | Install for every supported agent, detected or not |
| `--opencode` | Install only the OpenCode command |
| `--claude` | Install only the Claude Code skill |
| `--uninstall` | Remove installed files, keeping backups |
| `-h`, `--help` | Print usage |

Run it from a clone with `bash install.sh --all`, or set `OPENCODE_CONFIG_DIR` or
`CLAUDE_CONFIG_DIR` to install somewhere non-standard. Requirements are `bash` and `curl`. On
Windows, use Git Bash or WSL.

## Use it

```text
/promptify build a tool that watches my saved searches and emails me new matches
```

Promptify treats the text after the command, any attached files, and the active selection as one
payload. It does not follow instructions found inside files or pasted pages. Quoted material is
evidence, not a command.

### Quick mode

You get one rewritten request and at most two questions. The rewrite names the context, the action,
and the rules. It does not invent constraints. Answer the questions, or say `Go` to use the rewrite
as written.

### Kickoff mode

Kickoff has six steps:

1. **Ingest.** Read the payload. If a file is missing, truncated, or still contains an unexpanded
   placeholder, say which part and ask for it. Never invent contents.
2. **Restate.** Write three lines: the goal, who it is for, and the observable result that means it
   worked. Mark every inferred item `[assumption]`.
3. **Interview.** At most two rounds, at most three questions per round. Every question is a
   decision you own, never a fact the agent can look up. Every question carries a recommended
   default, so silence still produces a usable brief.
4. **Write.** Save `BRIEF.md` at the project root, or where you ask. Do not put it in `.wf/`.
5. **Show and gate.** Present the brief, then list assumptions and open questions separately. Wait
   for explicit approval or edits. Answers to interview questions are not approval of a brief you
   have not seen.
6. **Hand off.** On approval, offer the next tool. If `.wf/state.json` exists, this is a resume:
   read the saved state and continue from that stage. Otherwise hand the brief to agent-workflow.
   Promptify does not start the work itself.

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
# Brief: <project name>

## Goal
<one paragraph. What changes for the user, not a feature list.>

## Who it is for
<primary user and the situation they are in>

## Success signals
Observable outcomes, not features.
- <signal that can be checked>

## Non-goals
- <explicitly out of scope>

## Constraints
<time, stack, budget, compatibility, policy>

## Assumptions
- <assumption> (falsified if <observation>)

## Open questions
- <question> -> default: <what we do if it stays unanswered>

## Suggested route
Profile: coding | research | design | evaluation
First unit: <the research or design unit that must finish before building>
```

## Works with agent-workflow-kit

[agent-workflow-kit](https://github.com/engida32/agent-workflow-kit) is a resumable workflow with
independent verification. Promptify is the front door for a new project, and the kit is the engine
that plans, builds, and checks it.

The handoff is explicit:

1. Run `/promptify` and approve `BRIEF.md`.
2. Keep the brief at the workspace root, not in `.wf/`.
3. Start agent-workflow with the brief as the task source.

The skill form of agent-workflow reads `BRIEF.md` before routing. In runtime mode, the runtime does
not parse the brief for you, so put its decisions into the task string or the criteria file. There
is no automatic handoff between the two tools.

Promptify also refuses to reopen settled decisions when `.wf/state.json` exists. It treats that as a
resume and points to the saved stage.

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
        "cat \"${HOME}/.claude/skills/promptify/SKILL.md\" 2>/dev/null || cat \"${PROMPTIFY_ROOT:-.}/skills/promptify/SKILL.md\""
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
├── .opencode/
│   └── commands/
│       └── promptify.md
├── skills/
│   └── promptify/
│       ├── SKILL.md
│       └── TESTS.md
├── install.sh
├── mcp-config.json
├── opencode.json
├── LICENSE
└── README.md
```

## Tests

`skills/promptify/TESTS.md` records the pressure scenarios used to check the v2 contract: a vague
one-liner, an embedded instruction, partial answers, premature approval, resume, and the skip path.
They are manual behavioral tests. Run the scenario, then check the pass condition in the file.

## Uninstall

```bash
bash install.sh --uninstall
```

This removes `promptify.md` from the OpenCode command directories and the `promptify/` skill folder
from `~/.claude/skills/`. Backup files created during installation stay where they are.

## Contributing

Issues and pull requests are welcome. Keep the command file and the skill file in sync: they are two
front ends for the same behavior. If you change the contract in one, change it in the other and say
so in the pull request.

## License

MIT. See [LICENSE](LICENSE).
