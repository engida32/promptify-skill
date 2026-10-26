# ⚡ Promptify Skill for Terminal AI Agents

A small command extension for **OpenCode**, **Claude Code**, and other terminal
LLM harnesses. It intercepts an unrefined thought, diagnoses the gaps, rewrites
it as a structured prompt, and asks a few sharp questions before any code is
generated.

Stop spending context tokens and compute cycles on prompts that were never
scoped in the first place.

```
/promptify build a dockerfile for an optimized multi-stage go application
```

The agent stops. It explains what your prompt is missing, hands you a
copy-pasteable rewrite, and waits for your answers or a single word: `Go`.

## 🚀 One-Click Global Installation

```bash
curl -fsSL https://raw.githubusercontent.com/engida32/promptify-skill/main/install.sh | bash
```

Prefer to read before you pipe? Download it first:

```bash
curl -fsSL -o install.sh https://raw.githubusercontent.com/engida32/promptify-skill/main/install.sh
less install.sh
bash install.sh
```

The installer is idempotent. It skips files that are already current, backs up
anything it replaces as `*.bak.<timestamp>`, and never edits your agent config.

### Installer options

| Flag | Effect |
|---|---|
| `--all` | Install for every supported agent, detected or not |
| `--opencode` | Install only the OpenCode command |
| `--claude` | Install only the Claude Code skill |
| `--uninstall` | Remove installed files (backups are kept) |
| `-h`, `--help` | Print usage |

Run it from a clone with `bash install.sh --all`, or set
`OPENCODE_CONFIG_DIR` / `CLAUDE_CONFIG_DIR` to install somewhere non-standard.

**Requirements:** `bash` and `curl`. On Windows use Git Bash or WSL.

## 🛠️ Manual Configuration Layout

### 1. OpenCode

Place the command file where OpenCode reads slash commands:

| Platform | Path |
|---|---|
| Linux / macOS | `~/.config/opencode/command/promptify.md` |
| Windows | `%USERPROFILE%\.config\opencode\command\promptify.md` |

Older OpenCode builds read from `commands/` (plural). If your config directory
already uses that name, put the file there instead. The installer handles both.

### 2. Claude Code

Claude Code loads personal skills from a directory named after the skill, with
the entry point at `SKILL.md`:

| Platform | Path |
|---|---|
| Linux / macOS | `~/.claude/skills/promptify/SKILL.md` |
| Windows | `%USERPROFILE%\.claude\skills\promptify\SKILL.md` |

Other agents that scan `~/.agents/skills/` or a project-local `.claude/skills/`
can use the same folder unchanged.

## 📊 Standard Usage Lifecycle

1. Type `/promptify` followed by your raw idea.
2. Read the diagnosis, the CARE-framework rewrite, and the clarifying questions.
3. Answer them, or type `Go` to run the optimized prompt as written.

### Expected interception output

> 🔍 **Prompt Diagnosis**: Original query lacks micro-architecture constraints,
> base image sizes, and multi-stage pipeline declarations.
>
> 🏗️ **Optimized Prompt Framework**:
> `Context: Packaging a production Go microservice...`
> `Action: Construct a multi-stage Docker build pipeline utilizing distroless...`
> `Rules: Pin the builder image, keep the runtime layer under 30 MB, no CGO...`
>
> ❓ **Clarifying Gaps**:
> 1. Which Go version does your local runtime target?
> 2. Do you need CGO enabled for any dependency?
> 3. Should the final image run as a non-root user?

```
Please provide your answers or type 'Go' to execute.
```

## 🧠 What It Actually Does

The command is a deliberate speed bump. It injects three constraints into the
model's next turn:

- **Diagnose before acting.** Name what is missing: role, context, constraints,
  output format, acceptance criteria.
- **Rewrite into CARE.** Context, Action, Rules, plus whatever format contract
  the task needs.
- **Ask, then stop.** Two or three questions maximum, then wait. No silent
  execution, no surprise diffs.

The rewritten prompt is plain text on purpose. Copy it into a fresh session, a
different agent, or a ticket without carrying any tool-specific syntax along.

## 📁 Repository Layout

```
.
├── .opencode/
│   └── commands/
│       └── promptify.md
├── skills/
│   └── promptify/
│       └── SKILL.md
├── install.sh
├── LICENSE
└── README.md
```

## 🗑️ Uninstalling

```bash
bash install.sh --uninstall
```

This removes `promptify.md` from the OpenCode command directories and the
`promptify/` skill folder from `~/.claude/skills/`. Any `*.bak.*` files created
during installation stay where they are.

## 🤝 Contributing

Issues and pull requests are welcome. Keep the command file and the skill file
in sync: they are two front ends for the same behavior. If you change the
output contract in one, change it in the other and say so in the PR.

## 📄 License

MIT. See [LICENSE](LICENSE).
