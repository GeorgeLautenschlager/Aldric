#!/usr/bin/env bash
set -euo pipefail

# Aldric — Security Hardening Script
# Locks down an Ubuntu Server host for running an autonomous AI agent with
# unrestricted exec access. This script is re-runnable as a compliance audit.
#
# Run AFTER setup.sh. Requires root.
#
# Usage: sudo ./scripts/harden.sh

# Colors (match setup.sh)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${CYAN}[info]${NC} $*"; }
ok()    { echo -e "${GREEN}[ok]${NC} $*"; }
warn()  { echo -e "${YELLOW}[warn]${NC} $*"; }
err()   { echo -e "${RED}[error]${NC} $*" >&2; }

ALDRIC_USER="aldric"
SSH_HARDENED_CONF="/etc/ssh/sshd_config.d/hardened.conf"
SYSCTL_CONF="/etc/sysctl.d/99-aldric-hardened.conf"
JOURNALD_CONF_DIR="/etc/systemd/journald.conf.d"

# Track the operator (the user who invoked sudo)
OPERATOR="${SUDO_USER:-$(whoami)}"

# --------------------------------------------------------------------------
# Root check
# --------------------------------------------------------------------------

if [[ $EUID -ne 0 ]]; then
    err "This script must be run as root (use sudo)"
    exit 1
fi

# --------------------------------------------------------------------------
# Create dedicated service account
# --------------------------------------------------------------------------

create_service_account() {
    info "Configuring service account '$ALDRIC_USER'..."

    if id "$ALDRIC_USER" &>/dev/null; then
        ok "User '$ALDRIC_USER' already exists"
    else
        useradd --create-home --shell /bin/bash "$ALDRIC_USER"
        ok "User '$ALDRIC_USER' created"
    fi

    # Add to video and render groups for GPU access
    usermod -aG video,render "$ALDRIC_USER" 2>/dev/null || true
    ok "$ALDRIC_USER added to video,render groups (GPU access)"

    # Copy operator's SSH authorized_keys so they can SSH in as aldric
    local operator_keys="/home/${OPERATOR}/.ssh/authorized_keys"
    local aldric_ssh="/home/${ALDRIC_USER}/.ssh"

    if [[ -f "$operator_keys" ]]; then
        mkdir -p "$aldric_ssh"
        cp "$operator_keys" "$aldric_ssh/authorized_keys"
        chown -R "${ALDRIC_USER}:${ALDRIC_USER}" "$aldric_ssh"
        chmod 700 "$aldric_ssh"
        chmod 600 "$aldric_ssh/authorized_keys"
        ok "SSH keys copied from $OPERATOR to $ALDRIC_USER"
    else
        warn "No SSH keys found for $OPERATOR — you'll need to add them manually"
        warn "  mkdir -p $aldric_ssh && cp ~/.ssh/authorized_keys $aldric_ssh/"
    fi
}

# --------------------------------------------------------------------------
# Firewall (UFW)
# --------------------------------------------------------------------------

configure_firewall() {
    info "Configuring firewall..."

    if ! command -v ufw &>/dev/null; then
        err "ufw not installed — run bootstrap.sh first"
        return 1
    fi

    # Reset to clean state (idempotent)
    ufw --force reset &>/dev/null

    ufw default deny incoming
    ufw default allow outgoing

    # SSH with rate limiting (critical for internet-exposed box)
    # Limits to 6 connections per 30 seconds from a single IP
    ufw limit ssh

    # Ollama binds to localhost by default — no rule needed.
    # Discord bot connects outbound via WebSocket — no inbound rule needed.

    ufw --force enable
    ok "Firewall enabled (deny incoming, allow outgoing, SSH rate-limited)"
}

# --------------------------------------------------------------------------
# SSH hardening
# --------------------------------------------------------------------------

