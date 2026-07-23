# 🚀 LaunchInfra

Ferramenta para criar e gerenciar sites e proxies Nginx com suporte a Let's Encrypt.

## 📦 Dependências

### Build (desenvolvimento)

    sudo apt update
    sudo apt install -y devscripts debhelper build-essential

### Runtime (sistema)

As dependências de runtime (**nginx**, **certbot**, **python3-certbot-nginx**) são instaladas automaticamente ao instalar o pacote `.deb`. Não é necessária instalação manual.

- **nginx**: Servidor web e proxy reverso
- **certbot**: Gerador e gerenciador de certificados SSL/TLS Let's Encrypt
- **python3-certbot-nginx**: Plugin do certbot para integração com Nginx

## ⚡ Instalação

### Instalar todas as dependências

    make install-deps

Ou separadamente:

    # Apenas build
    make install-deps-build

    # Apenas runtime
    make install-deps-runtime

### Build do pacote .deb

    make build

O arquivo `.deb` ficará no diretório pai.

### Instalar o pacote

    sudo dpkg -i ../launchinfra_*.deb

### Build + instalação automática

    ./scripts/build-install.sh

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

Listar projetos

`launchinfra --info NOME`

Detalhes do projeto

`launchinfra --disable NOME`

Desativar (preserva config)

`launchinfra --restore NOME`

Reativar projeto

`launchinfra --renew NOME`

Renovar certificado SSL

`launchinfra --remove NOME` / `rm`

Remover projeto

`launchinfra --remove NOME --backup`

Remover com backup

### Utilitários

Comando

Descrição

`launchinfra --list-ports` / `ports`

Portas em uso

`launchinfra --check-port PORTA`

Verificar porta

`launchinfra --check-domain NOME`

Verificar domínio

`launchinfra --check-ssl`

Status de todos SSLs

`launchinfra --version` / `-v`

Versão

`launchinfra --help` / `-h`

Ajuda

### Configuração

Comando

Descrição

`launchinfra config --email EMAIL`

Definir email

`launchinfra config --domain DOMINIO`

Definir domínio base

`launchinfra config --system`

Salvar em /etc

`launchinfra config --show`

Ver configuração

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
      → Cria /var/www/projetos/blog
      → Configura Nginx HTTP
      → Certbot --nginx → HTTPS
      → ✓ https://blog.exemplo.com

## 📋 Versionamento

    # Manual
    ./scripts/bump-version.sh 2.0-6 "Descrição das mudanças"

    # Automático (detecta feat/fix dos commits)
    ./scripts/release-auto.sh

    # Build + instala
    ./scripts/build-install.sh

## 🤖 CI/CD

Push na `main` com commits `feat:` ou `fix:` dispara release automático no GitHub Actions, gerando tag, release e `.deb` anexado.

## 📁 Estrutura

    src/
    ├── launchinfra.sh          # Bootstrap
    └── lib/
        ├── cli.sh              # Dispatch de comandos
        ├── config.sh           # Configuração
        ├── logging.sh          # Cores e log
        ├── nginx_project.sh    # CRUD de projetos
        └── utils.sh            # Utilitários

## 📄 Licença

Uso permitido. **Redistribuição PROIBIDA** sem autorização expressa do autor.
