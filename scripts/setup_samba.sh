#!/bin/bash
# Настройка SAMBA credentials из config.yml

echo "🔐 Настройка SAMBA credentials..."
echo ""

# Загрузить пути и конфигурацию
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib_config.sh"

CREDS_FILE="$PROJECT_ROOT/.samba-credentials"

# Создать файл credentials из config.yml
cat > "$CREDS_FILE" << EOF
username=$SAMBA_USER
password=$SAMBA_PASS
EOF

# Установить права
chmod 600 "$CREDS_FILE"

echo "✅ Файл .samba-credentials создан в проекте"
echo ""
echo "📋 Содержимое:"
cat "$CREDS_FILE"

echo ""
echo "✅ Готово! Теперь можете монтировать:"
echo "   $SCRIPTS_DIR/mount.sh"
