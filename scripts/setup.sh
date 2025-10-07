#!/bin/bash
# Установка всех зависимостей для работы с Home Assistant

# Определить корень проекта
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "📦 Установка зависимостей..."
echo "Проект: $PROJECT_ROOT"
echo ""

# 1. Системные пакеты
echo "1️⃣ Системные пакеты..."
sudo apt update
sudo apt install -y openssh-client cifs-utils git netcat-openbsd

# 2. Python пакеты (с обходом защиты системы)
echo ""
echo "2️⃣ Python пакеты..."
pip3 install --user --break-system-packages yamllint pyyaml requests 2>/dev/null || \
    pip3 install --user yamllint pyyaml requests

# 3. Создание директорий
echo ""
echo "3️⃣ Создание директорий..."
sudo mkdir -p /mnt/hassio
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# 4. SSH ключ (локально в проекте)
echo ""
echo "4️⃣ SSH ключ..."
SSH_KEY="$PROJECT_ROOT/.ssh/id_hassio"

mkdir -p "$PROJECT_ROOT/.ssh"
chmod 700 "$PROJECT_ROOT/.ssh"

if [ ! -f "$SSH_KEY" ]; then
    ssh-keygen -t ed25519 -f "$SSH_KEY" -N "" -C "hassio-cursor"
    echo ""
    echo "✅ SSH ключ создан в проекте!"
else
    echo "✅ SSH ключ уже существует"
fi

chmod 600 "$SSH_KEY"
chmod 644 "${SSH_KEY}.pub"

# 5. Права на скрипты
echo ""
echo "5️⃣ Права на скрипты..."
cd "$PROJECT_ROOT/scripts" || exit 1
chmod +x ./*.sh
chmod +x "$PROJECT_ROOT/ha"

# 6. Pre-commit хуки
echo ""
echo "6️⃣ Pre-commit хуки..."
if command -v pre-commit &> /dev/null; then
    echo "✅ pre-commit уже установлен"
else
    echo "Установка pre-commit..."
    pip3 install --user --break-system-packages pre-commit 2>/dev/null || \
        pip3 install --user pre-commit
fi

cd "$PROJECT_ROOT" || exit 1
if [ -f .pre-commit-config.yaml ]; then
    pre-commit install
    echo "✅ Git хуки установлены"
else
    echo "⚠️  .pre-commit-config.yaml не найден"
fi

# 7. MCP для Home Assistant
echo ""
echo "7️⃣ MCP сервер для Home Assistant..."
if command -v npx &> /dev/null; then
    echo "✅ Node.js/npx доступен"
else
    echo "⚠️  Node.js не установлен. Установите для работы MCP:"
    echo "   curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -"
    echo "   sudo apt-get install -y nodejs"
fi

if [ -f "$PROJECT_ROOT/.cursor/mcp.json.example" ] && [ ! -f "$PROJECT_ROOT/.cursor/mcp.json" ]; then
    echo ""
    echo "📝 Создайте конфигурацию MCP:"
    echo "   cp .cursor/mcp.json.example .cursor/mcp.json"
    echo "   nano .cursor/mcp.json  # и добавьте ваш токен"
fi

echo ""
echo "======================================================"
echo "✅ Установка завершена!"
echo "======================================================"
echo ""
echo "📋 ВАШ SSH КЛЮЧ (скопируйте полностью):"
echo "────────────────────────────────────────────────────"
cat "${SSH_KEY}.pub"
echo "────────────────────────────────────────────────────"
echo ""
echo "📖 Следующий шаг:"
echo "   1. Скопируйте ключ выше"
echo "   2. Откройте: docs/SETUP.md"
echo "   3. Начните с шага 2 (установка SSH add-on)"
echo ""
