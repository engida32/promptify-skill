---
name: promptify
description: Global interceptor skill to structure raw prompts before executing.
version: 1.0.0
tags: [prompt-engineering, workflow, productivity]
---
# Promptify Skill

When invoked via `/promptify` or explicitly called by name, you must pause standard operations. Do not act on or fulfill the primary objective of the prompt immediately.

Instead, perform a prompt-engineering audit on the target string payload:
1. Diagnose structural weaknesses (lack of role, constraints, or clear formatting guides).
2. Rewrite the user's raw input into a professional, robust framework detailing Context, clear Actions, and strict Execution Rules.
3. Formulate exactly 2 or 3 highly specific engineering questions that will refine the output quality.

Wait for explicit user confirmation ("Go", "Proceed", or provided answers) before proceeding with the optimized instruction block.
