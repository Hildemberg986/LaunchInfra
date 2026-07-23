#!/bin/bash
# release.sh - Versionamento automático com Git
# Uso: ./scripts/release.sh [major|minor|patch]
# Exemplo: ./scripts/release.sh patch  -> 2.0-5 → 2.0-6
#          ./scripts/release.sh minor  -> 2.0-5 → 2.1-1
#          ./scripts/release.sh major  -> 2.0-5 → 3.0-1

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

# Pega versão atual do Makefile
CURRENT_VERSION=$(grep '^VERSION' Makefile | head -1 | awk '{print $3}')
MAJOR=$(echo "$CURRENT_VERSION" | cut -d. -f1)
MINOR=$(echo "$CURRENT_VERSION" | cut -d. -f2)
PATCH=$(echo "$CURRENT_VERSION" | cut -d. -f3 | cut -d- -f1)
REVISION=$(echo "$CURRENT_VERSION" | cut -d- -f2)

BUMP_TYPE="${1:-patch}"

case "$BUMP_TYPE" in
major)
    MAJOR=$((MAJOR + 1))
    MINOR=0
    PATCH=0
    REVISION=1
    ;;
minor)
    MINOR=$((MINOR + 1))
    PATCH=0
    REVISION=1
    ;;
patch)
    if [ -n "$REVISION" ]; then
        REVISION=$((REVISION + 1))
    else
        PATCH=$((PATCH + 1))
        REVISION=1
    fi
    ;;
*)
    echo "Uso: $0 [major|minor|patch]"
    echo "Exemplo: $0 patch"
    exit 1
    ;;
esac

NEW_VERSION="${MAJOR}.${MINOR}.${PATCH}-${REVISION}"

echo "📦 LaunchInfra v$CURRENT_VERSION → v$NEW_VERSION ($BUMP_TYPE)"
echo ""

# Commit automático das mudanças atuais (se houver)
if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
    echo "📝 Mudanças detectadas. Fazendo commit..."
    git add -A
    git commit -m "v$NEW_VERSION: preparação para release" || echo "  (nada para commitar)"
fi

# Atualiza versão nos arquivos
"$SCRIPT_DIR/bump-version.sh" "$NEW_VERSION" "Release v$NEW_VERSION ($BUMP_TYPE bump)" --no-install

# Commit da versão
git add -A
git commit -m "v$NEW_VERSION: bump version" || echo "  (já commitado)"

# Tag
git tag -a "v$NEW_VERSION" -m "LaunchInfra v$NEW_VERSION"

echo ""
echo "✅ Versão $NEW_VERSION criada!"
echo ""
echo "🚀 Para publicar:"
echo "  git push origin main"
echo "  git push origin v$NEW_VERSION"
echo ""
echo "📥 Para instalar localmente:"
echo "  sudo dpkg -i ../launchinfra_${NEW_VERSION}_all.deb"
