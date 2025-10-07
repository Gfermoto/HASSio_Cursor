#!/bin/bash
# Восстановление конфигурации из бэкапа

# Загрузить пути
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib_paths.sh"

echo "🔄 Восстановление конфигурации из бэкапа"
echo "========================================"
echo ""

# Проверить наличие бэкапов
if [ ! -d "$BACKUPS_DIR" ] || [ -z "$(ls -A "$BACKUPS_DIR"/config_*.tar.gz 2>/dev/null)" ]; then
    echo "❌ Бэкапы не найдены в $BACKUPS_DIR"
    exit 1
fi

# Показать доступные бэкапы
echo "📋 Доступные бэкапы:"
ls -lht "$BACKUPS_DIR"/config_*.tar.gz | head -10 | nl | awk '{print $1 ") " $10 " (" $6 ")"}'

echo ""
read -p "Введите номер бэкапа для восстановления: " NUM

# Получить файл бэкапа
BACKUP_FILE=$(ls -t "$BACKUPS_DIR"/config_*.tar.gz | sed -n "${NUM}p")

if [ -z "$BACKUP_FILE" ]; then
    echo "❌ Неверный номер"
    exit 1
fi

echo ""
echo "📦 Выбран: $(basename "$BACKUP_FILE")"
echo ""
read -p "⚠️  Это перезапишет текущую конфигурацию! Продолжить? (y/N): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Отменено"
    exit 0
fi

# Создать бэкап текущей конфигурации перед восстановлением
echo ""
echo "💾 Создание бэкапа текущей конфигурации..."
/home/gfer/HASSio/scripts/backup.sh

# Восстановить из бэкапа
echo ""
echo "🔄 Восстановление..."
cd /home/gfer/HASSio/config

tar -xzf "$BACKUP_FILE" --overwrite

if [ $? -eq 0 ]; then
    echo "✅ Конфигурация восстановлена!"
    echo ""
    echo "📋 Следующие шаги:"
    echo "   1. Проверьте конфигурацию: ssh hassio 'ha core check'"
    echo "   2. Перезагрузите HA: ssh hassio 'ha core restart'"
else
    echo "❌ Ошибка восстановления"
    exit 1
fi
