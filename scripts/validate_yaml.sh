#!/bin/bash
# Валидация всех YAML файлов в проекте
# Использует yamllint с конфигурацией из .yamllint

set -uo pipefail  # Убрали -e чтобы продолжать проверку даже при ошибках

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║              🔍 ВАЛИДАЦИЯ YAML ФАЙЛОВ 🔍                         ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""

# Проверяем что yamllint установлен
if ! command -v yamllint &> /dev/null; then
    echo "❌ yamllint не установлен!"
    echo ""
    echo "Установите командой:"
    echo "  pip3 install --user yamllint"
    echo ""
    echo "Или запустите:"
    echo "  ./scripts/setup.sh"
    exit 1
fi

# Счётчики
total_files=0
passed_files=0
failed_files=0

# Функция проверки файла
check_file() {
    local file=$1
    local filename
    filename=$(basename "$file")

    total_files=$((total_files + 1))

    echo -n "📄 $filename ... "

    if yamllint "$file" >/dev/null 2>&1; then
        echo "✅"
        passed_files=$((passed_files + 1))
    else
        echo "❌"
        failed_files=$((failed_files + 1))
        echo ""
        echo "   Ошибки:"
        yamllint "$file" 2>&1 | sed 's/^/   /'
        echo ""
    fi
}

# Проверяем config.yml (главный файл конфигурации)
if [ -f "$PROJECT_ROOT/config.yml" ]; then
    echo "🔧 Конфигурация проекта:"
    check_file "$PROJECT_ROOT/config.yml"
    echo ""
fi

# Проверяем примеры конфигурации
echo "📋 Примеры и другие YAML:"
if [ -f "$PROJECT_ROOT/config.yml.example" ]; then
    check_file "$PROJECT_ROOT/config.yml.example"
fi
if [ -f "$PROJECT_ROOT/mkdocs.yml" ]; then
    check_file "$PROJECT_ROOT/mkdocs.yml"
fi
echo ""

# Проверяем GitHub workflows
if [ -d "$PROJECT_ROOT/.github/workflows" ]; then
    echo "⚙️  GitHub Actions workflows:"
    for file in "$PROJECT_ROOT/.github/workflows"/*.yml "$PROJECT_ROOT/.github/workflows"/*.yaml; do
        if [ -f "$file" ]; then
            check_file "$file"
        fi
    done
    echo ""
fi

# Проверяем docker-compose файлы если есть
if [ -f "$PROJECT_ROOT/docker-compose.yml" ] || [ -f "$PROJECT_ROOT/docker-compose.yaml" ]; then
    echo "🐳 Docker Compose:"
    [ -f "$PROJECT_ROOT/docker-compose.yml" ] && check_file "$PROJECT_ROOT/docker-compose.yml"
    [ -f "$PROJECT_ROOT/docker-compose.yaml" ] && check_file "$PROJECT_ROOT/docker-compose.yaml"
    echo ""
fi

# Проверяем конфигурации Home Assistant (если доступно)
if [ -d "$PROJECT_ROOT/config" ] || [ -L "$PROJECT_ROOT/config" ]; then
    echo "🏠 Home Assistant конфигурации (config/):"

    # Находим ВСЕ .yaml и .yml файлы (включая через симлинки)
    yaml_count=0

    # Основные файлы в корне
    for file in "$PROJECT_ROOT/config"/*.yaml "$PROJECT_ROOT/config"/*.yml; do
        if [ -f "$file" ]; then
            # Пропускаем secrets.yaml (содержит чувствительные данные)
            if [[ "$(basename "$file")" != "secrets.yaml" ]]; then
                check_file "$file"
                yaml_count=$((yaml_count + 1))
            fi
        fi
    done

    # Файлы в подпапках (packages, custom_components и т.д.)
    if [ -d "$PROJECT_ROOT/config/packages" ]; then
        for file in "$PROJECT_ROOT/config/packages"/*.yaml; do
            if [ -f "$file" ]; then
                check_file "$file"
                yaml_count=$((yaml_count + 1))
            fi
        done
    fi

    # Custom components (только services.yaml)
    if [ -d "$PROJECT_ROOT/config/custom_components" ]; then
        for file in "$PROJECT_ROOT/config/custom_components"/*/services.yaml; do
            if [ -f "$file" ]; then
                check_file "$file"
                yaml_count=$((yaml_count + 1))
            fi
        done
    fi

    if [ $yaml_count -eq 0 ]; then
        echo "   ℹ️  YAML файлы не найдены (папка пуста или не смонтирована)"
    else
        echo "   ℹ️  Проверено $yaml_count YAML файлов (пропущен secrets.yaml)"
    fi

    echo ""
fi

# Итоговая статистика
echo "═══════════════════════════════════════════════════════════════════"
echo ""
echo "📊 Результаты:"
echo "   Всего файлов:  $total_files"
echo "   ✅ Успешно:    $passed_files"
echo "   ❌ Ошибки:     $failed_files"
echo ""

if [ $failed_files -eq 0 ]; then
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║              ✅ ВСЕ YAML ФАЙЛЫ ВАЛИДНЫ! ✅                       ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    exit 0
else
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║          ❌ ОБНАРУЖЕНЫ ОШИБКИ В YAML! ❌                        ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo ""
    echo "💡 Исправьте ошибки и запустите проверку снова"
    echo ""

    # Если запущен из ./ha (интерактивный режим), не выходить с ошибкой
    if [ -n "${INTERACTIVE_MODE:-}" ]; then
        exit 0  # Возвращаемся в меню
    else
        exit 1  # Для CI/CD и скриптов - выход с ошибкой
    fi
fi
