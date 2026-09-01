# Memória - LaunchInfra

## Usuário
- **user**: Desenvolvedor que cria e gerencia sites Nginx rapidamente com LaunchInfra. Usa para provisionar projetos web com SSL automático via Let's Encrypt, em ambientes multi-usuário.

## Projeto
- **project**: LaunchInfra é uma ferramenta CLI (Bash) para provisionar sites estáticos e proxies reversos Nginx com SSL automático via Certbot. Funciona em multi-usuário: cada usuário gerencia apenas seus próprios projetos em `/var/www/projetos/USER/`, root tem acesso total. Usuários do grupo `launchinfra` executam sem sudo; root controla configurações globais.

## Referências
- **reference**: Scripts principais: `src/launchinfra.sh` (bootstrap), `src/lib/cli.sh` (dispatch), `src/lib/config.sh` (configuração), `src/lib/nginx_project.sh` (criar/remover/editar), `src/lib/utils.sh` (list/info/ports/ssl), `src/lib/logging.sh`. Helper privilegiado: `launchinfra-helper` (nginx-test, reload, certbot, chown, mkdir, rm). Versão atual: 2.3.13.
