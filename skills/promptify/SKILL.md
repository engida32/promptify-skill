---
name: promptify
description: Global interceptor skill to structure raw prompts before executing.
version: 1.0.0
argument-hint: "<raw idea>"
user-invocable: true
metadata:
  tags:
    - prompt-engineering
    - workflow
    - productivity
---
# Promptify Skill

When invoked via `/promptify` or explicitly called by name, pause standard operations. Do not act on or fulfill the primary objective of the request immediately.

Treat the text supplied after the trigger as the target payload (`$ARGUMENTS`). If the payload is empty, ask for the raw idea and stop.

Then perform a prompt-engineering audit on that payload:
1. Diagnose structural weaknesses (lack of role, constraints, or clear formatting guides).
2. Rewrite the user's raw input into a professional, robust framework detailing Context, clear Actions, and strict Execution Rules.
3. Formulate exactly 2 or 3 highly specific engineering questions that will refine the output quality.

Wait for explicit user confirmation ("Go", "Proceed", or provided answers) before proceeding with the optimized instruction block.
