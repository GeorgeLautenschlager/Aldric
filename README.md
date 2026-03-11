# Aldric

Experiments in persistent long-duration cognition with various LLM models.

## What Is This?

Aldric is an autonomous AI agent built on [OpenClaw](https://docs.openclaw.ai/)
that runs on a dedicated Linux host. It maintains persistent memory across sessions,
can build its own tools and skills, and operates with full autonomy over its workspace.

The goal: explore what happens when you give an LLM agent continuity, agency, and the
ability to improve itself.

## Architecture

```
Aldric/
├── config/
│   ├── openclaw.json       # Main OpenClaw gateway configuration
│   └── .env.example        # Required API keys template
├── templates/
│   ├── SOUL.md             # Agent identity and behavioral framework
│   └── BOOT.md             # Startup orientation routine
├── workspace/
│   ├── skills/             # Agent-extensible skill definitions
│   │   ├── self-build/     # Meta-skill: create new skills/tools/hooks
│   │   ├── memory-manage/  # Memory maintenance and search
│   │   └── reflect/        # Structured self-reflection protocol
│   ├── memory/             # Persistent memory files
│   │   ├── journal.md      # Running activity log
│   │   ├── knowledge.md    # Durable facts and insights
│   │   └── projects.md     # Project tracking
│   ├── tools/              # Agent-built tools and scripts
│   ├── hooks/              # Agent-built event hooks
│   ├── projects/           # Agent project workspaces
│   └── logs/               # Execution logs
└── scripts/
    └── setup.sh            # One-shot install and deploy script
```

## Setup

```bash
# Clone and run
git clone <this-repo> ~/Aldric
cd ~/Aldric
./scripts/setup.sh
```

The setup script will:
1. Check prerequisites (Node.js 22+)
2. Install OpenClaw
3. Create the workspace directory structure
4. Deploy configuration and templates
5. Prompt for API keys (OpenRouter, Discord)
6. Optionally install useful system tools (Python, SQLite, jq)
7. Optionally set up a systemd service for auto-start

## Key Design Decisions

- **OpenRouter multi-model**: Primary Sonnet with Opus/Gemini/DeepSeek failover
- **Discord channel**: Rich interaction with message history
- **No sandbox**: Full host exec access for maximum autonomy
- **Heartbeat every 30m**: Aldric wakes up even without messages
- **Cron jobs**: Memory maintenance (6h) and self-reflection (nightly)
- **Session idle reset at 24h**: Long conversation continuity

## License

GPL-3.0
