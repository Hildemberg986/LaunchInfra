# LaunchInfra

Ferramenta para criar e gerenciar sites e proxies Nginx com suporte a Let's Encrypt.

## Empacotamento Debian (APT)

Instruções básicas para gerar um pacote .deb localmente:

1. Instale dependências de empacotamento:

```bash
sudo apt update
sudo apt install -y devscripts debhelper build-essential
```

2. Gere o pacote .deb:

```bash
make build
```

O arquivo `.deb` ficará no diretório pai (ex.: `../launchinfra_2.0-1_all.deb`).

IMPORTANTE: o script contém um cabeçalho de licença que PROÍBE redistribuição sem autorização. Antes de publicar este pacote em um repositório APT público, confirme que você tem permissão explícita do autor.
