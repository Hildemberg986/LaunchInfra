#!/bin/bash
# nginx / project operations: create, remove, disable, restore, dry-run

create_project() {
    local PROJETO="" PORTA="" NO_SSL="" FORCE="" DRY_RUN="" CUSTOM_DOMAIN="" TEMPLATE=""

    for arg in "$@"; do
        case "$arg" in
        --no-ssl) NO_SSL="--no-ssl" ;;
        --force) FORCE="--force" ;;
        --dry-run) DRY_RUN="--dry-run" ;;
        --domain | --dominio) ;;
        --template) ;;
        *)
            if [ -z "$PROJETO" ]; then
                PROJETO="$arg"
            elif [ "$prev_arg" = "--domain" ] || [ "$prev_arg" = "--dominio" ]; then
                CUSTOM_DOMAIN="$arg"
            elif [ "$prev_arg" = "--template" ]; then
                TEMPLATE="$arg"
            elif [ -z "$PORTA" ]; then
                if [[ "$arg" =~ ^[0-9]+$ ]]; then
                    PORTA="$arg"
                fi
            fi
            ;;
        esac
        prev_arg="$arg"
    done

    if [ -z "$PROJETO" ]; then
        log_error "Nome do projeto é obrigatório"
        return 1
    fi

    if [[ ! "$PROJETO" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        log_error "Nome de projeto inválido. Use apenas letras, números, hífen e underscore."
        return 1
    fi

    # Prefixo do nginx: root usa nome puro, usuário usa usuario-projeto
    local NGINX_NAME
    if [ "$REAL_USER" = "root" ]; then
        NGINX_NAME="$PROJETO"
    else
        NGINX_NAME="$REAL_USER-$PROJETO"
    fi

    if [ "$NO_SSL" != "--no-ssl" ]; then
        if [ -z "$EMAIL" ]; then
            log_error "EMAIL não configurado. Execute: launchinfra config --email seu@email.com"
            return 1
        fi
        if [ -z "$CUSTOM_DOMAIN" ] && [ -z "$DOMINIO_BASE" ]; then
            log_error "DOMINIO_BASE não configurado. Execute: launchinfra config --domain exemplo.com"
            return 1
        fi
    fi

    local DOMINIO
    if [ -n "$CUSTOM_DOMAIN" ]; then
        DOMINIO="$CUSTOM_DOMAIN"
    else
        DOMINIO="$PROJETO.$DOMINIO_BASE"
    fi

    local DIR="$USER_DIR/$PROJETO"

    # Dry run
    if [ "$DRY_RUN" = "--dry-run" ]; then
        echo -e "\n${BLUE}=== DRY RUN ===${NC}"
        echo "  Usuário:      $REAL_USER"
        echo "  Projeto:      $PROJETO"
        echo "  Nginx name:   $NGINX_NAME"
        echo "  Domínio:      $DOMINIO"
        echo "  Porta:        ${PORTA:-N/A (site estático)}"
        echo "  SSL:          $([ "$NO_SSL" = "--no-ssl" ] && echo 'Não' || echo 'Sim')"
        echo "  Diretório:    $DIR"
        echo "  Template:     ${TEMPLATE:-padrão}"
        echo "  Forçar:       $([ "$FORCE" = "--force" ] && echo 'Sim' || echo 'Não')"
        echo -e "${BLUE}================${NC}\n"
        log_info "DRY RUN: $REAL_USER/$PROJETO ($DOMINIO)"
        return 0
    fi

    # Verificações de conflito
    if [ -z "$FORCE" ] && [ "$FORCE" != "--force" ]; then
        if [ -f "$NGINX_AVAILABLE/$NGINX_NAME" ]; then
            log_error "Projeto $PROJETO já existe!"
            return 1
        fi
        if [ "$NO_SSL" != "--no-ssl" ] && check_domain "$DOMINIO"; then
            log_error "Domínio $DOMINIO já está em uso!"
            return 1
        fi
        if [ -n "$PORTA" ] && check_port "$PORTA"; then
            log_warning "Porta $PORTA está em uso!"
            list_ports
            read -r -p "Deseja continuar mesmo assim? (s/N): " continue_port
            if [[ ! $continue_port =~ ^[Ss]$ ]]; then return 1; fi
        fi
    fi

    log_info "Criando projeto: $REAL_USER/$PROJETO ($DOMINIO)"

    # Criar diretório do usuário se não existir
    sudo mkdir -p "$USER_DIR"
    sudo mkdir -p "$DIR"

    if [ -n "$TEMPLATE" ] && [ -d "$TEMPLATE" ]; then
        sudo cp -r "$TEMPLATE"/* "$DIR/"
    else
        sudo tee "$DIR/index.html" >/dev/null <<HTML
<!DOCTYPE html>
<html lang="pt-br">
<head><meta charset="utf-8"><title>$PROJETO</title></head>
<body><h1>$PROJETO</h1><p>$REAL_USER @ LaunchInfra</p></body></html>
HTML
    fi

    # Permissões: dono = usuário, grupo = www-data
    sudo chown -R "$REAL_USER:www-data" "$DIR"
    sudo chmod -R 755 "$DIR"

    # Configuração Nginx HTTP
    if [ -n "$PORTA" ]; then
        sudo tee "$NGINX_AVAILABLE/$NGINX_NAME" >/dev/null <<NGINX
# Projeto: $PROJETO | Usuário: $REAL_USER
server {
    listen 80;
    server_name $DOMINIO;
    location / {
        proxy_pass http://127.0.0.1:$PORTA;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
NGINX
    else
        sudo tee "$NGINX_AVAILABLE/$NGINX_NAME" >/dev/null <<NGINX
# Projeto: $PROJETO | Usuário: $REAL_USER
server {
    listen 80;
    server_name $DOMINIO;
    root $DIR;
    index index.html;
    location / {
        try_files \$uri \$uri/ =404;
    }
}
NGINX
    fi

    sudo ln -sf "$NGINX_AVAILABLE/$NGINX_NAME" "$NGINX_ENABLED/$NGINX_NAME"
    if ! sudo nginx -t 2>/dev/null; then
        log_error "Erro na configuração do Nginx"
        sudo nginx -t
        return 1
    fi
    sudo systemctl reload nginx
    log_success "Nginx configurado com HTTP"

    # SSL
    if [ "$NO_SSL" != "--no-ssl" ]; then
        log_info "Obtendo certificado SSL para $DOMINIO..."
        if sudo certbot --nginx -d "$DOMINIO" --non-interactive --agree-tos -m "$EMAIL" --redirect 2>&1 | grep -v "^Saving debug log"; then
            log_success "Certificado SSL instalado com sucesso"
        else
            log_warning "Falha ao obter certificado SSL. O site continua funcionando em HTTP."
            log_warning "Verifique: 1) Domínio $DOMINIO aponta para este servidor? 2) Porta 80 está acessível?"
        fi
    else
        log_info "Projeto criado sem SSL (HTTP apenas)"
    fi

    log_success "Projeto $PROJETO criado com sucesso!"
    if [ "$NO_SSL" != "--no-ssl" ]; then
        echo "  → https://$DOMINIO"
    else
        echo "  → http://$DOMINIO"
    fi
}

remove_project() {
    local project=$1
    local with_backup=""

    if [ -z "$project" ]; then
        log_error "Nome do projeto é obrigatório"
        return 1
    fi

    local NGINX_NAME
    if [ "$REAL_USER" = "root" ]; then
        NGINX_NAME="$project"
    else
        NGINX_NAME="$REAL_USER-$project"
    fi

    # Verifica propriedade (só root pode remover qualquer)
    if [ "$REAL_USER" != "root" ] && [ ! -f "$NGINX_AVAILABLE/$NGINX_NAME" ]; then
        log_error "Projeto '$project' não encontrado ou não pertence a você"
        return 1
    fi

    if [ "$2" = "--backup" ]; then
        with_backup="1"
    fi

    local domain="$project.$DOMINIO_BASE"

    if [ -n "$with_backup" ]; then
        backup_project "$project"
    fi

    log_info "Removendo projeto: $project"
    sudo rm -f "$NGINX_ENABLED/$NGINX_NAME" "$NGINX_AVAILABLE/$NGINX_NAME"

    read -r -p "Remover certificado SSL? (s/N): " remove_ssl
    if [[ $remove_ssl =~ ^[Ss]$ ]]; then
        sudo certbot delete --cert-name "$domain" --quiet 2>/dev/null && log_success "Certificado removido" || log_warning "Certificado não encontrado"
    fi

    read -r -p "Remover arquivos do projeto em $USER_DIR/$project? (s/N): " remove_files
    if [[ $remove_files =~ ^[Ss]$ ]]; then
        sudo rm -rf "$USER_DIR/$project"
        log_success "Arquivos removidos"
    fi

    sudo nginx -t && sudo systemctl reload nginx
    log_success "Projeto $project removido"
}

disable_project() {
    local project=$1
    if [ -z "$project" ]; then
        log_error "Nome do projeto é obrigatório"
        return 1
    fi

    local NGINX_NAME
    if [ "$REAL_USER" = "root" ]; then
        NGINX_NAME="$project"
    else
        NGINX_NAME="$REAL_USER-$project"
    fi

    if [ "$REAL_USER" != "root" ] && [ ! -f "$NGINX_AVAILABLE/$NGINX_NAME" ]; then
        log_error "Projeto '$project' não encontrado ou não pertence a você"
        return 1
    fi

    if [ ! -L "$NGINX_ENABLED/$NGINX_NAME" ]; then
        log_warning "Projeto '$project' já está desativado"
        return 0
    fi

    sudo rm -f "$NGINX_ENABLED/$NGINX_NAME"
    sudo nginx -t && sudo systemctl reload nginx
    log_success "Projeto '$project' desativado (config preservada)"
}

restore_project() {
    local project=$1
    if [ -z "$project" ]; then
        log_error "Nome do projeto é obrigatório"
        return 1
    fi

    local NGINX_NAME
    if [ "$REAL_USER" = "root" ]; then
        NGINX_NAME="$project"
    else
        NGINX_NAME="$REAL_USER-$project"
    fi

    if [ "$REAL_USER" != "root" ] && [ ! -f "$NGINX_AVAILABLE/$NGINX_NAME" ]; then
        log_error "Projeto '$project' não encontrado ou não pertence a você"
        return 1
    fi

    if [ -L "$NGINX_ENABLED/$NGINX_NAME" ]; then
        log_warning "Projeto '$project' já está ativo"
        return 0
    fi

    sudo ln -sf "$NGINX_AVAILABLE/$NGINX_NAME" "$NGINX_ENABLED/$NGINX_NAME"
    sudo nginx -t && sudo systemctl reload nginx
    log_success "Projeto '$project' restaurado"
}

renew_ssl() {
    local project=$1
    if [ -z "$project" ]; then
        log_error "Nome do projeto é obrigatório"
        return 1
    fi

    local NGINX_NAME
    if [ "$REAL_USER" = "root" ]; then
        NGINX_NAME="$project"
    else
        NGINX_NAME="$REAL_USER-$project"
    fi

    local config_file="$NGINX_AVAILABLE/$NGINX_NAME"
    if [ ! -f "$config_file" ]; then
        log_error "Projeto '$project' não encontrado"
        return 1
    fi

    if ! grep -q "ssl_certificate" "$config_file" 2>/dev/null; then
        log_warning "Projeto '$project' não tem SSL configurado"
        return 1
    fi

    local domain
    domain=$(grep -m1 "server_name" "$config_file" | awk '{print $2}' | tr -d ';')

    log_info "Renovando SSL para $domain..."
    if sudo certbot renew --cert-name "$domain" --quiet 2>/dev/null; then
        log_success "SSL renovado com sucesso"
    else
        log_warning "Renovação falhou, tentando forçar..."
        sudo certbot --nginx -d "$domain" --non-interactive --agree-tos -m "$EMAIL" --redirect 2>&1 | grep -v "^Saving debug log"
    fi
}
