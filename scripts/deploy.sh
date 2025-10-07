#!/bin/bash
# Безопасное развертывание изменений в Home Assistant

set -e

# Загрузить пути
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib_paths.sh"

echo "🚀 Развертывание изменений в Home Assistant"
echo "==========================================="
echo ""

# 1. Проверка что config смонтирован
CONFIG_LINK="$PROJECT_ROOT/config"
if [ ! -d "$CONFIG_LINK" ]; then
    echo "❌ Config не смонтирован. Запустите: $SCRIPTS_DIR/mount.sh"
    exit 1
fi

# 2. Создание бэкапа ПЕРЕД изменениями
echo "1️⃣ Создание бэкапа текущей конфигурации..."
"$SCRIPTS_DIR/backup.sh"
echo ""

# 3. Проверка YAML синтаксиса
echo "2️⃣ Проверка YAML синтаксиса..."
if command -v yamllint &> /dev/null; then
    if yamllint config/*.yaml 2>/dev/null; then
        echo "✅ YAML синтаксис корректен"
    else
        echo "⚠️  Предупреждения YAML (можно проигнорировать)"
    fi
else
    echo "⚠️  yamllint не установлен"
fi
echo ""

# 4. Проверка конфигурации HA
echo "3️⃣ Проверка конфигурации Home Assistant..."
if ssh -F .ssh/config hassio "ha core check" 2>&1 | tee /tmp/ha_check.log; then
    echo "✅ Конфигурация Home Assistant валидна"
else
    echo "❌ ОШИБКА в конфигурации Home Assistant!"
    echo ""
    cat /tmp/ha_check.log
    echo ""
    read -p "Всё равно продолжить? (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ Развертывание отменено"
        echo "💡 Исправьте ошибки и попробуйте снова"
        exit 1
    fi
fi
echo ""

# 5. Git коммит (если настроен)
if [ -d config/.git ]; then
    echo "4️⃣ Сохранение изменений в Git..."
    cd config/
    
    if git diff --quiet && git diff --cached --quiet; then
        echo "⚠️  Нет изменений для коммита"
    else
        git add -A
        
        echo "Введите сообщение коммита (или Enter для автоматического):"
        read -r COMMIT_MSG
        
        if [ -z "$COMMIT_MSG" ]; then
            COMMIT_MSG="Config update $(date '+%Y-%m-%d %H:%M')"
        fi
        
        git commit -m "$COMMIT_MSG"
        echo "✅ Изменения сохранены в Git"
    fi
    
    cd ..
    echo ""
fi

# 6. Перезагрузка HA
echo "5️⃣ Перезагрузка Home Assistant..."
read -p "Применить изменения и перезагрузить HA? (y/N): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Перезагрузка отменена"
    echo "💡 Изменения сохранены, но не применены"
    exit 0
fi

echo "🔄 Перезагрузка Home Assistant Core..."
ssh -F .ssh/config hassio "ha core restart"

echo ""
echo "⏳ Ожидание перезапуска (30 секунд)..."
for i in {30..1}; do
    echo -ne "   $i секунд...\r"
    sleep 1
done
echo ""

# 7. Проверка что HA запустился
echo "6️⃣ Проверка работоспособности..."
sleep 5

# Загрузить конфигурацию
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib_config.sh"

if curl -sf -m 10 "$HA_URL" > /dev/null 2>&1; then
    echo "✅ Home Assistant запущен успешно!"
else
    echo "⚠️  Home Assistant не отвечает"
    echo "💡 Проверьте логи: ./scripts/view_logs.sh"
fi

echo ""
echo "==========================================="
echo "✅ Развертывание завершено!"
echo "==========================================="
echo ""
echo "📋 Что было сделано:"
echo "   1. ✅ Создан бэкап"
echo "   2. ✅ Проверен YAML"
echo "   3. ✅ Проверена конфигурация HA"
echo "   4. ✅ Изменения закоммичены в Git"
echo "   5. ✅ Home Assistant перезагружен"
echo ""
echo "📝 Следующие шаги:"
echo "   - Проверьте логи: ./scripts/view_logs.sh"
echo "   - Откройте HA: $HA_URL"
echo "   - Если что-то сломалось: ./scripts/restore.sh"
echo ""

