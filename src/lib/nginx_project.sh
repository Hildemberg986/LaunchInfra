#!/bin/bash
set -eo pipefail
# nginx / project operations: create, remove, disable, restore, dry-run, edit

create_project() {
    local PROJETO="" PORTA="" NO_SSL="" FORCE="" DRY_RUN="" CUSTOM_DOMAIN="" TEMPLATE=""

    local prev_arg=""
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
        log_error "Nome do projeto e obrigatorio"
        return 1
    fi

    if [[ ! "$PROJETO" =~ ^[a-zA-Z0-9_-]+$ ]] || [[ "$PROJETO" =~ \.\. ]]; then
        log_error "Nome de projeto invalido. Use apenas letras, numeros, hifen e underscore."
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
            log_error "EMAIL nao configurado."
            return 1
        }
        [ -z "$CUSTOM_DOMAIN" ] && [ -z "$DOMINIO_BASE" ] && {
            log_error "DOMINIO_BASE nao configurado."
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
        echo "  Usuario:      $REAL_USER"
        echo "  Projeto:      $PROJETO"
        echo "  Nginx name:   $NGINX_NAME"
        echo "  Dominio:      $DOMINIO"
        echo "  Porta:        ${PORTA:-N/A (site estatico)}"
        echo "  SSL:          $([ "$NO_SSL" = "--no-ssl" ] && echo 'Nao' || echo 'Sim')"
        echo "  Diretorio:    $DIR"
        echo "  Template:     ${TEMPLATE:-padrao}"
        echo "  Forcar:       $([ "$FORCE" = "--force" ] && echo 'Sim' || echo 'Nao')"
        echo -e "${BLUE}================${NC}\n"
        log_info "DRY RUN: $REAL_USER/$PROJETO ($DOMINIO)"
        return 0
    fi

    # Verificacoes de conflito
    if [ -z "$FORCE" ]; then
        [ -f "$NGINX_AVAILABLE/$NGINX_NAME" ] && {
            log_error "Projeto $PROJETO ja existe!"
            return 1
        }
        if [ "$NO_SSL" != "--no-ssl" ] && check_domain "$DOMINIO"; then
            log_error "Dominio $DOMINIO ja esta em uso!"
            return 1
        fi
        # Porta em uso e esperado em proxy reverso (container rodando)
        # Apenas avisa como warning, nao bloqueia
        if [ -n "$PORTA" ] && check_port "$PORTA"; then
            log_warning "Porta $PORTA esta em uso (sera usada como backend no proxy reverso)"
        fi
    fi

    log_info "Criando projeto: $REAL_USER/$PROJETO ($DOMINIO)"

    run_helper mkdir "$REAL_USER" "$USER_DIR"
    run_helper mkdir "$REAL_USER" "$DIR"

    if [ -n "$TEMPLATE" ] && [ -d "$TEMPLATE" ]; then
        run_helper cp-template "$TEMPLATE" "$DIR"
    elif [ -n "$TEMPLATE" ]; then
        log_warning "Diretorio template '$TEMPLATE' nao existe. Usando template padrao."
        echo "<!DOCTYPE html><html lang=\"pt-br\"><head><meta charset=\"utf-8\"><title>$PROJETO</title></head><body><h1>$PROJETO</h1><p>$REAL_USER @ LaunchInfra</p></body></html>" | run_helper tee-nginx "$DIR/index.html"
    else
        echo "<!DOCTYPE html><html lang=\"pt-br\"><head><meta charset=\"utf-8\"><title>$PROJETO</title></head><body><h1>$PROJETO</h1><p>$REAL_USER @ LaunchInfra</p></body></html>" | run_helper tee-nginx "$DIR/index.html"
    fi

    run_helper chown-www "$REAL_USER" "$DIR"

    if [ -n "$PORTA" ]; then
        cat <<NGINX | run_helper tee-nginx "$NGINX_AVAILABLE/$NGINX_NAME"
# Projeto: $PROJETO | Usuario: $REAL_USER
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
# Projeto: $PROJETO | Usuario: $REAL_USER
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
    if ! run_helper nginx-test; then
        log_error "Erro no Nginx. Verifique: nginx -t"
        return 1
    fi
    run_helper nginx-reload
    log_success "Nginx configurado com HTTP"

    if [ "$NO_SSL" != "--no-ssl" ]; then
        # Valida que o backend responde antes de solicitar SSL
        # (necessario para o desafio HTTP-01 do Certbot)
        if [ -n "$PORTA" ]; then
            log_info "Validando backend na porta $PORTA..."
            # Testa se o proxy_pass responde via Nginx recem-configurado
            # O nginx ja foi recarregado acima, entao 127.0.0.1:80 -> projeto
            backend_test=$(curl -s -o /dev/null -w "%{http_code}" -H "Host: $DOMINIO" "http://127.0.0.1/" 2>/dev/null || echo "000")
            if [ "$backend_test" = "000" ]; then
                log_warning "Backend na porta $PORTA nao responde. SSL sera solicitado, mas verifique se o servico esta ativo."
            elif [ "$backend_test" = "502" ] || [ "$backend_test" = "503" ]; then
                log_warning "Backend na porta $PORTA retornou $backend_test. SSL sera solicitado, mas o servico pode nao estar pronto."
            else
                log_info "Backend respondendo HTTP $backend_test"
            fi
        fi

        log_info "Obtendo certificado SSL para $DOMINIO..."

        # CRITICO: Garante que o SSL seja aplicado ao arquivo do projeto, NAO ao default.
        # O problema: o default_server (de setup-nginx) responde a qualquer host,
        # entao o Certbot pode acabar modificando o arquivo 'default' em vez do projeto.
        #
        # Solucao robusta: salvamos o conteudo do default e restauramos depois,
        # garantindo que o Certbot so consiga modificar o arquivo do projeto.

        local default_backup_tmp=""
        local default_was_enabled=0

        # Detecta se default existe como link ou arquivo
        if [ -L "$NGINX_ENABLED/default" ] || [ -f "$NGINX_ENABLED/default" ]; then
            default_was_enabled=1
            default_backup_tmp="/tmp/launchinfra-default-backup-$$"

            # Salva tambem o original do sites-available (caso o sites-enabled seja um arquivo independente)
            run_helper cat-nginx "$NGINX_AVAILABLE/default" 2>/dev/null > "$default_backup_tmp" || true

            # Remove temporariamente o default de sites-enabled
            run_helper rm-nginx "$NGINX_ENABLED/default"

            # Recarrega nginx para aplicar a remocao
            run_helper nginx-reload
            sleep 1
        fi

        # Usa --preferred-challenges http para o desafio HTTP-01
        cert_output=$(run_helper certbot --nginx -d "$DOMINIO" --non-interactive --agree-tos -m "$EMAIL" --redirect --preferred-challenges http 2>&1)
        cert_status=$?
        echo "$cert_output" | grep -v "^Saving debug log" || true

        # SEMPRE restaura o default, mesmo em caso de erro
        if [ "$default_was_enabled" -eq 1 ]; then
            # Garante que o sites-available/default tem o conteudo original
            if [ -s "$default_backup_tmp" ]; then
                run_helper cp-backup "$default_backup_tmp" "$NGINX_AVAILABLE/default"
            fi
            # Recria o link em sites-enabled
            run_helper ln-nginx "$NGINX_AVAILABLE/default" "$NGINX_ENABLED/default"
            rm -f "$default_backup_tmp"
            # Recarrega nginx
            run_helper nginx-reload
        fi

        # Verifica se o SSL foi realmente aplicado ao arquivo do projeto
        local ssl_in_correct_file=0
        if grep -q "ssl_certificate" "$NGINX_AVAILABLE/$NGINX_NAME" 2>/dev/null; then
            ssl_in_correct_file=1
        fi

        if [ $cert_status -eq 0 ] && [ "$ssl_in_correct_file" -eq 1 ]; then
            log_success "Certificado SSL instalado em $NGINX_NAME"
        elif [ $cert_status -eq 0 ]; then
            log_warning "Certificado criado, mas nao foi aplicado ao arquivo do projeto."
            run_helper nginx-reload
        else
            log_warning "Falha ao obter certificado SSL. Site continua em HTTP."
            log_info "Tente renovar manualmente: launchinfra --renew $PROJETO"
        fi
    else
        log_info "Projeto criado sem SSL (HTTP apenas)"
    fi

    log_success "Projeto $PROJETO criado!"
    [ "$NO_SSL" != "--no-ssl" ] && echo "  -> https://$DOMINIO" || echo "  -> http://$DOMINIO"
}

