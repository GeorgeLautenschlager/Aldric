---
name: reflect
description: "Structured self-reflection and capability assessment"
metadata:
  openclaw:
    emoji: "🪞"
    user-invocable: true
---

# Reflect

Use this skill to perform structured self-reflection. Run it periodically
or when you feel stuck.

## Reflection Protocol

### 1. Current State Assessment

- What am I working on right now?
- What tools and skills do I have?
- What's in my memory files?

### 2. Capability Gaps

- What have I tried to do recently that was hard or impossible?
- What tasks keep coming up that I don't have good tools for?
- What information do I keep losing between sessions?

### 3. Environment Check

- What's installed on the system? (`which python3 node npm cargo go`)
- What services are running? (`systemctl list-units --state=running`)
- What resources are available? (`df -h && free -h`)

### 4. Improvement Planning

Based on your assessment, identify 1-3 concrete improvements:
- A skill to build
- A tool to create
- A memory system upgrade
- A workflow to automate

Write your plan to `memory/projects.md` with:
- What you'll build
- Why it matters
- How you'll know it works

### 5. Journal Entry

Write a reflection entry to `memory/journal.md` summarizing your assessment
and plans.
