#!/bin/bash
# CLI helpers and command dispatch

get_version() {
    # Tenta ler do changelog em desenvolvimento
    if [ -f "debian/changelog" ]; then
        head -1 debian/changelog | sed -n 's/launchinfra (\([^)]*\)).*/\1/p'
        return
    fi
    
    # Tenta caminhos de produção
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
    
    # Fallback
    echo "2.0"
}

show_version() {
    echo "LaunchInfra v$(get_version)"
}

show_help() {
    cat << HELP
${BLUE}LaunchInfra - Gerenciador de Projetos Web${NC}
${BLUE}© 2024 Hildemberg Eling de Araújo Lucena${NC}

${YELLOW}USO:${NC}
  launchinfra NOME [PORTA] [OPÇÕES]
  launchinfra config [--email EMAIL] [--domain DOMINIO_BASE] [--system]
  launchinfra --version
  launchinfra --list
  launchinfra --list-ports
  launchinfra --remove NOME
  launchinfra --check-port PORTA
  launchinfra --check-domain NOME

${YELLOW}OPÇÕES:${NC}
  --version, -v       Mostra versão e informações de licença
  --help, -h          Mostra esta ajuda
  --list              Lista todos os projetos
  --list-ports        Mostra portas em uso
  --remove NOME       Remove um projeto
  --check-port PORTA  Verifica se porta está em uso
  --check-domain NOME Verifica se domínio está em uso
  --no-ssl            Cria projeto sem certificado SSL (HTTP)
  --force             Força criação mesmo com conflitos
  config              Define EMAIL e DOMINIO_BASE

${YELLOW}EXEMPLOS:${NC}
  launchinfra site-estatico              # Site estático com SSL
  launchinfra api 3000                   # Proxy para porta 3000 com SSL
  launchinfra teste --no-ssl             # Site estático sem SSL (HTTP)
  launchinfra jenkins 8080 --force       # Força criação mesmo com conflitos
  launchinfra config --email dev@exemplo.com
  launchinfra config --domain exemplo.com

${YELLOW}LICENÇA:${NC}
  Este software é de uso permitido, mas redistribuição é PROIBIDA
  sem autorização do autor. Veja "launchinfra --version"

HELP
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
            TARGET="user"
            EMAIL_ARG=""
            DOMAIN_ARG=""
            while [ $# -gt 0 ]; do
                case "$1" in
                    --email)
                        EMAIL_ARG="$2"; shift 2;;
                    --domain|--dominio)
                        DOMAIN_ARG="$2"; shift 2;;
                    --system)
                        TARGET="system"; shift;;
                    --show)
                        show_config; return 0;;
                    --help|-h)
                        echo "Uso: launchinfra config [--email EMAIL] [--domain DOMINIO_BASE] [--system] [--show]"
                        return 0;;
                    *)
                        echo "Opção inválida: $1"
                        return 1;;
                esac
            done

            if [ -n "$EMAIL_ARG" ]; then
                save_config "EMAIL" "$EMAIL_ARG" "$TARGET" && echo "EMAIL salvo em $TARGET config"
            fi
            if [ -n "$DOMAIN_ARG" ]; then
                save_config "DOMINIO_BASE" "$DOMAIN_ARG" "$TARGET" && echo "DOMINIO_BASE salvo em $TARGET config"
            fi
            if [ -z "$EMAIL_ARG" ] && [ -z "$DOMAIN_ARG" ]; then
                echo "Nada para salvar. Use --email ou --domain, ou --show para exibir."
                return 1
            fi
            return 0
            ;;
        --version|-v)
            show_version; return 0;;
        --help|-h)
            show_help; return 0;;
        --list)
            list_projects; return 0;;
        --list-ports)
            list_ports; return 0;;
        --remove)
            remove_project "$2"
            return $?;;
        --check-port)
            if check_port "$2"; then echo "in use"; else echo "available"; fi
            return 0;;
        --check-domain)
            if check_domain "$2"; then echo "in use"; else echo "available"; fi
            return 0;;
        *)
            create_project "$@"
            return $?
            ;;
    esac
}
