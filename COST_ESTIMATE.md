# Aldric — Cost Estimate (Optimistic)

Assumes tiered model routing config as of March 2026.

## Pricing (OpenRouter, March 2026)

| Model | Input / 1M tokens | Output / 1M tokens |
|-------|-------------------|---------------------|
| Claude Sonnet 4.6 | $3.00 | $15.00 |
| Gemini 2.5 Pro | $1.25 | $10.00 |
| DeepSeek R1 | $0.50 | $2.18 |
| DeepSeek V3.2 (deepseek-chat) | $0.28 | $0.42 |

OpenRouter platform fee: 5.5% on all usage.

## Per-Invocation Token Assumptions

| Component | Input tokens | Output tokens |
|-----------|-------------|---------------|
| System prompt + SOUL.md + context | ~3,000 | — |
| Memory files (BOOT.md, journal, etc.) | ~1,500 | — |
| Conversation context | ~1,000 | — |
| Tool calls / exec results | ~500 | — |
| Response generation | — | ~500 |
| **Total per invocation** | **~6,000** | **~500** |

## Monthly Invocation Breakdown

| Source | Frequency | Monthly count | Model |
|--------|-----------|--------------|-------|
| Heartbeat | Every 4h | 180 | Sonnet 4.6* |
| Cron: memory maintenance | Every 12h | 60 | DeepSeek V3.2 |
| Cron: self-review | Weekly (Sun 3AM) | 4 | DeepSeek V3.2 |
| User conversations | ~10/day | 300 | Sonnet 4.6 |

\* `heartbeat.model` override is bugged ([#30894](https://github.com/openclaw/openclaw/issues/30894)) — heartbeats use the default model.

## Cost Breakdown

### Heartbeat (Sonnet 4.6) — 180 invocations/month
- Input: 180 × 6,000 = 1.08M tokens × $3.00 = **$3.24**
- Output: 180 × 500 = 90K tokens × $15.00 = **$1.35**

### Cron jobs (DeepSeek V3.2) — 64 invocations/month
- Input: 64 × 6,000 = 384K tokens × $0.28 = **$0.11**
- Output: 64 × 500 = 32K tokens × $0.42 = **$0.01**

### User conversations (Sonnet 4.6) — 300 invocations/month
- Input: 300 × 6,000 = 1.8M tokens × $3.00 = **$5.40**
- Output: 300 × 500 = 150K tokens × $15.00 = **$2.25**

### Total

| | Cost |
|---|---:|
| Heartbeat | $4.59 |
| Cron | $0.12 |
| User conversations | $7.65 |
| **Subtotal** | **$12.36** |
| OpenRouter fee (5.5%) | $0.68 |
| **Monthly total** | **~$13.04** |

## Sensitivity

| User msgs/day | Estimated monthly cost |
|---------------|----------------------:|
| 5 | ~$10 |
| 10 | ~$13 |
| 15 | ~$16 |
| 20 | ~$19 |

## Notes

- If the heartbeat model override bug is fixed, routing heartbeats to DeepSeek V3.2 would save ~$4.50/month.
- Opus 4.6 was removed from fallbacks to prevent accidental expensive calls ($5/$25 per 1M tokens).
- Prompt caching (if available on OpenRouter) could reduce input costs by up to 90% for repeated system prompts.