harden_ssh() {
    info "Hardening SSH configuration..."

    # SAFETY CHECK: Verify at least one authorized_keys file exists
    # before disabling password authentication to prevent lockout
    local has_keys=false

    for user_home in /home/*; do
        if [[ -f "${user_home}/.ssh/authorized_keys" ]] && [[ -s "${user_home}/.ssh/authorized_keys" ]]; then
            has_keys=true
            break
        fi
    done

    if [[ -f /root/.ssh/authorized_keys ]] && [[ -s /root/.ssh/authorized_keys ]]; then
        has_keys=true
    fi

    if ! $has_keys; then
        warn "No SSH authorized_keys found for any user!"
        warn "Skipping password auth disable to prevent lockout"
        warn "Add your SSH public key first, then re-run this script"
        echo ""
        echo "  On your local machine:"
        echo "    ssh-copy-id ${OPERATOR}@<this-server-ip>"
        echo "  Then re-run: sudo ./scripts/harden.sh"
        return
    fi

    # Write drop-in config (takes precedence over main sshd_config)
    mkdir -p "$(dirname "$SSH_HARDENED_CONF")"
    cat > "$SSH_HARDENED_CONF" <<EOF
# Aldric — SSH hardening (managed by harden.sh)
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
AuthenticationMethods publickey
X11Forwarding no
AllowTcpForwarding no
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2
AllowUsers ${OPERATOR} ${ALDRIC_USER}
EOF

    # Validate config before restarting
    if sshd -t 2>/dev/null; then
        systemctl restart sshd
        ok "SSH hardened (key-only, root disabled, AllowUsers: $OPERATOR $ALDRIC_USER)"
    else
        err "SSH config validation failed — reverting"
        rm -f "$SSH_HARDENED_CONF"
        return 1
    fi
}

# --------------------------------------------------------------------------
# Automatic security updates
# --------------------------------------------------------------------------

configure_auto_updates() {
    info "Configuring automatic security updates..."

    # Security updates only — no feature updates
    cat > /etc/apt/apt.conf.d/50unattended-upgrades <<'EOF'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}-security";
    "${distro_id}ESMApps:${distro_codename}-apps-security";
};
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
// Do NOT auto-reboot — Aldric runs 24h sessions, operator handles reboots
Unattended-Upgrade::Automatic-Reboot "false";
EOF

    # Enable the daily check
    cat > /etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF

    ok "Auto security updates enabled (no auto-reboot)"
}

# --------------------------------------------------------------------------
# Fail2ban
# --------------------------------------------------------------------------

configure_fail2ban() {
    info "Configuring fail2ban..."

    if ! command -v fail2ban-client &>/dev/null; then
        err "fail2ban not installed — run bootstrap.sh first"
        return 1
    fi

    cat > /etc/fail2ban/jail.local <<'EOF'
[DEFAULT]
banaction = ufw

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 5
bantime = 3600
findtime = 600
EOF

    systemctl enable --now fail2ban
    ok "Fail2ban enabled (SSH: 5 retries, 1h ban, 10m window)"
}

# --------------------------------------------------------------------------
# Kernel hardening (sysctl)
# --------------------------------------------------------------------------

harden_kernel() {
    info "Applying kernel security parameters..."

    cat > "$SYSCTL_CONF" <<'EOF'
# Aldric — kernel hardening (managed by harden.sh)

# Disable IP forwarding (this is not a router)
net.ipv4.ip_forward = 0
net.ipv6.conf.all.forwarding = 0

# Ignore ICMP redirects (prevent MITM)
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0

# Ignore source-routed packets
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0

# Enable SYN flood protection
net.ipv4.tcp_syncookies = 1

# Log Martian packets (impossible source addresses)
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1

# Ignore ICMP broadcast requests (Smurf attack protection)
net.ipv4.icmp_echo_ignore_broadcasts = 1

# Ignore bogus ICMP error responses
net.ipv4.icmp_ignore_bogus_error_responses = 1

# Enable reverse path filtering (anti-spoofing)
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Restrict kernel pointer exposure
kernel.kptr_restrict = 2

# Restrict dmesg to root only
kernel.dmesg_restrict = 1

# Full ASLR (Address Space Layout Randomization)
kernel.randomize_va_space = 2
EOF

    sysctl --system &>/dev/null
    ok "Kernel security parameters applied"
}

# --------------------------------------------------------------------------
# AppArmor enforcement
# --------------------------------------------------------------------------

enforce_apparmor() {
    info "Enforcing AppArmor profiles..."

    if ! command -v aa-enforce &>/dev/null; then
        warn "AppArmor utils not installed — skipping"
        return
    fi

    # Enforce all loaded profiles
    aa-enforce /etc/apparmor.d/* 2>/dev/null || true

    local enforced
    enforced=$(aa-status 2>/dev/null | grep -c "enforce" || echo "0")
    ok "AppArmor: $enforced profiles in enforce mode"
}

# --------------------------------------------------------------------------
# Disable unnecessary services
# --------------------------------------------------------------------------

disable_unnecessary_services() {
    info "Disabling unnecessary services..."

    local services=(cups avahi-daemon bluetooth ModemManager)
    local disabled=0

    for svc in "${services[@]}"; do
        if systemctl is-enabled "$svc" &>/dev/null; then
            systemctl disable --now "$svc" 2>/dev/null || true
            info "  Disabled: $svc"
            ((disabled++))
        fi
    done

    if (( disabled == 0 )); then
        ok "No unnecessary services found (minimal install — good)"
    else
        ok "Disabled $disabled unnecessary service(s)"
    fi
}

# --------------------------------------------------------------------------
# Logging
# --------------------------------------------------------------------------

configure_logging() {
    info "Configuring persistent logging..."

    mkdir -p "$JOURNALD_CONF_DIR"
    cat > "${JOURNALD_CONF_DIR}/aldric.conf" <<'EOF'
[Journal]
Storage=persistent
SystemMaxUse=500M
MaxFileSec=1month
EOF

    systemctl restart systemd-journald
    ok "Journald: persistent storage, 500M cap, 1-month rotation"
}

# --------------------------------------------------------------------------
# File permissions
# --------------------------------------------------------------------------

set_file_permissions() {
    info "Setting file permissions..."

    local aldric_home="/home/${ALDRIC_USER}"

    if [[ -d "$aldric_home" ]]; then
        chmod 700 "$aldric_home"
        ok "Home directory: 700"
    fi

    # Secure the env file if it exists
    local env_file="${aldric_home}/.openclaw/.env"
    if [[ -f "$env_file" ]]; then
        chmod 600 "$env_file"
        chown "${ALDRIC_USER}:${ALDRIC_USER}" "$env_file"
        ok "Env file: 600"
    fi

    # Scripts should be readable by owner/group, not world
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    chmod 750 "$script_dir"/*.sh 2>/dev/null || true
    ok "Scripts: 750"
}

# --------------------------------------------------------------------------
# Audit summary
# --------------------------------------------------------------------------

print_audit_summary() {
    echo ""
    echo "  ╔═══════════════════════════════════════╗"
    echo "  ║         Security Audit Summary        ║"
    echo "  ╚═══════════════════════════════════════╝"
    echo ""

    echo "  Firewall:"
    ufw status | sed 's/^/    /'
    echo ""

    echo "  Fail2ban:"
    fail2ban-client status sshd 2>/dev/null | sed 's/^/    /' || echo "    Not running"
    echo ""

    echo "  AppArmor:"
    aa-status 2>/dev/null | head -3 | sed 's/^/    /' || echo "    Not available"
    echo ""

    echo "  SSH:"
    if [[ -f "$SSH_HARDENED_CONF" ]]; then
        echo "    Key-only auth: YES"
        echo "    Root login: DISABLED"
        echo "    Allowed users: ${OPERATOR} ${ALDRIC_USER}"
    else
        echo -e "    ${YELLOW}Password auth still enabled (no SSH keys found)${NC}"
    fi
    echo ""

    echo "  Service account:"
    if id "$ALDRIC_USER" &>/dev/null; then
        echo "    User: $ALDRIC_USER"
        echo "    Groups: $(id -nG "$ALDRIC_USER" 2>/dev/null)"
        echo "    Home: /home/$ALDRIC_USER"
    else
        echo -e "    ${YELLOW}Not created${NC}"
    fi
    echo ""

    echo "  Auto-updates: security patches only, no auto-reboot"
    echo "  Kernel hardening: applied via $SYSCTL_CONF"
    echo ""
}

# --------------------------------------------------------------------------
# Main
# --------------------------------------------------------------------------

main() {
    echo ""
    echo "  ╔═══════════════════════════════════════╗"
    echo "  ║     Aldric — Security Hardening       ║"
    echo "  ║  Internet-exposed host lockdown       ║"
    echo "  ╚═══════════════════════════════════════╝"
    echo ""

    create_service_account
    echo ""
    configure_firewall
    echo ""
    harden_ssh
    echo ""
    configure_auto_updates
    echo ""
    configure_fail2ban
    echo ""
    harden_kernel
    echo ""
    enforce_apparmor
    echo ""
    disable_unnecessary_services
    echo ""
    configure_logging
    echo ""
    set_file_permissions
    echo ""

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    ok "Hardening complete!"
    print_audit_summary
    echo "  Next steps:"
    echo "    1. If setup.sh was run as $OPERATOR, re-run as $ALDRIC_USER"
    echo "       or move ~/.openclaw to /home/$ALDRIC_USER/.openclaw"
    echo "    2. Update the systemd service to run as $ALDRIC_USER"
    echo "    3. Verify SSH access: ssh $ALDRIC_USER@<this-server>"
    echo ""
    echo "  Re-run this script at any time to audit compliance."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

main "$@"
