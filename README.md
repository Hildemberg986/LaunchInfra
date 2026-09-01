# LaunchInfra

> Ferramenta para criar e gerenciar sites e proxies Nginx com suporte a Let's Encrypt.

---

## Dependências

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

## Instalação

```bash
make build                              # Build do .deb
sudo dpkg -i ../launchinfra_*.deb       # Instalar
```

Ou use o script automático:

```bash
./install.sh
```

---

## Pós-instalação

```bash
# Adicionar usuário ao grupo (uma vez)
sudo usermod -aG launchinfra USUARIO
# Fazer logout/login

# Configurar (uma vez)
launchinfra config --email admin@exemplo.com
launchinfra config --domain exemplo.com.br
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

## Exemplos

```bash
launchinfra blog
launchinfra api 3000
launchinfra app --domain meusite.com.br 8080
launchinfra teste --no-ssl
launchinfra blog --template ~/meu-template/
launchinfra novo --dry-run
launchinfra config --email dev@exemplo.com
launchinfra config --domain exemplo.com
launchinfra ls
launchinfra rm blog
launchinfra --renew blog
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

## Multi-usuário

Cada usuário gerencia apenas seus projetos. Root vê tudo.

```
/var/www/projetos/
+-- professor1/blog/
+-- professor2/site/

/etc/nginx/sites-available/
+-- professor1-blog
+-- professor2-site
```

Usuários sem grupo `launchinfra` não executam o comando. Membros do grupo usam **sem sudo**.

---

## Segurança

| Camada      | Descrição                           |
| ----------- | ----------------------------------- |
| Helper      | `/usr/local/bin/launchinfra-helper` |
| Sudoers     | Comandos específicos sem senha      |
| Grupo       | `launchinfra` isola permissões      |
| Propriedade | Usuário só gerencia seus projetos   |

---

## Versionamento

```bash
./scripts/bump-version.sh 2.0.6 "Descrição"   # Atualiza versão + build + instala
./scripts/release-auto.sh                      # Detecta bump via commits e publica
```

---

## CI/CD

Push na `main` com `feat:` ou `fix:` → release automático no GitHub Actions (tag + release + .deb).

---

## Estrutura

```
src/
├── launchinfra.sh          # Bootstrap (entry point)
└── lib/
    ├── cli.sh              # Dispatch de comandos e argumentos
    ├── config.sh           # Configuração, usuário, helper
    ├── nginx_project.sh    # Operações: criar, remover, editar, SSL
    ├── utils.sh            # Portas, domínios, listagem, backup
    └── logging.sh          # Funções de log colorido
debian/
├── control                  # Metadados do pacote
├── postinst                 # Setup do helper e sudoers
├── postrm                   # Limpeza na remoção
├── rules                    # Build rules
└── changelog                # Changelog
scripts/
├── bump-version.sh          # Atualiza versão e builda
├── release.sh               # Versionamento automático
└── release-auto.sh          # Detecta bump via conventional commits
```

---

## Licença

Copyright (c) 2024 Hildemberg Eling de Araujo Lucena.

Uso permitido. **Redistribuição PROIBIDA** sem autorização expressa do autor.