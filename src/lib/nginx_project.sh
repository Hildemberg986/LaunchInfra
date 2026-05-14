#!/bin/bash
# nginx / project operations: create and remove

create_project() {
    local PROJETO="" PORTA="" NO_SSL="" FORCE=""
    
    # Parse arguments - separate positional from flags
    for arg in "$@"; do
        case "$arg" in
            --no-ssl) NO_SSL="--no-ssl" ;;
            --force) FORCE="--force" ;;
            *)
                if [ -z "$PROJETO" ]; then
                    PROJETO="$arg"
                elif [ -z "$PORTA" ]; then
                    # Check if it looks like a port number (not a flag)
                    if [[ "$arg" =~ ^[0-9]+$ ]]; then
                        PORTA="$arg"
                    fi
                fi
                ;;
        esac
    done

    if [ -z "$PROJETO" ]; then
        log_error "Nome do projeto é obrigatório"
        return 1
    fi

    local DOMINIO="$PROJETO.$DOMINIO_BASE"
    local DIR="$DIR_BASE/$PROJETO"

    if [ -z "$FORCE" ] && [ "$FORCE" != "--force" ]; then
        if [ -f "/etc/nginx/sites-available/$PROJETO" ]; then
            log_error "Projeto $PROJETO já existe!"; return 1
        fi
        if [ "$NO_SSL" != "--no-ssl" ] && check_domain "$DOMINIO"; then
            log_error "Domínio $DOMINIO já está em uso!"; return 1
        fi
        if [ -n "$PORTA" ] && check_port "$PORTA"; then
            log_warning "Porta $PORTA está em uso!"; list_ports
            read -p "Deseja continuar mesmo assim? (s/N): " continue_port
            if [[ ! $continue_port =~ ^[Ss]$ ]]; then return 1; fi
        fi
    fi

    log_info "Criando projeto: $PROJETO"
    sudo mkdir -p "$DIR"
    sudo tee "$DIR/index.html" > /dev/null << HTML
<!DOCTYPE html>
<html lang="pt-br">
<head><meta charset="utf-8"><title>$PROJETO</title></head>
<body><h1>$PROJETO</h1><p>Powered by LaunchInfra</p></body></html>
HTML
    sudo chown -R www-data:www-data "$DIR"

    if [ "$NO_SSL" != "--no-ssl" ]; then
        log_info "Gerando certificado SSL para $DOMINIO..."
        sudo certbot certonly --webroot -w /var/www/letsencrypt --agree-tos --email "$EMAIL" -d "$DOMINIO" --quiet 2>/dev/null || true

        if [ -n "$PORTA" ]; then
            sudo tee "/etc/nginx/sites-available/$PROJETO" > /dev/null << NGINX
server {
    listen 443 ssl http2;
    server_name $DOMINIO;
    ssl_certificate /etc/letsencrypt/live/$DOMINIO/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMINIO/privkey.pem;
    add_header Strict-Transport-Security "max-age=31536000" always;
    location / { proxy_pass http://127.0.0.1:$PORTA; proxy_set_header Host \$host; }
}
server { listen 80; server_name $DOMINIO; return 301 https://\$host\$request_uri; }
NGINX
        else
            sudo tee "/etc/nginx/sites-available/$PROJETO" > /dev/null << NGINX
server { listen 443 ssl http2; server_name $DOMINIO; ssl_certificate /etc/letsencrypt/live/$DOMINIO/fullchain.pem; ssl_certificate_key /etc/letsencrypt/live/$DOMINIO/privkey.pem; root $DIR; index index.html; add_header Strict-Transport-Security "max-age=31536000" always; location / { try_files \$uri \$uri/ =404; } }
server { listen 80; server_name $DOMINIO; return 301 https://\$host\$request_uri; }
NGINX
        fi
    else
        log_info "Criando projeto sem SSL (HTTP apenas)"
        if [ -n "$PORTA" ]; then
            sudo tee "/etc/nginx/sites-available/$PROJETO" > /dev/null << NGINX
server {
    listen 80;
    server_name $DOMINIO;
    location / { proxy_pass http://127.0.0.1:$PORTA; proxy_set_header Host \$host; }
}
NGINX
        else
            sudo tee "/etc/nginx/sites-available/$PROJETO" > /dev/null << NGINX
server { listen 80; server_name $DOMINIO; root $DIR; index index.html; location / { try_files \$uri \$uri/ =404; } }
NGINX
        fi
    fi

    sudo ln -sf "/etc/nginx/sites-available/$PROJETO" "/etc/nginx/sites-enabled/"
    if sudo nginx -t 2>/dev/null; then sudo systemctl reload nginx; log_success "Nginx recarregado"; else log_error "Erro na configuração do Nginx"; sudo nginx -t; return 1; fi
    log_success "Projeto $PROJETO criado"
}

remove_project() {
    local project=$1 domain="$project.$DOMINIO_BASE"
    log_info "Removendo projeto: $project"
    sudo rm -f "/etc/nginx/sites-enabled/$project" "/etc/nginx/sites-available/$project"
    read -p "Remover certificado SSL? (s/N): " remove_ssl
    if [[ $remove_ssl =~ ^[Ss]$ ]]; then sudo certbot delete --cert-name "$domain" --quiet 2>/dev/null; fi
    read -p "Remover arquivos do projeto em $DIR_BASE/$project? (s/N): " remove_files
    if [[ $remove_files =~ ^[Ss]$ ]]; then sudo rm -rf "$DIR_BASE/$project"; fi
    sudo nginx -t && sudo systemctl reload nginx
    log_success "Projeto $project removido"
}