remove_project() {
    local project=$1
    [ -z "$project" ] && {
        log_error "Nome do projeto e obrigatorio"
        return 1
    }
    [[ "$project" =~ \.\. ]] || [[ "$project" =~ / ]] && {
        log_error "Nome de projeto invalido"
        return 1
    }

    local NGINX_NAME
    [ "$REAL_USER" = "root" ] && NGINX_NAME="$project" || NGINX_NAME="$REAL_USER-$project"

    if [ "$REAL_USER" != "root" ] && [ ! -f "$NGINX_AVAILABLE/$NGINX_NAME" ]; then
        log_error "Projeto '$project' nao encontrado ou nao pertence a voce"
        return 1
    fi

    [ "$2" = "--backup" ] && backup_project "$project"

    # Le o dominio real do arquivo nginx (funciona tanto com projetos padrao quanto com --domain custom)
    local domain
    domain=$(get_domain_from_config "$NGINX_AVAILABLE/$NGINX_NAME")
    [ -z "$domain" ] && domain="$project.$DOMINIO_BASE"

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
        log_error "Nome do projeto e obrigatorio"
        return 1
    }
    [[ "$project" =~ \.\. ]] || [[ "$project" =~ / ]] && {
        log_error "Nome de projeto invalido"
        return 1
    }
    local NGINX_NAME
    [ "$REAL_USER" = "root" ] && NGINX_NAME="$project" || NGINX_NAME="$REAL_USER-$project"
    [ "$REAL_USER" != "root" ] && [ ! -f "$NGINX_AVAILABLE/$NGINX_NAME" ] && {
        log_error "Nao encontrado"
        return 1
    }
    [ ! -L "$NGINX_ENABLED/$NGINX_NAME" ] && {
        log_warning "Ja desativado"
        return 0
    }
    run_helper rm-nginx "$NGINX_ENABLED/$NGINX_NAME"
    run_helper nginx-test && run_helper nginx-reload
    log_success "Projeto '$project' desativado"
}

