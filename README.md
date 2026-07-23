# 🚀 LaunchInfra

> Ferramenta para criar e gerenciar sites e proxies Nginx com suporte a Let's Encrypt.

---

## 📦 Dependências

### Build

```bash
sudo apt update && sudo apt install -y devscripts debhelper build-essential
```

### Runtime

**nginx**, **certbot** e **python3-certbot-nginx** são instalados automaticamente via `Depends` do `.deb`.

| Pacote                | Função                              |
| --------------------- | ----------------------------------- |
| nginx                 | Servidor web e proxy reverso        |
| certbot               | Gerenciador de certificados SSL/TLS |
| python3-certbot-nginx | Plugin certbot para Nginx           |

---

## ⚡ Instalação

```bash
make build                      # Build do .deb
sudo dpkg -i ../launchinfra_*.deb  # Instalar
```

Ou use o script automático:

```bash
./scripts/build-install.sh
```

---

## 🔧 Pós-instalação

```bash
# Adicionar usuário ao grupo (uma vez)
sudo usermod -aG launchinfra USUARIO
# Fazer logout/login

# Configurar (uma vez)
launchinfra config --email admin@exemplo.com
launchinfra config --domain exemplo.com.br
```

---

## 🎮 Comandos

### 🏗️ Criação

| Comando                           | Descrição                  |
| --------------------------------- | -------------------------- |
| `launchinfra NOME`                | Site estático com SSL      |
| `launchinfra NOME PORTA`          | Proxy reverso com SSL      |
| `launchinfra NOME --no-ssl`       | Site HTTP apenas           |
| `launchinfra NOME --force`        | Forçar ignorando conflitos |
| `launchinfra NOME --dry-run`      | Simular sem aplicar        |
| `launchinfra NOME --domain DOM`   | Domínio customizado        |
| `launchinfra NOME --template DIR` | Template HTML customizado  |

### 📋 Gerenciamento

| Comando                              | Descrição                    |
| ------------------------------------ | ---------------------------- |
| `launchinfra --list` / `ls`          | Listar projetos              |
| `launchinfra --info NOME`            | Detalhes do projeto          |
| `launchinfra --disable NOME`         | Desativar (preserva config)  |
| `launchinfra --restore NOME`         | Reativar projeto             |
| `launchinfra --renew NOME`           | Renovar SSL                  |
| `launchinfra --remove NOME` / `rm`   | Remover projeto              |
| `launchinfra --remove NOME --backup` | Remover com backup (.tar.gz) |

### 🔧 Utilitários

| Comando                              | Descrição         |
| ------------------------------------ | ----------------- |
| `launchinfra --list-ports` / `ports` | Portas em uso     |
| `launchinfra --check-port P`         | Verificar porta   |
| `launchinfra --check-domain D`       | Verificar domínio |
| `launchinfra --check-ssl`            | Expiração SSLs    |
| `launchinfra --version` / `-v`       | Versão            |
| `launchinfra --help` / `-h`          | Ajuda             |

### ⚙️ Configuração

| Comando                         | Descrição        |
| ------------------------------- | ---------------- |
| `launchinfra config --email E`  | Definir email    |
| `launchinfra config --domain D` | Definir domínio  |
| `launchinfra config --show`     | Ver configuração |

---

## 🧪 Exemplos

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

## 🔄 Fluxo

```
launchinfra blog
  → Valida nome
  → Verifica conflitos
  → Cria /var/www/projetos/usuario/blog
  → Configura Nginx HTTP
  → Certbot --nginx → HTTPS
  → ✓ https://blog.exemplo.com
```

---

## 👥 Multi-usuário

Cada usuário gerencia apenas seus projetos. Root vê tudo.

```
/var/www/projetos/
├── professor1/blog/
├── professor2/site/

/etc/nginx/sites-available/
├── professor1-blog
└── professor2-site
```

> Usuários sem grupo `launchinfra` não executam o comando.
> Membros do grupo usam **sem sudo**.

---

## 🛡️ Segurança

| Camada      | Descrição                           |
| ----------- | ----------------------------------- |
| Helper      | `/usr/local/bin/launchinfra-helper` |
| Sudoers     | Comandos específicos sem senha      |
| Grupo       | `launchinfra` isola permissões      |
| Propriedade | Usuário só gerencia seus projetos   |

---

## 📋 Versionamento

```bash
./scripts/bump-version.sh 2.0.6 "Descrição"   # Manual
./scripts/release-auto.sh                      # Automático (feat/fix)
./scripts/build-install.sh                     # Build + instala
```

---

## 🤖 CI/CD

Push na `main` com `feat:` ou `fix:` → release automático no GitHub Actions (tag + release + .deb).

---

## 📁 Estrutura

```
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
```

---

## 📄 Licença

Uso permitido. **Redistribuição PROIBIDA** sem autorização expressa do autor.
