#!/bin/bash
# Автоматическое создание бэкапа перед изменениями

# Загрузить пути
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib_paths.sh"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo "💾 Создание бэкапа конфигурации..."

# Создать директорию для бэкапов
mkdir -p "$BACKUPS_DIR"

# Проверить что config смонтирован
CONFIG_LINK="$PROJECT_ROOT/config"
if [ ! -d "$CONFIG_LINK" ]; then
    echo "❌ Папка config не найдена. Запустите: $SCRIPTS_DIR/mount.sh"
    exit 1
fi

# Создать бэкап важных файлов
cd "$CONFIG_LINK"

tar -czf "$BACKUPS_DIR/config_$TIMESTAMP.tar.gz" \
    configuration.yaml \
    automations.yaml \
    scripts.yaml \
    scenes.yaml \
    groups.yaml \
    customize.yaml \
    secrets.yaml \
    ui-lovelace.yaml \
    --ignore-failed-read \
    2>/dev/null

if [ -f "$BACKUP_DIR/config_$TIMESTAMP.tar.gz" ]; then
    SIZE=$(du -h "$BACKUP_DIR/config_$TIMESTAMP.tar.gz" | cut -f1)
    echo "✅ Бэкап создан: config_$TIMESTAMP.tar.gz ($SIZE)"
    echo "📂 Путь: $BACKUP_DIR/config_$TIMESTAMP.tar.gz"

    # Показать последние 5 бэкапов
    echo ""
    echo "📋 Последние бэкапы:"
    ls -lht "$BACKUP_DIR"/config_*.tar.gz 2>/dev/null | head -5 | awk '{print "   " $9 " (" $5 ")"}'

    # Удалить старые бэкапы (старше 7 дней)
    find "$BACKUP_DIR" -name "config_*.tar.gz" -mtime +7 -delete

    echo ""
    echo "💡 Для восстановления: ./scripts/restore.sh"
else
    echo "❌ Ошибка создания бэкапа"
    exit 1
fi
