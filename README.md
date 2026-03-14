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
    ├── bootstrap.sh        # OS-level package/driver installation (run first)
    ├── setup.sh            # App-level install and deploy (OpenClaw, Ollama, Claude Code)
    └── harden.sh           # Security hardening (firewall, SSH, fail2ban)
```

## Host Setup

Aldric targets **Ubuntu Server 24.04 LTS (minimal install)** on a dedicated host.
The minimal image has several networking issues out of the box: no netplan config (no
DHCP), no `systemd-resolved` (broken DNS symlink), and `nsswitch.conf` references a
missing `resolve` module.

### 1. Fix networking (mandatory on minimal install)

The minimal installer may not configure your network interface. Check and fix in order:

```bash
# Check if you have a default route
ip route | grep default

# If blank: no netplan config exists — create one for DHCP
# Find your interface name first:
ip link show                    # look for your ethernet device (e.g. enp9s0)
sudo tee /etc/netplan/01-netcfg.yaml <<'EOF'
network:
  version: 2
  ethernets:
    enp9s0:                     # replace with your interface from: ip link show
      dhcp4: true
EOF
sudo netplan apply

# Verify you now have an IP and gateway
ip route | grep default         # should show a route via your router

# Fix DNS: resolv.conf is a broken symlink (systemd-resolved not installed)
sudo rm -f /etc/resolv.conf
echo "nameserver $(ip route | grep default | awk '{print $3}')" | sudo tee /etc/resolv.conf

# Fix nsswitch.conf (resolve module is missing on minimal)
sudo sed -i 's/^hosts:.*/hosts:          files dns/' /etc/nsswitch.conf

# Verify DNS works
getent hosts archive.ubuntu.com

# Install the permanent DNS fix
sudo apt update && sudo apt install -y systemd-resolved
sudo ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
sudo systemctl enable --now systemd-resolved
```

### 2. Clone and bootstrap

```bash
sudo apt install -y git curl openssh-server
sudo systemctl enable --now ssh

git clone <this-repo> ~/Aldric
cd ~/Aldric
sudo ./scripts/bootstrap.sh    # installs packages, NVIDIA drivers, Node.js, etc.
sudo reboot                    # required if NVIDIA drivers were installed
```

### 3. Set up SSH key access

Do this **before** running `harden.sh` — it disables password authentication.

```bash
# On the server: find your LAN IP
ip addr show | grep "inet "

# On your local machine (skip if you already have a key pair)
ssh-keygen -t ed25519

# Copy your public key to the server (while password auth still works)
ssh-copy-id your-user@<server-ip>

# Test key-based login
ssh your-user@<server-ip>
```

For reliable access, assign the server a static IP or a DHCP reservation in your router.

> `harden.sh` automatically copies the operator's SSH keys to the `aldric` service account, so you only need to do this once for your own user.

### 4. App setup and hardening

```bash
cd ~/Aldric
nvidia-smi                     # verify GPU after reboot
./scripts/setup.sh             # OpenClaw, Ollama, Claude Code, workspace
sudo ./scripts/harden.sh       # firewall, SSH lockdown, fail2ban, service account
```

### What each script does

- **`bootstrap.sh`** — OS-level packages: NVIDIA drivers, Node.js 22, Python 3, build tools, security tools. Idempotent — safe to re-run.
- **`setup.sh`** — App-level: installs OpenClaw, Ollama, Claude Code; deploys config and workspace; optionally creates a systemd service.
- **`harden.sh`** — Security: creates a dedicated `aldric` service account (no sudo), configures UFW firewall with SSH rate limiting, hardens SSH (key-only), sets up fail2ban, applies kernel security parameters, enforces AppArmor. Re-runnable as a compliance audit.

## Key Design Decisions

- **OpenRouter multi-model**: Primary Sonnet with Opus/Gemini/DeepSeek failover
- **Discord channel**: Rich interaction with message history
- **No sandbox**: Full host exec access for maximum autonomy
- **Heartbeat every 30m**: Aldric wakes up even without messages
- **Cron jobs**: Memory maintenance (6h) and self-reflection (nightly)
- **Session idle reset at 24h**: Long conversation continuity

## License

GPL-3.0
