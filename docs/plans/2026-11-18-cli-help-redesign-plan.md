# [UX/CLI] Redesign do Sistema de Ajuda (Help) do LaunchInfra

> **For Antigravity:** REQUIRED SUB-SKILL: Load executing-plans to implement this plan task-by-task.

**Goal:** Transformar o sistema de ajuda do LaunchInfra (`launchinfra --help`, `launchinfra help`, e subcomandos como `launchinfra mod --help`) em uma interface moderna, profissional, categorizada e explicativa inspirada em ferramentas como Docker CLI e GitHub CLI (`gh`).

**Architecture:** Centralizar a formatação de ajuda no módulo `src/lib/cli.sh`, implementando suporte a cores condicionais (respeitando pipes), ajudas contextuais para subcomandos (`help_mod()`, `help_config()`), explicação detalhada de presets e modificadores, e roteamento flexível no `dispatch_cli()` para `help <subcomando>`.

**Tech Stack:** Bash puro (POSIX-compliant com Bash 4+), ShellCheck, ANSI styling condicional.

---

### Task 1: Estruturar Sub-Ajuda Contextual para Modificadores (`launchinfra mod --help`)
**Files:**
- Modify: `src/lib/modifiers.sh` ou `src/lib/cli.sh`
- Test: manual via `./src/launchinfra.sh mod --help`

**Step 1: Implementar `show_mod_help()`**
Documentar detalhadamente a sintaxe:
- `launchinfra mod <projeto> list`
- `launchinfra mod <projeto> add <recurso>`
- `launchinfra mod <projeto> rm <recurso>`
Descrever cada um dos recursos disponíveis com seu propósito e impacto técnico:
- `cors`: Permite requisições de outros domínios com suporte a preflight.
- `security`: Aplica headers restritivos HTTP (HSTS, CSP, X-Frame-Options).
- `protect-hidden`: Bloqueia leitura de arquivos sensíveis (.git, .env).
- `gzip`: Ativa compressão HTTP gzip para assets estáticos e payloads de APIs.
- `static-cache`: Adiciona cabeçalhos de cache agressivo (Cache-Control: max-age=31536000, immutable).
- `spa`: Adiciona regra de fallback de rotas client-side (`try_files $uri $uri/ /index.html`).

**Step 2: Conectar ao `dispatch_cli()`**
Garantir que `launchinfra mod --help`, `launchinfra mod -h` ou `launchinfra mod help` invoque a ajuda do `mod`.

---

### Task 2: Estruturar Sub-Ajuda Contextual para Configurações (`launchinfra config --help`)
**Files:**
- Modify: `src/lib/cli.sh`
- Test: manual via `./src/launchinfra.sh config --help`

**Step 1: Implementar `show_config_help()`**
Documentar detalhadamente:
- Opções `--email`, `--domain`, `--show`
- Arquivo onde as configurações são persistidas (`~/.config/launchinfra/config` ou `/etc/launchinfra/config`)
- Exemplos de setup inicial do administrador.

---

### Task 3: Redesenhar o Menu Principal de Ajuda (`show_help()`)
**Files:**
- Modify: `src/lib/cli.sh`

**Estrutura do Novo Menu Principal:**
1. **Cabeçalho:** Nome da ferramenta, versão dinâmica, slogan conciso.
2. **USO / SYNOPSIS:**
   - `launchinfra <comando> [opções...]`
   - `launchinfra <projeto> [porta] [opções de criação]`
3. **COMANDOS PRINCIPAIS (Categorizados):**
   - **Gerenciamento de Projetos:** `create`, `list/ls`, `info`, `edit`, `backup`, `disable`, `restore/enable`, `remove/rm`
   - **Modificadores Nginx:** `mod <projeto> <list|add|rm> <recurso>`
   - **Certificados SSL:** `renew`, `check-ssl`
   - **Diagnóstico e Rede:** `ports`, `check-port`, `check-domain`
   - **Configuração do Sistema:** `config`, `setup-nginx`
4. **OPÇÕES DE CRIAÇÃO (`create`):**
   - `--preset <nome>` (spa, api, secure, static-cached)
   - `--no-ssl`
   - `--domain <dominio>`
   - `--template <diretório>`
   - `--max-body <tamanho>` (ex: 50M, 100M)
   - `--dry-run`
   - `--force`
5. **PRESETS PRÉ-CONFIGURADOS (Explicação detalhada):**
   - `spa`: Single Page Application (fallback de rotas, gzip e cache de estáticos)
   - `api`: Proxy reverso otimizado com suporte a WebSockets e CORS
   - `secure`: Blindagem máxima de headers e proteção a arquivos sensíveis
   - `static-cached`: Site estático de altíssima performance com gzip e cache de assets
6. **MODIFICADORES NGINX (`launchinfra mod`):**
   - Lista explicativa com `cors`, `security`, `protect-hidden`, `gzip`, `static-cache`, `spa`
7. **EXEMPLOS PRÁTICOS (Do básico ao avançado):**
   - Criação de SPA, API com preset, domínio customizado, adição de modificadores, backup.
8. **RODAPÉ / AJUDA ADICIONAL:**
   - Link do repositório, documentação, como obter ajuda específica (`launchinfra help <comando>`).

---

### Task 4: Adicionar Suporte a `launchinfra help [subcomando]`
**Files:**
- Modify: `src/lib/cli.sh`

Permitir que o usuário digite tanto `launchinfra --help` quanto `launchinfra help`, e também `launchinfra help mod` ou `launchinfra help config`.

---

### Task 5: Validação, ShellCheck e Abertura de Pull Request
**Files:**
- Verify: `shellcheck src/*.sh src/lib/*.sh`
- Test: execução de todos os fluxos de help
- Open PR vinculando a Issue #25.