restore_project() {
    local project=$1
    [ -z "$project" ] && {
        log_error "Nome do projeto e obrigatorio"
        return 1
    }
    [[ "$project" =~ \.\. ]] || [[ "$project" =~ / ]] && {
        log_error "Nome de projeto invalido"
        return 1
    }
    local NGINX_NAME
    [ "$REAL_USER" = "root" ] && NGINX_NAME="$project" || NGINX_NAME="$REAL_USER-$project"
    [ "$REAL_USER" != "root" ] && [ ! -f "$NGINX_AVAILABLE/$NGINX_NAME" ] && {
        log_error "Nao encontrado"
        return 1
    }
    [ -L "$NGINX_ENABLED/$NGINX_NAME" ] && {
        log_warning "Ja ativo"
        return 0
    }
    run_helper ln-nginx "$NGINX_AVAILABLE/$NGINX_NAME" "$NGINX_ENABLED/$NGINX_NAME"
    run_helper nginx-test && run_helper nginx-reload
    log_success "Projeto '$project' restaurado"
}

renew_ssl() {
    local project=$1
    [ -z "$project" ] && {
        log_error "Nome do projeto e obrigatorio"
        return 1
    }
    [[ "$project" =~ \.\. ]] || [[ "$project" =~ / ]] && {
        log_error "Nome de projeto invalido"
        return 1
    }
    local NGINX_NAME
    [ "$REAL_USER" = "root" ] && NGINX_NAME="$project" || NGINX_NAME="$REAL_USER-$project"
    local config_file="$NGINX_AVAILABLE/$NGINX_NAME"
    [ ! -f "$config_file" ] && {
        log_error "Projeto nao encontrado"
        return 1
    }
    grep -q "ssl_certificate" "$config_file" 2>/dev/null || {
        log_warning "Sem SSL"
        return 1
    }
    local domain
    domain=$(get_domain_from_config "$config_file")
    log_info "Renovando SSL para $domain..."
    if run_helper certbot renew --cert-name "$domain" --quiet 2>/dev/null; then
        log_success "SSL renovado"
        return 0
    fi

    # CRITICO: Remove default_server temporariamente e salva backup
    # para garantir que o Certbot atue no arquivo do projeto, nao no default
    local default_backup_tmp=""
    local default_was_enabled=0

    if [ -L "$NGINX_ENABLED/default" ] || [ -f "$NGINX_ENABLED/default" ]; then
        default_was_enabled=1
        default_backup_tmp="/tmp/launchinfra-default-backup-$$"

        # Salva o backup do default
        run_helper cat-nginx "$NGINX_AVAILABLE/default" 2>/dev/null > "$default_backup_tmp" || true

        # Remove temporariamente
        run_helper rm-nginx "$NGINX_ENABLED/default"
        run_helper nginx-reload
        sleep 1
    fi

    cert_output=$(run_helper certbot --nginx -d "$domain" --non-interactive --agree-tos -m "$EMAIL" --redirect --preferred-challenges http 2>&1)
    cert_status=$?
    echo "$cert_output" | grep -v "^Saving debug log" || true

    # SEMPRE restaura o default
    if [ "$default_was_enabled" -eq 1 ]; then
        if [ -s "$default_backup_tmp" ]; then
            run_helper cp-backup "$default_backup_tmp" "$NGINX_AVAILABLE/default"
        fi
        run_helper ln-nginx "$NGINX_AVAILABLE/default" "$NGINX_ENABLED/default"
        rm -f "$default_backup_tmp"
        run_helper nginx-reload
    fi

    if [ $cert_status -ne 0 ]; then
        log_warning "Falha ao renovar SSL"
        return 1
    fi
    log_success "SSL renovado"
}

