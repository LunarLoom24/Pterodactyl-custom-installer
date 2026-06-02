#!/bin/bash
set -Eeuo pipefail

# ==================================================
# Pterodactyl Full Installer
# Panel + Wings + SSL + Firewall + Optional LiveNode
# Made by LunarLoom © $(date +%Y)
# ==================================================

APP_NAME="Pterodactyl Installer"
AUTHOR="LunarLoom"
YEAR="$(date +%Y)"
TIMEZONE="Europe/Helsinki"

GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[1;33m"
BLUE="\033[0;34m"
CYAN="\033[0;36m"
MAGENTA="\033[0;35m"
BOLD="\033[1m"
RESET="\033[0m"

DOMAIN=""
WINGS_COMMAND=""
LIVENODE_COMMAND=""

clear_screen() {
    clear || true
}

banner() {
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║                                                      ║"
    echo "║              PTERODACTYL AUTO INSTALLER             ║"
    echo "║                                                      ║"
    echo "║        Panel • Wings • SSL • Firewall • Tools        ║"
    echo "║                                                      ║"
    echo "║                 ${AUTHOR} © ${YEAR}                      ║"
    echo "╚══════════════════════════════════════════════════════╝"
    echo -e "${RESET}"
}

section() {
    echo ""
    echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${BOLD}${BLUE} $1${RESET}"
    echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
}

step() {
    echo -e "${YELLOW}➜${RESET} $1"
}

success() {
    echo -e "${GREEN}✔${RESET} $1"
}

warn() {
    echo -e "${YELLOW}⚠${RESET} $1"
}

fail() {
    echo -e "${RED}✖${RESET} $1"
}

pause_short() {
    sleep 1
}

on_error() {
    echo ""
    fail "Installation failed."
    warn "Check the error above, then rerun the script."
    echo ""
    exit 1
}

trap on_error ERR

require_root() {
    if [[ "${EUID}" -ne 0 ]]; then
        fail "Please run this script as root."
        echo "Use:"
        echo "  sudo su"
        echo "  bash installer.sh"
        exit 1
    fi
}

require_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        fail "Required command missing: $1"
        exit 1
    fi
}

confirm_continue() {
    echo ""
    warn "This script will update packages, configure firewall rules, install Pterodactyl, configure SSL, and run your Wings command."
    read -r -p "Continue? [Y/N]: " CONFIRM

    if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
        fail "Installation cancelled."
        exit 0
    fi
}

install_packages() {
    section "System Preparation"

    step "Updating system packages..."
    apt update
    apt upgrade -y
    success "System updated."

    step "Installing required packages..."
    apt install -y \
        apache2 \
        curl \
        smartmontools \
        certbot \
        python3-certbot-apache \
        ufw \
        ca-certificates \
        gnupg \
        lsb-release
    success "Required packages installed."

    step "Setting timezone to ${TIMEZONE}..."
    timedatectl set-timezone "$TIMEZONE"
    ln -sf "/usr/share/zoneinfo/${TIMEZONE}" /etc/localtime
    success "Timezone configured."
}

configure_firewall() {
    section "Firewall Configuration"

    step "Allowing required ports..."

    ufw allow 22/tcp
    ufw allow ssh
    ufw allow 80/tcp
    ufw allow 443/tcp
    ufw allow 3306/tcp
    ufw allow 8080/tcp
    ufw allow 2022/tcp
    ufw allow 5555/tcp
    ufw allow 123/udp

    ufw --force enable
    ufw reload

    success "Firewall rules applied."
}

