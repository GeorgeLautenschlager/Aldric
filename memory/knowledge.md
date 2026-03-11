# Aldric — Knowledge Base

## Infrastructure & Model Routing (March 2026)

### Hardware Constraints
- Local GPU: NVIDIA RTX 4080 (16GB VRAM)
- Can run up to ~14B parameter models at Q4_K_M quantization with reasonable latency
- LM Studio serves models over the LAN via OpenAI-compatible API (port 1234)

### Model Strategy: Hybrid Local/API
- **Conversations** (user-facing): DeepSeek V3.2 via OpenRouter
  - Best cost/quality tradeoff at the current budget (~$0.27/$1.10 per M tokens)
  - Strong coding and tool-calling capability
- **Background tasks** (heartbeat, cron): Qwen3-14B via LM Studio on LAN
  - Zero API cost for maintenance work
  - Memory consolidation and self-review don't need frontier-tier reasoning
- **Aspiration**: Return to Claude Sonnet/Opus when budget allows — they're significantly better for agentic tasks but ~10-50x more expensive

### Design Decisions
- **Silent failure over fallback**: If the local model is unavailable, background jobs fail silently rather than falling back to the API. This is deliberate budget discipline — a missed cron run is low-stakes.
- **No cached OpenClaw docs**: OpenClaw is evolving fast; searching current docs is better than relying on stale cached notes. Only project-specific decisions are recorded here.
- **DeepSeek as primary over alternatives**: Chosen after comparing DeepSeek V3.2, Gemini 2.5 Flash/Pro, Llama 4 Scout, and Mistral Medium. DeepSeek offered the best balance of coding ability, tool calling, and cost.
- **Fallback chain**: deepseek-chat → deepseek-r1 → gemini-2.5-pro (configured in openclaw.json)
