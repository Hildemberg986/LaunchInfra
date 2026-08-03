#!/bin/bash
set -eo pipefail
# configuration management

# Detecta usuário real (funciona com sudo e root)
if [ "$(id -u)" = "0" ] && [ -n "$SUDO_USER" ]; then
    REAL_USER="$SUDO_USER"
elif [ "$(id -u)" = "0" ]; then
    REAL_USER="root"
else
    REAL_USER="$USER"
fi

HOME_DIR=$(getent passwd "$REAL_USER" 2>/dev/null | cut -d: -f6)
[ -z "$HOME_DIR" ] && HOME_DIR="/home/$REAL_USER"

# Valores padrão (usuário deve configurar com launchinfra config)
DOMINIO_BASE="${DOMINIO_BASE:-}"
EMAIL="${EMAIL:-}"

# Root vê/usa tudo, usuário normal só seu diretório
if [ "$REAL_USER" = "root" ]; then
    DIR_BASE="${DIR_BASE:-/var/www/projetos}"
    USER_DIR="$DIR_BASE"
    USER_CONFIG_DIR="/root/.config/launchinfra"
    USER_CONFIG_FILE="$USER_CONFIG_DIR/launchinfra.conf"
else
    DIR_BASE="${DIR_BASE:-/var/www/projetos}"
    USER_DIR="$DIR_BASE/$REAL_USER"
    USER_CONFIG_DIR="$HOME_DIR/.config/launchinfra"
    USER_CONFIG_FILE="$USER_CONFIG_DIR/launchinfra.conf"
fi

LOG_FILE="${LOG_FILE:-/var/log/launchinfra.log}"

CONFIG_DIR_SYSTEM="/etc/launchinfra"
CONFIG_FILE_SYSTEM="$CONFIG_DIR_SYSTEM/launchinfra.conf"

# shellcheck disable=SC2034
NGINX_AVAILABLE="/etc/nginx/sites-available"
# shellcheck disable=SC2034
NGINX_ENABLED="/etc/nginx/sites-enabled"

# Helper para comandos privilegiados
LAUNCHINFRA_HELPER="/usr/local/bin/launchinfra-helper"

run_helper() {
    if [ -x "$LAUNCHINFRA_HELPER" ]; then
        sudo "$LAUNCHINFRA_HELPER" "$@"
    else
        echo "❌ Helper não encontrado: $LAUNCHINFRA_HELPER"
        echo "   Reinstale o LaunchInfra: sudo apt install --reinstall launchinfra"
        return 1
    fi
}

load_config() {
    if [ -r "$CONFIG_FILE_SYSTEM" ]; then
        # shellcheck disable=SC1090
        . "$CONFIG_FILE_SYSTEM"
    fi
    if [ -r "$USER_CONFIG_FILE" ]; then
        # shellcheck disable=SC1090
        . "$USER_CONFIG_FILE"
    fi
}

save_config() {
    local key="$1" value="$2"
    mkdir -p "$USER_CONFIG_DIR" || return 1
    if grep -q "^$key=" "$USER_CONFIG_FILE" 2>/dev/null; then
        awk -v key="$key" -v value="$value" \
            'BEGIN{FS=OFS="="} $1==key{$0=key"=\""value"\""}1' \
            "$USER_CONFIG_FILE" >"$USER_CONFIG_FILE.tmp" &&
            mv "$USER_CONFIG_FILE.tmp" "$USER_CONFIG_FILE"
    else
        echo "$key=\"$value\"" >>"$USER_CONFIG_FILE"
    fi
}

show_config() {
    echo "Usuário:       $REAL_USER"
    echo "DOMINIO_BASE:  ${DOMINIO_BASE:-"(não configurado)"}"
    echo "EMAIL:         ${EMAIL:-"(não configurado)"}"
    echo "Diretório:     $USER_DIR"
    echo "LOG:           $LOG_FILE"
    [ "$REAL_USER" = "root" ] && echo "Modo:          ROOT (acesso total)"
    [ -r "$CONFIG_FILE_SYSTEM" ] && echo "System config: $CONFIG_FILE_SYSTEM"
    [ -r "$USER_CONFIG_FILE" ] && echo "User config:   $USER_CONFIG_FILE"
}

log_to_file() {
    local msg="$1"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    printf '[%s] [%s] %s\n' "$timestamp" "$REAL_USER" "$msg" | run_helper tee-log "$LOG_FILE"
}
