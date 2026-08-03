# LaunchInfra

> Ferramenta para criar e gerenciar sites e proxies Nginx com suporte a Let's Encrypt.

---

## Dependencias

### Build

```bash
sudo apt update && sudo apt install -y devscripts debhelper build-essential
```

### Runtime

**nginx**, **certbot** e **python3-certbot-nginx** sao instalados automaticamente via `Depends` do `.deb`.

| Pacote                | Funcao                              |
| --------------------- | ----------------------------------- |
| nginx                 | Servidor web e proxy reverso        |
| certbot               | Gerenciador de certificados SSL/TLS |
| python3-certbot-nginx | Plugin certbot para Nginx           |

---

## Instalacao

```bash
make build                              # Build do .deb
sudo dpkg -i ../launchinfra_*.deb       # Instalar
```

Ou use o script automatico:

```bash
./scripts/build-install.sh
```

---

## Pos-instalacao

```bash
# Adicionar usuario ao grupo (uma vez)
sudo usermod -aG launchinfra USUARIO
# Fazer logout/login

# Configurar (uma vez)
launchinfra config --email admin@exemplo.com
launchinfra config --domain exemplo.com.br
```

---

## Comandos

### Criacao

| Comando                           | Descricao                  |
| --------------------------------- | -------------------------- |
| `launchinfra NOME`                | Site estatico com SSL      |
| `launchinfra NOME PORTA`          | Proxy reverso com SSL      |
| `launchinfra NOME --no-ssl`       | Site HTTP apenas           |
| `launchinfra NOME --force`        | Forcar ignorando conflitos |
| `launchinfra NOME --dry-run`      | Simular sem aplicar        |
| `launchinfra NOME --domain DOM`   | Dominio customizado        |
| `launchinfra NOME --template DIR` | Template HTML customizado  |

### Gerenciamento

| Comando                              | Descricao                    |
| ------------------------------------ | ---------------------------- |
| `launchinfra --list` / `ls`          | Listar projetos              |
| `launchinfra --info NOME`            | Detalhes do projeto          |
| `launchinfra --edit NOME`            | Editar config Nginx          |
| `launchinfra --disable NOME`         | Desativar (preserva config)  |
| `launchinfra --restore NOME`         | Reativar projeto             |
| `launchinfra --renew NOME`           | Renovar SSL                  |
| `launchinfra --remove NOME` / `rm`   | Remover projeto              |
| `launchinfra --remove NOME --backup` | Remover com backup (.tar.gz) |

### Utilitarios

| Comando                              | Descricao         |
| ------------------------------------ | ----------------- |
| `launchinfra --list-ports` / `ports` | Portas em uso     |
| `launchinfra --check-port P`         | Verificar porta   |
| `launchinfra --check-domain D`       | Verificar dominio |
| `launchinfra --check-ssl`            | Expiracao SSLs    |
| `launchinfra --version` / `-v`       | Versao            |
| `launchinfra --help` / `-h`          | Ajuda             |

### Configuracao

| Comando                         | Descricao        |
| ------------------------------- | ---------------- |
| `launchinfra config --email E`  | Definir email    |
| `launchinfra config --domain D` | Definir dominio  |
| `launchinfra config --show`     | Ver configuracao |

---

## Exemplos

```bash
launchinfra blog
launchinfra api 3000
launchinfra app --domain meusite.com.br 8080
launchinfra teste --no-ssl
launchinfra blog --template ~/meu-template/
launchinfra novo --dry-run
launchinfra config --email dev@exemplo.com --domain exemplo.com
launchinfra ls
launchinfra rm blog
```

---

## Fluxo

```
launchinfra blog
  -> Valida nome
  -> Verifica conflitos
  -> Cria /var/www/projetos/usuario/blog
  -> Configura Nginx HTTP
  -> Certbot --nginx -> HTTPS
  -> https://blog.exemplo.com
```

---

## Multi-usuario

Cada usuario gerencia apenas seus projetos. Root ve tudo.

```
/var/www/projetos/
+-- professor1/blog/
+-- professor2/site/

/etc/nginx/sites-available/
+-- professor1-blog
+-- professor2-site
```

Usuarios sem grupo `launchinfra` nao executam o comando.
Membros do grupo usam **sem sudo**.

---

## Seguranca

| Camada      | Descricao                           |
| ----------- | ----------------------------------- |
| Helper      | `/usr/local/bin/launchinfra-helper` |
| Sudoers     | Comandos especificos sem senha      |
| Grupo       | `launchinfra` isola permissoes      |
| Propriedade | Usuario so gerencia seus projetos   |

---

## Versionamento

```bash
./scripts/bump-version.sh 2.0.6 "Descricao"   # Manual
./scripts/release-auto.sh                      # Automatico (feat/fix)
./scripts/build-install.sh                     # Build + instala
```

---

## CI/CD

Push na `main` com `feat:` ou `fix:` -> release automatico no GitHub Actions (tag + release + .deb).

---

## Estrutura

```
src/
+-- launchinfra.sh
+-- lib/
    +-- cli.sh
    +-- config.sh
    +-- logging.sh
    +-- nginx_project.sh
    +-- utils.sh
debian/
+-- control
+-- postinst
+-- postrm
+-- rules
+-- changelog
scripts/
+-- bump-version.sh
+-- release.sh
+-- release-auto.sh
+-- build-install.sh
```

---

## Licenca

Copyright (c) 2024 Hildemberg Eling de Araujo Lucena.

Uso permitido. **Redistribuicao PROIBIDA** sem autorizacao expressa do autor.
