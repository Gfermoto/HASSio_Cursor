#!/bin/bash
# Монтирование Home Assistant через SAMBA

# Загрузить пути и конфигурацию
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib_config.sh"

# Проверка прав (запускать с sudo)
if [ "$EUID" -ne 0 ]; then 
    echo "❌ Этот скрипт нужно запускать с sudo:"
    echo "   sudo $0"
    exit 1
fi

if mountpoint -q "$MOUNT_POINT"; then
    echo "✅ Уже смонтировано"
    
    # Проверить/создать ссылку даже если уже смонтировано
    CONFIG_LINK="$PROJECT_ROOT/config"
    if [ ! -L "$CONFIG_LINK" ]; then
        ln -sf "$MOUNT_POINT" "$CONFIG_LINK"
        echo "✅ Создана ссылка: config → $MOUNT_POINT"
    fi
    
    ls -la "$MOUNT_POINT" | head -10
    exit 0
fi

CREDS_FILE="$PROJECT_ROOT/.samba-credentials"

if [ ! -f "$CREDS_FILE" ]; then
    echo "❌ Файл .samba-credentials не найден!"
    echo ""
    echo "Запустите: $SCRIPTS_DIR/setup_samba.sh"
    exit 1
fi

echo "🔌 Монтирование шары '$SAMBA_SHARE' с $SAMBA_HOST..."
mount -t cifs "//$SAMBA_HOST/$SAMBA_SHARE" "$MOUNT_POINT" \
  -o credentials="$CREDS_FILE",uid=1000,gid=1000,iocharset=utf8,file_mode=0777,dir_mode=0777,vers=3.0

if mountpoint -q "$MOUNT_POINT"; then
    echo "✅ Смонтировано!"
    
    # Создать символическую ссылку в проекте
    # Удалить старую если существует (файл или битая ссылка)
    CONFIG_LINK="$PROJECT_ROOT/config"
    rm -f "$CONFIG_LINK" 2>/dev/null
    ln -sf "$MOUNT_POINT" "$CONFIG_LINK"
    echo "✅ Создана ссылка: config → $MOUNT_POINT"
    
    echo ""
    echo "📂 Содержимое $MOUNT_POINT (папка config из HA):"
    ls -la "$MOUNT_POINT" | head -10
    
    echo ""
    echo "💡 Теперь в Cursor откройте папку:"
    echo "   $CONFIG_LINK"
else
    echo "❌ Ошибка монтирования"
fi

