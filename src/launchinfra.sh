#!/bin/bash
# ============================================
# LaunchInfra - Gerenciador de Projetos Web
# ============================================
# AUTOR: Hildemberg Eling de Araújo Lucena
# COPYRIGHT: © 2024 Hildemberg Eling de Araújo Lucena
# PROJETO: https://github.com/Hildemberg986/LaunchInfra
# CONTATO: hildembergeling@gmail.com
# VERSÃO: 2.0
# ============================================
# LICENÇA: USO PERMITIDO - REDISTRIBUIÇÃO PROIBIDA
# ============================================
#
# ✅ PERMITIDO:
#   - Uso pessoal, educacional e comercial
#   - Modificação para uso interno
#   - Execução em servidores próprios
#
# ❌ PROIBIDO:
#   - Redistribuir o código fonte
#   - Publicar em repositórios públicos
#   - Vender ou comercializar
#   - Remover créditos do autor
#
# 📌 OBRIGATÓRIO:
#   - Manter este cabeçalho completo
#   - Manter atribuição ao autor
#   - Incluir link do projeto original
#   - Notificar autor sobre uso
#
# Para redistribuição, solicitar autorização em:
# hildembergeling@gmail.com
# ============================================
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND.
#
# © 2024 Hildemberg Eling de Araújo Lucena. All rights reserved.
# ============================================

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configurações
DOMINIO_BASE="dct.ceres.ufrn.br"
EMAIL="hildembergeling@gmail.com"
DIR_BASE="/var/www/projetos"
NGINX_AVAILABLE="/etc/nginx/sites-available"
NGINX_ENABLED="/etc/nginx/sites-enabled"

# Função para mostrar versão
show_version() {
    cat << VERSION
LaunchInfra v2.0
═══════════════════════════════════════
© 2024 Hildemberg Eling de Araújo Lucena
Todos os direitos reservados.

LICENÇA: USO PERMITIDO - REDISTRIBUIÇÃO PROIBIDA

✅ Você PODE usar este software
❌ Você NÃO PODE redistribuir sem autorização

Contato: hildembergeling@gmail.com
Projeto: https://github.com/Hildemberg986/LaunchInfra
═══════════════════════════════════════

Este software é fornecido "COMO ESTÁ", sem garantias.
Para redistribuição, solicite autorização ao autor.
VERSION
}

# Funções de log
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Função para verificar portas em uso
check_port() {
    local port=$1
    if ss -tuln | grep -q ":$port "; then
        return 0 # Porta em uso
    else
        return 1 # Porta livre
    fi
}

# Função para listar portas em uso
list_ports() {
    echo -e "\n${BLUE}=== Portas em uso no sistema ===${NC}"
    ss -tuln | grep -E 'LISTEN|LISTENING' | awk '{print $5}' | cut -d: -f2 | sort -n | uniq | while read port; do
        process=$(lsof -i :$port 2>/dev/null | grep LISTEN | head -1 | awk '{print $1}')
        echo "  Porta $port: ${process:-desconhecido}"
    done
}

# Função para verificar domínio existente
check_domain() {
    local domain=$1
    if [ -f "$NGINX_AVAILABLE/$domain" ] || grep -r "server_name $domain" "$NGINX_AVAILABLE/" 2>/dev/null | grep -q .; then
        return 0 # Domínio existe
    else
        return 1 # Domínio disponível
    fi
}

