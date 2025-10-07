#!/bin/bash
# Проверка готовности окружения

# Загрузить пути и конфигурацию
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib_config.sh"

# Перейти в директорию проекта
cd "$PROJECT_ROOT"

echo "🔍 Проверка окружения"
echo "====================="
echo ""

# SSH
if [ -f "$SSH_DIR/config" ]; then
    # Выбрать правильный хост в зависимости от режима
    if [ "$SSH_USE_LOCAL" = "true" ]; then
        SSH_TARGET="hassio-local"
    else
        SSH_TARGET="hassio"
    fi

    if ssh -F "$SSH_DIR/config" -o ConnectTimeout=2 -o BatchMode=yes "$SSH_TARGET" "echo OK" &>/dev/null; then
        echo "✅ SSH работает ($SSH_HOST:$SSH_PORT)"
    else
        echo "❌ SSH не работает (проверьте: ssh -F $SSH_DIR/config $SSH_TARGET)"
    fi
else
    echo "❌ SSH config не найден ($SSH_DIR/config)"
fi

# SAMBA
if mountpoint -q "$MOUNT_POINT" 2>/dev/null; then
    echo "✅ SAMBA смонтирован"
    if [ -f "$MOUNT_POINT/configuration.yaml" ]; then
        echo "✅ Доступ к configuration.yaml"
    fi
else
    echo "❌ SAMBA не смонтирован (запустите: $SCRIPTS_DIR/mount.sh)"
fi

# MCP
if [ -f "$CURSOR_DIR/mcp.json" ]; then
    echo "✅ MCP настроен"
fi

echo ""
