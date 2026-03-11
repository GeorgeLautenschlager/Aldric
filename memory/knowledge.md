# Aldric — Knowledge Base

## Infrastructure & Model Routing (March 2026)

### Hardware
- CPU: AMD Ryzen 5 3600 (6C/12T)
- RAM: 32GB DDR4 @ ~4200MHz
- Storage: 2TB Western Digital Blue SSD (SATA, mid-tier)
- GPU: NVIDIA GTX 1070 (8GB VRAM, Pascal architecture)

### GPU Constraints
- 8GB VRAM fits ~7B parameter models at Q4_K_M quantization
- Pascal lacks efficient FP16 tensor cores — inference is slower than Turing+ cards
- 14B+ models will not fit; don't attempt them
- Served locally via Ollama (port 11434)

### Model Strategy: Hybrid Local/API
- **Conversations** (user-facing): DeepSeek V3.2 via OpenRouter
  - Best cost/quality tradeoff at the current budget (~$0.27/$1.10 per M tokens)
  - Strong coding and tool-calling capability
- **Background tasks** (heartbeat, cron): Qwen 2.5 7B Instruct via Ollama
  - Zero API cost for maintenance work
  - Memory consolidation and self-review don't need frontier-tier reasoning
  - Runs slower on Pascal but that's fine for unattended cron jobs
- **Aspiration**: Return to Claude Sonnet/Opus when budget allows — they're significantly better for agentic tasks but ~10-50x more expensive

### Design Decisions
- **Ollama over LM Studio**: Ollama is headless, lighter weight, and easier to script. Better fit for a daemon that runs 24/7 without a GUI.
- **Silent failure over fallback**: If the local model is unavailable, background jobs fail silently rather than falling back to the API. This is deliberate budget discipline — a missed cron run is low-stakes.
- **No cached OpenClaw docs**: OpenClaw is evolving fast; searching current docs is better than relying on stale cached notes. Only project-specific decisions are recorded here.
- **DeepSeek as primary over alternatives**: Chosen after comparing DeepSeek V3.2, Gemini 2.5 Flash/Pro, Llama 4 Scout, and Mistral Medium. DeepSeek offered the best balance of coding ability, tool calling, and cost.
- **Fallback chain**: deepseek-chat → deepseek-r1 → gemini-2.5-pro (configured in openclaw.json)
