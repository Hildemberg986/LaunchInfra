#!/bin/bash
set -eo pipefail
# modifiers and presets management: list, add, remove, presets

get_snippets_dir() {
    if [ -d "/usr/share/launchinfra/snippets" ]; then
        echo "/usr/share/launchinfra/snippets"
    elif [ -d "$BASEDIR/snippets" ]; then
        echo "$BASEDIR/snippets"
    elif [ -d "$BASEDIR/../snippets" ]; then
        echo "$BASEDIR/../snippets"
    elif [ -d "$BASEDIR/../src/snippets" ]; then
        echo "$BASEDIR/../src/snippets"
    else
        echo "/usr/share/launchinfra/snippets"
    fi
}

# Retorna a lista de modificadores disponíveis
get_available_modifiers() {
    local dir
    dir=$(get_snippets_dir)
    if [ -d "$dir" ]; then
        for f in "$dir"/*.conf; do
            [ -f "$f" ] || continue
            basename "$f" .conf
        done
    else
        echo "cors security protect-hidden gzip static-cache spa"
    fi
}

# Resolve o arquivo de configuração de um projeto
get_project_config() {
    local project="$1"
    local NGINX_NAME
    [ "$REAL_USER" = "root" ] && NGINX_NAME="$project" || NGINX_NAME="$REAL_USER-$project"
    echo "$NGINX_AVAILABLE/$NGINX_NAME"
}

list_modifiers() {
    local project="$1"
    [ -z "$project" ] && {
        log_error "Nome do projeto e obrigatorio"
        return 1
    }

    local config_file
    config_file=$(get_project_config "$project")
    [ ! -f "$config_file" ] && {
        log_error "Projeto '$project' nao encontrado"
        return 1
    }

    echo -e "\n${BLUE}=== Modificadores do Projeto: $project ===${NC}"

    local available
    available=$(get_available_modifiers)

    local count_active=0
    for mod in $available; do
        if grep -q "include .*/snippets/$mod\.conf;" "$config_file" 2>/dev/null; then
            echo -e "  ${GREEN}✓ $mod${NC} (ativo)"
            count_active=$((count_active + 1))
        else
            echo -e "  ${NC}○ $mod${NC} (inativo)"
        fi
    done

    if [ "$count_active" -eq 0 ]; then
        echo -e "\n  ${YELLOW}Nenhum modificador ativo neste projeto.${NC}"
    fi
    echo -e "  Use: launchinfra mod $project add <recurso> para ativar.\n"
    return 0
}

add_modifier() {
    local project="$1"
    local mod="$2"

    [ -z "$project" ] && {
        log_error "Nome do projeto e obrigatorio"
        return 1
    }
    [ -z "$mod" ] && {
        log_error "Nome do modificador e obrigatorio. Disponiveis: $(get_available_modifiers | tr '\n' ' ')"
        return 1
    }

    local config_file
    config_file=$(get_project_config "$project")
    [ ! -f "$config_file" ] && {
        log_error "Projeto '$project' nao encontrado"
        return 1
    }

    local snippets_dir
    snippets_dir=$(get_snippets_dir)
    local snippet_path="$snippets_dir/$mod.conf"

    # Se instalado no sistema, preferir o caminho padrao do sistema
    if [ -f "/usr/share/launchinfra/snippets/$mod.conf" ]; then
        snippet_path="/usr/share/launchinfra/snippets/$mod.conf"
    elif [ ! -f "$snippet_path" ]; then
        log_error "Modificador '$mod' nao encontrado. Disponiveis: $(get_available_modifiers | tr '\n' ' ')"
        return 1
    fi

    # Idempotência: verifica se já está ativo
    if grep -q "include .*/snippets/$mod\.conf;" "$config_file" 2>/dev/null; then
        log_info "Modificador '$mod' ja esta ativo no projeto '$project'."
        return 0
    fi

    log_info "Adicionando modificador '$mod' ao projeto '$project'..."

    # Prepara cópia de trabalho em diretório temporário do usuário
    local tmp_dir="$USER_CONFIG_DIR/tmp"
    mkdir -p "$tmp_dir"
    local tmp_file="$tmp_dir/mod-edit-$$.conf"
    local backup_file="$tmp_dir/mod-backup-$$.conf"

    cat "$config_file" > "$tmp_file" 2>/dev/null || run_helper cat-nginx "$config_file" > "$tmp_file"
    cp "$tmp_file" "$backup_file"

    local include_line="    include $snippet_path;"

    # Se já tem os delimitadores, insere antes da tag de fim
    if grep -q "\[launchinfra:snippets:end\]" "$tmp_file"; then
        awk -v line="$include_line" '
            /\[launchinfra:snippets:end\]/ { print line }
            { print }
        ' "$tmp_file" > "$tmp_file.new" && mv "$tmp_file.new" "$tmp_file"
    else
        # Se não tem delimitadores (legado), insere após server_name
        awk -v line="$include_line" '
            /server_name/ {
                print
                print "    # --- [launchinfra:snippets:start] ---"
                print line
                print "    # --- [launchinfra:snippets:end] ---"
                next
            }
            { print }
        ' "$tmp_file" > "$tmp_file.new" && mv "$tmp_file.new" "$tmp_file"
    fi

    # Aplica via helper e valida com nginx-test
    run_helper tee-nginx "$config_file" < "$tmp_file"

    if run_helper nginx-test; then
        run_helper nginx-reload
        rm -f "$tmp_file" "$backup_file"
        log_success "Modificador '$mod' ativado com sucesso!"
        return 0
    else
        log_error "Erro na validacao do Nginx ao adicionar '$mod'! Revertendo..."
        run_helper tee-nginx "$config_file" < "$backup_file"
        run_helper nginx-reload 2>/dev/null || true
        rm -f "$tmp_file" "$backup_file"
        return 1
    fi
}