edit_project() {
    local project=$1
    [ -z "$project" ] && {
        log_error "Nome do projeto e obrigatorio"
        return 1
    }
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

    run_helper edit-nginx "$config_file"

    if run_helper nginx-test; then
        run_helper nginx-reload
        log_success "Configuracao editada e Nginx recarregado"
    else
        log_warning "Erro na configuracao. Corrija com: launchinfra --edit $project"
    fi
}

setup_nginx_default() {
    if [ "$(id -u)" != "0" ]; then
        log_error "Execute como root: sudo launchinfra setup-nginx"
        return 1
    fi

    log_info "Configurando Nginx default para wildcard..."

    run_helper tee-nginx /etc/nginx/sites-available/default <<'NGINX'
# Default server - LaunchInfra
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    root /var/www/projetos;
    index index.html index.htm;

    server_name _;

    location / {
        try_files $uri $uri/ =404;
    }

    location /.well-known/acme-challenge/ {
        root /var/www/letsencrypt;
    }
}
NGINX

    run_helper mkdir root /var/www/letsencrypt
    if ! run_helper nginx-test; then
        log_error "Erro na configuracao do Nginx"
        return 1
    fi
    run_helper nginx-reload
    log_success "Nginx default configurado para wildcard SSL."
    echo "  Agora o servidor responde a qualquer dominio na porta 80."
    echo "  Use: launchinfra NOME para criar projetos com SSL."
}
