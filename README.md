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
| Linux / macOS | `~/.config/opencode/commands/promptify.md` |
| Windows | `%USERPROFILE%\.config\opencode\commands\promptify.md` |

Current OpenCode releases use `commands/` (plural). Older builds used
`command/` (singular). If only the legacy directory exists, the installer links
`commands/` to it so both names resolve to the same files. If both directories
already exist independently, it installs into both.

### 2. Claude Code

Claude Code loads personal skills from a directory named after the skill, with
the entry point at `SKILL.md`:

| Platform | Path |
|---|---|
| Linux / macOS | `~/.claude/skills/promptify/SKILL.md` |
| Windows | `%USERPROFILE%\.claude\skills\promptify\SKILL.md` |

Other agents that scan `~/.agents/skills/` or a project-local `.claude/skills/`
can use the same folder unchanged.

### 3. MCP clients (Claude Code, Cursor, Windsurf)

`mcp-config.json` is a stdio blueprint that reads the installed skill file and
falls back to the copy in this repository:

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

Merge the `mcpServers.promptify` block into your client's MCP config. On
Windows, start the client from Git Bash or WSL so `sh` and `cat` are on PATH.

A bare `cat` process does not implement the MCP JSON-RPC handshake. Treat this
entry as a static context blueprint. If your client requires a full server
handshake, wrap the same `SKILL.md` file in a JSON-RPC server.

### 4. OpenCode package manifest

`opencode.json` carries the marketplace metadata (`name`, `identifier`,
`version`, `author`) and a `promptify` command shortcut. OpenCode still loads
the markdown command directly and ignores those extra metadata keys, so the
shortcut mainly serves catalogs and package indexes. Schema-aware editors may
flag the metadata because the published OpenCode config schema does not define
those fields.

## 📊 Standard Usage Lifecycle

1. Type `/promptify` followed by your raw idea.
2. Attach files with `@path` or select code in your editor when the harness supports it. Promptify reads the request (`$ARGUMENTS`), attached files (`$CONTEXT_FILES`), and the active selection (`$SELECTION`) as one payload.
3. Read the diagnosis, the CARE-framework rewrite, and the clarifying questions.
4. Answer them, or type `Go` to run the optimized prompt as written.

If your OpenCode build does not populate `$CONTEXT_FILES` or `$SELECTION`, the
command says so and asks for the missing material. It does not guess at file
contents.

### Expected interception output

#### 1. Prompt diagnosis

```text
- No target platform, Go version, or base image constraints.
- No size, security, or build-cache requirements.
- No statement about CGO or which dependencies need it.
```

#### 2. Optimized prompt framework

```text
Context:
Packaging a production Go microservice as a container image. The service must
build reproducibly and run with a minimal attack surface.

Action:
Construct a multi-stage Dockerfile. Build the binary in a pinned Go builder
image, then copy it into a distroless runtime image.

Rules:
- Pin both image tags; do not use latest.
- Disable CGO unless a dependency requires it.
- Run as a non-root user.
- Keep the runtime layer under 30 MB.
- Cache module downloads between builds.
```

#### 3. Clarifying questions

```text
1. Which Go version does your local runtime target?
2. Do you need CGO enabled for any dependency?
3. Should the final image run as a non-root user?
```

```text
Please provide your answers or type 'Go' to execute.
```

## 🧠 What It Actually Does

The command is a deliberate speed bump. It injects four constraints into the
model's next turn:

- **Harvest the context.** Read attached files and editor selections, name the
  paths, and refuse to guess when a placeholder arrives empty or truncated.
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
├── mcp-config.json
├── opencode.json
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
