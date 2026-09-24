#!/bin/bash
set -eo pipefail
# CLI helpers and command dispatch

get_version() {
    if [ -f "debian/changelog" ]; then
        head -1 debian/changelog | sed -n 's/launchinfra (\([^)]*\)).*/\1/p'
        return
    fi

    for changelog in /usr/share/doc/launchinfra/changelog.Debian.gz \
        /usr/share/doc/launchinfra/changelog.Debian; do
        if [ -f "$changelog" ]; then
            if [[ "$changelog" == *.gz ]]; then
                zcat "$changelog" 2>/dev/null | head -1 | sed -n 's/launchinfra (\([^)]*\)).*/\1/p'
            else
                head -1 "$changelog" | sed -n 's/launchinfra (\([^)]*\)).*/\1/p'
            fi
            return
        fi
    done

    # Sem fallback silencioso - retorna vazio e log_error em quem chama
    return 1
}

show_version() {
    local version
    version=$(get_version) || version="desconhecida"
    echo "LaunchInfra v$version"
    echo "Copyright (c) 2024 Hildemberg Eling de Araujo Lucena"
}

validate_email() {
    local email="$1"
    [[ "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]
}

show_help() {
    echo -e "${BLUE}LaunchInfra - Gerenciador de Projetos Web${NC}"
    echo -e "${BLUE}Nginx + SSL automatico (Let's Encrypt), sem complicacao.${NC}"
    echo ""
    echo -e "${YELLOW}ATALHO RAPIDO${NC}"
    echo "  launchinfra NOME            Cria um site estatico"
    echo "  launchinfra NOME 3000       Cria um reverse proxy p/ porta 3000 (API)"
    echo "  launchinfra --help          Mostra este menu (todas as opcoes abaixo)"
    echo ""
    echo -e "${YELLOW}COMANDOS${NC}"
    echo ""
    echo -e "${GREEN}-- Criacao --${NC}"
    echo "  NOME [PORTA] [OPCOES]       Cria um site ou API (ve as OPCOES abaixo)"
    echo "  config                      Define seu email e dominio padrao"
    echo "  setup-nginx                 Prepara o Nginx p/ SSL automatico"
    echo ""
    echo -e "${GREEN}-- Projetos --${NC}"
    echo "  --list, ls                  Lista seus projetos (root ve todos)"
    echo "  --info NOME                 Detalhes de um projeto"
    echo "  --edit NOME                 Edita o config Nginx do projeto"
    echo "  --disable NOME              Para um projeto (guardando a config)"
    echo "  --restore, --enable NOME    Reativa um projeto parado"
    echo "  --remove, rm NOME [--backup]  Apaga um projeto (backup opcional)"
    echo ""
    echo -e "${GREEN}-- SSL --${NC}"
    echo "  --renew NOME                Renova o certificado de um projeto"
    echo "  --check-ssl                 Checa a validade de todos os certificados"
    echo ""
    echo -e "${GREEN}-- Verificacao --${NC}"
    echo "  --list-ports, ports         Mostra as portas em uso no sistema"
    echo "  --check-port PORTA          Verifica se uma porta esta ocupada"
    echo "  --check-domain NOME         Verifica se um dominio ja esta em uso"
    echo ""
    echo -e "${GREEN}-- Informacoes --${NC}"
    echo "  --version, -v               Mostra a versao"
    echo "  --help, -h                  Mostra este menu"
    echo ""
    echo -e "${YELLOW}OPCOES DE CRIACAO (usar junto com NOME)${NC}"
    echo "  --no-ssl                    Sem SSL (so HTTP)"
    echo "  --domain DOMINIO            Usa um dominio no lugar do padrao"
    echo "  --template DIR              Copia um template HTML p/ o projeto"
    echo "  --dry-run                   Simula a criacao, nao aplica nada"
    echo "  --force                     Cria mesmo havendo conflitos"
    echo ""
    echo -e "${YELLOW}EXEMPLOS${NC}"
    echo "  launchinfra blog                            Site estatico"
    echo "  launchinfra api 3000                        Reverse proxy p/ porta 3000"
    echo "  launchinfra app --domain meusite.com.br 8080  Dominio proprio"
    echo "  launchinfra teste --no-ssl                  Site sem SSL"
    echo "  launchinfra blog --template ~/meu-template/  Site com template"
    echo "  launchinfra novo --dry-run                  Testa a criacao sem aplicar"
    echo "  launchinfra config --email dev@exemplo.com --domain exemplo.com"
    echo "  launchinfra ls"
    echo "  launchinfra rm blog"
    echo ""
    echo -e "${YELLOW}LICENCA${NC}"
    echo "  Uso permitido. Redistribuicao PROIBIDA sem autorizacao do autor."
    echo "  Veja \"launchinfra --version\" para mais informacoes."
}

dispatch_cli() {
    load_config

    if [ $# -eq 0 ]; then
        show_help
        return 0
    fi

    case "$1" in
    config)
        shift
        EMAIL_ARG=""
        DOMAIN_ARG=""
        while [ $# -gt 0 ]; do
            case "$1" in
            --email)
                EMAIL_ARG="$2"
                if ! validate_email "$EMAIL_ARG"; then
                    echo "Email invalido: $EMAIL_ARG"
                    return 1
                fi
                shift 2
                ;;
            --domain | --dominio)
                DOMAIN_ARG="$2"
                shift 2
                ;;
            --show)
                show_config
                return 0
                ;;
            --help | -h)
                echo "Uso: launchinfra config [--email EMAIL] [--domain DOMINIO_BASE] [--show]"
                return 0
                ;;
            *)
                echo "Opcao invalida: $1"
                return 1
                ;;
            esac
        done

        if [ -n "$EMAIL_ARG" ]; then
            save_config "EMAIL" "$EMAIL_ARG" && echo "EMAIL salvo"
        fi
        if [ -n "$DOMAIN_ARG" ]; then
            save_config "DOMINIO_BASE" "$DOMAIN_ARG" && echo "DOMINIO_BASE salvo"
        fi
        if [ -z "$EMAIL_ARG" ] && [ -z "$DOMAIN_ARG" ]; then
            echo "Use --email ou --domain, ou --show para exibir."
            return 1
        fi
        return 0
        ;;
    --version | -v)
        show_version
        return 0
        ;;
    --help | -h)
        show_help
        return 0
        ;;
    setup-nginx)
        setup_nginx_default
        return $?
        ;;
    --list | ls)
        list_projects
        return 0
        ;;
    --list-ports | ports)
        list_ports
        return 0
        ;;
    --info)
        if [ -z "$2" ]; then
            echo "Uso: launchinfra --info NOME"
            return 1
        fi
        show_project_info "$2"
        return $?
        ;;
    --edit)
        if [ -z "$2" ]; then
            echo "Uso: launchinfra --edit NOME"
            return 1
        fi
        edit_project "$2"
        return $?
        ;;
    --remove | rm)
        if [ -z "$2" ]; then
            echo "Uso: launchinfra --remove NOME [--backup]"
            return 1
        fi
        remove_project "$2" "$3"
        return $?
        ;;
    --disable)
        if [ -z "$2" ]; then
            echo "Uso: launchinfra --disable NOME"
            return 1
        fi
        disable_project "$2"
        return $?
        ;;
    --restore | --enable)
        if [ -z "$2" ]; then
            echo "Uso: launchinfra --restore NOME"
            return 1
        fi
        restore_project "$2"
        return $?
        ;;
    --renew)
        if [ -z "$2" ]; then
            echo "Uso: launchinfra --renew NOME"
            return 1
        fi
        renew_ssl "$2"
        return $?
        ;;
    --check-ssl)
        check_all_ssl
        return 0
        ;;
    --check-port)
        if [ -z "$2" ]; then
            echo "Uso: launchinfra --check-port PORTA"
            return 1
        fi
        if check_port "$2"; then echo "in use"; else echo "available"; fi
        return 0
        ;;
    --check-domain)
        if [ -z "$2" ]; then
            echo "Uso: launchinfra --check-domain DOMINIO"
            return 1
        fi
        if check_domain "$2"; then echo "in use"; else echo "available"; fi
        return 0
        ;;
    *)
        create_project "$@"
        return $?
        ;;
    esac
}
