#!/bin/bash
# utility functions: ports, domain checks, listing
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
    ss -tuln | grep -E 'LISTEN|LISTENING' | awk '{print $5}' | cut -d: -f2 | sort -n | uniq | while read port; do
        process=$(lsof -i :$port 2>/dev/null | grep LISTEN | head -1 | awk '{print $1}')
        echo "  Porta $port: ${process:-desconhecido}"
    done
}

check_domain() {
    local domain=$1
    if [ -f "$NGINX_AVAILABLE/$domain" ] || grep -r "server_name $domain" "$NGINX_AVAILABLE/" 2>/dev/null | grep -q .; then
        return 0
    else
        return 1
    fi
}

list_projects() {
    echo -e "\n=== Projetos existentes ==="
    for config in "$NGINX_AVAILABLE"/*; do
        if [ -f "$config" ]; then
            project_name=$(basename "$config")
            if [ -L "$NGINX_ENABLED/$project_name" ]; then
                echo "  ✓ $project_name (ativo)"
            else
                echo "  ○ $project_name (inativo)"
            fi
        fi
    done
}
