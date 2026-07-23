#!/bin/bash
# bump-version.sh - Atualiza versão, builda e instala
# Uso: ./scripts/bump-version.sh <versão> [descrição das mudanças] [--no-install]

set -e

if [ $# -lt 1 ]; then
    echo "Uso: $0 <versão> [descrição das mudanças] [--no-install]"
    echo "Exemplo: $0 2.0-6 'Novo recurso X, bugfix Y'"
    echo "         $0 2.0-6 --no-install  (só atualiza e builda, não instala)"
    exit 1
fi

NEW_VERSION="$1"
shift

CHANGES=""
NO_INSTALL=""

for arg in "$@"; do
    case "$arg" in
    --no-install) NO_INSTALL="1" ;;
    *) CHANGES="$arg" ;;
    esac
done

CHANGES="${CHANGES:-DESCRIBE YOUR CHANGES HERE}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Pega o nome do pacote do Makefile
PACKAGE_NAME=$(grep '^PACKAGE_NAME' "$PROJECT_DIR/Makefile" | head -1 | awk '{print $3}')

echo "📦 Atualizando versão para $NEW_VERSION..."

# 1. Atualizar Makefile
sed -i "s/^VERSION=.*/VERSION=$NEW_VERSION/" "$PROJECT_DIR/Makefile"
echo "✓ Makefile atualizado"

# 2. Adicionar entrada no changelog
CURRENT_DATE=$(LC_TIME=C date -u +'%a, %d %b %Y %H:%M:%S +0000')
TEMP_CHANGELOG=$(mktemp)

cat >"$TEMP_CHANGELOG" <<EOF
launchinfra ($NEW_VERSION) noble; urgency=medium

  * $CHANGES

 -- Hildemberg Eling <hildembergeling@gmail.com>  $CURRENT_DATE

EOF

cat "$PROJECT_DIR/debian/changelog" >>"$TEMP_CHANGELOG"
mv "$TEMP_CHANGELOG" "$PROJECT_DIR/debian/changelog"
echo "✓ debian/changelog atualizado"

# 3. Atualizar versão no código (cli.sh)
sed -i 's/echo "LaunchInfra v.*/echo "LaunchInfra v'"${NEW_VERSION%%-*}"'"/' "$PROJECT_DIR/src/lib/cli.sh"
echo "✓ src/lib/cli.sh atualizado"

echo ""
echo "✅ Versão atualizada para $NEW_VERSION em todos os arquivos!"

# 4. Build automático
echo ""
echo "🔨 Buildando..."
cd "$PROJECT_DIR"
make clean
make build

DEB_FILE="../${PACKAGE_NAME}_${NEW_VERSION}_all.deb"

if [ -f "$DEB_FILE" ]; then
    echo "✅ Build concluído: $DEB_FILE"

    # 5. Instalar (se não for --no-install)
    if [ -z "$NO_INSTALL" ]; then
        echo ""
        echo "📥 Instalando..."
        sudo dpkg -i "$DEB_FILE"
        echo "✅ LaunchInfra v$NEW_VERSION instalado!"
    else
        echo ""
        echo "⏭️  Instalação pulada (--no-install)"
    fi
else
    echo "❌ Erro: arquivo .deb não encontrado"
    exit 1
fi

echo ""
echo "📋 Próximos passos:"
echo "  git add -A && git commit -m 'Versão $NEW_VERSION'"
echo "  git tag v$NEW_VERSION"
