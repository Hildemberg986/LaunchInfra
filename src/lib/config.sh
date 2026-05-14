#!/bin/bash
# configuration management
DOMINIO_BASE="dct.ceres.ufrn.br"
EMAIL="hildembergeling@gmail.com"
DIR_BASE="/var/www/projetos"

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
            sed -i "s|^$key=.*|$key=\"$value\"|" "$CONFIG_FILE_USER"
        else
            echo "$key=\"$value\"" >> "$CONFIG_FILE_USER"
        fi
    fi
}

show_config() {
    echo "DOMINIO_BASE=$DOMINIO_BASE"
    echo "EMAIL=$EMAIL"
    [ -r "$CONFIG_FILE_SYSTEM" ] && echo "System config: $CONFIG_FILE_SYSTEM"
    [ -r "$CONFIG_FILE_USER" ] && echo "User config: $CONFIG_FILE_USER"
}
