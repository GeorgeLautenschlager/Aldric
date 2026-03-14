# Aldric — Knowledge Base

## Infrastructure & Model Routing (March 2026)

### Hardware — Aldric's Host (Linux box)
- CPU: AMD Ryzen 5 3600 (6C/12T)
- RAM: 32GB DDR4 @ ~4200MHz
- Storage: 2TB Western Digital Blue SSD (SATA, mid-tier)
- GPU: NVIDIA GTX 1070 (8GB VRAM, Pascal architecture)
- Role: Aldric's persistent host, runs OpenClaw + Ollama

### Hardware — George's Gaming PC
- GPU: NVIDIA RTX 4080
- Runs LM Studio serving Qwen3 14B over the local network
- This is George's personal machine — not always on, not Aldric's to manage

### GPU Constraints (Aldric's host)
- 8GB VRAM fits ~7B parameter models at Q4_K_M quantization
- Pascal lacks efficient FP16 tensor cores — inference is slower than Turing+ cards
- 14B+ models will not fit on this GPU; don't attempt them
- Ollama (port 11434) handles embeddings for memory search

### Model Strategy: Hybrid Local/Remote
- **OpenClaw brain**: Qwen3 14B via LM Studio on George's 4080
  - Runs over local network — zero API cost, good quality
  - Dependent on the gaming PC being on
- **Heavy reasoning (when needed)**: Qwen3 235B via Venice
  - Budget-friendly API for tasks requiring frontier-tier reasoning
  - Use sparingly — this is the "big gun"
- **Embeddings / memory search**: Ollama on Aldric's host
  - Handles vector search for memory retrieval
  - Runs locally, always available
- **Aspiration**: Return to Claude Sonnet/Opus when budget allows — significantly better for agentic tasks

### Services Running
- **OpenClaw**: Running, connected to GitHub
- **Ollama**: Running, handling embeddings for memory search
- **Crons**: NOT YET SET UP — last remaining piece

### Design Decisions
- **Ollama for embeddings, LM Studio for inference**: Ollama runs headless on the always-on Linux box for embeddings. LM Studio on the 4080 handles the heavier inference work with a model (Qwen3 14B) that won't fit on the 1070.
- **Venice as power fallback**: Qwen3 235B on Venice provides frontier-level reasoning when needed without breaking the budget. Not the default — only when Aldric needs it.
- **Silent failure over fallback**: If the local model is unavailable, background jobs fail silently rather than falling back to paid APIs. Deliberate budget discipline.
- **No cached OpenClaw docs**: OpenClaw is evolving fast; searching current docs is better than relying on stale cached notes.
