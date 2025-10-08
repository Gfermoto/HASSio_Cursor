#!/bin/bash
# Валидация всех YAML файлов в проекте
# Использует yamllint с конфигурацией из .yamllint
# Универсальный скрипт - находит ВСЕ .yaml/.yml файлы автоматически

set -uo pipefail

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
failed_file_list=""

# Функция проверки файла
check_file() {
    local file=$1
    local rel_path="${file#"$PROJECT_ROOT"/}"

    echo -n "📄 $rel_path ... "

    if yamllint "$file" >/dev/null 2>&1; then
        echo "✅"
        passed_files=$((passed_files + 1))
    else
        echo "❌ ОШИБКА!"
        echo ""
        echo "   Ошибки:"
        yamllint "$file" 2>&1 | sed 's/^/   /'
        echo ""
        failed_files=$((failed_files + 1))
        failed_file_list="${failed_file_list}$rel_path, "
    fi
    total_files=$((total_files + 1))
}

echo "🔍 Поиск всех YAML файлов в проекте..."
echo ""

# Находим ВСЕ .yaml и .yml файлы рекурсивно
# -L следует за символическими ссылками (для config/)
# Исключаем согласно .yamllint ignore
yaml_files=$(find -L "$PROJECT_ROOT" -type f \( -name "*.yaml" -o -name "*.yml" \) 2>/dev/null | \
    grep -v "\.git/" | \
    grep -v "node_modules/" | \
    grep -v "__pycache__/" | \
    grep -v "\.venv/" | \
    grep -v "/venv/" | \
    grep -v "\.storage/" | \
    grep -v "/backups/" | \
    grep -v "/logs/" | \
    grep -v "/deps/" | \
    grep -v "/tts/" | \
    grep -v "/audits/" | \
    sort)

# Подсчитываем файлы
file_count=$(echo "$yaml_files" | grep -c . || echo "0")

if [ "$file_count" -eq 0 ]; then
    echo "⚠️  YAML файлы не найдены в проекте"
    exit 0
fi

echo "📊 Найдено YAML файлов: $file_count"
echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo ""

# Группируем файлы по категориям для красивого вывода
config_project=""
config_ha=""
workflows=""
other=""

while IFS= read -r file; do
    [ -z "$file" ] && continue

    rel_path="${file#"$PROJECT_ROOT"/}"

    # Пропускаем secrets.yaml (чувствительные данные)
    if [[ "$file" == */secrets.yaml ]]; then
        continue
    fi

    # Категоризация для вывода
    if [[ "$file" == "$PROJECT_ROOT/config.yml"* ]] || [[ "$file" == "$PROJECT_ROOT/mkdocs.yml" ]]; then
        config_project="$config_project$file"$'\n'
    elif [[ "$file" == *"/.github/workflows/"* ]]; then
        workflows="$workflows$file"$'\n'
    elif [[ "$file" == "$PROJECT_ROOT/config/"* ]]; then
        config_ha="$config_ha$file"$'\n'
    else
        other="$other$file"$'\n'
    fi
done <<< "$yaml_files"

# Проверяем конфигурацию проекта
if [ -n "$config_project" ]; then
    echo "🔧 Конфигурация проекта:"
    while IFS= read -r file; do
        [ -n "$file" ] && check_file "$file"
    done <<< "$config_project"
    echo ""
fi

# Проверяем GitHub workflows
if [ -n "$workflows" ]; then
    echo "⚙️  GitHub Actions workflows:"
    while IFS= read -r file; do
        [ -n "$file" ] && check_file "$file"
    done <<< "$workflows"
    echo ""
fi

# Проверяем Home Assistant конфигурации
if [ -n "$config_ha" ]; then
    echo "🏠 Home Assistant конфигурации (config/):"
    ha_count=0
    while IFS= read -r file; do
        if [ -n "$file" ]; then
            check_file "$file"
            ha_count=$((ha_count + 1))
        fi
    done <<< "$config_ha"
    echo "   ℹ️  Проверено $ha_count файлов (secrets.yaml пропущен)"
    echo ""
fi

# Проверяем другие YAML файлы
if [ -n "$other" ]; then
    echo "📁 Другие YAML файлы:"
    while IFS= read -r file; do
        [ -n "$file" ] && check_file "$file"
    done <<< "$other"
    echo ""
fi

# Итоговая статистика
echo "═══════════════════════════════════════════════════════════════════"
echo ""
echo "📊 Результаты:"
echo "   Всего файлов:  $total_files"
echo "   ✅ Успешно:    $passed_files"
echo "   ❌ Ошибки:     $failed_files"

if [ $failed_files -gt 0 ] && [ -n "$failed_file_list" ]; then
    echo ""
    echo "   🔴 Файлы с ошибками:"
    # Показываем каждый файл на новой строке
    IFS=',' read -ra FAILED_ARRAY <<< "$failed_file_list"
    for item in "${FAILED_ARRAY[@]}"; do
        item=$(echo "$item" | xargs)  # Trim spaces
        [ -n "$item" ] && echo "      • $item"
    done
fi
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
