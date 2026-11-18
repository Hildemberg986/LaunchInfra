# Plano de Implementação: Motor de Presets e Modificadores Nginx

> **Para o Agente:** SUB-SKILL OBRIGATÓRIA: Utilize `executing-plans` para implementar este plano tarefa por tarefa.

**Objetivo:** Implementar no LaunchInfra um motor extensível de Presets de aplicação (`--preset <nome>`) e Modificadores incrementais (`launchinfra mod <proj> <add|rm|list> <recurso>`), baseados em snippets modulares do Nginx em `/usr/share/launchinfra/snippets/`.

**Arquitetura:** 
- Snippets Nginx reutilizáveis em `src/snippets/*.conf`.
- Novo módulo `src/lib/modifiers.sh` contendo a lógica de injeção, remoção, listagem e aplicação de presets.
- Preservação da integridade do vhost através de delimitadores (`# --- [launchinfra:snippets:start] ---`).
- Validação automática de sintaxe via `nginx -t` e rollback seguro em caso de falha.
- Empacotamento Debian via `Makefile` e `debian/rules`.

**Tech Stack:** Bash POSIX/GNU, Nginx, ShellCheck, Debian packaging.

---

### Tarefa 1: Criação dos Snippets Nginx Compartilhados

**Arquivos:**
- Criar: `src/snippets/cors.conf`
- Criar: `src/snippets/security.conf`
- Criar: `src/snippets/protect-hidden.conf`
- Criar: `src/snippets/gzip.conf`
- Criar: `src/snippets/static-cache.conf`
- Criar: `src/snippets/spa.conf`

**Passo 1: Escrever os 6 arquivos de snippets modulares**
- `cors.conf`: Headers `Access-Control-Allow-Origin *`, métodos permitidos e resposta para `OPTIONS`.
- `security.conf`: `X-Frame-Options SAMEORIGIN`, `X-Content-Type-Options nosniff`, `Referrer-Policy`, HSTS.
- `protect-hidden.conf`: Bloqueio de dotfiles (`location ~ /\. { deny all; access_log off; log_not_found off; }`).
- `gzip.conf`: Compressão gzip ativa com tipos MIME para HTML, CSS, JS, JSON, SVG e XML.
- `static-cache.conf`: `expires 30d` e cabeçalhos de cache para imagens, fontes e assets compilados.
- `spa.conf`: Fallback de roteamento SPA `try_files $uri $uri/ /index.html;`.

**Passo 2: Commit**
```bash
git add src/snippets/
git commit -m "feat(snippets): add modular Nginx configuration snippets"
```

---

### Tarefa 2: Instalação e Empacotamento dos Snippets no Sistema

**Arquivos:**
- Modificar: `Makefile`
- Modificar: `debian/rules`

**Passo 1: Atualizar o Makefile para instalar os snippets**
- Instalar `src/snippets/*.conf` em `$(DESTDIR)/usr/share/launchinfra/snippets/`.

**Passo 2: Atualizar `debian/rules` se necessário**
- Garantir que o diretório `/usr/share/launchinfra/snippets` seja criado e incluído no pacote `.deb`.

**Passo 3: Commit**
```bash
git add Makefile debian/rules
git commit -m "build: install Nginx snippets to /usr/share/launchinfra/snippets"
```

---

### Tarefa 3: Implementação do Módulo de Modificadores (`src/lib/modifiers.sh`)

**Arquivos:**
- Criar: `src/lib/modifiers.sh`
- Modificar: `src/launchinfra.sh` (carregar o módulo `modifiers`)

**Passo 1: Implementar as funções centrais**
- `get_snippets_dir()`: Localiza o diretório de snippets (local em dev ou `/usr/share/launchinfra/snippets`).
- `list_modifiers(project)`: Analisa o vhost do Nginx e lista quais snippets estão ativados.
- `add_modifier(project, modifier, [args])`:
  - Valida se o modificador existe.
  - Cria cópia de trabalho segura no diretório temporário do usuário.
  - Insere o `include <snippet>;` na seção delimitada do arquivo.
  - Aplica no vhost, testa com `nginx -t` e recarrega.
  - Reverte se `nginx -t` falhar.
- `remove_modifier(project, modifier)`:
  - Remove a linha de include correspondente.
  - Valida e recarrega o Nginx.
- `apply_preset(project, preset)`:
  - Aplica o conjunto de snippets do preset escolhido (`spa`, `api`, `secure`, `static-cached`).

**Passo 2: Atualizar `src/launchinfra.sh`**
- Adicionar `modifiers` na lista de módulos carregados no bootstrap.

**Passo 3: Validar com ShellCheck**
```bash
shellcheck src/lib/modifiers.sh src/launchinfra.sh
```

**Passo 4: Commit**
```bash
git add src/lib/modifiers.sh src/launchinfra.sh
git commit -m "feat: implement modifiers and presets engine in modifiers.sh"
```

---

### Tarefa 4: Integração de Presets na Criação de Projetos (`src/lib/nginx_project.sh`)

**Arquivos:**
- Modificar: `src/lib/nginx_project.sh`

**Passo 1: Suporte à flag `--preset <nome>` no `create_project()`**
- Adicionar parsing de `--preset`.
- Gerar os blocos virtuais do Nginx com a seção delimitada:
  ```nginx
  # --- [launchinfra:snippets:start] ---
  # --- [launchinfra:snippets:end] ---
  ```
- Logo após a criação inicial do vhost, invocar `apply_preset "$PROJETO" "$PRESET"` caso a flag tenha sido fornecida.
- Suportar visualização do preset no `--dry-run`.

**Passo 2: Validar com ShellCheck**
```bash
shellcheck src/lib/nginx_project.sh
```

**Passo 3: Commit**
```bash
git add src/lib/nginx_project.sh
git commit -m "feat: support --preset flag in create_project"
```

---

### Tarefa 5: Integração do Subcomando `mod` e Documentação na CLI (`src/lib/cli.sh`)

**Arquivos:**
- Modificar: `src/lib/cli.sh`
- Modificar: `src/bash-completion/launchinfra`

**Passo 1: Adicionar despacho de `mod` no `dispatch_cli()`**
- Sintaxe: `launchinfra mod PROJETO <add|rm|list> [RECURSO] [ARGS]`
- Casos de erro e mensagens informativas.

**Passo 2: Atualizar `show_help()`**
- Adicionar seção `-- Modificadores Nginx --` documentando `mod` e os presets disponíveis.

**Passo 3: Atualizar Bash Completion**
- Adicionar autocompletion para o comando `mod`, seus subcomandos (`add`, `rm`, `list`) e a lista de modificadores disponíveis (`cors`, `security`, `protect-hidden`, `gzip`, `static-cache`, `spa`, `basic-auth`, `rate-limit`).

**Passo 4: Validar com ShellCheck**
```bash
shellcheck src/lib/cli.sh
```

**Passo 5: Commit**
```bash
git add src/lib/cli.sh src/bash-completion/launchinfra
git commit -m "feat(cli): add 'mod' command and bash completion for Nginx modifiers"
```

---

### Tarefa 6: Testes Integrados e Validação Final

**Passo 1: Testar fluxo completo de criação com presets**
- Testar `--dry-run` de cada preset: `spa`, `api`, `secure`, `static-cached`.
- Testar validações de sintaxe.

**Passo 2: Testar comandos `mod`**
- Testar `list`, `add`, `rm`.

**Passo 3: Rodar Shellcheck em todo o repositório**
```bash
shellcheck src/*.sh src/lib/*.sh
```

**Passo 4: Commit e Tag/Push de Release ou PR**
