# 🚀 LaunchInfra

Ferramenta para criar e gerenciar sites e proxies Nginx com suporte a Let's Encrypt.

## 📦 Dependências

### Build (desenvolvimento)

    sudo apt update
    sudo apt install -y devscripts debhelper build-essential

### Runtime (automático)

As dependências de runtime (**nginx**, **certbot**, **python3-certbot-nginx**) são instaladas automaticamente ao instalar o pacote `.deb`.

- **nginx**: Servidor web e proxy reverso
- **certbot**: Gerador e gerenciador de certificados SSL/TLS Let's Encrypt
- **python3-certbot-nginx**: Plugin do certbot para integração com Nginx

## ⚡ Instalação

### Build do pacote .deb

    make build

### Instalar o pacote

    sudo dpkg -i ../launchinfra_*.deb

### Build + instalação automática

    ./scripts/build-install.sh

## 🔧 Pós-instalação

Adicionar usuário ao grupo `launchinfra` (sem sudo):

    sudo usermod -aG launchinfra NOME_DO_USUARIO

O usuário precisa fazer logout/login.

### Configurar email e domínio

    launchinfra config --email seu@email.com
    launchinfra config --domain exemplo.com.br

## 🎮 Comandos

### Criação

Comando

Descrição

`launchinfra NOME`

Site estático com SSL

`launchinfra NOME PORTA`

Proxy reverso com SSL

`launchinfra NOME --no-ssl`

Site HTTP apenas

`launchinfra NOME --force`

Forçar ignorando conflitos

`launchinfra NOME --dry-run`

Simular sem aplicar

`launchinfra NOME --domain DOMINIO`

Domínio customizado

`launchinfra NOME --template DIR`

Template HTML customizado

### Gerenciamento

Comando

Descrição

`launchinfra --list` / `ls`

Listar projetos do usuário (root vê todos)

`launchinfra --info NOME`

Detalhes do projeto (domínio, porta, SSL, data)

`launchinfra --disable NOME`

Desativar projeto (preserva config)

`launchinfra --restore NOME`

Reativar projeto desativado

`launchinfra --renew NOME`

Renovar certificado SSL

`launchinfra --remove NOME` / `rm`

Remover projeto

`launchinfra --remove NOME --backup`

Remover com backup (.tar.gz)

### Utilitários

Comando

Descrição

`launchinfra --list-ports` / `ports`

Portas em uso no sistema

`launchinfra --check-port PORTA`

Verificar se porta está em uso

`launchinfra --check-domain NOME`

Verificar se domínio está em uso

`launchinfra --check-ssl`

Status de expiração de todos SSLs

`launchinfra --version` / `-v`

Versão

`launchinfra --help` / `-h`

Ajuda

### Configuração

Comando

Descrição

`launchinfra config --email EMAIL`

Definir email para certificados SSL

`launchinfra config --domain DOMINIO`

Definir domínio base

`launchinfra config --show`

Ver configuração atual

## 🧪 Exemplos

    launchinfra blog
    launchinfra api 3000
    launchinfra app --domain meusite.com.br 8080
    launchinfra teste --no-ssl
    launchinfra blog --template ~/meu-template/
    launchinfra novo --dry-run
    launchinfra config --email dev@exemplo.com --domain exemplo.com
    launchinfra ls
    launchinfra rm blog

## 🔄 Fluxo de criação

    launchinfra blog
      → Valida nome
      → Verifica conflitos
      → Cria /var/www/projetos/usuario/blog
      → Configura Nginx HTTP
      → Certbot --nginx → HTTPS
      → ✓ https://blog.exemplo.com

## 👥 Multi-usuário

Cada usuário gerencia apenas seus próprios projetos. Root tem acesso total.

    /var/www/projetos/
    ├── professor1/
    │   └── blog/
    ├── professor2/
    │   └── site/

    /etc/nginx/sites-available/
    ├── professor1-blog
    └── professor2-site

Usuário sem grupo `launchinfra` não consegue usar o comando. Comando **sem sudo** para membros do grupo.

## 🛡️ Segurança

- Helper privilegiado em `/usr/local/bin/launchinfra-helper`
- Sudoers permite apenas comandos específicos sem senha
- Grupo `launchinfra` isola permissões
- Usuário só remove/desativa seus próprios projetos

## 📋 Versionamento

    # Manual
    ./scripts/bump-version.sh 2.0.6 "Descrição"

    # Automático (detecta feat/fix)
    ./scripts/release-auto.sh

    # Build + instala
    ./scripts/build-install.sh

## 🤖 CI/CD

Push na `main` com commits `feat:` ou `fix:` dispara release automático no GitHub Actions, gerando tag, release e `.deb`.

## 📁 Estrutura

    src/
    ├── launchinfra.sh
    └── lib/
        ├── cli.sh
        ├── config.sh
        ├── logging.sh
        ├── nginx_project.sh
        └── utils.sh
    debian/
    ├── control
    ├── postinst
    ├── postrm
    ├── rules
    └── changelog
    scripts/
    ├── bump-version.sh
    ├── release.sh
    ├── release-auto.sh
    └── build-install.sh

## 📄 Licença

Uso permitido. **Redistribuição PROIBIDA** sem autorização expressa do autor.
