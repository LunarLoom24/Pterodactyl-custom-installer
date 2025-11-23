#!/bin/bash
set -e

# ---------------------------
# Pretty output helpers
# ---------------------------
GREEN="\e[32m"
YELLOW="\e[33m"
RED="\e[31m"
RESET="\e[0m"

info() { echo -e "${GREEN}[INFO]${RESET} $1"; }
warn() { echo -e "${YELLOW}[WARN]${RESET} $1"; }
error() { echo -e "${RED}[ERROR]${RESET} $1"; }

# ---------------------------
# Root Check
# ---------------------------
if [[ "$EUID" -ne 0 ]]; then
    error "Please run this script as root (sudo su)."
    exit 1
fi

info "Starting installation..."

# ---------------------------
# System Update & Installation
# ---------------------------
info "Updating system and installing packages..."
apt update && apt upgrade -y
apt install -y apache2 curl smartmontools certbot python3-certbot-apache ufw

timedatectl set-timezone Europe/Helsinki
ln -sf /usr/share/zoneinfo/Europe/Helsinki /etc/localtime

# ---------------------------
# UFW Firewall Rules
# ---------------------------
info "Configuring UFW firewall..."

ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 3306/tcp
ufw allow 8080/tcp
ufw allow 2022/tcp
ufw allow 5555/tcp
ufw allow 123/udp
ufw allow ssh

ufw --force enable
ufw reload

info "Firewall configured."

# ---------------------------
# Optional: Monitoring Script
# ---------------------------
info "Installing monitoring script..."
bash <(curl -s https://static.linux123123.com/install.sh)

# ---------------------------
# Pterodactyl Installer
# ---------------------------
info "Installing Pterodactyl Panel and Wings..."
bash <(curl -s https://pterodactyl-installer.se/)

info "Waiting for install to settle..."
sleep 5

# ---------------------------
# Domain Input
# ---------------------------
echo ""
read -r -e -p "Enter your domain (example: node1.yourdomain.com): " DOMAIN
if [[ -z "$DOMAIN" ]]; then
    error "Domain cannot be empty!"
    exit 1
fi

# ---------------------------
# Wings Configuration Input
# ---------------------------
echo ""
info "Example command:"
echo "cd /etc/pterodactyl && sudo wings configure --panel-url https://panel.domain.com --token TOKEN --node NODE_ID"
read -r -e -p "Enter your full Wings configuration command: " WINGS_COMMAND

if [[ -z "$WINGS_COMMAND" ]]; then
    error "Wings command cannot be empty!"
    exit 1
fi

# Trim trailing spaces
WINGS_COMMAND="$(echo -e "${WINGS_COMMAND}" | sed 's/^[ \t]*//;s/[ \t]*$//')"

# ---------------------------
# LiveNode Input
# ---------------------------
echo ""
read -r -e -p "Do you have LiveNode (paid)? [Y/N]: " HAS_LIVENODE

if [[ "$HAS_LIVENODE" =~ ^[Yy]$ ]]; then
    echo ""
    info "Example: livenode --config YOUR_TOKEN YOUR_IP:3001"
    read -r -e -p "Enter your LiveNode command (leave empty to skip): " LIVENODE_COMMAND
else
    LIVENODE_COMMAND=""
fi

# Trim trailing spaces
LIVENODE_COMMAND="$(echo -e "${LIVENODE_COMMAND}" | sed 's/^[ \t]*//;s/[ \t]*$//')"

# ---------------------------
# Input Summary
# ---------------------------
echo ""
echo "==== INPUT SUMMARY ===="
echo " Domain:            $DOMAIN"
echo " Wings Command:     $WINGS_COMMAND"
if [[ -n "$LIVENODE_COMMAND" ]]; then
    echo " LiveNode Command:  $LIVENODE_COMMAND"
else
    echo " LiveNode Command:  SKIPPED"
fi
echo "========================"
sleep 2

# ---------------------------
# SSL Certificate
# ---------------------------
info "Issuing SSL certificate for $DOMAIN..."
certbot certonly --apache --non-interactive --agree-tos -m admin@"$DOMAIN" -d "$DOMAIN" || warn "Certbot failed. You may need to run it manually."

# ---------------------------
# Wings Configuration
# ---------------------------
info "Configuring Wings..."
eval "$WINGS_COMMAND"

systemctl start wings

# Fix allowed_origins formatting
if [[ -f /etc/pterodactyl/config.yml ]]; then
    sed -i "s/allowed_origins:.*/allowed_origins:\n  - '*'/g" /etc/pterodactyl/config.yml
fi

systemctl restart wings
info "Wings configured successfully."

# ---------------------------
# LiveNode Setup
# ---------------------------
if [[ -n "$LIVENODE_COMMAND" ]]; then
    info "Starting LiveNode..."
    eval "$LIVENODE_COMMAND"
    systemctl enable --now livenode || warn "LiveNode service setup failed, but command executed."
    info "LiveNode started."
else
    info "LiveNode skipped."
fi

info "Installation completed successfully!"

echo ""
echo "-------------------------------------"
echo "  Code made by LunarLoom © $(date +%Y)"
echo "-------------------------------------"
echo ""
