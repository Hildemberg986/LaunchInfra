#!/bin/bash
# bump-version.sh - Atualiza versão em todos os arquivos
# Uso: ./scripts/bump-version.sh <versão> [descrição das mudanças]

set -e

if [ $# -lt 1 ]; then
    echo "Uso: $0 <versão> [descrição das mudanças]"
    echo "Exemplo: $0 2.0-6 'Novo recurso X, bugfix Y'"
    exit 1
fi

NEW_VERSION="$1"
CHANGES="${2:-DESCRIBE YOUR CHANGES HERE}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "📦 Atualizando versão para $NEW_VERSION..."

# 1. Atualizar Makefile
sed -i "s/^VERSION=.*/VERSION=$NEW_VERSION/" "$PROJECT_DIR/Makefile"
echo "✓ Makefile atualizado"

# 2. Adicionar entrada no changelog
CURRENT_DATE=$(LC_TIME=C date -u +'%a, %d %b %Y %H:%M:%S +0000')
TEMP_CHANGELOG=$(mktemp)

cat > "$TEMP_CHANGELOG" << EOF
launchinfra ($NEW_VERSION) unstable; urgency=medium

  * $CHANGES

 -- Hildemberg Eling <hildembergeling@gmail.com>  $CURRENT_DATE

EOF

cat "$PROJECT_DIR/debian/changelog" >> "$TEMP_CHANGELOG"
mv "$TEMP_CHANGELOG" "$PROJECT_DIR/debian/changelog"
echo "✓ debian/changelog atualizado"

# 3. Atualizar versão no código (cli.sh)
sed -i 's/LaunchInfra v.*/LaunchInfra v'"${NEW_VERSION%%-*}"'/' "$PROJECT_DIR/src/lib/cli.sh"
echo "✓ src/lib/cli.sh atualizado"

echo ""
echo "✅ Versão atualizada para $NEW_VERSION em todos os arquivos!"
echo ""
echo "Próximos passos:"
echo "  1. make clean && make build"
echo "  2. git add -A && git commit -m 'Versão $NEW_VERSION'"
echo "  3. git tag v$NEW_VERSION"
