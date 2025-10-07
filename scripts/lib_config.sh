#!/bin/bash
# Библиотека для чтения конфигурации из config.yml

# Загрузить пути
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib_paths.sh"

# Функции для чтения конфигурации (простой парсер YAML)
get_config() {
    local key="$1"
    # Убираем комментарии, читаем значение
    grep "^  $key:" "$CONFIG_FILE" | sed 's/#.*//' | sed 's/.*: *"\?\([^"]*\)"\?/\1/' | sed 's/^ *//;s/ *$//'
}

# Экспорт переменных
export MODE=$(grep "^mode:" "$CONFIG_FILE" | sed 's/.*: *"\?\([^"]*\)"\?/\1/' | sed 's/^ *//;s/ *$//')
export HA_URL=$(get_config "url")
export HA_HOSTNAME=$(get_config "hostname")
export HA_LOCAL_IP=$(get_config "local_ip")

# SSH
export SSH_USE_LOCAL=$(grep "ssh:" -A 10 "$CONFIG_FILE" | grep "use_local:" | head -1 | sed 's/.*: *"\?\([^"]*\)"\?/\1/' | sed 's/^ *//;s/ *$//')
export SSH_PORT_EXT=$(get_config "port_external")
export SSH_PORT_INT=$(get_config "port_internal")
export SSH_USER=$(get_config "user")

if [ "$SSH_USE_LOCAL" = "true" ]; then
    export SSH_HOST="$HA_LOCAL_IP"
    export SSH_PORT="$SSH_PORT_INT"
else
    export SSH_HOST="$HA_HOSTNAME"
    export SSH_PORT="$SSH_PORT_EXT"
fi

# SAMBA
export SAMBA_USE_LOCAL=$(grep "samba:" -A 10 "$CONFIG_FILE" | grep "use_local:" | head -1 | sed 's/.*: *"\?\([^"]*\)"\?/\1/' | sed 's/^ *//;s/ *$//')
export SAMBA_USER=$(get_config "username")
export SAMBA_PASS=$(get_config "password")
export SAMBA_SHARE=$(get_config "share")
export MOUNT_POINT=$(get_config "mount_point")

if [ "$SAMBA_USE_LOCAL" = "true" ]; then
    export SAMBA_HOST="$HA_LOCAL_IP"
else
    export SAMBA_HOST="$HA_HOSTNAME"
fi

# MCP
export MCP_USE_LOCAL=$(grep "mcp:" -A 10 "$CONFIG_FILE" | grep "use_local:" | head -1 | sed 's/.*: *"\?\([^"]*\)"\?/\1/' | sed 's/^ *//;s/ *$//')
export MCP_TOKEN=$(grep "token:" "$CONFIG_FILE" | grep -v "API_ACCESS_TOKEN" | head -1 | sed 's/.*: *"\(.*\)"/\1/')
export MCP_ENDPOINT_GLOBAL=$(grep "endpoint_global:" "$CONFIG_FILE" | head -1 | sed 's/.*: *"\(.*\)"/\1/')
export MCP_ENDPOINT_LOCAL=$(grep "endpoint_local:" "$CONFIG_FILE" | head -1 | sed 's/.*: *"\(.*\)"/\1/')

if [ "$MCP_USE_LOCAL" = "true" ]; then
    export MCP_ENDPOINT="$MCP_ENDPOINT_LOCAL"
else
    export MCP_ENDPOINT="$MCP_ENDPOINT_GLOBAL"
fi

# Backup
export BACKUP_DAYS=$(get_config "retention_days")
