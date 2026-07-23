#!/bin/bash
# release-auto.sh - Detecta automaticamente o tipo de bump baseado nos commits
# Usa Conventional Commits pra decidir: feat → minor, fix → patch, BREAKING → major

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

# Última tag
LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0-0")

echo "🔍 Analisando commits desde $LAST_TAG..."

# Pega todos os commits desde a última tag
COMMITS=$(git log "$LAST_TAG"..HEAD --pretty=format:"%s" 2>/dev/null)

if [ -z "$COMMITS" ]; then
    echo "❌ Nenhum commit novo desde $LAST_TAG"
    exit 1
fi

# Conta tipos de commit
MAJOR_COUNT=0
MINOR_COUNT=0
PATCH_COUNT=0

while IFS= read -r commit; do
    # Remove merge commits
    [[ "$commit" == Merge* ]] && continue

    # Analisa o tipo
    if echo "$commit" | grep -qiE '^(feat|feature|add|adiciona|adicionado)[^a-z]'; then
        MINOR_COUNT=$((MINOR_COUNT + 1))
    elif echo "$commit" | grep -qiE '^(fix|bug|corrige|correção|hotfix|resolve)[^a-z]'; then
        PATCH_COUNT=$((PATCH_COUNT + 1))
    elif echo "$commit" | grep -qiE 'BREAKING CHANGE|breaking|major'; then
        MAJOR_COUNT=$((MAJOR_COUNT + 1))
    else
        # Commits sem prefixo claro → patch
        PATCH_COUNT=$((PATCH_COUNT + 1))
    fi
done <<<"$COMMITS"

# Decide o bump
if [ "$MAJOR_COUNT" -gt 0 ]; then
    BUMP="major"
    REASON="BREAKING CHANGE detectado"
elif [ "$MINOR_COUNT" -gt 0 ]; then
    BUMP="minor"
    REASON="$MINOR_COUNT feat(s), $PATCH_COUNT fix(es)"
else
    BUMP="patch"
    REASON="$PATCH_COUNT commit(s) de correção/melhorias"
fi

echo ""
echo "📊 Análise:"
echo "  BREAKING: $MAJOR_COUNT"
echo "  feat:     $MINOR_COUNT"
echo "  fix:      $PATCH_COUNT"
echo ""
echo "🎯 Bump detectado: $BUMP ($REASON)"
echo ""

read -r -p "Confirma bump $BUMP? (S/n): " confirm
if [[ "$confirm" =~ ^[Nn] ]]; then
    echo "Cancelado."
    exit 0
fi

# Executa o release com o bump detectado
"$SCRIPT_DIR/release.sh" "$BUMP"
