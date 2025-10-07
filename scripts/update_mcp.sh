#!/bin/bash
# Обновление MCP конфигурации в зависимости от режима

# Загрузить пути и конфигурацию
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib_config.sh"

echo "🔄 Обновление MCP конфигурации..."
echo ""

MCP_CONFIG="$CURSOR_DIR/mcp.json"

# Определить endpoint
if [ "$MCP_USE_LOCAL" = "true" ]; then
    ENDPOINT="$MCP_ENDPOINT_LOCAL"
    echo "📍 Режим: Локальный ($HA_LOCAL_IP)"
else
    ENDPOINT="$MCP_ENDPOINT_GLOBAL"
    echo "📍 Режим: Глобальный ($HA_HOSTNAME)"
fi

# Создать новую конфигурацию
cat > "$MCP_CONFIG" << EOF
{
    "mcpServers": {
      "home-assistant": {
        "command": "mcp-proxy",
        "args": [
          "$ENDPOINT"
        ],
        "env": {
          "API_ACCESS_TOKEN": "$MCP_TOKEN"
        }
      }
    }
  }
EOF

echo "✅ MCP конфигурация обновлена"
echo ""
echo "📋 Текущий endpoint: $ENDPOINT"
echo ""
echo "⚠️  ВАЖНО: Перезапустите Cursor чтобы изменения вступили в силу!"
echo ""
