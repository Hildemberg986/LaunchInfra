#!/bin/bash
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

    echo "2.0"
}

show_version() {
    echo "LaunchInfra v2.3.3"
}

validate_email() {
    local email="$1"
    [[ "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]
}

show_help() {
    echo -e "${BLUE}LaunchInfra - Gerenciador de Projetos Web${NC}"
    echo -e "${BLUE}© 2024 Hildemberg Eling de Araújo Lucena${NC}"
    echo ""
    echo -e "${YELLOW}USO:${NC}"
    echo "  launchinfra NOME [PORTA] [OPÇÕES]"
    echo "  launchinfra config [--email EMAIL] [--domain DOMINIO_BASE]"
    echo "  launchinfra --version | --help"
    echo "  launchinfra --list | --list-ports"
    echo "  launchinfra --remove NOME [--backup]"
    echo "  launchinfra --disable NOME"
    echo "  launchinfra --restore NOME"
    echo "  launchinfra --info NOME"
    echo "  launchinfra --edit NOME"
    echo "  launchinfra --renew NOME"
    echo "  launchinfra --check-ssl"
    echo "  launchinfra --check-port PORTA"
    echo "  launchinfra --check-domain NOME"
    echo ""
    echo -e "${YELLOW}OPÇÕES:${NC}"
    echo "  --version, -v        Mostra versão"
    echo "  --help, -h           Mostra esta ajuda"
    echo "  --list               Lista seus projetos (root vê todos)"
    echo "  --list-ports         Mostra portas em uso"
    echo "  --info NOME          Mostra detalhes de um projeto"
    echo "  --edit NOME          Editar configuração Nginx do projeto"
    echo "  --remove NOME        Remove um projeto"
    echo "  --remove NOME --backup  Remove com backup"
    echo "  --disable NOME       Desativa projeto (preserva config)"
    echo "  --restore NOME       Reativa projeto desativado"
    echo "  --renew NOME         Renova certificado SSL"
    echo "  --check-ssl          Verifica expiração de todos os SSLs"
    echo "  --check-port PORTA   Verifica se porta está em uso"
    echo "  --check-domain NOME  Verifica se domínio está em uso"
    echo "  --dry-run            Simula criação sem aplicar"
    echo "  --no-ssl             Cria projeto sem SSL (HTTP)"
    echo "  --force              Força criação mesmo com conflitos"
    echo "  --domain DOMINIO     Domínio customizado (não usa DOMINIO_BASE)"
    echo "  --template DIR       Diretório com template HTML"
    echo "  config               Define EMAIL e DOMINIO_BASE"
    echo ""
    echo -e "${YELLOW}EXEMPLOS:${NC}"
    echo "  launchinfra blog"
    echo "  launchinfra api 3000"
    echo "  launchinfra app --domain meusite.com.br 8080"
    echo "  launchinfra teste --no-ssl"
    echo "  launchinfra blog --template ~/meu-template/"
    echo "  launchinfra novo --dry-run"
    echo "  launchinfra config --email dev@exemplo.com"
    echo "  launchinfra config --domain exemplo.com"
    echo "  launchinfra ls"
    echo "  launchinfra rm blog"
    echo "  launchinfra --edit blog"
    echo ""
    echo -e "${YELLOW}LICENÇA:${NC}"
    echo "  Este software é de uso permitido, mas redistribuição é PROIBIDA"
    echo "  sem autorização do autor. Veja \"launchinfra --version\""
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
                    echo "Email inválido: $EMAIL_ARG"
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
                echo "Opção inválida: $1"
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
    --list | ls)
        list_projects
        return 0
        ;;
    --list-ports | ports)
        list_ports
        return 0
        ;;
    --info)
        show_project_info "$2"
        return $?
        ;;
    --edit)
        edit_project "$2"
        return $?
        ;;
    --remove | rm)
        remove_project "$2" "$3"
        return $?
        ;;
    --disable)
        disable_project "$2"
        return $?
        ;;
    --restore | --enable)
        restore_project "$2"
        return $?
        ;;
    --renew)
        renew_ssl "$2"
        return $?
        ;;
    --check-ssl)
        check_all_ssl
        return 0
        ;;
    --check-port)
        if check_port "$2"; then echo "in use"; else echo "available"; fi
        return 0
        ;;
    --check-domain)
        if check_domain "$2"; then echo "in use"; else echo "available"; fi
        return 0
        ;;
    *)
        create_project "$@"
        return $?
        ;;
    esac
}