install_monitoring() {
    section "Monitoring Setup"

    step "Installing monitoring script..."
    bash <(curl -fsSL https://static.linux123123.com/install.sh) || warn "Monitoring script failed, continuing..."
    success "Monitoring step completed."
}

install_pterodactyl() {
    section "Pterodactyl Installation"

    step "Starting Pterodactyl installer..."
    bash <(curl -fsSL https://pterodactyl-installer.se/)
    success "Pterodactyl installer finished."

    step "Waiting for services to settle..."
    sleep 5
    success "Ready for configuration."
}

collect_inputs() {
    section "Configuration Input"

    echo ""
    read -r -e -p "Enter node domain, example node1.domain.com: " DOMAIN

    if [[ -z "$DOMAIN" ]]; then
        fail "Domain cannot be empty."
        exit 1
    fi

    echo ""
    echo -e "${CYAN}Example Wings command:${RESET}"
    echo "cd /etc/pterodactyl && sudo wings configure --panel-url https://panel.domain.com --token TOKEN --node NODE_ID"
    echo ""

    read -r -e -p "Enter full Wings configuration command: " WINGS_COMMAND

    if [[ -z "$WINGS_COMMAND" ]]; then
        fail "Wings command cannot be empty."
        exit 1
    fi

    WINGS_COMMAND="$(echo -e "$WINGS_COMMAND" | sed 's/^[ \t]*//;s/[ \t]*$//')"

    echo ""
    read -r -e -p "Do you have LiveNode paid addon? [Y/N]: " HAS_LIVENODE

    if [[ "$HAS_LIVENODE" =~ ^[Yy]$ ]]; then
        echo ""
        echo -e "${CYAN}Example LiveNode command:${RESET}"
        echo "livenode --config YOUR_TOKEN YOUR_IP:3001"
        echo ""

        read -r -e -p "Enter LiveNode command, or leave empty to skip: " LIVENODE_COMMAND
        LIVENODE_COMMAND="$(echo -e "$LIVENODE_COMMAND" | sed 's/^[ \t]*//;s/[ \t]*$//')"
    else
        LIVENODE_COMMAND=""
    fi
}

show_summary() {
    section "Install Summary"

    echo -e "${BOLD}Domain:${RESET}        $DOMAIN"
    echo -e "${BOLD}Wings:${RESET}         $WINGS_COMMAND"

    if [[ -n "$LIVENODE_COMMAND" ]]; then
        echo -e "${BOLD}LiveNode:${RESET}      $LIVENODE_COMMAND"
    else
        echo -e "${BOLD}LiveNode:${RESET}      Skipped"
    fi

    echo ""
    read -r -p "Is this correct? [Y/N]: " SUMMARY_CONFIRM

    if [[ ! "$SUMMARY_CONFIRM" =~ ^[Yy]$ ]]; then
        fail "Installation cancelled by user."
        exit 0
    fi
}

setup_ssl() {
    section "SSL Certificate"

    step "Requesting SSL certificate for ${DOMAIN}..."

    certbot certonly \
        --apache \
        --non-interactive \
        --agree-tos \
        -m "admin@${DOMAIN}" \
        -d "$DOMAIN" || warn "Certbot failed. You may need to run it manually."

    success "SSL step completed."
}

configure_wings() {
    section "Wings Configuration"

    step "Running Wings configuration command..."
    eval "$WINGS_COMMAND"
    success "Wings configured."

    step "Starting Wings service..."
    systemctl enable wings || true
    systemctl start wings || true
    success "Wings service started."

    if [[ -f /etc/pterodactyl/config.yml ]]; then
        step "Fixing allowed_origins in Wings config..."
        sed -i "s/allowed_origins:.*/allowed_origins:\n  - '*'/g" /etc/pterodactyl/config.yml
        success "allowed_origins updated."
    else
        warn "Wings config file not found, skipping allowed_origins fix."
    fi

    step "Restarting Wings..."
    systemctl restart wings
    success "Wings restarted."

    if systemctl is-active --quiet wings; then
        success "Wings is running."
    else
        warn "Wings is not running. Check logs with:"
        echo "journalctl -u wings -n 100 --no-pager"
    fi
}

setup_livenode() {
    section "LiveNode Setup"

    if [[ -n "$LIVENODE_COMMAND" ]]; then
        step "Running LiveNode command..."
        eval "$LIVENODE_COMMAND" || warn "LiveNode command failed."

        step "Trying to enable LiveNode service..."
        systemctl enable --now livenode || warn "LiveNode service enable failed."

        success "LiveNode setup completed."
    else
        success "LiveNode skipped."
    fi
}

final_screen() {
    echo ""
    echo -e "${GREEN}"
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║                                                      ║"
    echo "║              INSTALLATION COMPLETED                 ║"
    echo "║                                                      ║"
    echo "║  ✔ System packages installed                         ║"
    echo "║  ✔ Firewall configured                               ║"
    echo "║  ✔ Pterodactyl installer completed                   ║"
    echo "║  ✔ SSL step completed                                ║"
    echo "║  ✔ Wings configured                                  ║"
    echo "║  ✔ LiveNode handled                                  ║"
    echo "║                                                      ║"
    echo "║  Domain: ${DOMAIN}"
    echo "║                                                      ║"
    echo "║  Code made by ${AUTHOR} © ${YEAR}                         ║"
    echo "╚══════════════════════════════════════════════════════╝"
    echo -e "${RESET}"
    echo ""
}

main() {
    clear_screen
    banner
    require_root
    require_command apt
    require_command curl
    require_command systemctl
    confirm_continue

    install_packages
    configure_firewall
    install_monitoring
    install_pterodactyl
    collect_inputs
    show_summary
    setup_ssl
    configure_wings
    setup_livenode
    final_screen
}

main "$@"
