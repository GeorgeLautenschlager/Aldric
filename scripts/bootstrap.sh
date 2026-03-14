#!/usr/bin/env bash
set -euo pipefail

# Aldric — OS Bootstrap Script
# Transforms a fresh Ubuntu Server 24.04 LTS (minimal) install into a
# GPU-ready development host. Run with sudo.
#
# Usage: sudo ./scripts/bootstrap.sh

export DEBIAN_FRONTEND=noninteractive

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

NEEDS_REBOOT=false

# --------------------------------------------------------------------------
# Root check
# --------------------------------------------------------------------------

if [[ $EUID -ne 0 ]]; then
    err "This script must be run as root (use sudo)"
    exit 1
fi

# --------------------------------------------------------------------------
# Fix networking (Ubuntu 24.04 minimal install issues)
#
# The minimal install can have multiple networking problems:
# 1. No netplan config — interface never gets DHCP, no IP, no route
# 2. systemd-resolved not installed — /etc/resolv.conf is a broken symlink
# 3. nsswitch.conf references missing 'resolve' module
# We fix these first since everything else needs apt.
# --------------------------------------------------------------------------

fix_networking() {
    info "Checking network connectivity..."

    # Check for a default route (requires netplan to be configured)
    if ! ip route | grep -q default; then
        err "No default route — your network interface has no IP address"
        err "The minimal installer may not have created a netplan config."
        err ""
        err "Fix manually:"
        err "  1. Find your interface:  ip link show"
        err "  2. Create /etc/netplan/01-netcfg.yaml with DHCP enabled"
        err "  3. Run: sudo netplan apply"
        err "  4. Re-run this script"
        err ""
        err "See README.md step 1 for the full commands."
        exit 1
    fi
    ok "Default route exists"

    # Fix nsswitch.conf if it references the missing 'resolve' module
    if grep -qE '^hosts:.*\bresolve\b' /etc/nsswitch.conf 2>/dev/null; then
        warn "nsswitch.conf references missing 'resolve' module — fixing"
        sed -i 's/^hosts:.*/hosts:          files dns/' /etc/nsswitch.conf
        ok "nsswitch.conf fixed (hosts: files dns)"
    fi

    # Check if DNS resolution already works
    if getent hosts archive.ubuntu.com &>/dev/null; then
        ok "DNS resolution is working"
        return
    fi

    warn "DNS resolution failed — applying fix"

    # Verify raw network connectivity (not DNS) via bash built-in
    if ! bash -c 'echo > /dev/tcp/8.8.8.8/53' 2>/dev/null; then
        err "No network connectivity (cannot reach 8.8.8.8:53)"
        err "Check your network cable / netplan config and try again"
        exit 1
    fi
    ok "Network connectivity confirmed"

    # Write a temporary resolv.conf using the gateway IP (works even if
    # the network blocks external DNS like 8.8.8.8)
    local gateway
    gateway=$(ip route | grep default | awk '{print $3}')
    rm -f /etc/resolv.conf
    cat > /etc/resolv.conf <<EOF
nameserver ${gateway}
nameserver 8.8.8.8
EOF
    ok "Temporary DNS configured (${gateway}, 8.8.8.8)"

    # Install the permanent fix
    apt-get update -qq
    apt-get install -y -qq systemd-resolved
    ok "systemd-resolved installed"

    # Restore the proper symlink — systemd-resolved manages DNS from here
    ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
    systemctl enable --now systemd-resolved
    ok "DNS resolution restored via systemd-resolved"

    # Verify
    if getent hosts archive.ubuntu.com &>/dev/null; then
        ok "DNS verified — archive.ubuntu.com resolves"
    else
        err "DNS still not working after fix. Check network config."
        exit 1
    fi
}

# --------------------------------------------------------------------------
# System update
# --------------------------------------------------------------------------

system_update() {
    info "Updating system packages..."
    apt-get update -qq
    apt-get upgrade -y -qq
    apt-get install -y -qq software-properties-common
    ok "System updated"
}

# --------------------------------------------------------------------------
# Kernel headers (required for NVIDIA DKMS)
# --------------------------------------------------------------------------

install_kernel_headers() {
    if dpkg -l | grep -q "linux-headers-$(uname -r)"; then
        ok "Kernel headers already installed"
    else
        info "Installing kernel headers..."
        apt-get install -y -qq "linux-headers-$(uname -r)" linux-headers-generic
        ok "Kernel headers installed"
    fi
}

# --------------------------------------------------------------------------
# NVIDIA drivers
# --------------------------------------------------------------------------

