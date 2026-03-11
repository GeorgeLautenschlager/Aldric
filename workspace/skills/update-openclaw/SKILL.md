---
name: update-openclaw
description: "Update OpenClaw to the latest version, back up config, restart daemon"
metadata:
  openclaw:
    emoji: "📦"
    user-invocable: true
---

# Update OpenClaw

Update the OpenClaw runtime to the latest published version.

## What It Does

1. Records the current version
2. Backs up `~/.openclaw/openclaw.json` (timestamped)
3. Runs `npm install -g openclaw@latest`
4. Restarts the systemd service (if active)
5. Rolls back config if the service fails to start
6. Logs everything and writes a journal entry

## Usage

Run the update script:

```bash
bash tools/update-openclaw/update.sh
```

Review the output. If the update introduced breaking config changes, check the
OpenClaw release notes and update `config/openclaw.json` in the Aldric repo
accordingly, then redeploy with `scripts/setup.sh`.

## After Updating

- Check `logs/update-openclaw-*.log` for warnings or deprecations
- If new config keys were introduced, add them to `config/openclaw.json`
- Test that heartbeat and cron jobs still fire correctly
