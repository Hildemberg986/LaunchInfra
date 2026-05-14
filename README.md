# LaunchInfra

Ferramenta para criar e gerenciar sites e proxies Nginx com suporte a Let's Encrypt.

## Dependências

### Empacotamento (desenvolvimento)

Instale estas dependências para compilar o pacote .deb:

```bash
sudo apt update
sudo apt install -y devscripts debhelper build-essential
```

### Runtime (sistema)

Após instalar o pacote `launchinfra`, você precisa instalar as seguintes dependências:

```bash
sudo apt update
sudo apt install -y nginx certbot python3-certbot-nginx
```

**O que cada uma faz:**
- **nginx**: Servidor web e proxy reverso
- **certbot**: Gerador e gerenciador de certificados SSL/TLS Let's Encrypt
- **python3-certbot-nginx**: Plugin do certbot para integração com Nginx

## Instalação

### Instalar todas as dependências

```bash
make install-deps
```

Ou instalar separadamente:

```bash
# Apenas dependências de compilação
make install-deps-build

# Apenas dependências de runtime
make install-deps-runtime
```

### Build do pacote .deb

```bash
make build
```

O arquivo `.deb` ficará no diretório pai (ex.: `../launchinfra_2.0-5_all.deb`).

### Instalar o pacote

```bash
sudo dpkg -i ../launchinfra_2.0-5_all.deb
```

## Uso

```bash
# Criar site estático com SSL
launchinfra meu-site

# Criar proxy reverso com SSL (porta 3000)
launchinfra api 3000

# Criar site sem SSL (HTTP apenas)
launchinfra dev-site --no-ssl

# Forçar criação mesmo com conflitos
launchinfra prod 8080 --force

# Configurar email e domínio
launchinfra config --email seu@email.com --domain exemplo.com

# Ver configuração atual
launchinfra config --show

# Listar projetos
launchinfra --list

# Remover projeto
launchinfra --remove meu-site

# Ver versão
launchinfra --version
```

## Versionamento

Para atualizar a versão em todos os arquivos simultaneamente:

```bash
./scripts/bump-version.sh 2.0-6 "Descrição das mudanças"
make clean && make build
```

## Licença

IMPORTANTE: Este software contém um cabeçalho de licença que PROÍBE redistribuição sem autorização. Antes de publicar este pacote em um repositório APT público, confirme que você tem permissão explícita do autor.