install_nvidia_drivers() {
    if command -v nvidia-smi &>/dev/null && nvidia-smi &>/dev/null; then
        ok "NVIDIA drivers already working ($(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null || echo 'unknown'))"
        return
    fi

    info "Installing NVIDIA drivers..."
    apt-get install -y -qq ubuntu-drivers-common

    # Auto-detect and install the recommended driver for the GPU
    ubuntu-drivers install
    ok "NVIDIA drivers installed"

    NEEDS_REBOOT=true
}

# --------------------------------------------------------------------------
# Build essentials
# --------------------------------------------------------------------------

install_build_essentials() {
    if command -v gcc &>/dev/null; then
        ok "Build essentials already installed"
    else
        info "Installing build essentials..."
        apt-get install -y -qq build-essential pkg-config
        ok "Build essentials installed"
    fi
}

# --------------------------------------------------------------------------
# Node.js 22 (via NodeSource)
# --------------------------------------------------------------------------

install_nodejs() {
    if command -v node &>/dev/null; then
        local node_major
        node_major=$(node -v | sed 's/v//' | cut -d. -f1)
        if (( node_major >= 22 )); then
            ok "Node.js $(node -v) already installed"
            return
        else
            warn "Node.js $(node -v) found but 22+ required — upgrading"
        fi
    fi

    info "Installing Node.js 22..."
    curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
    apt-get install -y -qq nodejs
    ok "Node.js $(node -v) installed"
}

# --------------------------------------------------------------------------
# Python 3
# --------------------------------------------------------------------------

install_python() {
    if command -v python3 &>/dev/null && dpkg -l | grep -q python3-venv; then
        ok "Python3 already installed"
    else
        info "Installing Python3..."
        apt-get install -y -qq python3 python3-pip python3-venv
        ok "Python3 installed"
    fi
}

# --------------------------------------------------------------------------
# System tools
# --------------------------------------------------------------------------

install_system_tools() {
    info "Installing system tools..."
    apt-get install -y -qq sqlite3 jq curl wget htop tmux unzip
    ok "System tools installed (sqlite3, jq, curl, wget, htop, tmux, unzip)"
}

# --------------------------------------------------------------------------
# Security tools (installed here, configured by harden.sh)
# --------------------------------------------------------------------------

install_security_tools() {
    info "Installing security tools..."
    apt-get install -y -qq ufw fail2ban unattended-upgrades apparmor apparmor-utils
    ok "Security tools installed (ufw, fail2ban, unattended-upgrades, apparmor)"
}

# --------------------------------------------------------------------------
# Cleanup
# --------------------------------------------------------------------------

cleanup() {
    info "Cleaning up..."
    apt-get autoremove -y -qq
    apt-get clean
    ok "Cleanup complete"
}

# --------------------------------------------------------------------------
# Main
# --------------------------------------------------------------------------

main() {
    echo ""
    echo "  ╔═══════════════════════════════════════╗"
    echo "  ║     Aldric — OS Bootstrap             ║"
    echo "  ║  Ubuntu Server 24.04 LTS (minimal)    ║"
    echo "  ╚═══════════════════════════════════════╝"
    echo ""

    fix_networking
    echo ""
    system_update
    echo ""
    install_kernel_headers
    echo ""
    install_nvidia_drivers
    echo ""
    install_build_essentials
    echo ""
    install_nodejs
    echo ""
    install_python
    echo ""
    install_system_tools
    echo ""
    install_security_tools
    echo ""
    cleanup
    echo ""

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    ok "Bootstrap complete!"
    echo ""
    echo "  Installed:"
    echo "    Node.js:  $(node -v 2>/dev/null || echo 'not found')"
    echo "    npm:      $(npm -v 2>/dev/null || echo 'not found')"
    echo "    Python:   $(python3 --version 2>/dev/null || echo 'not found')"
    echo "    gcc:      $(gcc --version | head -1 2>/dev/null || echo 'not found')"
    echo ""

    if $NEEDS_REBOOT; then
        echo -e "  ${YELLOW}╔═══════════════════════════════════════════════════════╗${NC}"
        echo -e "  ${YELLOW}║  REBOOT REQUIRED — NVIDIA drivers need a kernel      ║${NC}"
        echo -e "  ${YELLOW}║  reload before the GPU will be available.             ║${NC}"
        echo -e "  ${YELLOW}║                                                       ║${NC}"
        echo -e "  ${YELLOW}║  Run:  sudo reboot                                   ║${NC}"
        echo -e "  ${YELLOW}║  Then: nvidia-smi  (to verify)                        ║${NC}"
        echo -e "  ${YELLOW}║  Then: ./scripts/setup.sh                             ║${NC}"
        echo -e "  ${YELLOW}╚═══════════════════════════════════════════════════════╝${NC}"
    else
        echo "  Next steps:"
        echo "    1. Run: ./scripts/setup.sh"
        echo "    2. Run: sudo ./scripts/harden.sh"
    fi
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

main "$@"
