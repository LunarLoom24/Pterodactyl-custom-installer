#!/bin/bash
set -e

# ==========================================
# Pterodactyl Wings Auto Updater
# Made by LunarLoom © $(date +%Y)
# ==========================================

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

print_banner() {
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════╗"
    echo "║           PTERODACTYL WINGS UPDATER         ║"
    echo "║                                              ║"
    echo "║           Fast • Clean • Automatic           ║"
    echo "║                                              ║"
    echo "║           LunarLoom © $(date +%Y)                 ║"
    echo "╚══════════════════════════════════════════════╝"
    echo -e "${NC}"
}

step() {
    echo -e "${YELLOW}[➜]${NC} $1"
}

success() {
    echo -e "${GREEN}[✔]${NC} $1"
}

error() {
    echo -e "${RED}[✖]${NC} $1"
}

print_banner

if [[ $EUID -ne 0 ]]; then
    error "Please run as root."
    exit 1
fi

ARCH=$(uname -m)

case "$ARCH" in
    x86_64)
        BINARY_ARCH="amd64"
        ;;
    aarch64|arm64)
        BINARY_ARCH="arm64"
        ;;
    *)
        error "Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

step "Detected architecture: $BINARY_ARCH"

step "Stopping Wings service..."
systemctl stop wings
success "Wings service stopped."

step "Downloading latest Wings release..."
curl -L -o /usr/local/bin/wings \
"https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_${BINARY_ARCH}"
success "Latest Wings downloaded."

step "Updating permissions..."
chmod +x /usr/local/bin/wings
success "Binary marked as executable."

step "Starting Wings service..."
systemctl restart wings
success "Wings service started."

step "Verifying service status..."

if systemctl is-active --quiet wings; then
    STATUS="ONLINE"
    STATUS_COLOR="${GREEN}"
else
    STATUS="OFFLINE"
    STATUS_COLOR="${RED}"
fi

echo ""
echo -e "${STATUS_COLOR}╔══════════════════════════════════════════════╗"
echo "║              UPDATE COMPLETED               ║"
echo "║                                              ║"
echo "║  ✓ Latest Wings version installed           ║"
echo "║  ✓ Permissions updated                      ║"
echo "║  ✓ Service restarted                        ║"
printf "║  ✓ Status: %-32s║\n" "$STATUS"
echo "║                                              ║"
echo "║  LunarLoom © $(date +%Y)                        ║"
echo -e "╚══════════════════════════════════════════════╝${NC}"
echo ""
