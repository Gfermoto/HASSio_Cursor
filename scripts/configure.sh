#!/bin/bash
# Интерактивная настройка режима работы

echo "⚙️  Настройка режима работы с Home Assistant"
echo "=============================================="
echo ""

# Загрузить пути
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib_paths.sh"

echo "Выберите режим работы:"
echo ""
echo "  1) 🏠 Локальный - всё через локальную сеть"
echo "     SSH: локальный IP:22"
echo "     SAMBA: локальный IP"
echo "     MCP: локальный IP"
echo "     ✅ Быстрее, но работает только дома"
echo ""
echo "  2) 🌍 Глобальный - всё через интернет"
echo "     SSH: домен:2222"
echo "     SAMBA: домен"
echo "     MCP: домен"
echo "     ✅ Работает везде, но медленнее"
echo ""
echo "  3) 🔀 Смешанный - SSH/SAMBA локально, MCP глобально (рекомендуется!)"
echo "     SSH: локальный IP:22"
echo "     SAMBA: локальный IP"
echo "     MCP: домен"
echo "     ✅ Быстрое редактирование + AI работает везде"
echo ""
read -p "Ваш выбор (1-3): " -n 1 -r mode
echo ""
echo ""

case $mode in
    1)
        echo "🏠 Настройка локального режима..."
        MODE="local"
        USE_LOCAL_SSH=true
        USE_LOCAL_SAMBA=true
        USE_LOCAL_MCP=true
        ;;
    2)
        echo "🌍 Настройка глобального режима..."
        MODE="global"
        USE_LOCAL_SSH=false
        USE_LOCAL_SAMBA=false
        USE_LOCAL_MCP=false
        ;;
    3)
        echo "🔀 Настройка смешанного режима..."
        MODE="mixed"
        USE_LOCAL_SSH=true
        USE_LOCAL_SAMBA=true
        USE_LOCAL_MCP=false
        ;;
    *)
        echo "❌ Неверный выбор"
        exit 1
        ;;
esac

# Обновить config.yml
echo "Обновление config.yml..."

# Обновить только режим и use_local флаги, сохранив остальное
sed -i "s/^mode: .*/mode: \"$MODE\"/" "$CONFIG_FILE"
sed -i "/ssh:/,/^[^ ]/ s/use_local: .*/use_local: $USE_LOCAL_SSH/" "$CONFIG_FILE"
sed -i "/samba:/,/^[^ ]/ s/use_local: .*/use_local: $USE_LOCAL_SAMBA/" "$CONFIG_FILE"
sed -i "/mcp:/,/^[^ ]/ s/use_local: .*/use_local: $USE_LOCAL_MCP/" "$CONFIG_FILE"

chmod 600 "$CONFIG_FILE"

echo "✅ config.yml обновлён"
echo ""

# Обновить MCP конфигурацию
echo "Обновление MCP..."
"$SCRIPTS_DIR/update_mcp.sh"

# Загрузить конфигурацию для показа
source "$SCRIPTS_DIR/lib_config.sh"

# Показать итоговую конфигурацию
echo "📋 Текущая конфигурация:"
echo "────────────────────────────────────────"
case $mode in
    1)
        echo "🏠 Режим: Локальный"
        echo "   SSH: $HA_LOCAL_IP:$SSH_PORT_INT"
        echo "   SAMBA: //$HA_LOCAL_IP/config"
        echo "   MCP: http://$HA_LOCAL_IP:8123"
        ;;
    2)
        echo "🌍 Режим: Глобальный"
        echo "   SSH: $HA_HOSTNAME:$SSH_PORT_EXT"
        echo "   SAMBA: //$HA_HOSTNAME/config"
        echo "   MCP: https://$HA_HOSTNAME"
        ;;
    3)
        echo "🔀 Режим: Смешанный (рекомендуется)"
        echo "   SSH: $HA_LOCAL_IP:$SSH_PORT_INT (локально)"
        echo "   SAMBA: //$HA_LOCAL_IP/config (локально)"
        echo "   MCP: https://$HA_HOSTNAME (глобально)"
        ;;
esac
echo "────────────────────────────────────────"
echo ""

# Обновить .samba-credentials
echo "Обновление SAMBA credentials..."
./scripts/setup_samba.sh

echo ""
echo "=============================================="
echo "✅ Настройка завершена!"
echo "=============================================="
echo ""
echo "📝 Следующие шаги:"
echo "   1. Смонтируйте SAMBA: sudo ./scripts/mount.sh"
echo "   2. Проверьте подключения: ./scripts/check.sh"
echo "   3. Перезапустите Cursor (для применения MCP)"
echo ""
echo "💡 Сменить режим: запустите этот скрипт снова"
echo ""

