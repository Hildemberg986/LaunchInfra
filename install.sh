#!/bin/bash
set -e

echo "LaunchInfra Installer"
echo ""

if [ "$(id -u)" = "0" ]; then
    echo "Erro: Nao execute como root. Use seu usuario normal."
    exit 1
fi

echo "Este script configura o repositorio LaunchInfra e instala o pacote."
echo "Serao instalados: launchinfra, nginx, certbot, python3-certbot-nginx"
echo ""

read -r -p "Continuar? (s/N): " confirm
if [[ ! $confirm =~ ^[Ss]$ ]]; then
    echo "Cancelado."
    exit 0
fi

echo ""
echo "Configurando repositorio..."
sudo tee /etc/apt/sources.list.d/launchinfra.list >/dev/null <<EOF
deb [trusted=yes] https://Hildemberg986.github.io/LaunchInfra/ stable main
EOF

echo "Atualizando pacotes..."
sudo apt update

echo "Instalando launchinfra..."
sudo apt install -y launchinfra

echo ""
echo "Instalacao concluida."
echo ""
echo "Proximos passos:"
echo "  sudo usermod -aG launchinfra \$USER"
echo "  (faca logout e login)"
echo "  launchinfra config --email admin@exemplo.com"
echo "  launchinfra config --domain exemplo.com.br"
