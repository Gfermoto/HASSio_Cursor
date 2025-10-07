# Changelog

Все значимые изменения в этом проекте будут документированы в этом файле.

Формат основан на [Keep a Changelog](https://keepachangelog.com/ru/1.0.0/),
и этот проект придерживается [Semantic Versioning](https://semver.org/lang/ru/).

## [1.0.0] - 2025-10-07

### Добавлено

#### Инфраструктура

- 🎉 Первый публичный релиз!
- 📦 MIT License
- 🤝 CONTRIBUTING.md с правилами участия
- 🔒 SECURITY.md с инструкциями по безопасности
- 📚 Полная документация на MkDocs
- 🌐 [GitHub Pages](https://gfermoto.github.io/HASSio_Cursor)

#### Скрипты (13 шт)

- `ha` - Интерактивное главное меню
- `setup.sh` - Установка окружения
- `configure.sh` - Настройка режима работы (local/global/mixed)
- `mount.sh` - Монтирование Samba
- `check.sh` - Проверка статуса (SSH/Samba/MCP)
- `deploy.sh` - Безопасное развёртывание изменений
- `backup.sh` - Создание бэкапов
- `restore.sh` - Восстановление из бэкапа
- `audit.sh` - Аудит умного дома с AI
- `check_security.sh` - Проверка утечек данных
- `update_mcp.sh` - Обновление MCP конфигурации
- `setup_samba.sh` - Первичная настройка Samba
- `install_git_hooks.sh` - Установка pre-commit hooks

#### Библиотеки

- `lib_config.sh` - Парсинг config.yml
- `lib_paths.sh` - Централизованные пути проекта
- `lib_logging.sh` - Логирование операций

#### Документация

- **Установка:**
  - Быстрый старт (5 минут)
  - Детальная инструкция с командами
- **Руководства:**
  - Первый аудит системы
  - Оптимизация отопления (экономия до 30%)
  - Безопасность умного дома (камеры, датчики)
- **Примеры:**
  - Автоматизация отопления
  - Мониторинг безопасности
  - Энергосбережение
- **Справочник:**
  - Все команды
  - Рабочий процесс

#### CI/CD

- **GitHub Actions:**
  - `docs.yml` - Автоматическая публикация документации
  - `lint.yml` - Проверка кода (YAML, Shell, Markdown)
  - `security.yml` - Поиск утечек данных
- **Pre-commit hooks:**
  - yamllint
  - shellcheck
  - markdownlint
  - custom security check

#### Безопасность

- `.gitignore` с исключением всех чувствительных данных
- `config.yml.example` - шаблон конфигурации
- `.cursor/mcp.json.example` - шаблон MCP
- Автоматическая проверка утечек перед коммитом
- Project-specific SSH keys
- Audit reports excluded from Git

### Особенности

- 🤖 **AI-powered управление** через MCP в Cursor IDE
- 🔬 **Smart Audit** - глубокий анализ системы с рекомендациями
- 🔧 **SSH/SAMBA** - прямой доступ к конфигурации HA
- 💾 **Auto-backup** - безопасное развёртывание с откатом
- 📊 **Optimization guides** - экономия до 30% на отоплении
- 🔒 **Security first** - защита всех чувствительных данных
- 📚 **Complete docs** - от установки до продвинутых сценариев

### Технические детали

- **Язык:** Bash, Markdown, YAML
- **Окружение:** WSL/Linux
- **Зависимости:**
  - Home Assistant (любая версия)
  - MCP Server for Home Assistant
  - SSH, Samba
  - Git
  - Python 3.x + pip (для MkDocs)
- **Документация:** MkDocs + Material Theme
- **Строк кода:** 3,500+
- **Файлов:** 45+

## [Unreleased]

### Планируется

- [ ] Интеграция с HA Supervisor API
- [ ] Автоматическое обновление документации при изменении конфигурации
- [ ] Dashboard для визуализации метрик аудита
- [ ] Telegram bot для управления
- [ ] Docker контейнер для полной изоляции
- [ ] Поддержка нескольких HA инстансов

---

[1.0.0]: https://github.com/Gfermoto/HASSio_Cursor/releases/tag/v1.0.0
