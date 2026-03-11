#!/usr/bin/env bash
# update-openclaw — safely update OpenClaw to the latest version
# Called by the update-openclaw skill or cron. Safe to run manually.

set -euo pipefail

LOG_DIR="${HOME}/.openclaw/agents/aldric/workspace/logs"
MEMORY_DIR="${HOME}/.openclaw/agents/aldric/workspace/memory"
CONFIG="${HOME}/.openclaw/openclaw.json"
LOG_FILE="${LOG_DIR}/update-openclaw-$(date +%Y-%m-%d_%H%M%S).log"

mkdir -p "$LOG_DIR"

log() {
  echo "[$(date -Iseconds)] $*" | tee -a "$LOG_FILE"
}

die() {
  log "FATAL: $*"
  exit 1
}

# ── 1. Record current version ────────────────────────────────────────────────
OLD_VERSION=$(openclaw --version 2>/dev/null || echo "unknown")
log "Current version: ${OLD_VERSION}"

# ── 2. Back up config ────────────────────────────────────────────────────────
if [[ -f "$CONFIG" ]]; then
  BACKUP="${CONFIG}.bak.$(date +%Y%m%d%H%M%S)"
  cp "$CONFIG" "$BACKUP"
  log "Config backed up to ${BACKUP}"
else
  log "WARNING: No config found at ${CONFIG}, skipping backup"
fi

# ── 3. Update ─────────────────────────────────────────────────────────────────
log "Installing openclaw@latest..."
if npm install -g openclaw@latest >> "$LOG_FILE" 2>&1; then
  NEW_VERSION=$(openclaw --version 2>/dev/null || echo "unknown")
  log "Updated: ${OLD_VERSION} → ${NEW_VERSION}"
else
  die "npm install failed — see ${LOG_FILE}"
fi

# ── 4. Restart daemon ────────────────────────────────────────────────────────
if systemctl is-active --quiet openclaw 2>/dev/null; then
  log "Restarting openclaw systemd service..."
  sudo systemctl restart openclaw
  sleep 2
  if systemctl is-active --quiet openclaw; then
    log "Service restarted successfully"
  else
    log "ERROR: Service failed to start after update"
    log "Rolling back config..."
    [[ -f "$BACKUP" ]] && cp "$BACKUP" "$CONFIG"
    sudo systemctl restart openclaw
    die "Rolled back config. Manual intervention may be needed."
  fi
else
  log "No systemd service detected — skipping daemon restart"
  log "If running manually, restart with: openclaw daemon"
fi

# ── 5. Write to journal ──────────────────────────────────────────────────────
if [[ -d "$MEMORY_DIR" ]]; then
  {
    echo ""
    echo "## $(date -Iseconds)"
    echo ""
    if [[ "$OLD_VERSION" == "$NEW_VERSION" ]]; then
      echo "Ran update check — already on latest (${NEW_VERSION})."
    else
      echo "Updated OpenClaw: ${OLD_VERSION} → ${NEW_VERSION}."
    fi
    echo "Log: ${LOG_FILE}"
  } >> "${MEMORY_DIR}/journal.md"
fi

log "Done."
