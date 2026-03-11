#!/usr/bin/env bash
set -euo pipefail

# Aldric — OpenClaw Setup Script
# Sets up a dedicated Linux host for long-duration autonomous LLM cognition.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
OPENCLAW_HOME="$HOME/.openclaw"
AGENT_DIR="$OPENCLAW_HOME/agents/aldric"
WORKSPACE="$AGENT_DIR/workspace"
ENV_FILE="$OPENCLAW_HOME/.env"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${CYAN}[info]${NC} $*"; }
ok()    { echo -e "${GREEN}[ok]${NC} $*"; }
warn()  { echo -e "${YELLOW}[warn]${NC} $*"; }
err()   { echo -e "${RED}[error]${NC} $*" >&2; }

# --------------------------------------------------------------------------
# Pre-flight checks
# --------------------------------------------------------------------------

check_prereqs() {
    info "Checking prerequisites..."

    local missing=()

    if ! command -v node &>/dev/null; then
        missing+=("node")
    else
        local node_major
        node_major=$(node -v | sed 's/v//' | cut -d. -f1)
        if (( node_major < 22 )); then
            err "Node.js 22+ required (found $(node -v))"
            exit 1
        fi
        ok "Node.js $(node -v)"
    fi

    if ! command -v npm &>/dev/null; then
        missing+=("npm")
    fi

    if ! command -v git &>/dev/null; then
        missing+=("git")
    fi

    if (( ${#missing[@]} > 0 )); then
        err "Missing required tools: ${missing[*]}"
        echo ""
        echo "Install Node.js 22+:"
        echo "  curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -"
        echo "  sudo apt-get install -y nodejs"
        exit 1
    fi

    ok "All prerequisites met"
}

# --------------------------------------------------------------------------
# Install OpenClaw
# --------------------------------------------------------------------------

install_openclaw() {
    if command -v openclaw &>/dev/null; then
        local current_version
        current_version=$(openclaw --version 2>/dev/null || echo "unknown")
        ok "OpenClaw already installed ($current_version)"
        read -rp "Update to latest? [y/N] " update
        if [[ "$update" =~ ^[Yy]$ ]]; then
            info "Updating OpenClaw..."
            npm install -g openclaw@latest
        fi
    else
        info "Installing OpenClaw..."
        npm install -g openclaw@latest
        ok "OpenClaw installed"
    fi
}

# --------------------------------------------------------------------------
# Create directory structure
# --------------------------------------------------------------------------

create_directories() {
    info "Creating workspace directories..."

    mkdir -p "$OPENCLAW_HOME"
    mkdir -p "$AGENT_DIR"
    mkdir -p "$WORKSPACE"/{skills,hooks,memory,memory/archive,projects,tools,logs}

    ok "Directory structure created at $WORKSPACE"
}

# --------------------------------------------------------------------------
# Deploy configuration files
# --------------------------------------------------------------------------

deploy_config() {
    info "Deploying configuration..."

    # Main config
    if [[ -f "$OPENCLAW_HOME/openclaw.json" ]]; then
        warn "openclaw.json already exists — backing up to openclaw.json.bak"
        cp "$OPENCLAW_HOME/openclaw.json" "$OPENCLAW_HOME/openclaw.json.bak"
    fi
    cp "$PROJECT_DIR/config/openclaw.json" "$OPENCLAW_HOME/openclaw.json"
    ok "openclaw.json deployed"

    # SOUL.md
    cp "$PROJECT_DIR/templates/SOUL.md" "$WORKSPACE/SOUL.md"
    ok "SOUL.md deployed to workspace"

    # BOOT.md
    cp "$PROJECT_DIR/templates/BOOT.md" "$WORKSPACE/BOOT.md"
    ok "BOOT.md deployed to workspace"

    # Skills
    cp -r "$PROJECT_DIR/workspace/skills/"* "$WORKSPACE/skills/"
    ok "Skills deployed"

    # Seed memory files (only if they don't already exist)
    for f in journal.md knowledge.md projects.md; do
        if [[ ! -f "$WORKSPACE/memory/$f" ]]; then
            cp "$PROJECT_DIR/workspace/memory/$f" "$WORKSPACE/memory/$f"
            ok "Seeded memory/$f"
        else
            warn "memory/$f already exists — skipping"
        fi
    done
}

# --------------------------------------------------------------------------
# Environment / secrets
# --------------------------------------------------------------------------

setup_env() {
    info "Checking environment variables..."

    local needs_env=false

    if [[ -f "$ENV_FILE" ]]; then
        # shellcheck disable=SC1090
        source "$ENV_FILE"
    fi

    if [[ -z "${OPENROUTER_API_KEY:-}" ]]; then
        warn "OPENROUTER_API_KEY not set"
        echo "  Get one at https://openrouter.ai/keys"
        read -rp "  Enter your OpenRouter API key (or press Enter to skip): " key
        if [[ -n "$key" ]]; then
            echo "OPENROUTER_API_KEY=$key" >> "$ENV_FILE"
            ok "OpenRouter key saved to $ENV_FILE"
        else
            needs_env=true
        fi
    else
        ok "OPENROUTER_API_KEY is set"
    fi

    if [[ -z "${DISCORD_BOT_TOKEN:-}" ]]; then
        warn "DISCORD_BOT_TOKEN not set"
        echo "  Create a bot at https://discord.com/developers/applications"
        echo "  Enable MESSAGE CONTENT intent under Bot settings"
        read -rp "  Enter your Discord bot token (or press Enter to skip): " token
        if [[ -n "$token" ]]; then
            echo "DISCORD_BOT_TOKEN=$token" >> "$ENV_FILE"
            ok "Discord token saved to $ENV_FILE"
        else
            needs_env=true
        fi
    else
        ok "DISCORD_BOT_TOKEN is set"
    fi

    if [[ -f "$ENV_FILE" ]]; then
        chmod 600 "$ENV_FILE"
    fi

    if $needs_env; then
        warn "Some keys are missing. Add them to $ENV_FILE before starting."
    fi
}

# --------------------------------------------------------------------------
# Install useful system tools Aldric might want
# --------------------------------------------------------------------------

install_tools() {
    info "Checking useful system tools..."

    local tools=(python3 pip3 sqlite3 jq curl wget)
    local missing=()

    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &>/dev/null; then
            missing+=("$tool")
        fi
    done

    if (( ${#missing[@]} > 0 )); then
        warn "Optional tools not found: ${missing[*]}"
        read -rp "Install them via apt? [y/N] " install
        if [[ "$install" =~ ^[Yy]$ ]]; then
            sudo apt-get update -qq
            sudo apt-get install -y -qq python3 python3-pip sqlite3 jq curl wget
            ok "System tools installed"
        fi
    else
        ok "System tools available"
    fi
}

# --------------------------------------------------------------------------
# Systemd service (optional)
# --------------------------------------------------------------------------

setup_systemd() {
    read -rp "Set up OpenClaw as a systemd service (auto-start on boot)? [y/N] " service
    if [[ ! "$service" =~ ^[Yy]$ ]]; then
        return
    fi

    local service_file="/etc/systemd/system/openclaw.service"

    info "Creating systemd service..."

    sudo tee "$service_file" > /dev/null <<EOF
[Unit]
Description=OpenClaw Gateway — Aldric
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$HOME
EnvironmentFile=$ENV_FILE
ExecStart=$(command -v openclaw) daemon
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable openclaw.service
    ok "Systemd service created and enabled"
    echo "  Start now:  sudo systemctl start openclaw"
    echo "  View logs:  journalctl -u openclaw -f"
}

# --------------------------------------------------------------------------
# Main
# --------------------------------------------------------------------------

main() {
    echo ""
    echo "  ╔═══════════════════════════════════════╗"
    echo "  ║       Aldric — OpenClaw Setup         ║"
    echo "  ║  Long-duration autonomous cognition   ║"
    echo "  ╚═══════════════════════════════════════╝"
    echo ""

    check_prereqs
    echo ""
    install_openclaw
    echo ""
    create_directories
    echo ""
    deploy_config
    echo ""
    setup_env
    echo ""
    install_tools
    echo ""
    setup_systemd
    echo ""

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    ok "Setup complete!"
    echo ""
    echo "  Workspace:  $WORKSPACE"
    echo "  Config:     $OPENCLAW_HOME/openclaw.json"
    echo "  Secrets:    $ENV_FILE"
    echo ""
    echo "  Next steps:"
    echo "    1. Ensure API keys are set in $ENV_FILE"
    echo "    2. Invite your Discord bot to a server"
    echo "    3. Start: openclaw daemon"
    echo "    4. Pair:  openclaw pairing"
    echo ""
    echo "  Aldric will wake up, read BOOT.md, and orient himself."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

main "$@"
