#!/bin/bash
# nginx / project operations: create, remove, disable, restore, dry-run, edit

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
        log_error "Nome de projeto inválido."
        return 1
    fi

    local NGINX_NAME
    if [ "$REAL_USER" = "root" ]; then
        NGINX_NAME="$PROJETO"
    else
        NGINX_NAME="$REAL_USER-$PROJETO"
    fi

    if [ "$NO_SSL" != "--no-ssl" ]; then
        [ -z "$EMAIL" ] && {
            log_error "EMAIL não configurado."
            return 1
        }
        [ -z "$CUSTOM_DOMAIN" ] && [ -z "$DOMINIO_BASE" ] && {
            log_error "DOMINIO_BASE não configurado."
            return 1
        }
    fi

    local DOMINIO
    if [ -n "$CUSTOM_DOMAIN" ]; then
        DOMINIO="$CUSTOM_DOMAIN"
    else
        DOMINIO="$PROJETO.$DOMINIO_BASE"
    fi

    local DIR="$USER_DIR/$PROJETO"

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

    if [ -z "$FORCE" ] && [ "$FORCE" != "--force" ]; then
        [ -f "$NGINX_AVAILABLE/$NGINX_NAME" ] && {
            log_error "Projeto $PROJETO já existe!"
            return 1
        }
        if [ "$NO_SSL" != "--no-ssl" ] && check_domain "$DOMINIO"; then
            log_error "Domínio $DOMINIO já está em uso!"
            return 1
        fi
        if [ -n "$PORTA" ] && check_port "$PORTA"; then
            log_warning "Porta $PORTA está em uso!"
            list_ports
            read -r -p "Deseja continuar? (s/N): " continue_port
            [[ ! $continue_port =~ ^[Ss]$ ]] && return 1
        fi
    fi

    log_info "Criando projeto: $REAL_USER/$PROJETO ($DOMINIO)"

    run_helper mkdir "$REAL_USER" "$USER_DIR"
    run_helper mkdir "$REAL_USER" "$DIR"

    if [ -n "$TEMPLATE" ] && [ -d "$TEMPLATE" ]; then
        run_helper cp-template "$TEMPLATE" "$DIR"
    else
        echo "<!DOCTYPE html><html lang=\"pt-br\"><head><meta charset=\"utf-8\"><title>$PROJETO</title></head><body><h1>$PROJETO</h1><p>$REAL_USER @ LaunchInfra</p></body></html>" | run_helper tee-nginx "$DIR/index.html"
    fi

    run_helper chown-www "$REAL_USER" "$DIR"

    if [ -n "$PORTA" ]; then
        cat <<NGINX | run_helper tee-nginx "$NGINX_AVAILABLE/$NGINX_NAME"
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
        cat <<NGINX | run_helper tee-nginx "$NGINX_AVAILABLE/$NGINX_NAME"
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

    run_helper ln-nginx "$NGINX_AVAILABLE/$NGINX_NAME" "$NGINX_ENABLED/$NGINX_NAME"
    run_helper nginx-test || {
        log_error "Erro no Nginx"
        run_helper nginx-test
        return 1
    }
    run_helper nginx-reload
    log_success "Nginx configurado com HTTP"

    if [ "$NO_SSL" != "--no-ssl" ]; then
        log_info "Obtendo certificado SSL para $DOMINIO..."
        run_helper certbot --nginx -d "$DOMINIO" --non-interactive --agree-tos -m "$EMAIL" --redirect 2>&1 | grep -v "^Saving debug log" &&
            log_success "Certificado SSL instalado" ||
            { log_warning "Falha SSL. Site em HTTP."; }
    else
        log_info "Projeto criado sem SSL (HTTP apenas)"
    fi

    log_success "Projeto $PROJETO criado!"
    [ "$NO_SSL" != "--no-ssl" ] && echo "  → https://$DOMINIO" || echo "  → http://$DOMINIO"
}

