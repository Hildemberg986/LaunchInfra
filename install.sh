#!/bin/bash
set -e

echo "LaunchInfra Installer"
echo ""

if [ "$(id -u)" = "0" ]; then
    echo "Erro: Nao execute como root. Use seu usuario normal."
    exit 1
fi

# Detectar distro e codename
if [ ! -f /etc/os-release ]; then
    echo "Erro: /etc/os-release nao encontrado. Distribuicao nao suportada."
    exit 1
fi
. /etc/os-release

echo "Distribuicao detectada: $PRETTY_NAME ($ID ${VERSION_ID:-})"
echo "Serao instalados: launchinfra, nginx, certbot, python3-certbot-nginx"
echo ""

REPO_TYPE=""
case "$ID" in
    ubuntu)
        echo "🟠 Ubuntu detectado. Usando PPA oficial do Launchpad."
        REPO_TYPE="ppa"
        sudo apt install -y software-properties-common
        sudo add-apt-repository -y ppa:hildemberg986/launchinfra
        ;;
    debian|linuxmint|pop|elementary|zorin|kali|neon)
        echo "🟢 $ID detectado. Usando repositorio estavel do GitHub Pages."
        REPO_TYPE="ghpages"
        sudo install -d -m 0755 /etc/apt/keyrings
        # Tentar baixar chave publica via varios caminhos
        if curl -fsSL https://Hildemberg986.github.io/LaunchInfra/public.key \
                | sudo gpg --dearmor -o /etc/apt/keyrings/launchinfra.gpg 2>/dev/null; then
            :
        else
            echo "Aviso: nao foi possivel baixar chave publica. Usando [trusted=yes]."
            sudo tee /etc/apt/sources.list.d/launchinfra.list >/dev/null <<EOF
deb [trusted=yes] https://Hildemberg986.github.io/LaunchInfra/ stable main
EOF
            REPO_TYPE="ghpages-trusted"
        fi
        if [ "$REPO_TYPE" = "ghpages" ]; then
            echo "deb [signed-by=/etc/apt/keyrings/launchinfra.gpg] https://Hildemberg986.github.io/LaunchInfra/ stable main" \
                | sudo tee /etc/apt/sources.list.d/launchinfra.list >/dev/null
        fi
        ;;
    *)
        echo "ERRO: distribuicao '$ID' nao suportada por este instalador."
        echo ""
        echo "Opcoes:"
        echo "  1. Em Ubuntu: use o PPA diretamente:"
        echo "     sudo add-apt-repository ppa:hildemberg986/launchinfra"
        echo "     sudo apt update && sudo apt install launchinfra"
        echo "  2. Em qualquer distro Debian-like: adicione manualmente:"
        echo "     echo 'deb [trusted=yes] https://Hildemberg986.github.io/LaunchInfra/ stable main' \\"
        echo "       | sudo tee /etc/apt/sources.list.d/launchinfra.list"
        echo "     sudo apt update && sudo apt install launchinfra"
        exit 1
        ;;
esac

echo ""
echo "Atualizando pacotes..."
sudo apt update

echo ""
echo "Instalando launchinfra..."
sudo apt install -y launchinfra

echo ""
echo "Instalacao concluida via $REPO_TYPE."
echo ""
echo "Proximos passos:"
echo "  sudo usermod -aG launchinfra \$USER"
echo "  (faca logout e login)"
echo "  launchinfra config --email admin@exemplo.com"
echo "  launchinfra config --domain exemplo.com.br"
echo ""
echo "Atualizacoes futuras: 'sudo apt update && sudo apt upgrade' traz versoes novas."
echo "Em Ubuntu Server, unattended-upgrades ja vem ativo por padrao."
