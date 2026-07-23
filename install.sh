#!/bin/bash
set -e
echo "🔐 Instalando LaunchInfra..."
curl -fsSL https://Hildemberg986.github.io/LaunchInfra/public.key | sudo gpg --dearmor -o /usr/share/keyrings/launchinfra-archive-keyring.gpg 2>/dev/null || true
echo "deb [trusted=yes] https://Hildemberg986.github.io/LaunchInfra/ stable main" | sudo tee /etc/apt/sources.list.d/launchinfra.list
sudo apt update
sudo apt install launchinfra
echo ""
echo "✅ LaunchInfra instalado!"
echo "📋 Adicione usuários: sudo usermod -aG launchinfra USUARIO"
echo "⚙️  Configure: launchinfra config --email seu@email.com --domain exemplo.com"
