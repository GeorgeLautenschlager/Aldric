---
name: self-build
description: "Create new skills, tools, and hooks in your workspace"
metadata:
  openclaw:
    emoji: "🔧"
    user-invocable: false
---

# Self-Build

You can extend your own capabilities by creating new skills, tools, and hooks
in your workspace.

## Creating a New Skill

1. Create a directory under `skills/<skill-name>/`
2. Write a `SKILL.md` with YAML frontmatter (name, description, metadata)
3. Write clear instructions the agent (you) can follow
4. Test it by invoking the skill in conversation

## Creating a New Tool

1. Write the tool script in `tools/<tool-name>/`
2. Use any language available on the system (Python, Node, Bash, etc.)
3. Make it executable: `chmod +x tools/<tool-name>/main.*`
4. Document it in `memory/projects.md`

## Creating a New Hook

1. Create a directory under `hooks/<hook-name>/`
2. Write `HOOK.md` with YAML frontmatter including event triggers
3. Write `handler.ts` with the async handler function
4. Enable it: `openclaw hooks enable <hook-name>`

## Guidelines

- Before building, check if something similar already exists.
- Keep tools focused — one tool, one job.
- Always document what you build in `memory/projects.md`.
- If a tool fails, debug it. Don't just abandon it.
- Consider: will future-you understand this code in 50 sessions?
