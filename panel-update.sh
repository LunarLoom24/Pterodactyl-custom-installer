#!/bin/bash
set -e

# -------------------------------------
# Pterodactyl Panel Auto Updater
# Code made by LunarLoom © $(date +%Y)
# -------------------------------------

PANEL_DIR="/var/www/pterodactyl"
WEBUSER="www-data"
BACKUP_DIR="/root/pterodactyl-backups"

GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
BLUE="\e[34m"
CYAN="\e[36m"
RESET="\e[0m"

TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)

banner() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════╗"
    echo "║              PTERODACTYL UPDATER                ║"
    echo "║                                                  ║"
    echo "║            Panel Update + Backup Tool            ║"
    echo "║                                                  ║"
    echo "║              LunarLoom © $(date +%Y)                  ║"
    echo "╚══════════════════════════════════════════════════╝"
    echo -e "${RESET}"
}

step() {
    echo -e "${YELLOW}➜ $1${RESET}"
}

success() {
    echo -e "${GREEN}✔ $1${RESET}"
}

fail() {
    echo -e "${RED}✖ $1${RESET}"
}

error_exit() {
    fail "Update failed!"
    echo -e "${YELLOW}Trying to disable maintenance mode...${RESET}"
    cd "$PANEL_DIR" 2>/dev/null && php artisan up 2>/dev/null || true
    exit 1
}

trap error_exit ERR

banner

if [ "$EUID" -ne 0 ]; then
    fail "Please run this script as root."
    exit 1
fi

step "Checking panel directory..."
if [ ! -d "$PANEL_DIR" ]; then
    fail "Panel directory not found: $PANEL_DIR"
    exit 1
fi

cd "$PANEL_DIR"
success "Panel directory found."

step "Checking required commands..."
command -v php >/dev/null 2>&1 || { fail "PHP is not installed."; exit 1; }
command -v composer >/dev/null 2>&1 || { fail "Composer is not installed."; exit 1; }
command -v curl >/dev/null 2>&1 || { fail "curl is not installed."; exit 1; }
command -v tar >/dev/null 2>&1 || { fail "tar is not installed."; exit 1; }
command -v mysqldump >/dev/null 2>&1 || { fail "mysqldump is not installed."; exit 1; }
success "All required commands are available."

step "Reading database details from .env..."

DB_NAME=$(grep '^DB_DATABASE=' .env | cut -d '=' -f2- | tr -d '"')
DB_USER=$(grep '^DB_USERNAME=' .env | cut -d '=' -f2- | tr -d '"')
DB_PASS=$(grep '^DB_PASSWORD=' .env | cut -d '=' -f2- | tr -d '"')
DB_HOST=$(grep '^DB_HOST=' .env | cut -d '=' -f2- | tr -d '"')

if [ -z "$DB_HOST" ]; then
    DB_HOST="127.0.0.1"
fi

if [ -z "$DB_NAME" ] || [ -z "$DB_USER" ]; then
    fail "Could not read database details from .env"
    exit 1
fi

success "Database details loaded."

step "Creating backup directory..."
mkdir -p "$BACKUP_DIR"
success "Backup directory ready: $BACKUP_DIR"

step "Backing up panel files..."
tar -czf "$BACKUP_DIR/panel-files-$TIMESTAMP.tar.gz" "$PANEL_DIR"
success "Panel files backed up."

step "Backing up database..."
mysqldump -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" > "$BACKUP_DIR/panel-database-$TIMESTAMP.sql"
success "Database backed up."

step "Enabling maintenance mode..."
php artisan down || true
success "Maintenance mode enabled."

step "Downloading latest Pterodactyl Panel release..."
curl -L https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz | tar -xzv
success "Latest panel release downloaded."

step "Setting permissions..."
chmod -R 755 storage/* bootstrap/cache
success "Permissions updated."

step "Installing Composer dependencies..."
composer install --no-dev --optimize-autoloader
success "Composer dependencies installed."

step "Clearing caches..."
php artisan view:clear
php artisan config:clear
php artisan cache:clear
php artisan route:clear
success "Caches cleared."

step "Running database migrations..."
php artisan migrate --seed --force
success "Database migrations completed."

step "Fixing ownership..."
chown -R "$WEBUSER:$WEBUSER" "$PANEL_DIR"/*
success "Ownership fixed."

step "Restarting queue workers..."
php artisan queue:restart
success "Queue workers restarted."

step "Disabling maintenance mode..."
php artisan up
success "Maintenance mode disabled."

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════╗"
echo "║              UPDATE COMPLETED                   ║"
echo "║                                                  ║"
echo "║  ✔ Panel files backed up                         ║"
echo "║  ✔ Database backed up                            ║"
echo "║  ✔ Latest release installed                      ║"
echo "║  ✔ Composer dependencies updated                 ║"
echo "║  ✔ Database migrations completed                 ║"
echo "║  ✔ Queue workers restarted                       ║"
echo "║  ✔ Maintenance mode disabled                     ║"
echo "║                                                  ║"
echo "║  Backup location:                                ║"
echo "║  $BACKUP_DIR"
echo "║                                                  ║"
echo "║  LunarLoom © $(date +%Y)                              ║"
echo -e "╚══════════════════════════════════════════════════╝${RESET}"
echo ""