remove_project() {
    local project=$1
    [ -z "$project" ] && {
        log_error "Nome do projeto é obrigatório"
        return 1
    }

    local NGINX_NAME
    [ "$REAL_USER" = "root" ] && NGINX_NAME="$project" || NGINX_NAME="$REAL_USER-$project"

    if [ "$REAL_USER" != "root" ] && [ ! -f "$NGINX_AVAILABLE/$NGINX_NAME" ]; then
        log_error "Projeto '$project' não encontrado ou não pertence a você"
        return 1
    fi

    [ "$2" = "--backup" ] && backup_project "$project"

    local domain="$project.$DOMINIO_BASE"
    log_info "Removendo projeto: $project"
    run_helper rm-nginx "$NGINX_ENABLED/$NGINX_NAME" "$NGINX_AVAILABLE/$NGINX_NAME"

    read -r -p "Remover certificado SSL? (s/N): " remove_ssl
    [[ $remove_ssl =~ ^[Ss]$ ]] && run_helper certbot delete --cert-name "$domain" --quiet 2>/dev/null

    read -r -p "Remover arquivos em $USER_DIR/$project? (s/N): " remove_files
    [[ $remove_files =~ ^[Ss]$ ]] && run_helper rm-files "$USER_DIR/$project"

    run_helper nginx-test && run_helper nginx-reload
    log_success "Projeto $project removido"
}

disable_project() {
    local project=$1
    [ -z "$project" ] && {
        log_error "Nome do projeto é obrigatório"
        return 1
    }
    local NGINX_NAME
    [ "$REAL_USER" = "root" ] && NGINX_NAME="$project" || NGINX_NAME="$REAL_USER-$project"
    [ "$REAL_USER" != "root" ] && [ ! -f "$NGINX_AVAILABLE/$NGINX_NAME" ] && {
        log_error "Não encontrado"
        return 1
    }
    [ ! -L "$NGINX_ENABLED/$NGINX_NAME" ] && {
        log_warning "Já desativado"
        return 0
    }
    run_helper rm-nginx "$NGINX_ENABLED/$NGINX_NAME"
    run_helper nginx-test && run_helper nginx-reload
    log_success "Projeto '$project' desativado"
}

restore_project() {
    local project=$1
    [ -z "$project" ] && {
        log_error "Nome do projeto é obrigatório"
        return 1
    }
    local NGINX_NAME
    [ "$REAL_USER" = "root" ] && NGINX_NAME="$project" || NGINX_NAME="$REAL_USER-$project"
    [ "$REAL_USER" != "root" ] && [ ! -f "$NGINX_AVAILABLE/$NGINX_NAME" ] && {
        log_error "Não encontrado"
        return 1
    }
    [ -L "$NGINX_ENABLED/$NGINX_NAME" ] && {
        log_warning "Já ativo"
        return 0
    }
    run_helper ln-nginx "$NGINX_AVAILABLE/$NGINX_NAME" "$NGINX_ENABLED/$NGINX_NAME"
    run_helper nginx-test && run_helper nginx-reload
    log_success "Projeto '$project' restaurado"
}

renew_ssl() {
    local project=$1
    [ -z "$project" ] && {
        log_error "Nome do projeto é obrigatório"
        return 1
    }
    local NGINX_NAME
    [ "$REAL_USER" = "root" ] && NGINX_NAME="$project" || NGINX_NAME="$REAL_USER-$project"
    local config_file="$NGINX_AVAILABLE/$NGINX_NAME"
    [ ! -f "$config_file" ] && {
        log_error "Projeto não encontrado"
        return 1
    }
    grep -q "ssl_certificate" "$config_file" 2>/dev/null || {
        log_warning "Sem SSL"
        return 1
    }
    local domain
    domain=$(grep -m1 "server_name" "$config_file" | awk '{print $2}' | tr -d ';')
    log_info "Renovando SSL para $domain..."
    run_helper certbot renew --cert-name "$domain" --quiet 2>/dev/null && log_success "SSL renovado" ||
        run_helper certbot --nginx -d "$domain" --non-interactive --agree-tos -m "$EMAIL" --redirect 2>&1 | grep -v "^Saving debug log"
}

edit_project() {
    local project=$1
    [ -z "$project" ] && {
        log_error "Nome do projeto é obrigatório"
        return 1
    }

    local NGINX_NAME
    [ "$REAL_USER" = "root" ] && NGINX_NAME="$project" || NGINX_NAME="$REAL_USER-$project"
    local config_file="$NGINX_AVAILABLE/$NGINX_NAME"

    [ ! -f "$config_file" ] && {
        log_error "Projeto '$project' não encontrado"
        return 1
    }

    if [ "$REAL_USER" != "root" ] && [ ! -f "$config_file" ]; then
        log_error "Projeto '$project' não encontrado ou não pertence a você"
        return 1
    fi

    run_helper edit-nginx "$config_file"

    if run_helper nginx-test; then
        run_helper nginx-reload
        log_success "Configuração editada e Nginx recarregado"
    else
        log_warning "Erro na configuração. Corrija com: launchinfra --edit $project"
    fi
}
