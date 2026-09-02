#!/bin/bash
set -eo pipefail
# utility functions: ports, domain checks, listing, info, backup, ssl check
NGINX_AVAILABLE="/etc/nginx/sites-available"
NGINX_ENABLED="/etc/nginx/sites-enabled"

# Detecta qual ferramenta usar para listar portas (compatibilidade)
detect_port_scanner() {
    if command -v ss >/dev/null 2>&1; then
        echo "ss"
    elif command -v netstat >/dev/null 2>&1; then
        echo "netstat"
    elif command -v lsof >/dev/null 2>&1; then
        echo "lsof"
    else
        echo "none"
    fi
}

check_port() {
    local port=$1
    local scanner
    scanner=$(detect_port_scanner)
    case "$scanner" in
        ss)
            if ss -tuln 2>/dev/null | grep -q ":$port "; then
                return 0
            fi
            ;;
        netstat)
            if netstat -tuln 2>/dev/null | grep -q ":$port "; then
                return 0
            fi
            ;;
        lsof)
            if lsof -i :"$port" 2>/dev/null | grep -q LISTEN; then
                return 0
            fi
            ;;
    esac
    return 1
}

list_ports() {
    echo -e "\n=== Portas em uso no sistema ==="
    local scanner
    scanner=$(detect_port_scanner)
    case "$scanner" in
        ss)
            ss -tuln 2>/dev/null | grep -E 'LISTEN' | awk '{print $5}' | rev | cut -d: -f1 | rev | sort -n | uniq | while read -r port; do
                [ -z "$port" ] && continue
                if command -v lsof >/dev/null 2>&1; then
                    process=$(lsof -i :"$port" 2>/dev/null | grep LISTEN | head -1 | awk '{print $1}')
                else
                    process="desconhecido"
                fi
                echo "  Porta $port: ${process:-desconhecido}"
            done
            ;;
        netstat)
            netstat -tuln 2>/dev/null | grep -E 'LISTEN' | awk '{print $4}' | rev | cut -d: -f1 | rev | sort -n | uniq | while read -r port; do
                [ -z "$port" ] && continue
                if command -v lsof >/dev/null 2>&1; then
                    process=$(lsof -i :"$port" 2>/dev/null | grep LISTEN | head -1 | awk '{print $1}')
                else
                    process="desconhecido"
                fi
                echo "  Porta $port: ${process:-desconhecido}"
            done
            ;;
        lsof)
            lsof -i -P -n 2>/dev/null | grep LISTEN | awk '{print $9}' | cut -d: -f2 | sort -n | uniq | while read -r port; do
                [ -z "$port" ] && continue
                process=$(lsof -i :"$port" 2>/dev/null | grep LISTEN | head -1 | awk '{print $1}')
                echo "  Porta $port: ${process:-desconhecido}"
            done
            ;;
        *)
            echo "  Nenhuma ferramenta disponivel para escanear portas."
            ;;
    esac
}

check_domain() {
    local domain=$1
    [ -z "$domain" ] && return 1

    # Verifica arquivo direto
    [ -f "$NGINX_AVAILABLE/$domain" ] && return 0

    # Busca server_name em todos os configs
    # Usa grep com regex que pega o dominio como palavra inteira ou seguido de espaco/ponto-e-virgula
    local base_domain
    base_domain=$(printf '%s' "$domain" | sed 's/\./\\./g')
    if grep -qr "server_name.*[[:space:]]${base_domain}\([[:space:]]\|;\|$\)" "$NGINX_AVAILABLE/" 2>/dev/null; then
        return 0
    fi
    if grep -qr "server_name.*[[:space:]]${base_domain}\([[:space:]]\|;\|$\)" "$NGINX_ENABLED/" 2>/dev/null; then
        return 0
    fi
    return 1
}

