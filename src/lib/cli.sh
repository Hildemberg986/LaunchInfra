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
    local version
    version=$(get_version) || version="desconhecida"

    echo -e "${BOLD}${BLUE}LaunchInfra v$version — Gerenciador de Infraestrutura Web & Nginx${NC}"
    echo "Hospede sites estaticos, SPAs e APIs com SSL automatico em segundos."
    echo ""
    echo -e "${BOLD}${YELLOW}USO${NC}"
    echo "  launchinfra <comando> [opcoes...]"
    echo "  launchinfra <projeto> [porta] [opcoes de criacao]"
    echo ""
    echo -e "${BOLD}${YELLOW}COMANDOS${NC}"
    echo ""
    echo -e "${BOLD}${GREEN}  Gerenciamento de Projetos${NC}"
    echo "    <projeto> [porta]            Cria um novo projeto (estatico ou proxy reverso)"
    echo "    ls, --list                   Lista todos os projetos do usuario atual"
    echo "    --info <projeto>             Exibe detalhes tecnicos e status do projeto"
    echo "    --edit <projeto>             Abre o arquivo de configuracao do Nginx no editor"
    echo "    --backup <projeto>           Gera backup (.tar.gz) dos arquivos web e do Nginx"
    echo "    --disable <projeto>          Desativa temporariamente o site mantendo a config"
    echo "    --restore, --enable <proj>   Reativa um projeto previamente desativado"
    echo "    rm, --remove <proj> [-y]     Remove o projeto (--backup e -y opcionais)"
    echo ""
    echo -e "${BOLD}${GREEN}  Modificadores Nginx (launchinfra mod)${NC}"
    echo "    mod <proj> list              Lista modificadores ativos no projeto"
    echo "    mod <proj> add <recurso>     Ativa um modificador (cors, security, gzip, etc.)"
    echo "    mod <proj> rm <recurso>      Desativa um modificador do projeto"
    echo ""
    echo -e "${BOLD}${GREEN}  Certificados & Seguranca SSL${NC}"
    echo "    --renew <projeto>            Renova ou emite certificado SSL via Certbot"
    echo "    --check-ssl                  Verifica validade e dias para expiracao do SSL"
    echo ""
    echo -e "${BOLD}${GREEN}  Rede & Diagnostico${NC}"
    echo "    ports, --list-ports          Lista as portas TCP em escuta no sistema"
    echo "    --check-port <porta>         Verifica se uma porta local ja esta ocupada"
    echo "    --check-domain <dominio>     Verifica se um dominio ja esta configurado"
    echo ""
    echo -e "${BOLD}${GREEN}  Configuracao & Sistema${NC}"
    echo "    config                       Configura email e dominio padrao para SSL"
    echo "    setup-nginx                  Prepara o Nginx e pastas do sistema"
    echo "    help, --help, -h             Exibe este menu (ou 'help mod', 'help config')"
    echo "    --version, -v                Exibe a versao instalada e informacoes"
    echo ""
    echo -e "${BOLD}${YELLOW}OPCOES DE CRIACAO (usar com <projeto>)${NC}"
    echo "    --preset <nome>              Aplica preset: spa, api, secure, static-cached"
    echo "    --domain, --dominio <dom>    Define dominio proprio (ex: app.meusite.com)"
    echo "    --template <dir>             Copia template HTML para a pasta do projeto"
    echo "    --max-body <tamanho>         Tamanho maximo de upload/payload (padrao: 50M)"
    echo "    --no-ssl                     Cria o projeto apenas em HTTP (porta 80)"
    echo "    --dry-run                    Simula a criacao sem modificar nada no sistema"
    echo "    --force                      Cria o projeto mesmo se houver conflitos"
    echo ""
    echo -e "${BOLD}${YELLOW}PRESETS DISPONIVEIS (--preset)${NC}"
    echo "    spa            Single Page Apps (React/Vue): fallback de rotas, gzip e cache"
    echo "    api            APIs REST/GraphQL: proxy reverso com CORS, gzip e WebSocket"
    echo "    secure         Hardening: headers estritos de seguranca e bloqueio de ocultos"
    echo "    static-cached  Site estatico de alta performance: gzip e cache agressivo"
    echo ""
    echo -e "${BOLD}${YELLOW}MODIFICADORES DISPONIVEIS (launchinfra mod <proj> add|rm)${NC}"
    echo "    cors           Headers de Cross-Origin Resource Sharing e preflight OPTIONS"
    echo "    security       Headers HTTP de protecao (HSTS, CSP, X-Frame-Options, etc.)"
    echo "    protect-hidden Bloqueio de acesso a arquivos sensiveis (.git, .env, .htaccess)"
    echo "    gzip           Compressao de conteudo para acelerar carregamento"
    echo "    static-cache   Cache estatico com max-age longo para assets (.js, .css, imagens)"
    echo "    spa            Fallback de rotas client-side para SPA (index.html)"
    echo ""
    echo -e "${BOLD}${YELLOW}EXEMPLOS PRATICOS${NC}"
    echo "  # 1. Site estatico simples:"
    echo "    launchinfra blog"
    echo ""
    echo "  # 2. Single Page Application (React/Vue/Vite) com preset:"
    echo "    launchinfra painel --preset spa"
    echo ""
    echo "  # 3. API Node.js/Python na porta 3000 com CORS e dominio proprio:"
    echo "    launchinfra api 3000 --preset api --domain api.exemplo.com"
    echo ""
    echo "  # 4. Habilitar seguranca e compressao em projeto existente:"
    echo "    launchinfra mod blog add security"
    echo "    launchinfra mod blog add gzip"
    echo ""
    echo "  # 5. Backup e remocao automatica sem confirmacao:"
    echo "    launchinfra rm blog --backup -y"
    echo ""
    echo -e "${BOLD}${YELLOW}AJUDA ESPECIFICA${NC}"
    echo "  Para obter mais detalhes sobre comandos especificos, execute:"
    echo "    launchinfra mod --help"
    echo "    launchinfra config --help"
}

