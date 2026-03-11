# Aldric — Cost Estimate (Realistic / Pessimistic)

A more honest projection accounting for OpenClaw's large system prompt,
growing memory files, active user engagement, and substantial output generation.

## What the Optimistic Estimate Underestimates

1. **OpenClaw's system prompt is huge.** The gateway injects its own framework
   instructions, tool definitions, safety rules, and session context before
   SOUL.md and BOOT.md even load. Community reports put this at 8,000–15,000
   tokens depending on which features are active (exec, hooks, skills, cron).

2. **Memory files grow.** As Aldric journals, builds knowledge, and accumulates
   project notes, the BOOT.md-injected memory context will grow from ~1,500
   tokens to 5,000–10,000+ within a few months.

3. **Conversations aren't single-turn.** A real exchange is multi-turn — each
   subsequent message in a session carries the full conversation history. A
   5-message thread means the 5th message includes all prior turns as input.

4. **Output tokens add up fast.** Aldric writing code, journal entries, skill
   files, and detailed responses easily produces 1,500–3,000 tokens per turn —
   not 500.

5. **Active usage will be higher.** If Aldric becomes genuinely useful, 20–30
   messages/day is realistic for an engaged user.

## Revised Per-Invocation Token Assumptions

| Component | Optimistic | Realistic |
|-----------|-----------|-----------|
| OpenClaw system prompt | ~1,500 | ~12,000 |
| SOUL.md + BOOT.md + directives | ~1,500 | ~3,000 |
| Memory files (journal, knowledge, projects) | ~1,500 | ~6,000 |
| Conversation history (multi-turn average) | ~1,000 | ~8,000 |
| Tool calls / exec results | ~500 | ~3,000 |
| **Total input per invocation** | **~6,000** | **~32,000** |
| **Output per invocation** | **~500** | **~2,500** |

The multi-turn conversation history is the real killer. In a 5-message thread,
the last message carries ~40,000 input tokens of accumulated context. The 32K
average accounts for a mix of fresh sessions and mid-conversation turns.

## Revised Monthly Invocation Breakdown

| Source | Frequency | Monthly count | Model |
|--------|-----------|--------------|-------|
| Heartbeat | Every 4h | 180 | Sonnet 4.6 |
| Cron: memory maintenance | Every 12h | 60 | DeepSeek V3.2 |
| Cron: self-review | Weekly | 4 | DeepSeek V3.2 |
| User conversations | ~25/day | 750 | Sonnet 4.6 |

## Realistic Cost Breakdown

### Heartbeat (Sonnet 4.6) — 180 invocations/month
Heartbeats carry the full system prompt + memory but no conversation history.
- Input: 180 × 21,000 = 3.78M tokens × $3.00 = **$11.34**
- Output: 180 × 1,000 = 180K tokens × $15.00 = **$2.70**

### Cron jobs (DeepSeek V3.2) — 64 invocations/month
Isolated jobs, so lighter context — but still includes system prompt + memory.
- Input: 64 × 18,000 = 1.15M tokens × $0.28 = **$0.32**
- Output: 64 × 1,500 = 96K tokens × $0.42 = **$0.04**

### User conversations (Sonnet 4.6) — 750 invocations/month
Multi-turn threads with growing context windows.
- Input: 750 × 32,000 = 24M tokens × $3.00 = **$72.00**
- Output: 750 × 2,500 = 1.875M tokens × $15.00 = **$28.13**

### Total

| | Optimistic | Realistic |
|---|---:|---:|
| Heartbeat | $4.59 | $14.04 |
| Cron | $0.12 | $0.36 |
| User conversations | $7.65 | $100.13 |
| **Subtotal** | **$12.36** | **$114.53** |
| OpenRouter fee (5.5%) | $0.68 | $6.30 |
| **Monthly total** | **~$13** | **~$121** |

## Sensitivity Table (Realistic Token Assumptions)

| User msgs/day | Est. monthly cost |
|---------------|------------------:|
| 5 | ~$27 |
| 10 | ~$47 |
| 15 | ~$67 |
| 20 | ~$87 |
| 25 | ~$121 |
| 30 | ~$141 |

## What Would It Take to Stay Under $15/month?

With realistic token volumes, Sonnet 4.6 for user conversations blows past $15
almost immediately. Options:

### Option A: DeepSeek V3.2 as primary for everything (~$5–12/month)
Switch `agents.aldric.model` to `openrouter/deepseek/deepseek-chat`.
At $0.28/$0.42 per 1M tokens, even 25 msgs/day with fat context stays cheap.
**Trade-off:** Noticeably less capable for complex reasoning and coding.

### Option B: Gemini 2.5 Pro as primary (~$30–60/month at 25 msgs/day)
Middle ground. $1.25/$10 pricing. Better than DeepSeek for reasoning,
cheaper than Sonnet. Still over $15 at high usage.

### Option C: Aggressive prompt caching + Sonnet 4.6
If OpenRouter supports prompt caching for Anthropic models, cached input
tokens drop to $0.30/M (90% discount). The ~12K OpenClaw system prompt
and ~9K memory/directives would be cached across turns.
- Cached input: 21K tokens × $0.30/M = negligible
- Uncached input: 11K tokens × $3.00/M per turn
- This could cut Sonnet costs by ~50–60%.
**Estimated with caching: ~$50–65/month at 25 msgs/day.**
Still not $15, but much more palatable.

### Option D: Hybrid — DeepSeek primary, Sonnet on-demand
Use DeepSeek V3.2 as the default model. When Aldric encounters a task
that genuinely needs frontier reasoning (complex coding, architecture
decisions), the user manually invokes `/model sonnet` for that thread.
**Estimated: $8–15/month** depending on how often you escalate.

## Recommendation

For a hard $15/month budget with heavy usage, **Option D (hybrid with manual
escalation)** is the most practical. DeepSeek V3.2 handles routine
conversation, journaling, and maintenance well. Reserve Sonnet for when you
genuinely need it.

If budget can flex to ~$50/month, keep Sonnet as primary and investigate
prompt caching support on OpenRouter.

## Key Takeaway

The optimistic estimate assumed small, single-turn interactions. Real-world
autonomous agent usage with multi-turn conversations, growing memory, and
OpenClaw's framework overhead puts costs at **8–10x the optimistic projection**.
The token cost isn't the model call — it's carrying the full context window
on every single turn.
