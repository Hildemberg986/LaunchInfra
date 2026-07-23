#!/bin/bash
# configuration management

# Valores padrão (usuário deve configurar com launchinfra config)
DOMINIO_BASE="${DOMINIO_BASE:-}"
EMAIL="${EMAIL:-}"
DIR_BASE="${DIR_BASE:-/var/www/projetos}"
LOG_FILE="${LOG_FILE:-/var/log/launchinfra.log}"

CONFIG_DIR_SYSTEM="/etc/launchinfra"
CONFIG_FILE_SYSTEM="$CONFIG_DIR_SYSTEM/launchinfra.conf"
CONFIG_DIR_USER="$HOME/.config/launchinfra"
CONFIG_FILE_USER="$CONFIG_DIR_USER/launchinfra.conf"

load_config() {
    if [ -r "$CONFIG_FILE_SYSTEM" ]; then
        # shellcheck disable=SC1090
        . "$CONFIG_FILE_SYSTEM"
    fi
    if [ -r "$CONFIG_FILE_USER" ]; then
        # shellcheck disable=SC1090
        . "$CONFIG_FILE_USER"
    fi
}

save_config() {
    local key="$1" value="$2" target="$3"
    if [ "$target" = "system" ]; then
        sudo mkdir -p "$CONFIG_DIR_SYSTEM" || return 1
        sudo sh -c "echo '$key=\"$value\"' >> '$CONFIG_FILE_SYSTEM'"
    else
        mkdir -p "$CONFIG_DIR_USER" || return 1
        if grep -q "^$key=" "$CONFIG_FILE_USER" 2>/dev/null; then
            awk -v key="$key" -v value="$value" \
                'BEGIN{FS=OFS="="} $1==key{$0=key"=\""value"\""}1' \
                "$CONFIG_FILE_USER" >"$CONFIG_FILE_USER.tmp" &&
                mv "$CONFIG_FILE_USER.tmp" "$CONFIG_FILE_USER"
        else
            echo "$key=\"$value\"" >>"$CONFIG_FILE_USER"
        fi
    fi
}

show_config() {
    echo "DOMINIO_BASE=${DOMINIO_BASE:-"(não configurado)"}"
    echo "EMAIL=${EMAIL:-"(não configurado)"}"
    echo "DIR_BASE=$DIR_BASE"
    echo "LOG_FILE=$LOG_FILE"
    [ -r "$CONFIG_FILE_SYSTEM" ] && echo "System config: $CONFIG_FILE_SYSTEM"
    [ -r "$CONFIG_FILE_USER" ] && echo "User config: $CONFIG_FILE_USER"
}

# Log de operações
log_to_file() {
    local msg="$1"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $msg" | sudo tee -a "$LOG_FILE" >/dev/null 2>&1
}