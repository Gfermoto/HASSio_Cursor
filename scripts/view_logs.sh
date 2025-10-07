#!/bin/bash
# Просмотр логов Home Assistant

echo "📋 Логи Home Assistant"
echo "======================"
echo ""

if [ ! -f .ssh/config ]; then
    echo "❌ SSH не настроен"
    exit 1
fi

# Выбор действия
echo "Выберите действие:"
echo "  1) Последние 50 строк"
echo "  2) Последние 100 строк"
echo "  3) Только ошибки (ERROR)"
echo "  4) Только предупреждения (WARNING)"
echo "  5) В реальном времени (tail -f)"
echo "  6) Поиск по тексту"
echo ""
read -p "Ваш выбор (1-6): " -n 1 -r choice
echo ""
echo ""

case $choice in
    1)
        echo "📋 Последние 50 строк:"
        echo "─────────────────────────────────────────"
        ssh -F .ssh/config hassio "tail -50 /config/home-assistant.log"
        ;;
    2)
        echo "📋 Последние 100 строк:"
        echo "─────────────────────────────────────────"
        ssh -F .ssh/config hassio "tail -100 /config/home-assistant.log"
        ;;
    3)
        echo "❌ Только ошибки (последние 20):"
        echo "─────────────────────────────────────────"
        ssh -F .ssh/config hassio "grep ERROR /config/home-assistant.log | tail -20"
        ;;
    4)
        echo "⚠️  Только предупреждения (последние 20):"
        echo "─────────────────────────────────────────"
        ssh -F .ssh/config hassio "grep WARNING /config/home-assistant.log | tail -20"
        ;;
    5)
        echo "📺 Логи в реальном времени (Ctrl+C для выхода):"
        echo "─────────────────────────────────────────"
        ssh -F .ssh/config hassio "tail -f /config/home-assistant.log"
        ;;
    6)
        echo "Введите текст для поиска:"
        read -r search_text
        echo ""
        echo "🔍 Результаты поиска '$search_text':"
        echo "─────────────────────────────────────────"
        ssh -F .ssh/config hassio "grep -i '$search_text' /config/home-assistant.log | tail -30"
        ;;
    *)
        echo "❌ Неверный выбор"
        exit 1
        ;;
esac

echo ""
