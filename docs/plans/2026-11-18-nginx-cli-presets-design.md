# Design Specification: Motor de Presets e Modificadores Nginx para o LaunchInfra

**Data:** 18 de novembro de 2026  
**Status:** Aprovado  
**Objetivo:** Transformar diretivas complexas do Nginx em comandos CLI simples, intuitivos e modulares através de Presets de aplicação e Modificadores incrementais.

---

## 1. Visão Geral e Experiência do Desenvolvedor (CLI)

O LaunchInfra adota um modelo híbrido para configuração do Nginx:
1. **Presets na criação (`--preset <nome>`)**: Configura automaticamente o conjunto ideal de diretivas para o tipo da aplicação (SPA, API, segurança estrita, cache estático).
2. **Modificadores incrementais (`launchinfra mod <projeto> <add|rm|list> <recurso>`)**: Permite ligar ou desligar blocos específicos de configuração a qualquer momento, com teste de sintaxe e recarregamento automático do Nginx.

### Exemplos de Uso

```bash
# Criação direta com presets
launchinfra meu-frontend --preset spa
launchinfra minha-api 3000 --preset api
launchinfra blog --preset static-cached
launchinfra admin-panel 8080 --preset secure

# Modificadores em projetos existentes
launchinfra mod minha-api add cors
launchinfra mod minha-api add protect-hidden
launchinfra mod minha-api add rate-limit
launchinfra mod blog add gzip
launchinfra mod blog add basic-auth dev:segredo123

# Inspeção e remoção
launchinfra mod minha-api list
launchinfra mod minha-api rm cors
```

---

## 2. Arquitetura dos Snippets Nginx

Os blocos de configuração são instalados no sistema em `/usr/share/launchinfra/snippets/*.conf`, permitindo reutilização, testes pontuais e atualizações de segurança sem reescrever os arquivos dos projetos.

### Catálogo de Snippets

| Snippet | Arquivo | Finalidade |
|---|---|---|
| **CORS** | `cors.conf` | Libera `Access-Control-Allow-Origin *`, métodos HTTP comuns e pré-voo `OPTIONS`. |
| **Security Headers** | `security.conf` | `X-Frame-Options: SAMEORIGIN`, `X-Content-Type-Options: nosniff`, `Referrer-Policy`, HSTS estrito. |
| **Protect Hidden** | `protect-hidden.conf` | Bloqueia acesso a arquivos dotfile (`.env`, `.git`, `.htaccess`, `.svn`) retornando 403/404. |
| **Gzip Compression** | `gzip.conf` | Ativa compactação gzip para HTML, CSS, JS, JSON, XML e fontes com nível 6. |
| **Static Cache** | `static-cache.conf` | Define cabeçalhos `Cache-Control "public, no-transform"` e expiração de 30 dias para mídias e assets estáticos. |
| **SPA Fallback** | `spa.conf` | Redirecionamento `try_files $uri $uri/ /index.html` para roteamento no cliente (HTML5 History API). |

---

## 3. Catálogo de Presets

Cada preset combina os snippets de forma coerente:

* **`spa`** (Single Page Applications - React, Vue, Vite, Angular):
  * Base: Site estático
  * Snippets: `spa.conf`, `gzip.conf`, `static-cache.conf`, `protect-hidden.conf`
* **`api`** (APIs e Microsserviços - Node.js, FastAPI, Go, Docker):
  * Base: Proxy reverso
  * Snippets: WebSockets nativos (`Upgrade`), `protect-hidden.conf`, `client_max_body_size 50M`
* **`secure`** (Aplicações com alta exigência de segurança):
  * Base: Estático ou Proxy
  * Snippets: `security.conf` (Headers A+), `protect-hidden.conf`
* **`static-cached`** (Sites estáticos de alta performance):
  * Base: Site estático
  * Snippets: `gzip.conf`, `static-cache.conf`, `protect-hidden.conf`

---

## 4. Estrutura do Virtual Host do Projeto

Os arquivos de configuração em `/etc/nginx/sites-available/<projeto>` utilizam delimitadores padronizados para injeção de snippets:

```nginx
# Projeto: api | Usuario: dev
server {
    listen 80;
    server_name api.meudominio.com;

    # --- [launchinfra:snippets:start] ---
    include /usr/share/launchinfra/snippets/cors.conf;
    include /usr/share/launchinfra/snippets/protect-hidden.conf;
    # --- [launchinfra:snippets:end] ---

    client_max_body_size 50M;

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

---

## 5. Fluxo de Operação e Segurança

1. **Idempotência**: Ao adicionar um modificador já presente, o comando apenas informa que o recurso já está ativo.
2. **Validação e Rollback**:
   * O arquivo é modificado em cópia temporária do usuário.
   * Injetado via `run_helper tee-nginx`.
   * Testado com `run_helper nginx-test`.
   * Se válido, `run_helper nginx-reload`.
   * Se inválido, revertido imediatamente ao backup e mensagem de erro apresentada ao usuário.
3. **Casos Especiais**:
   * `basic-auth`: Gera senha criptografada via `openssl passwd` e salva em pasta protegida `/etc/nginx/launchinfra-auth/`.
   * `rate-limit`: Configura zona de limite de requisições por IP e aplica no vhost.

---

## 6. Empacotamento Debian

* Os arquivos `.conf` dos snippets serão incluídos em `src/snippets/`.
* No `debian/rules` e `Makefile`, serão instalados em `/usr/share/launchinfra/snippets/`.
* No `debian/postinst`, a pasta de auth `/etc/nginx/launchinfra-auth/` será criada com permissões adequadas.
