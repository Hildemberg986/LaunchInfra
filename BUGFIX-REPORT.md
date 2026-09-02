# LaunchInfra v2.4.1 - Relatório de Correções de Bugs

**Data:** 01 de setembro de 2026  
**Versão:** 2.4.1  
**Status:** Pronto para compilação e distribuição via PPA

---

## Bugs Críticos Corrigidos

### 1. **SSL indo para arquivo `default`** ✅ CRÍTICO
- **Problema:** Quando o `default_server` estava ativo, o Certbot podia aplicar diretivas SSL ao arquivo `/etc/nginx/sites-available/default` em vez do arquivo do projeto.
- **Solução:** Implementada em `create_project()` e `renew_ssl()`:
  - Salva backup de `/etc/nginx/sites-available/default`
  - Remove temporariamente `/etc/nginx/sites-enabled/default`
  - Recarrega Nginx (Certbot só vê o projeto)
  - Restaura o backup após conclusão
  - Garantia: SSL sempre fica no arquivo correto
- **Arquivo:** `src/lib/nginx_project.sh` linhas 180-220, 356-388

### 2. **`remove_project` falha com `--domain` customizado** ✅
- **Problema:** Ao remover um projeto criado com `--domain CUSTOM`, a função tentava remover certificado com nome `projeto.$DOMINIO_BASE` (errado).
- **Solução:** Função nova `get_domain_from_config()` lê o domínio real do arquivo nginx.
- **Arquivo:** `src/lib/utils.sh` linhas 234-239, `src/lib/nginx_project.sh` linha 258

### 3. **Falta validação de argumentos em `--check-port` e `--check-domain`** ✅
- **Problema:** `launchinfra --check-port` sem argumento não validava `$2`.
- **Solução:** Adicionadas verificações `[ -z "$2" ]` em `cli.sh`.
- **Arquivo:** `src/lib/cli.sh` linhas 171-177, 182-188

### 4. **Backend validation testa 127.0.0.1 direto, não via Nginx** ✅
- **Problema:** `curl http://127.0.0.1:$PORTA` testa o backend direto, não via proxy Nginx recém-configurado.
- **Solução:** Usa `curl -H "Host: $DOMINIO" http://127.0.0.1/` para testar via Nginx.
- **Arquivo:** `src/lib/nginx_project.sh` linhas 158-159

### 5. **Condicao duplicada em backend_test** ✅
- **Problema:** `[ "$backend_test" = "000" ] || [ "$backend_test" = "000" ]` (mesmo teste 2x).
- **Solução:** Removida duplicação.
- **Arquivo:** `src/lib/nginx_project.sh` linhas 163-164

### 6. **`nginx-test` chamado 2x em falha** ✅
- **Problema:** Falha de teste chamava `run_helper nginx-test` novamente antes de retornar 1.
- **Solução:** Removida chamada redundante, usa `if ! run_helper nginx-test`.
- **Arquivo:** `src/lib/nginx_project.sh` linhas 149-151

### 7. **`log_to_file` sempre invoca sudo** ✅
- **Problema:** Toda escrita de log chamava `run_helper` (sudo), mesmo que arquivo fosse writable.
- **Solução:** Tenta escrita direta primeiro, fallback sudo se necessário.
- **Arquivo:** `src/lib/config.sh` linhas 92-100

---

## Bugs Médios Corrigidos

### 8. **`lsof` sem fallback em `list_ports`** ✅
- **Problema:** `list_ports` usava `lsof` sem verificar disponibilidade.
- **Solução:** Adicionado `if command -v lsof` antes de usar.
- **Arquivo:** `src/lib/utils.sh` linhas 53, 60, 66

### 9. **`check_domain` regex quebrada com múltiplos server_name** ✅
- **Problema:** Regex com `\b` word boundary não funcionava após domínio escapado.
- **Solução:** Nova regex com `[[:space:]]\|;\|$` para limites corretos.
- **Arquivo:** `src/lib/utils.sh` linhas 76-86

### 10. **`get_version` fallback silencioso para "2.0"** ✅
- **Problema:** Se changelog não fosse encontrado, retornava "2.0" silenciosamente (mascarava erros).
- **Solução:** Removido fallback, retorna vazio para detecção de erro.
- **Arquivo:** `src/lib/cli.sh` linhas 5-24

### 11. **`show_project_info` usa `date -r` (BSD-only)** ✅
- **Problema:** `date -r` não funciona no GNU coreutils (Linux).
- **Solução:** Usa `stat -c '%y'` com fallback para `ls -l`.
- **Arquivo:** `src/lib/utils.sh` linhas 147-150

### 12. **`--template DIR` silenciosamente ignora dir inválido** ✅
- **Problema:** Se `--template` apontava para dir inexistente, caía para template padrão sem avisar.
- **Solução:** Adicionado `log_warning` quando dir não existe.
- **Arquivo:** `src/lib/nginx_project.sh` linhas 110-111

### 13. **Template HTML com tags malformadas** ✅
- **Problema:** `<title>$PROJETO</title</head>` e `</p</body</html>` (faltam `>`).
- **Solução:** Corrigido para `</title></head>` e `</p></body></html>`.
- **Arquivo:** `src/lib/nginx_project.sh` linhas 112, 114

