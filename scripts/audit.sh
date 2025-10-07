#!/bin/bash
# Скрипт для проведения аудита умного дома

# Загрузить пути
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib_paths.sh"

AUDIT_DIR="$PROJECT_ROOT/audits"
DATE=$(date +%Y-%m-%d)
TIME=$(date +%H-%M-%S)
REPORT_FILE="$AUDIT_DIR/audit_${DATE}_${TIME}.md"

echo "🔍 Запуск аудита умного дома..."
echo "📅 Дата: $DATE $TIME"
echo ""

# Создать директорию если не существует
mkdir -p "$AUDIT_DIR"

# Начать отчёт
cat > "$REPORT_FILE" << EOF
# 🏠 АУДИТ УМНОГО ДОМА
**Дата:** $DATE
**Время:** $TIME
**Система:** Home Assistant

---

## 📊 СБОР ДАННЫХ

Получение данных от Home Assistant через MCP...

EOF

echo "✅ Отчёт создан: $REPORT_FILE"
echo ""
echo "💡 Теперь используйте AI через Cursor для анализа:"
echo "   Скажите: 'Проанализируй мою систему и добавь результаты в $REPORT_FILE'"
echo ""
echo "📂 Все отчёты в папке: $AUDIT_DIR"
echo ""

# Показать список предыдущих аудитов
if [ "$(ls -A $AUDIT_DIR/*.md 2>/dev/null | wc -l)" -gt 0 ]; then
    echo "📋 История аудитов:"
    ls -lht "$AUDIT_DIR"/audit_*.md | head -5 | awk '{print "   " $9 " (" $6 " " $7 ")"}'
    echo ""
fi

# Открыть отчёт в редакторе
if command -v cursor &> /dev/null; then
    echo "🚀 Открываю в Cursor..."
    cursor "$REPORT_FILE"
else
    echo "💡 Откройте файл вручную:"
    echo "   $REPORT_FILE"
fi