list_projects() {
    if [ "$REAL_USER" = "root" ]; then
        echo -e "\n=== Todos os projetos (root) ==="
        local found=0
        for config in "$NGINX_AVAILABLE"/*; do
            [ -f "$config" ] || continue
            found=1
            project_name=$(basename "$config")
            if [ -L "$NGINX_ENABLED/$project_name" ]; then
                echo "  ✓ $project_name (ativo)"
            else
                echo "  ○ $project_name (inativo)"
            fi
        done
        [ "$found" -eq 0 ] && echo "  Nenhum projeto."
    else
        echo -e "\n=== Projetos de $REAL_USER ==="
        local found=0
        for config in "$NGINX_AVAILABLE/$REAL_USER-"*; do
            [ -f "$config" ] || continue
            found=1
            local fullname
            fullname=$(basename "$config")
            local project="${fullname#"$REAL_USER"-}"
            if [ -L "$NGINX_ENABLED/$fullname" ]; then
                echo "  ✓ $project (ativo)"
            else
                echo "  ○ $project (inativo)"
            fi
        done
        [ "$found" -eq 0 ] && echo "  Nenhum projeto."
    fi
}

show_project_info() {
    local project=$1
    [[ "$project" =~ \.\. ]] || [[ "$project" =~ / ]] && {
        log_error "Nome de projeto invalido"
        return 1
    }
    local NGINX_NAME
    [ "$REAL_USER" = "root" ] && NGINX_NAME="$project" || NGINX_NAME="$REAL_USER-$project"
    local config_file="$NGINX_AVAILABLE/$NGINX_NAME"

    [ ! -f "$config_file" ] && {
        log_error "Projeto '$project' nao encontrado"
        return 1
    }

    local domain port ssl enabled dir created ssl_expiry
    domain=$(grep -m1 "server_name" "$config_file" | awk '{print $2}' | tr -d ';')
    port=$(grep -m1 "proxy_pass" "$config_file" | grep -oE '[0-9]+' | tail -1)
    ssl="Nao"
    grep -q "ssl_certificate" "$config_file" 2>/dev/null && ssl="Sim"
    enabled="Nao"
    [ -L "$NGINX_ENABLED/$NGINX_NAME" ] && enabled="Sim"
    dir="$USER_DIR/$project"
    [ ! -d "$dir" ] && dir="(nao encontrado)"
    # Usa stat que funciona em Linux (GNU coreutils)
    if command -v stat >/dev/null 2>&1; then
        created=$(stat -c '%y' "$config_file" 2>/dev/null | cut -d. -f1)
    else
        created=$(ls -l "$config_file" 2>/dev/null | awk '{print $6, $7, $8}')
    fi
    ssl_expiry="N/A"
    if [ "$ssl" = "Sim" ] && [ -n "$domain" ]; then
        ssl_expiry=$(echo | run_helper openssl-check "$domain" 2>/dev/null | cut -d= -f2)
        [ -z "$ssl_expiry" ] && ssl_expiry="Nao foi possivel verificar"
    fi

    echo -e "\n${BLUE}=== $project ===${NC}"
    echo "  Dono:       $REAL_USER"
    echo "  Dominio:    ${domain:-N/A}"
    echo "  Porta:      ${port:-N/A (site estatico)}"
    echo "  SSL:        $ssl"
    echo "  Ativo:      $enabled"
    echo "  Diretorio:  $dir"
    echo "  Criado em:  ${created:-N/A}"
    [ "$ssl" = "Sim" ] && echo "  SSL expira: $ssl_expiry"
}

check_all_ssl() {
    echo -e "\n${BLUE}=== Verificacao de Certificados SSL ===${NC}"
    local found=0
    local pattern
    if [ "$REAL_USER" = "root" ]; then
        pattern="$NGINX_AVAILABLE/*"
    else
        pattern="$NGINX_AVAILABLE/$REAL_USER-*"
    fi

    for config in $pattern; do
        [ -f "$config" ] || continue
        if grep -q "ssl_certificate" "$config" 2>/dev/null; then
            found=1
            local project domain
            project=$(basename "$config")
            domain=$(grep -m1 "server_name" "$config" | awk '{print $2}' | tr -d ';')
            if [ -n "$domain" ]; then
                local expiry
                expiry=$(echo | run_helper openssl-check "$domain" 2>/dev/null | cut -d= -f2)
                if [ -n "$expiry" ]; then
                    local expiry_epoch now_epoch days_left
                    expiry_epoch=$(date -d "$expiry" +%s 2>/dev/null)
                    now_epoch=$(date +%s)
                    days_left=$(((expiry_epoch - now_epoch) / 86400))
                    if [ "$days_left" -lt 30 ]; then
                        echo -e "  ${RED}⚠ $project ($domain): $days_left dias restantes - RENOVE!${NC}"
                    else
                        echo -e "  ${GREEN}✓ $project ($domain): $days_left dias restantes${NC}"
                    fi
                else
                    echo -e "  ${YELLOW}? $project ($domain): Nao foi possivel verificar${NC}"
                fi
            fi
        fi
    done
    [ "$found" -eq 0 ] && echo "  Nenhum projeto com SSL encontrado."
}

backup_project() {
    local project=$1
    [[ "$project" =~ \.\. ]] || [[ "$project" =~ / ]] && {
        log_error "Nome de projeto invalido"
        return 1
    }
    local dir="$USER_DIR/$project"
    [ ! -d "$dir" ] && {
        log_error "Diretorio nao encontrado"
        return 1
    }

    local backup_name backup_dir
    backup_name="$project-$(date +%Y%m%d-%H%M%S).tar.gz"
    backup_dir="/tmp/launchinfra-backups"
    mkdir -p "$backup_dir"

    log_info "Criando backup de $project..."
    if run_helper tar-backup "$backup_dir/$backup_name" "$USER_DIR" "$project" "$REAL_USER"; then
        log_success "Backup salvo em: $backup_dir/$backup_name"
    else
        log_error "Falha ao criar backup"
        return 1
    fi
}

# Extrai o dominio principal de um arquivo de config nginx
# Usa o primeiro server_name encontrado
get_domain_from_config() {
    local config_file="$1"
    [ ! -f "$config_file" ] && return 1
    grep -m1 "server_name" "$config_file" | awk '{print $2}' | tr -d ';'
}
