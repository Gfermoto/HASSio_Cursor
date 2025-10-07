#!/bin/bash
# Библиотека путей проекта - автоопределение корневой директории

# Определить корень проекта (там где находится config.yml)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Основные пути
export CONFIG_FILE="$PROJECT_ROOT/config.yml"
export SCRIPTS_DIR="$PROJECT_ROOT/scripts"
export LOGS_DIR="$PROJECT_ROOT/logs"
export BACKUPS_DIR="$PROJECT_ROOT/backups"
export SSH_DIR="$PROJECT_ROOT/.ssh"
export CURSOR_DIR="$PROJECT_ROOT/.cursor"

# Проверка что config.yml существует
if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ Файл config.yml не найден в $PROJECT_ROOT"
    echo "Скопируйте config.yml.example в config.yml и заполните данные"
    exit 1
fi