show_mod_help() {
    local version
    version=$(get_version) || version="desconhecida"

    echo -e "${BOLD}${BLUE}LaunchInfra v$version — Modificadores Nginx (launchinfra mod)${NC}"
    echo "Gerenciamento modular de recursos e diretivas avancadas do Nginx."
    echo ""
    echo -e "${BOLD}${YELLOW}USO${NC}"
    echo "  launchinfra mod <projeto> <acao> [recurso]"
    echo ""
    echo -e "${BOLD}${YELLOW}ACOES${NC}"
    echo "  list, ls                     Lista os modificadores atualmente ativos no projeto"
    echo "  add, enable <recurso>        Injeta e ativa um modificador no virtualhost"
    echo "  rm, remove, del <recurso>    Remove e desativa um modificador do virtualhost"
    echo ""
    echo -e "${BOLD}${YELLOW}RECURSOS DISPONIVEIS${NC}"
    echo "  cors             Habilita cabecalhos CORS e responde preflight (OPTIONS 204)"
    echo "  security         Headers HTTP de seguranca (HSTS, CSP, X-Frame-Options, etc.)"
    echo "  protect-hidden   Bloqueia acesso a arquivos sensiveis (.git, .env, .htaccess)"
    echo "  gzip             Habilita compressao gzip para JS, CSS, JSON, XML e fontes"
    echo "  static-cache     Cache agressivo (max-age=31536000, immutable) para assets"
    echo "  spa              Fallback client-side routing (try_files \$uri \$uri/ /index.html)"
    echo ""
    echo -e "${BOLD}${YELLOW}EXEMPLOS${NC}"
    echo "  launchinfra mod meu-site list"
    echo "  launchinfra mod minha-api add cors"
    echo "  launchinfra mod meu-site add gzip"
    echo "  launchinfra mod meu-site add security"
    echo "  launchinfra mod meu-site rm cors"
}

show_config_help() {
    local version
    version=$(get_version) || version="desconhecida"

    echo -e "${BOLD}${BLUE}LaunchInfra v$version — Configuracao Global (launchinfra config)${NC}"
    echo "Gerencia os padroes de dominio e email para emissao de certificados SSL."
    echo ""
    echo -e "${BOLD}${YELLOW}USO${NC}"
    echo "  launchinfra config [opcoes]"
    echo ""
    echo -e "${BOLD}${YELLOW}OPCOES${NC}"
    echo "  --email <email>              Define o email padrao para alertas do Let's Encrypt"
    echo "  --domain, --dominio <dom>    Define o sufixo de dominio base (ex: meusite.com)"
    echo "  --show                       Exibe as configuracoes salvas atualmente"
    echo "  --help, -h                   Exibe este menu de ajuda"
    echo ""
    echo -e "${BOLD}${YELLOW}LOCALIZACAO DO ARQUIVO${NC}"
    echo "  Usuario: ~/.config/launchinfra/config"
    echo "  Global:  /etc/launchinfra/config"
    echo ""
    echo -e "${BOLD}${YELLOW}EXEMPLOS${NC}"
    echo "  launchinfra config --show"
    echo "  launchinfra config --email admin@empresa.com --domain empresa.com"
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
        if [ $# -eq 0 ]; then
            show_config_help
            return 0
        fi
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
            --help | -h | help)
                show_config_help
                return 0
                ;;
            *)
                echo "Opcao invalida: $1 (consulte 'launchinfra config --help')"
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
    help | --help | -h)
        case "$2" in
        mod)
            show_mod_help
            return 0
            ;;
        config)
            show_config_help
            return 0
            ;;
        *)
            show_help
            return 0
            ;;
        esac
        ;;
    setup-nginx)
        setup_nginx_default
        return $?
        ;;
    mod)
        if [ $# -eq 1 ] || [ "$2" = "--help" ] || [ "$2" = "-h" ] || [ "$2" = "help" ]; then
            show_mod_help
            return 0
        fi
        local project="$2" action="$3" modifier="$4"
        if [ -z "$project" ] || [ -z "$action" ]; then
            echo "Uso: launchinfra mod PROJETO <list|add|rm> [RECURSO] (consulte 'launchinfra mod --help')"
            return 1
        fi
        case "$action" in
        list | ls)
            list_modifiers "$project"
            ;;
        add | enable)
            if [ -z "$modifier" ]; then
                echo "Informe o recurso a adicionar (consulte 'launchinfra mod --help')"
                return 1
            fi
            add_modifier "$project" "$modifier"
            ;;
        rm | remove | del | disable)
            if [ -z "$modifier" ]; then
                echo "Informe o recurso a remover (consulte 'launchinfra mod --help')"
                return 1
            fi
            remove_modifier "$project" "$modifier"
            ;;
        *)
            echo "Acao invalida: $action (use list, add ou rm; consulte 'launchinfra mod --help')"
            return 1
            ;;
        esac
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
    --backup | backup)
        if [ -z "$2" ]; then
            echo "Uso: launchinfra --backup NOME"
            return 1
        fi
        backup_project "$2"
        return $?
        ;;
    --remove | rm)
        shift
        if [ -z "$1" ]; then
            echo "Uso: launchinfra --remove NOME [--backup] [-y|--yes]"
            return 1
        fi
        remove_project "$@"
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