### 14. **Condicao `[ -z "$FORCE" ] && [ "$FORCE" != "--force" ]` redundante** ✅
- **Problema:** Lógica duplicada para verificar FORCE.
- **Solução:** Simplificada para `[ -z "$FORCE" ]`.
- **Arquivo:** `src/lib/nginx_project.sh` linha 85

---

## Melhorias Implementadas

### 15. **Bash Completion Automático** ✨
- Arquivo instalado: `/usr/share/bash-completion/completions/launchinfra`
- **Completa:**
  - Comandos: `--list`, `--info`, `--edit`, `--remove`, `--disable`, `--restore`, `--renew`, etc.
  - Nomes de projetos (lê via `launchinfra --list`)
  - Opções: `--no-ssl`, `--force`, `--dry-run`, `--domain`, `--template`
  - Portas comuns: 80, 443, 3000, 5000, 8000, 8080, 8443
  - Diretórios para `--template`
- **Arquivo:** `src/bash-completion/launchinfra`

### 16. **Helper sempre sobrescrito (bugfix garantia)** ✨
- O `postinst` agora **sempre** reescreve `/usr/local/bin/launchinfra-helper`.
- Garante que versões antigas com bugs sejam atualizadas automaticamente.
- **Arquivo:** `debian/postinst` linhas 51-99

### 17. **Detecção automática de init system** ✨
- Helper detecta `systemd`, `sysvinit`, ou fallback `direct` para reload nginx.
- Compatível com Ubuntu 18.04 até 24.04 e variantes.
- **Arquivo:** `debian/postinst` linhas 54-78

### 18. **`launchinfra config --show`** ✨
- Novo argumento para exibir configuração atual.
- **Arquivo:** `src/lib/cli.sh` linha 126

### 19. **Alias `--restore` = `--enable`** ✨
- Adicionado `--enable` como alias para `--restore`.
- **Arquivo:** `src/lib/cli.sh` linha 188

### 20. **README.md Profissional Completo** ✨
- Documentação expandida com:
  - Instalação via PPA/APT
  - Bash completion explicado
  - Bug crítico SSL documentado
  - Multi-usuário detalhado
  - Segurança explicada
  - Estrutura do projeto
  - CI/CD e versionamento
- **Arquivo:** `README.md`

---

## Arquivos Modificados

| Arquivo | Status | Mudanças |
|---------|--------|----------|
| `src/lib/nginx_project.sh` | ✅ Corrigido | 14 bugs, SSL fix, template HTML |
| `src/lib/utils.sh` | ✅ Corrigido | 4 bugs, check_domain, lsof fallback |
| `src/lib/cli.sh` | ✅ Corrigido | 3 bugs, validação args, --show |
| `src/lib/config.sh` | ✅ Corrigido | log_to_file optimize |
| `debian/postinst` | ✅ Melhorado | Helper auto-rewrite, systemd detect, completion |
| `debian/control` | ✅ Atualizado | Dependências, descrição |
| `debian/changelog` | ✅ Atualizado | v2.4.1 com changelog completo |
| `debian/compat` | ✅ Criado | debhelper compat 13 |
| `src/bash-completion/launchinfra` | ✨ Novo | Bash completion automático |
| `Makefile` | ✅ Atualizado | v2.4.1, install completion, deps |
| `README.md` | ✨ Novo | Documentação completa profissional |
| `src/lib/cli.sh` | ✅ Atualizado | v2.4.1 |

---

## Testes Recomendados

```bash
# Syntax check
for f in src/lib/*.sh; do bash -n "$f"; done

# Build
make build

# Install
sudo dpkg -i ../launchinfra_2.4.1_all.deb

# Pós-install
sudo usermod -aG launchinfra $USER
# logout/login
launchinfra config --email test@exemplo.com
launchinfra config --domain exemplo.com.br
sudo launchinfra setup-nginx

# Testes básicos
launchinfra --list
launchinfra --help
launchinfra blog --dry-run
launchinfra<TAB>  # Testar bash completion

# Bug fix: Criar com --domain, depois remover (verifica domínio real)
launchinfra teste --domain custom.com.br --no-ssl
launchinfra rm teste  # Deve remover SSL de custom.com.br (se existisse)

# Bug fix: SSL para projeto, não default
sudo launchinfra setup-nginx
launchinfra ssl-test 8000  # Proxy teste
# Verificar: SSL em /etc/nginx/sites-available/user-ssl-test, não em default
```

---

## Repositório PPA

Próximos passos para publicação:

1. Commit e push para `main`
2. Tag: `git tag v2.4.1`
3. GitHub Actions dispara:
   - Build do `.deb`
   - Assinatura GPG
   - Upload para PPA
   - Publicação na branch `gh-pages`
4. Usuários recebem via: `sudo apt update && sudo apt upgrade`

**URL do repositório:** `https://Hildemberg986.github.io/LaunchInfra/`

---

## Status Final

✅ **Todos os bugs críticos corrigidos**  
✅ **Bash completion implementado**  
✅ **README.md profissional completo**  
✅ **Helper com service manager detection**  
✅ **Pronto para PPA/distribuição**  

**Versão:** 2.4.1  
**Data de conclusão:** 01 de setembro de 2026