# Função para listar projetos existentes
list_projects() {
    echo -e "\n${BLUE}=== Projetos existentes ===${NC}"
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

# Função para remover projeto
remove_project() {
    local project=$1
    local domain="$project.$DOMINIO_BASE"
    
    echo -e "\n${YELLOW}Removendo projeto: $project${NC}"
    
    # Desabilitar no Nginx
    sudo rm -f "$NGINX_ENABLED/$project"
    
    # Remover configuração
    sudo rm -f "$NGINX_AVAILABLE/$project"
    
    # Remover certificado SSL (opcional)
    read -p "Remover certificado SSL? (s/N): " remove_ssl
    if [[ $remove_ssl =~ ^[Ss]$ ]]; then
        sudo certbot delete --cert-name "$domain" --quiet 2>/dev/null
        log_success "Certificado removido"
    fi
    
    # Remover diretório (opcional)
    read -p "Remover arquivos do projeto em $DIR_BASE/$project? (s/N): " remove_files
    if [[ $remove_files =~ ^[Ss]$ ]]; then
        sudo rm -rf "$DIR_BASE/$project"
        log_success "Arquivos removidos"
    fi
    
    # Recarregar Nginx
    sudo nginx -t && sudo systemctl reload nginx
    log_success "Projeto $project removido"
}

# Função para mostrar ajuda
show_help() {
    cat << HELP
${BLUE}LaunchInfra - Gerenciador de Projetos Web${NC}
${BLUE}© 2024 Hildemberg Eling de Araújo Lucena${NC}

${YELLOW}USO:${NC}
  launchinfra NOME [PORTA] [OPÇÕES]
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

${YELLOW}EXEMPLOS:${NC}
  launchinfra site-estatico              # Site estático
  launchinfra api 3000                   # Proxy para porta 3000
  launchinfra jenkins 8080 --force       # Força criação mesmo com conflitos
  launchinfra --list-ports               # Ver portas ocupadas
  launchinfra --remove site-antigo       # Remove projeto

${YELLOW}LICENÇA:${NC}
  Este software é de uso permitido, mas redistribuição é PROIBIDA
  sem autorização do autor. Veja "launchinfra --version"

HELP
}

# Função principal de criação
create_project() {
    local PROJETO=$1
    local PORTA=$2
    local FORCE=$3
    local DOMINIO="$PROJETO.$DOMINIO_BASE"
    local DIR="$DIR_BASE/$PROJETO"
    
    # Verificações pré-criação
    if [ -z "$FORCE" ]; then
        # Verificar se projeto já existe
        if [ -f "$NGINX_AVAILABLE/$PROJETO" ]; then
            log_error "Projeto $PROJETO já existe!"
            echo "Use --remove $PROJETO primeiro ou --force para sobrescrever"
            return 1
        fi
        
        # Verificar domínio
        if check_domain "$DOMINIO"; then
            log_error "Domínio $DOMINIO já está em uso por outro projeto!"
            return 1
        fi
        
        # Verificar porta se for proxy
        if [ -n "$PORTA" ] && check_port "$PORTA"; then
            log_warning "Porta $PORTA está em uso!"
            list_ports
            read -p "Deseja continuar mesmo assim? (s/N): " continue_port
            if [[ ! $continue_port =~ ^[Ss]$ ]]; then
                return 1
            fi
        fi
    fi
    
    log_info "Criando projeto: $PROJETO"
    
    # Criar diretório do projeto
    sudo mkdir -p "$DIR"
    
    # Criar index.html dinâmico
    sudo tee "$DIR/index.html" > /dev/null << HTML
<!DOCTYPE html>
<html lang="pt-br">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$PROJETO - LaunchInfra</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        }
        .container {
            text-align: center;
            background: white;
            padding: 2rem;
            border-radius: 10px;
            box-shadow: 0 10px 40px rgba(0,0,0,0.2);
        }
        h1 { color: #333; margin-bottom: 1rem; }
        .status { 
            color: #4CAF50; 
            font-weight: bold;
            margin: 1rem 0;
        }
        .info {
            background: #f5f5f5;
            padding: 1rem;
            border-radius: 5px;
            margin-top: 1rem;
            font-size: 0.9rem;
        }
        .credits {
            color: #999;
            font-size: 0.7rem;
            margin-top: 1rem;
        }
        .date { color: #666; font-size: 0.8rem; margin-top: 1rem; }
        a { color: #667eea; text-decoration: none; }
        a:hover { text-decoration: underline; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 $PROJETO</h1>
        <p class="status">✅ HTTPS ativo e funcionando!</p>
        $( [ -n "$PORTA" ] && echo "<div class='info'>🔄 Proxy reverso ativo<br>Localhost:$PORTA → $DOMINIO</div>" )
        <div class="date">Criado em: $(date '+%d/%m/%Y %H:%M:%S')</div>
        <div class="credits">
            Powered by <a href="https://github.com/Hildemberg986/LaunchInfra">LaunchInfra</a><br>
            © 2024 Hildemberg Eling de Araújo Lucena
        </div>
    </div>
</body>
</html>
HTML
    
    sudo chown -R www-data:www-data "$DIR"
    log_success "Arquivos criados em: $DIR"
    
    # Gerar certificado SSL
    log_info "Gerando certificado SSL para $DOMINIO..."
    sudo certbot certonly --webroot -w /var/www/letsencrypt \
        --agree-tos --email "$EMAIL" \
        -d "$DOMINIO" \
        --quiet 2>/dev/null
    
    if [ $? -ne 0 ]; then
        log_warning "Erro ao gerar certificado. Tentando renew ou já existente..."
        sudo certbot renew --quiet 2>/dev/null
    fi
    
    # Configuração do Nginx
    if [ -n "$PORTA" ]; then
        log_info "Configurando proxy reverso: localhost:$PORTA → $DOMINIO"
        sudo tee "$NGINX_AVAILABLE/$PROJETO" > /dev/null << NGINX
server {
    listen 443 ssl http2;
    server_name $DOMINIO;
    
    ssl_certificate /etc/letsencrypt/live/$DOMINIO/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMINIO/privkey.pem;
    
    # Segurança
    add_header Strict-Transport-Security "max-age=31536000" always;
    
    location / {
        proxy_pass http://127.0.0.1:$PORTA;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}

server {
    listen 80;
    server_name $DOMINIO;
    return 301 https://\$host\$request_uri;
}
NGINX
    else
        log_info "Configurando site estático: $DIR"
        sudo tee "$NGINX_AVAILABLE/$PROJETO" > /dev/null << NGINX
server {
    listen 443 ssl http2;
    server_name $DOMINIO;
    
    ssl_certificate /etc/letsencrypt/live/$DOMINIO/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMINIO/privkey.pem;
    
    root $DIR;
    index index.html;
    
    # Segurança
    add_header Strict-Transport-Security "max-age=31536000" always;
    
    location / {
        try_files \$uri \$uri/ =404;
    }
}

server {
    listen 80;
    server_name $DOMINIO;
    return 301 https://\$host\$request_uri;
}
NGINX
    fi
    
    # Ativar configuração
    sudo ln -sf "$NGINX_AVAILABLE/$PROJETO" "$NGINX_ENABLED/"
    
    # Recarregar Nginx
    log_info "Recarregando Nginx..."
    if sudo nginx -t 2>/dev/null; then
        sudo systemctl reload nginx
        log_success "Nginx recarregado com sucesso!"
    else
        log_error "Erro na configuração do Nginx!"
        sudo nginx -t
        return 1
    fi
    
    # Resumo final
    echo ""
    echo -e "${GREEN}════════════════════════════════════════${NC}"
    echo -e "${GREEN}✅ PROJETO CRIADO COM SUCESSO!${NC}"
    echo -e "${GREEN}════════════════════════════════════════${NC}"
    echo -e "🌐 ${BLUE}URL:${NC} https://$DOMINIO"
    [ -n "$PORTA" ] && echo -e "🔄 ${BLUE}Proxy:${NC} localhost:$PORTA → $DOMINIO"
    echo -e "📁 ${BLUE}Arquivos:${NC} $DIR"
    echo -e "🔧 ${BLUE}Config:${NC} $NGINX_AVAILABLE/$PROJETO"
    echo -e "📊 ${BLUE}Logs:${NC} sudo tail -f /var/log/nginx/${PROJETO}_*.log"
    echo -e "${GREEN}════════════════════════════════════════${NC}"
    echo -e "${YELLOW}© 2024 Hildemberg Eling de Araújo Lucena - LaunchInfra${NC}"
}

# Main
case "$1" in
    --version|-v)
        show_version
        ;;
    --help|-h)
        show_help
        ;;
    --list)
        list_projects
        ;;
    --list-ports)
        list_ports
        ;;
    --check-port)
        if [ -z "$2" ]; then
            log_error "Especifique uma porta"
            exit 1
        fi
        if check_port "$2"; then
            echo "Porta $2 está em uso"
        else
            echo "Porta $2 está livre"
        fi
        ;;
    --check-domain)
        if [ -z "$2" ]; then
            log_error "Especifique um nome de projeto"
            exit 1
        fi
        DOMAIN_CHECK="$2.$DOMINIO_BASE"
        if check_domain "$DOMAIN_CHECK"; then
            echo "Domínio $DOMAIN_CHECK já está em uso"
        else
            echo "Domínio $DOMAIN_CHECK está disponível"
        fi
        ;;
    --remove)
        if [ -z "$2" ]; then
            log_error "Especifique o nome do projeto para remover"
            exit 1
        fi
        remove_project "$2"
        ;;
    *)
        if [ -z "$1" ]; then
            show_help
            exit 1
        fi
        FORCE=""
        [ "$3" = "--force" ] && FORCE="force"
        create_project "$1" "$2" "$FORCE"
        ;;
esac
