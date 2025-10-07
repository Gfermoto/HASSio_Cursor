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
cd /home/gfer/HASSio/scripts
chmod +x *.sh

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