remove_modifier() {
    local project="$1"
    local mod="$2"

    [ -z "$project" ] && {
        log_error "Nome do projeto e obrigatorio"
        return 1
    }
    [ -z "$mod" ] && {
        log_error "Nome do modificador e obrigatorio"
        return 1
    }

    local config_file
    config_file=$(get_project_config "$project")
    [ ! -f "$config_file" ] && {
        log_error "Projeto '$project' nao encontrado"
        return 1
    }

    # Verifica se está presente
    if ! grep -q "include .*/snippets/$mod\.conf;" "$config_file" 2>/dev/null; then
        log_warning "Modificador '$mod' nao esta ativo no projeto '$project'."
        return 0
    fi

    log_info "Removendo modificador '$mod' do projeto '$project'..."

    local tmp_dir="$USER_CONFIG_DIR/tmp"
    mkdir -p "$tmp_dir"
    local tmp_file="$tmp_dir/mod-edit-$$.conf"
    local backup_file="$tmp_dir/mod-backup-$$.conf"

    cat "$config_file" > "$tmp_file" 2>/dev/null || run_helper cat-nginx "$config_file" > "$tmp_file"
    cp "$tmp_file" "$backup_file"

    # Remove a linha que contém o include do modificador
    grep -v "include .*/snippets/$mod\.conf;" "$tmp_file" > "$tmp_file.new" && mv "$tmp_file.new" "$tmp_file"

    run_helper tee-nginx "$config_file" < "$tmp_file"

    if run_helper nginx-test; then
        run_helper nginx-reload
        rm -f "$tmp_file" "$backup_file"
        log_success "Modificador '$mod' removido com sucesso!"
        return 0
    else
        log_error "Erro na validacao do Nginx ao remover '$mod'! Revertendo..."
        run_helper tee-nginx "$config_file" < "$backup_file"
        run_helper nginx-reload 2>/dev/null || true
        rm -f "$tmp_file" "$backup_file"
        return 1
    fi
}

apply_preset() {
    local project="$1"
    local preset="$2"

    [ -z "$project" ] || [ -z "$preset" ] && return 1

    case "$preset" in
    spa)
        log_info "Aplicando preset 'spa' no projeto '$project'..."
        add_modifier "$project" "protect-hidden"
        add_modifier "$project" "gzip"
        add_modifier "$project" "static-cache"
        add_modifier "$project" "spa"
        ;;
    api)
        log_info "Aplicando preset 'api' no projeto '$project'..."
        add_modifier "$project" "protect-hidden"
        add_modifier "$project" "cors"
        ;;
    secure)
        log_info "Aplicando preset 'secure' no projeto '$project'..."
        add_modifier "$project" "security"
        add_modifier "$project" "protect-hidden"
        ;;
    static-cached)
        log_info "Aplicando preset 'static-cached' no projeto '$project'..."
        add_modifier "$project" "gzip"
        add_modifier "$project" "static-cache"
        add_modifier "$project" "protect-hidden"
        ;;
    *)
        log_warning "Preset desconhecido: '$preset'. Disponiveis: spa, api, secure, static-cached"
        return 1
        ;;
    esac
}
