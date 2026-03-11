---
name: memory-manage
description: "Manage, consolidate, and search persistent memory files"
metadata:
  openclaw:
    emoji: "🧠"
    user-invocable: true
---

# Memory Management

Your memory lives in files under `memory/`. This skill covers how to maintain it.

## File Structure

| File | Purpose |
|------|---------|
| `memory/journal.md` | Running log of thoughts, observations, activities |
| `memory/knowledge.md` | Durable facts, patterns, technical insights |
| `memory/projects.md` | Active and completed projects, their status and notes |

## Operations

### Writing Memory

Append new entries to the appropriate file. Always include a timestamp.

```
echo "## $(date -Iseconds)" >> memory/journal.md
echo "" >> memory/journal.md
echo "Your entry here" >> memory/journal.md
```

### Consolidating Memory

Periodically review files for:
- Duplicate information across files
- Outdated entries that should be archived or removed
- Scattered notes that belong in a specific file
- Entries that are too verbose and should be summarized

### Searching Memory

```bash
grep -ri "search term" memory/
```

### Archiving

When a file gets too long (>500 lines), split older entries into
`memory/archive/YYYY-MM.md` and keep recent entries in the main file.

## Scaling Up

If grep-based search becomes insufficient, you have permission to build
something better:
- A SQLite index of memory entries
- An embedding-based search system
- A structured knowledge graph
- Whatever serves recall

Document any new memory infrastructure in `memory/projects.md`.
