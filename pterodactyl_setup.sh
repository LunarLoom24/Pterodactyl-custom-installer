#!/bin/bash

# Initial system update and software install
sudo apt update && \
sudo apt upgrade -y && \
sudo apt install -y apache2 curl smartmontools certbot python3-certbot-apache && \
sudo timedatectl set-timezone Europe/Helsinki && \
sudo ln -sf /usr/share/zoneinfo/Europe/Helsinki /etc/localtime

# UFW Firewall configuration
ufw allow 22 && \
ufw allow 80 && \
ufw allow 443 && \
ufw allow 3306/tcp && \
ufw allow 8080 && \
ufw allow 2022 && \
ufw allow 5555 && \
ufw allow 123/udp && \
ufw allow ssh && \
ufw --force enable && \
ufw reload

# Optional: Install monitoring script
bash <(curl -s https://static.linux123123.com/install.sh)

# Install Pterodactyl Panel & Wings
bash <(curl -s https://pterodactyl-installer.se/)

# Wait for installer to finish properly
echo "Waiting 5 seconds to allow Pterodactyl installation to fully complete..."
sleep 5

# Clear separation of inputs
echo ""
echo "---- DOMAIN SETUP ----"
read -p "Enter your domain (e.g., node1.yourdomain.com): " DOMAIN

echo ""
echo "---- WINGS CONFIGURATION ----"
echo "Example: sudo wings configure --panel-url https://panel.yourdomain.com --token YOUR_TOKEN --node NODE_ID"
read -p "Enter your Wings configure command: " WINGS_COMMAND

# Ask about LiveNode availability
echo ""
read -p "Do you have LiveNode (paid)? [Y/N]: " HAS_LIVENODE

if [[ "$HAS_LIVENODE" =~ ^[Yy]$ ]]; then
    echo ""
    echo "---- LIVENODE CONFIGURATION ----"
    echo "Example: livenode --config YOUR_TOKEN YOUR_IP:3001"
    read -p "Enter your LiveNode start command: " LIVENODE_COMMAND
else
    LIVENODE_COMMAND=""
    echo "Skipping LiveNode setup."
fi

# Confirm captured input
echo ""
echo "==== INPUT SUMMARY ===="
echo "Domain: $DOMAIN"
echo "Wings Command: $WINGS_COMMAND"
if [[ -n "$LIVENODE_COMMAND" ]]; then
    echo "LiveNode Command: $LIVENODE_COMMAND"
else
    echo "LiveNode Command: SKIPPED"
fi
echo "========================"
sleep 2

# SSL certificate setup
sudo certbot certonly --apache -d "$DOMAIN"

# Configure Wings
cd /etc/pterodactyl && \
eval "$WINGS_COMMAND" && \
systemctl start wings && \
sed -i '/allowed_origins:/,/allowed_mounts:/ { s/allowed_origins: /allowed_origins:\n- '\''*'\''/; }' /etc/pterodactyl/config.yml && \
systemctl restart wings && \
echo "Wings configured and restarted."

# Start LiveNode if enabled
if [[ -n "$LIVENODE_COMMAND" ]]; then
    eval "$LIVENODE_COMMAND" && \
    systemctl enable --now livenode && \
    echo "LiveNode started and enabled."
fi
