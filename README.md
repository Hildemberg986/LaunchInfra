# LaunchInfra

> Ferramenta para criar e gerenciar sites e proxies Nginx com suporte a Let's Encrypt.

**Versão atual:** 2.4.1

**Compatibilidade:** Ubuntu 18.04 (Bionic Beaver) até 24.04 (Noble Numbat) e variantes (Kubuntu, Xubuntu, Lubuntu, etc). Suporta systemd e sysvinit.

---

## Índice

- [Instalação](#instalação)
- [Pós-instalação](#pós-instalação)
- [Comandos](#comandos)
- [Bash Completion](#bash-completion)
- [Exemplos](#exemplos)
- [Fluxo de Criação](#fluxo-de-criação)
- [Multi-usuário](#multi-usuário)
- [Segurança](#segurança)
- [Repositório PPA/APT](#repositório-ppaapt)
- [Versionamento](#versionamento)
- [CI/CD](#cicd)
- [Estrutura](#estrutura)
- [Licença](#licença)

---

## Instalação

### Rápido (Ubuntu qualquer versão)

```bash
sudo add-apt-repository ppa:hildemberg986/launchinfra
sudo apt update
sudo apt install launchinfra
```

Funciona em Ubuntu 18.04 (bionic) até a versão atual (noble, jammy, e futuras como resolute). A replicação automática entre séries no painel do Launchpad garante cobertura.

### Script automático (Ubuntu, Debian, Mint, Pop_OS, etc.)

```bash
curl -fsSL https://Hildemberg986.github.io/LaunchInfra/install.sh | sudo bash
```

O script detecta a distribuição e configura a melhor fonte:

- **Ubuntu** → PPA `ppa:hildemberg986/launchinfra`
- **Debian, Mint, Pop_OS, elementary, Zorin, Kali** → repositório estável `https://Hildemberg986.github.io/LaunchInfra/` (suite `stable`)

### Manual em Debian e derivados

```bash
sudo install -d -m 0755 /etc/apt/keyrings
curl -fsSL https://Hildemberg986.github.io/LaunchInfra/public.key \
    | sudo gpg --dearmor -o /etc/apt/keyrings/launchinfra.gpg
echo "deb [signed-by=/etc/apt/keyrings/launchinfra.gpg] https://Hildemberg986.github.io/LaunchInfra/ stable main" \
    | sudo tee /etc/apt/sources.list.d/launchinfra.list
sudo apt update
sudo apt install launchinfra
```

### Via .deb local

```bash
make build                              # Build do .deb
sudo dpkg -i ../launchinfra_*.deb       # Instalar
```

### Atualizações automáticas

Em **Ubuntu Server** o pacote `unattended-upgrades` já vem ativo por padrão. Para confirmar:

```bash
apt list --installed 2>/dev/null | grep unattended-upgrades
dpkg-reconfigure -plow unattended-upgrades   # habilitar interativamente
```

Em qualquer distro Debian-like, atualizações vêm via `sudo apt update && sudo apt upgrade`.

### Dependências de build

```bash
sudo apt update && sudo apt install -y devscripts debhelper build-essential
```

Dependências de runtime (instaladas automaticamente via `Depends`):
- **nginx** — servidor web e proxy reverso
- **certbot** — gerenciador de certificados SSL/TLS
- **python3-certbot-nginx** — plugin certbot para Nginx
- **bash-completion** — completion de comandos

| Pacote                | Função                              |
| --------------------- | ----------------------------------- |
| nginx                 | Servidor web e proxy reverso        |
| certbot               | Gerenciador de certificados SSL/TLS |
| python3-certbot-nginx | Plugin certbot para Nginx           |
| bash-completion       | Autocomplete no shell               |

---

## Pós-instalação

```bash
# Adicionar usuário ao grupo (uma vez)
sudo usermod -aG launchinfra USUARIO
# Fazer logout/login

# Configurar (uma vez)
launchinfra config --email admin@exemplo.com
launchinfra config --domain exemplo.com.br

# Ver configuração atual
launchinfra config --show

# Configurar nginx default (uma vez, como root)
sudo launchinfra setup-nginx
```

---

## Comandos

### Criação

| Comando                              | Descrição                                      |
| ------------------------------------ | ---------------------------------------------- |
| `launchinfra NOME`                   | Site estático com SSL                          |
| `launchinfra NOME PORTA`             | Proxy reverso com SSL                          |
| `launchinfra NOME --no-ssl`          | Site HTTP apenas (sem SSL)                     |
| `launchinfra NOME --force`           | Forçar criação ignorando conflitos             |
| `launchinfra NOME --dry-run`         | Simular criação sem aplicar alterações         |
| `launchinfra NOME --domain DOM`      | Domínio customizado (substitui DOMINIO_BASE)   |
| `launchinfra NOME --template DIR`    | Usar template HTML personalizado               |

> **Proxy reverso**: a porta indicada deve ter o serviço rodando (ex: container Docker). O LaunchInfra configura apenas o proxy Nginx — não inicia o backend.

### Gerenciamento

| Comando                                 | Descrição                          |
| --------------------------------------- | ---------------------------------- |
| `launchinfra --list` / `launchinfra ls` | Listar seus projetos (root: todos) |
| `launchinfra --info NOME`               | Detalhes de um projeto             |
| `launchinfra --edit NOME`               | Editar configuração Nginx          |
| `launchinfra --disable NOME`            | Desativar (preserva configuração)  |
| `launchinfra --restore NOME`            | Reativar projeto desativado        |
| `launchinfra --renew NOME`              | Renovar certificado SSL            |
| `launchinfra --remove NOME` / `launchinfra rm NOME` | Remover projeto         |
| `launchinfra --remove NOME --backup`    | Remover com backup (.tar.gz)       |

### Servidor

| Comando                       | Descrição                                  |
| ----------------------------- | ------------------------------------------ |
| `sudo launchinfra setup-nginx` | Configurar Nginx default para wildcard SSL |

> Requer root. Configure uma vez antes de criar projetos com SSL.

### Utilitários

| Comando                              | Descrição                    |
| ------------------------------------ | ---------------------------- |
| `launchinfra --list-ports` / `launchinfra ports` | Listar portas em uso |
| `launchinfra --check-port PORTA`     | Verificar se porta está em uso |
| `launchinfra --check-domain DOM`     | Verificar se domínio está em uso |
| `launchinfra --check-ssl`            | Verificar expiração de todos os SSLs |
| `launchinfra --version` / `launchinfra -v` | Mostrar versão       |
| `launchinfra --help` / `launchinfra -h`    | Mostrar ajuda      |

### Configuração

| Comando                              | Descrição              |
| ------------------------------------ | ---------------------- |
| `launchinfra config --email EMAIL`   | Definir email de contato |
| `launchinfra config --domain DOM`    | Definir domínio base    |
| `launchinfra config --show`          | Exibir configuração     |

---

## Bash Completion

O LaunchInfra instala **automaticamente** o bash completion em `/usr/share/bash-completion/completions/launchinfra`. Após instalar o pacote, basta **reiniciar o shell** (ou abrir novo terminal) e digitar:

```bash
launchinfra <TAB>           # completa comandos
launchinfra meu-<TAB>       # completa com nome de projeto existente
launchinfra --check-port 8<TAB>  # completa portas comuns
```

**Completa:**
- Comandos principais: `--list`, `--info`, `--edit`, `--remove`, `--disable`, `--restore`, `--renew`, `--check-ssl`, `--check-port`, `--check-domain`, `setup-nginx`, `config`
- Nomes de projetos do seu usuário (via `launchinfra --list`)
- Opções de criação: `--no-ssl`, `--force`, `--dry-run`, `--domain`, `--template`
- Portas comuns (80, 443, 3000, 5000, 8000, 8080, 8443)
- Diretórios para `--template`
- Sub-opções de `config`

---

## Exemplos

```bash
# Criar site estático com SSL
launchinfra blog

# Criar proxy reverso (backend na porta 3000)
launchinfra api 3000

# Domínio customizado + porta
launchinfra app --domain meusite.com.br 8080

# Apenas HTTP
launchinfra teste --no-ssl

# Com template HTML
launchinfra blog --template ~/meu-template/

# Simular sem aplicar
launchinfra novo --dry-run

# Configurar
launchinfra config --email dev@exemplo.com
launchinfra config --domain exemplo.com
launchinfra config --show

# Gerenciar
launchinfra ls
launchinfra --info blog
launchinfra --edit blog
launchinfra --renew blog
launchinfra rm blog
launchinfra --remove blog --backup
launchinfra --disable blog
launchinfra --restore blog

# Utilitários
launchinfra --list-ports
launchinfra --check-port 8080
launchinfra --check-domain meusite.com.br
launchinfra --check-ssl

# Setup inicial
sudo launchinfra setup-nginx
```

---

## Fluxo de Criação

```
launchinfra blog
  -> Valida nome
  -> Verifica conflitos (projeto/dominio)
  -> Cria /var/www/projetos/usuario/blog
  -> Configura Nginx HTTP
  -> Temporariamente remove default_server (evita bug SSL)
  -> Certbot --nginx -> HTTPS no arquivo do projeto
  -> Restaura default_server
  -> https://blog.exemplo.com
```

### Bug crítico evitado: SSL indo para o arquivo `default`

O LaunchInfra detecta e evita um bug conhecido: quando o `default_server` está ativo, o Certbot pode aplicar as diretivas SSL ao arquivo `default` em vez do arquivo do projeto. A solução:

1. Salva o conteúdo de `/etc/nginx/sites-available/default`
2. Remove o link em `/etc/nginx/sites-enabled/default`
3. Recarrega o Nginx
4. Roda `certbot --nginx` (certbot só vê o projeto)
5. Restaura o backup do `default`
6. Recria o link
7. Recarrega o Nginx

Garantia: o SSL fica no arquivo correto (`/etc/nginx/sites-available/usuario-projeto`).

---

## Multi-usuário

Cada usuário gerencia apenas seus projetos. Root vê tudo.

```
/var/www/projetos/
├── professor1/
│   ├── blog/
│   └── site/
├── professor2/
│   └── app/
└── aluno1/
    └── portfolio/

/etc/nginx/sites-available/
├── professor1-blog
├── professor1-site
├── professor2-app
└── aluno1-portfolio
```

**Convenção de nomes:** Nginx usa `usuario-projeto` para isolar. O domínio segue `projeto.dominiobase.com` (configurável via `--domain`).

Usuários sem grupo `launchinfra` não executam o comando. Membros do grupo usam **sem sudo**.

Para adicionar um usuário:

```bash
sudo usermod -aG launchinfra NOME
# logout/login para aplicar
```

---

## Segurança

| Camada      | Descrição                           |
| ----------- | ----------------------------------- |
| Helper      | `/usr/local/bin/launchinfra-helper` (sempre sobrescrito pelo postinst) |
| Sudoers     | Comandos específicos sem senha      |
| Grupo       | `launchinfra` isola permissões      |
| Propriedade | Usuário só gerencia seus projetos   |

### Helper

O `launchinfra-helper` é instalado em `/usr/local/bin/launchinfra-helper` e expõe apenas operações privilegiadas específicas:

- `nginx-test`, `nginx-reload` (com fallback systemd/sysvinit/direct)
- `certbot` (todos os argumentos)
- `chown-www`, `mkdir` (com ownership)
- `rm-nginx`, `rm-files`, `ln-nginx`
- `tee-nginx`, `tee-log`, `cat-nginx`, `cp-backup`
- `cp-template`, `tar-backup`, `edit-nginx`
- `openssl-check` (para verificar SSL)

> **Importante:** o helper é **sempre reescrito** pelo `postinst` ao instalar/atualizar. Isso garante que versões antigas com bugs (ex: helper sem `cat-nginx`/`cp-backup`) sejam corrigidas automaticamente.

---

## Repositório PPA/APT

O LaunchInfra é distribuído via repositório APT hospedado em `https://Hildemberg986.github.io/LaunchInfra/`.

**Estrutura:**
- Branch `main` — código fonte
- Branch `gh-pages` — repositório APT (`pool/main/l/launchinfra/`, `dists/stable/`)
- Tags `v*` — releases GitHub com `.deb` anexado

**Fluxo de release:**
1. Push na `main` com conventional commits (`feat:`, `fix:`)
2. GitHub Actions detecta o tipo de bump
3. Bump automático da versão
4. Build do `.deb`
5. Assinatura GPG e upload para PPA (`ppa:hildemberg986/launchinfra`)
6. Publicação no GitHub Releases
7. Publicação na `gh-pages` (APT repo)
8. Usuários recebem via `apt upgrade`

---

## Versionamento

```bash
# Bump manual
./scripts/bump-version.sh 2.4.1 "Descrição das mudanças"

# Detectar bump via conventional commits
./scripts/release-auto.sh

# Release com nível explícito
./scripts/release.sh patch
./scripts/release.sh minor
./scripts/release.sh major
```

---

## CI/CD

Push na `main` com `feat:` ou `fix:` → release automático no GitHub Actions:
- Bump de versão
- Build do `.deb`
- Assinatura e upload para PPA
- Publicação na branch `gh-pages`
- Release no GitHub

---

## Estrutura

```
src/
├── launchinfra.sh              # Bootstrap (entry point)
├── lib/
│   ├── cli.sh                  # Dispatch de comandos e argumentos
│   ├── config.sh               # Configuração, usuário, helper
│   ├── nginx_project.sh        # Operações: criar, remover, editar, SSL
│   ├── utils.sh                # Portas, domínios, listagem, backup
│   └── logging.sh              # Funções de log colorido
├── bash-completion/
│   └── launchinfra             # Script de bash completion
debian/
├── control                     # Metadados do pacote
├── postinst                    # Setup do helper, sudoers, completion
├── postrm                      # Limpeza na remoção
├── rules                       # Build rules
├── compat                      # debhelper compat
└── changelog                   # Changelog
scripts/
├── bump-version.sh             # Atualiza versão e builda
├── release.sh                  # Versionamento automático
└── release-auto.sh             # Detecta bump via conventional commits
```

---

## Licença

Copyright (c) 2024-2026 Hildemberg Eling de Araujo Lucena.

Uso permitido. **Redistribuição PROIBIDA** sem autorização expressa do autor.
