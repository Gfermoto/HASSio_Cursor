#!/bin/bash
# Автоматическая проверка безопасности перед коммитом

echo "🔐 Проверка безопасности проекта..."
echo "════════════════════════════════════════"
echo ""

ERRORS=0

# Определить корень проекта
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

# 1. Проверка .gitignore
echo "1️⃣ Проверка .gitignore..."
if [ ! -f .gitignore ]; then
    echo "   ❌ .gitignore не найден!"
    ERRORS=$((ERRORS + 1))
else
    REQUIRED_PATTERNS=(
        "config.yml"
        ".cursor/mcp.json"
        ".samba-credentials"
        ".ssh/"
        "logs/*.log"
        "backups/"
        "config/"
    )

    for pattern in "${REQUIRED_PATTERNS[@]}"; do
        # Экранировать спецсимволы для grep
        escaped_pattern=$(echo "$pattern" | sed 's/\./\\./g; s/\*/\\*/g')
        if grep -q "$escaped_pattern" .gitignore; then
            echo "   ✅ $pattern"
        else
            echo "   ⚠️  Рекомендуется: $pattern"
            # Не считаем ошибкой если основные файлы защищены
        fi
    done
fi
echo ""

# 2. Проверка что чувствительные файлы НЕ в Git
echo "2️⃣ Проверка чувствительных файлов..."
SENSITIVE_FILES=(
    "config.yml"
    ".cursor/mcp.json"
    ".samba-credentials"
)

for file in "${SENSITIVE_FILES[@]}"; do
    if git ls-files --error-unmatch "$file" 2>/dev/null; then
        echo "   ❌ $file НАЙДЕН В GIT!"
        ERRORS=$((ERRORS + 1))
    else
        echo "   ✅ $file не в Git"
    fi
done

if git ls-files | grep -q "^.ssh/"; then
    echo "   ❌ .ssh/ НАЙДЕНА В GIT!"
    ERRORS=$((ERRORS + 1))
else
    echo "   ✅ .ssh/ не в Git"
fi
echo ""

# 3. Проверка staged файлов (если Git инициализирован)
if [ -d .git ]; then
    echo "3️⃣ Проверка staged файлов..."
    STAGED=$(git diff --cached --name-only)

    if [ -z "$STAGED" ]; then
        echo "   ℹ️  Нет staged файлов"
    else
        for file in $STAGED; do
            # Проверить что это не чувствительный файл
            if [[ "$file" == "config.yml" ]] || \
               [[ "$file" == ".cursor/mcp.json" ]] || \
               [[ "$file" == ".samba-credentials" ]] || \
               [[ "$file" == .ssh/* ]]; then
                echo "   ❌ ОПАСНО: $file в staged!"
                ERRORS=$((ERRORS + 1))
            else
                echo "   ✅ $file"
            fi
        done
    fi
    echo ""
fi

# 4. Поиск чувствительных данных в staged файлах
if [ -d .git ] && [ -n "$STAGED" ]; then
    echo "4️⃣ Поиск утечек в staged файлах..."

    # Загрузить config.yml если существует для проверки
    if [ -f config.yml ]; then
        # Извлечь реальные значения из config.yml
        REAL_IP=$(grep "local_ip:" config.yml | sed 's/.*: *"\?\([^"]*\)"\?/\1/' | sed 's/^ *//;s/ *$//' | head -1)
        REAL_HOSTNAME=$(grep "hostname:" config.yml | sed 's/.*: *"\?\([^"]*\)"\?/\1/' | sed 's/^ *//;s/ *$//' | head -1)
        REAL_PASSWORD=$(grep "password:" config.yml | grep -v "your_" | sed 's/.*: *"\?\([^"]*\)"\?/\1/' | sed 's/^ *//;s/ *$//' | head -1)

        # Проверить IP (но игнорировать примеры типа 192.168.1.XXX или 192.168.1.100)
        if [ -n "$REAL_IP" ] && [ "$REAL_IP" != "192.168.1.XXX" ]; then
            if git diff --cached | grep -q "$REAL_IP"; then
                echo "   ⚠️  ВНИМАНИЕ: Найден ваш реальный IP!"
                ERRORS=$((ERRORS + 1))
            fi
        fi

        # Проверить hostname
        if [ -n "$REAL_HOSTNAME" ] && [ "$REAL_HOSTNAME" != "your-domain.com" ]; then
            if git diff --cached | grep -q "$REAL_HOSTNAME"; then
                echo "   ⚠️  ВНИМАНИЕ: Найден ваш реальный домен!"
                ERRORS=$((ERRORS + 1))
            fi
        fi

        # Проверить пароль
        if [ -n "$REAL_PASSWORD" ] && [ "$REAL_PASSWORD" != "your_password" ]; then
            if git diff --cached | grep -q "$REAL_PASSWORD"; then
                echo "   ❌ КРИТИЧНО: Найден ваш реальный пароль!"
                ERRORS=$((ERRORS + 1))
            fi
        fi
    fi

    # Поиск токенов (JWT начинается с eyJ)
    if git diff --cached | grep -q "eyJ[A-Za-z0-9]"; then
        # Проверить что это не в примерах
        if git diff --cached | grep "eyJ" | grep -qv "YOUR_TOKEN_HERE\|YOUR_MCP_TOKEN"; then
            echo "   ⚠️  ВНИМАНИЕ: Найден токен (JWT)!"
            ERRORS=$((ERRORS + 1))
        fi
    fi

    if [ $ERRORS -eq 0 ]; then
        echo "   ✅ Утечек не обнаружено"
    fi
    echo ""
fi

# 5. Проверка примеров
echo "5️⃣ Проверка файлов-примеров..."
EXAMPLE_FILES=(
    "config.yml.example"
    ".cursor/mcp.json.example"
)

for file in "${EXAMPLE_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "   ✅ $file существует"
    else
        echo "   ⚠️  $file не найден"
    fi
done
echo ""

# Итоговый результат
echo "════════════════════════════════════════"
if [ $ERRORS -eq 0 ]; then
    echo "✅ ВСЁ В ПОРЯДКЕ! Безопасно делать commit/push"
    echo ""
    exit 0
else
    echo "❌ ОБНАРУЖЕНО ПРОБЛЕМ: $ERRORS"
    echo ""
    echo "⚠️  НЕ ДЕЛАЙТЕ git push до исправления!"
    echo ""
    echo "Что делать:"
    echo "  1. Удалите чувствительные файлы из staged:"
    echo "     git reset HEAD config.yml"
    echo ""
    echo "  2. Удалите чувствительные данные из скриптов"
    echo ""
    echo "  3. Запустите этот скрипт снова:"
    echo "     ./scripts/check_security.sh"
    echo ""
    exit 1
fi
