#!/bin/bash
# Установка Git hooks для автоматической проверки безопасности

# Определить корень проекта
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "🔧 Установка Git hooks..."
echo ""

# Проверить что Git инициализирован
if [ ! -d "$PROJECT_ROOT/.git" ]; then
    echo "❌ Git не инициализирован!"
    echo "Сначала выполните: git init"
    exit 1
fi

# Создать pre-commit hook
PRE_COMMIT_HOOK="$PROJECT_ROOT/.git/hooks/pre-commit"

cat > "$PRE_COMMIT_HOOK" << 'EOF'
#!/bin/bash
# Pre-commit hook: автоматическая проверка безопасности

echo ""
echo "🔐 Pre-commit: Проверка безопасности..."
echo ""

# Запустить проверку
./scripts/check_security.sh

RESULT=$?

if [ $RESULT -ne 0 ]; then
    echo ""
    echo "╔════════════════════════════════════════════════╗"
    echo "║  ❌ КОММИТ ОТМЕНЁН из-за проблем безопасности  ║"
    echo "╚════════════════════════════════════════════════╝"
    echo ""
    echo "Исправьте проблемы и попробуйте снова."
    echo ""
    exit 1
fi

echo ""
echo "✅ Проверка безопасности пройдена. Продолжаем коммит..."
echo ""

exit 0
EOF

chmod +x "$PRE_COMMIT_HOOK"

echo "✅ Pre-commit hook установлен!"
echo ""
echo "Теперь перед КАЖДЫМ коммитом будет автоматически:"
echo "  1. Проверяться .gitignore"
echo "  2. Проверяться что config.yml не в staged"
echo "  3. Искаться утечки IP/паролей/токенов"
echo "  4. Блокироваться коммит при обнаружении проблем"
echo ""
echo "💡 Проверить вручную:"
echo "   ./scripts/check_security.sh"
echo ""
echo "🎉 Готово! Теперь Git защитит вас от случайных утечек."
echo ""
