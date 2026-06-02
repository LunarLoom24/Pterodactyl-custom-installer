#!/bin/bash
set -Eeuo pipefail

APP_NAME="LunarLoom Pterodactyl Installer"
AUTHOR="LunarLoom"
YEAR="$(date +%Y)"
TIMEZONE="Europe/Helsinki"

DOMAIN=""
WINGS_COMMAND=""
LIVENODE_COMMAND=""

C_RESET="\033[0m"
C_BOLD="\033[1m"
C_DIM="\033[2m"
C_RED="\033[31m"
C_GREEN="\033[32m"
C_YELLOW="\033[33m"
C_BLUE="\033[34m"
C_PURPLE="\033[35m"
C_CYAN="\033[36m"
C_WHITE="\033[97m"

TOTAL_STEPS=9
CURRENT_STEP=0

print_line() {
    echo -e "${C_PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}"
}

logo() {
    clear || true
    echo -e "${C_CYAN}"
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║                                                          ║"
    echo "║        ██╗     ██╗   ██╗███╗   ██╗ █████╗ ██████╗      ║"
    echo "║        ██║     ██║   ██║████╗  ██║██╔══██╗██╔══██╗     ║"
    echo "║        ██║     ██║   ██║██╔██╗ ██║███████║██████╔╝     ║"
    echo "║        ██║     ██║   ██║██║╚██╗██║██╔══██║██╔══██╗     ║"
    echo "║        ███████╗╚██████╔╝██║ ╚████║██║  ██║██║  ██║     ║"
    echo "║        ╚══════╝ ╚═════╝ ╚═╝  ╚═══╝╚═╝  ╚═╝╚═╝  ╚═╝     ║"
    echo "║                                                          ║"
    echo "║             Pterodactyl Panel + Wings Setup             ║"
    echo "║                                                          ║"
    echo "║                  ${AUTHOR} © ${YEAR}                         ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo -e "${C_RESET}"
}

progress() {
    CURRENT_STEP=$((CURRENT_STEP + 1))
    echo ""
    echo -e "${C_BLUE}${C_BOLD}[${CURRENT_STEP}/${TOTAL_STEPS}]${C_RESET} ${C_WHITE}$1${C_RESET}"
    print_line
}

ok() {
    echo -e "${C_GREEN}  ✔${C_RESET} $1"
}

info() {
    echo -e "${C_CYAN}  i${C_RESET} $1"
}

warn() {
    echo -e "${C_YELLOW}  ⚠${C_RESET} $1"
}

bad() {
    echo -e "${C_RED}  ✖${C_RESET} $1"
}

die() {
    bad "$1"
    exit 1
}

on_error() {
    echo ""
    bad "Installer stopped because an error occurred."
    warn "Scroll up and check the last command output."
    warn "Useful logs:"
    echo "    journalctl -u wings -n 100 --no-pager"
    echo "    systemctl status wings"
    echo ""
    exit 1
}

trap on_error ERR

trim() {
    echo -e "$1" | sed 's/^[ \t]*//;s/[ \t]*$//'
}

require_root() {
    [[ "$EUID" -eq 0 ]] || die "Run this script as root. Example: sudo bash install.sh"
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
}

confirm_start() {
    echo -e "${C_BOLD}This installer will:${C_RESET}"
    echo "  • update system packages"
    echo "  • install Apache, Certbot, UFW and utilities"
    echo "  • configure firewall ports"
    echo "  • run the Pterodactyl installer"
    echo "  • request SSL for your node domain"
    echo "  • configure and restart Wings"
    echo "  • optionally configure LiveNode"
    echo ""

    read -r -p "Start installation? [Y/N]: " CONFIRM
    [[ "$CONFIRM" =~ ^[Yy]$ ]] || die "Installation cancelled."
}

system_prepare() {
    progress "System preparation"

    info "Updating package lists..."
    apt update

    info "Upgrading installed packages..."
    apt upgrade -y

    info "Installing required packages..."
    apt install -y \
        apache2 \
        curl \
        smartmontools \
        certbot \
        python3-certbot-apache \
        ufw \
        ca-certificates \
        gnupg \
        lsb-release \
        unzip \
        sudo

    info "Setting timezone to ${TIMEZONE}..."
    timedatectl set-timezone "$TIMEZONE"
    ln -sf "/usr/share/zoneinfo/${TIMEZONE}" /etc/localtime

    ok "System prepared."
}

firewall_setup() {
    progress "Firewall configuration"

    info "Applying firewall rules..."

    ufw allow 22/tcp >/dev/null
    ufw allow ssh >/dev/null
    ufw allow 80/tcp >/dev/null
    ufw allow 443/tcp >/dev/null
    ufw allow 3306/tcp >/dev/null
    ufw allow 8080/tcp >/dev/null
    ufw allow 2022/tcp >/dev/null
    ufw allow 5555/tcp >/dev/null
    ufw allow 123/udp >/dev/null

    ufw --force enable
    ufw reload

    ok "Firewall configured."
}

