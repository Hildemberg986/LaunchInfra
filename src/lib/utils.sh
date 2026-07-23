#!/bin/bash
# utility functions: ports, domain checks, listing, info, backup, ssl check
NGINX_AVAILABLE="/etc/nginx/sites-available"
NGINX_ENABLED="/etc/nginx/sites-enabled"

check_port() {
    local port=$1
    if ss -tuln | grep -q ":$port "; then
        return 0
    else
        return 1
    fi
}

list_ports() {
    echo -e "\n=== Portas em uso no sistema ==="
    ss -tuln | grep -E 'LISTEN' | awk '{print $5}' | rev | cut -d: -f1 | rev | sort -n | uniq | while read -r port; do
        [ -z "$port" ] && continue
        process=$(lsof -i :"$port" 2>/dev/null | grep LISTEN | head -1 | awk '{print $1}')
        echo "  Porta $port: ${process:-desconhecido}"
    done
}

check_domain() {
    local domain=$1
    local escaped_domain
    escaped_domain=$(echo "$domain" | sed 's/\./\\./g')
    if [ -f "$NGINX_AVAILABLE/$domain" ] ||
        grep -qr "server_name $escaped_domain\b" "$NGINX_AVAILABLE/" 2>/dev/null ||
        grep -qr "server_name $escaped_domain\b" "$NGINX_ENABLED/" 2>/dev/null; then
        return 0
    else
        return 1
    fi
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
            local project="${fullname#$REAL_USER-}"
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
    local NGINX_NAME
    [ "$REAL_USER" = "root" ] && NGINX_NAME="$project" || NGINX_NAME="$REAL_USER-$project"
    local config_file="$NGINX_AVAILABLE/$NGINX_NAME"

    [ ! -f "$config_file" ] && {
        log_error "Projeto '$project' não encontrado"
        return 1
    }

    local domain port ssl enabled dir created ssl_expiry
    domain=$(grep -m1 "server_name" "$config_file" | awk '{print $2}' | tr -d ';')
    port=$(grep -m1 "proxy_pass" "$config_file" | grep -oP '\d+' | tail -1)
    ssl="Não"
    grep -q "ssl_certificate" "$config_file" 2>/dev/null && ssl="Sim"
    enabled="Não"
    [ -L "$NGINX_ENABLED/$NGINX_NAME" ] && enabled="Sim"
    dir="$USER_DIR/$project"
    [ ! -d "$dir" ] && dir="(não encontrado)"
    created=$(stat -c '%y' "$config_file" 2>/dev/null | cut -d. -f1)
    ssl_expiry="N/A"
    if [ "$ssl" = "Sim" ] && [ -n "$domain" ]; then
        ssl_expiry=$(echo | run_helper openssl-check "$domain" 2>/dev/null | cut -d= -f2)
        [ -z "$ssl_expiry" ] && ssl_expiry="Não foi possível verificar"
    fi

    echo -e "\n${BLUE}=== $project ===${NC}"
    echo "  Dono:       $REAL_USER"
    echo "  Domínio:    ${domain:-N/A}"
    echo "  Porta:      ${port:-N/A (site estático)}"
    echo "  SSL:        $ssl"
    echo "  Ativo:      $enabled"
    echo "  Diretório:  $dir"
    echo "  Criado em:  ${created:-N/A}"
    [ "$ssl" = "Sim" ] && echo "  SSL expira: $ssl_expiry"
}

check_all_ssl() {
    echo -e "\n${BLUE}=== Verificação de Certificados SSL ===${NC}"
    local found=0
    [ "$REAL_USER" = "root" ] && local pattern="$NGINX_AVAILABLE/*" || local pattern="$NGINX_AVAILABLE/$REAL_USER-*"

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
                    echo -e "  ${YELLOW}? $project ($domain): Não foi possível verificar${NC}"
                fi
            fi
        fi
    done
    [ "$found" -eq 0 ] && echo "  Nenhum projeto com SSL encontrado."
}

backup_project() {
    local project=$1
    local dir="$USER_DIR/$project"
    [ ! -d "$dir" ] && {
        log_error "Diretório não encontrado"
        return 1
    }

    local backup_name backup_dir
    backup_name="$project-$(date +%Y%m%d-%H%M%S).tar.gz"
    backup_dir="/tmp/launchinfra-backups"
    mkdir -p "$backup_dir"

    log_info "Criando backup de $project..."
    run_helper tar-backup "$backup_dir/$backup_name" "$USER_DIR" "$project" "$REAL_USER" &&
        log_success "Backup salvo em: $backup_dir/$backup_name" ||
        {
            log_error "Falha ao criar backup"
            return 1
        }
}