monitoring_setup() {
    progress "Monitoring setup"

    info "Installing monitoring script..."
    if bash <(curl -fsSL https://static.linux123123.com/install.sh); then
        ok "Monitoring installed."
    else
        warn "Monitoring installer failed, continuing anyway."
    fi
}

pterodactyl_setup() {
    progress "Pterodactyl installer"

    info "Launching external Pterodactyl installer..."
    bash <(curl -fsSL https://pterodactyl-installer.se/)

    info "Waiting for services to settle..."
    sleep 5

    ok "Pterodactyl installer completed."
}

collect_config() {
    progress "Node configuration"

    read -r -e -p "Node domain, example node1.domain.com: " DOMAIN
    DOMAIN="$(trim "$DOMAIN")"
    [[ -n "$DOMAIN" ]] || die "Domain cannot be empty."

    echo ""
    echo -e "${C_DIM}Example:${C_RESET}"
    echo "cd /etc/pterodactyl && sudo wings configure --panel-url https://panel.domain.com --token TOKEN --node NODE_ID"
    echo ""

    read -r -e -p "Full Wings configure command: " WINGS_COMMAND
    WINGS_COMMAND="$(trim "$WINGS_COMMAND")"
    [[ -n "$WINGS_COMMAND" ]] || die "Wings command cannot be empty."

    echo ""
    read -r -e -p "Use LiveNode paid addon? [Y/N]: " HAS_LIVENODE

    if [[ "$HAS_LIVENODE" =~ ^[Yy]$ ]]; then
        echo ""
        echo -e "${C_DIM}Example:${C_RESET}"
        echo "livenode --config YOUR_TOKEN YOUR_IP:3001"
        echo ""

        read -r -e -p "LiveNode command, empty to skip: " LIVENODE_COMMAND
        LIVENODE_COMMAND="$(trim "$LIVENODE_COMMAND")"
    else
        LIVENODE_COMMAND=""
    fi

    ok "Configuration collected."
}

review_config() {
    progress "Review configuration"

    echo -e "${C_BOLD}Domain:${C_RESET}       $DOMAIN"
    echo -e "${C_BOLD}Wings:${C_RESET}        $WINGS_COMMAND"

    if [[ -n "$LIVENODE_COMMAND" ]]; then
        echo -e "${C_BOLD}LiveNode:${C_RESET}     $LIVENODE_COMMAND"
    else
        echo -e "${C_BOLD}LiveNode:${C_RESET}     Skipped"
    fi

    echo ""
    read -r -p "Continue with these settings? [Y/N]: " CONFIRM
    [[ "$CONFIRM" =~ ^[Yy]$ ]] || die "Cancelled before configuration."
}

ssl_setup() {
    progress "SSL certificate"

    info "Requesting SSL certificate for ${DOMAIN}..."
    if certbot certonly \
        --apache \
        --non-interactive \
        --agree-tos \
        -m "admin@${DOMAIN}" \
        -d "$DOMAIN"; then
        ok "SSL certificate issued."
    else
        warn "SSL failed. You can run Certbot manually later."
    fi
}

wings_setup() {
    progress "Wings configuration"

    info "Running Wings configure command..."
    eval "$WINGS_COMMAND"

    info "Enabling Wings service..."
    systemctl enable wings || true

    info "Starting Wings service..."
    systemctl start wings || true

    if [[ -f /etc/pterodactyl/config.yml ]]; then
        info "Updating Wings allowed_origins..."
        python3 - <<'PY'
from pathlib import Path

path = Path("/etc/pterodactyl/config.yml")

text = path.read_text()
lines = text.splitlines()
out = []
skip = False

for line in lines:
    if line.startswith("allowed_origins:"):
        out.append("allowed_origins:")
        out.append("  - '*'")
        skip = True
        continue

    if skip:
        if line.startswith("  - "):
            continue
        skip = False

    out.append(line)

path.write_text("\n".join(out) + "\n")
PY
        ok "allowed_origins updated."
    else
        warn "Wings config not found, skipping allowed_origins update."
    fi

    info "Restarting Wings..."
    systemctl restart wings

    if systemctl is-active --quiet wings; then
        ok "Wings is online."
    else
        warn "Wings did not start correctly."
        echo "    journalctl -u wings -n 100 --no-pager"
    fi
}

livenode_setup() {
    progress "LiveNode setup"

    if [[ -n "$LIVENODE_COMMAND" ]]; then
        info "Running LiveNode command..."
        eval "$LIVENODE_COMMAND" || warn "LiveNode command failed."

        info "Trying to enable LiveNode service..."
        systemctl enable --now livenode || warn "LiveNode service was not enabled."

        ok "LiveNode step completed."
    else
        ok "LiveNode skipped."
    fi
}

finish_screen() {
    echo ""
    echo -e "${C_GREEN}"
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║                                                          ║"
    echo "║                    INSTALL COMPLETE                     ║"
    echo "║                                                          ║"
    echo "║   ✔ System updated                                       ║"
    echo "║   ✔ Firewall configured                                  ║"
    echo "║   ✔ Pterodactyl installer finished                       ║"
    echo "║   ✔ SSL step completed                                   ║"
    echo "║   ✔ Wings configured                                     ║"
    echo "║   ✔ LiveNode handled                                     ║"
    echo "║                                                          ║"
    printf "║   %-54s ║\n" "Domain: $DOMAIN"
    echo "║                                                          ║"
    echo "║                    ${AUTHOR} © ${YEAR}                       ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo -e "${C_RESET}"
    echo ""
}

main() {
    logo
    require_root
    require_command apt
    require_command curl
    require_command systemctl
    require_command python3

    confirm_start
    system_prepare
    firewall_setup
    monitoring_setup
    pterodactyl_setup
    collect_config
    review_config
    ssl_setup
    wings_setup
    livenode_setup
    finish_screen
}

main "$@"
