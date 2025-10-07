# 🏠 Home Assistant Cursor Integration

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Documentation](https://img.shields.io/badge/docs-live-brightgreen)][docs]
[![GitHub Pages](https://github.com/Gfermoto/HASSio_Cursor/workflows/Deploy%20Documentation/badge.svg)](https://github.com/Gfermoto/HASSio_Cursor/actions)
[![Pre-commit](https://img.shields.io/badge/pre--commit-enabled-brightgreen?logo=pre-commit)](https://github.com/pre-commit/pre-commit)
[![Home Assistant](https://img.shields.io/badge/Home%20Assistant-Compatible-41BDF5.svg)](https://www.home-assistant.io/)
[![Release](https://img.shields.io/github/v/release/Gfermoto/HASSio_Cursor)](https://github.com/Gfermoto/HASSio_Cursor/releases)
[![GitHub Stars](https://img.shields.io/github/stars/Gfermoto/HASSio_Cursor?style=social)](https://github.com/Gfermoto/HASSio_Cursor/stargazers)

Профессиональная среда разработки для Home Assistant с AI-ассистентом, интеграцией MCP, SSH и SAMBA.

## ✨ Возможности

- 🤖 **AI-powered** - управление устройствами через MCP в Cursor
- 🔬 **Smart Audit** - глубокий анализ системы с рекомендациями
- 🔧 **SSH/SAMBA** - прямой доступ к конфигурации
- 💾 **Auto-backup** - безопасное развертывание с откатом
- 📊 **Optimization** - экономия до 30% на отоплении
- 🔒 **Security** - автопроверка утечек данных перед коммитом
- 📚 **Documentation** - полная документация с примерами

## 🚀 Быстрый старт

```bash
# 1. Установка (один раз)
./scripts/setup.sh
```

**Что устанавливает setup.sh:**

- ✅ Системные пакеты (SSH, CIFS, Git, netcat)
- ✅ Python пакеты (yamllint, pyyaml, requests)
- ✅ **mcp-proxy** - MCP сервер для Home Assistant
- ✅ Pre-commit хуки (автопроверка перед коммитом)
- ✅ SSH ключ для подключения к HA
- ✅ Права на все скрипты

```bash
# 2. Главное меню (всё управление здесь!)
./ha
```

**Или напрямую:**

```bash
./scripts/configure.sh    # Настроить режим
./scripts/mount.sh        # Смонтировать
code config/              # Редактировать
./scripts/deploy.sh       # Развернуть
```

## 📂 Структура

```text
/home/gfer/HASSio/
├── README.md             # Обзор проекта
├── docs/                 # Документация для разработчиков
│   ├── SETUP.md          # Пошаговая инструкция
│   ├── COMMANDS.md       # Справочник команд
│   └── WORKFLOW.md       # Рабочий процесс
├── scripts/              # ВСЕ скрипты
│   ├── setup.sh          # Установка
│   ├── mount.sh          # Монтирование
│   ├── check.sh          # Проверка
│   ├── deploy.sh         # Развертывание
│   ├── backup.sh         # Бэкап
│   ├── restore.sh        # Восстановление
│   └── ...
├── config/               # Конфиги HA
├── backups/              # Локальные бэкапы
└── .cursor/              # MCP
```

## 📖 Документация

- **[docs/SETUP.md](docs/SETUP.md)** - Полная инструкция по настройке MCP, SSH и SAMBA
- **[docs/COMMANDS.md](docs/COMMANDS.md)** - Справочник команд
- **[docs/WORKFLOW.md](docs/WORKFLOW.md)** - Рабочий процесс и best practices
- **[SECURITY.md](SECURITY.md)** - 🔒 Безопасность и публикация

## 💻 Главное меню

```bash
./ha
```

**Интерактивное меню со всеми функциями:**

1. Настроить режим (локальный/глобальный/смешанный)
2. Смонтировать конфиги
3. Проверить статус
4. Развернуть изменения
5. Создать бэкап
6. Восстановить из бэкапа
7. Просмотр логов
8. Открыть в Cursor
9. Размонтировать

**Режимы работы:**

- 🏠 **Локальный** - всё через локальную сеть (быстро, только дома)
- 🌍 **Глобальный** - всё через интернет (медленнее, работает везде)
- 🔀 **Смешанный** - автоматический выбор (локально/ZeroTier/глобально)
  - Дома → прямое подключение (быстро)
  - Не дома + ZeroTier → через VPN (безопасно)
  - Без ZeroTier → через белый IP (fallback)

## 💻 Основное использование

```bash
# Редактирование
code config/configuration.yaml

# Развертывание (с проверками и бэкапом)
./scripts/deploy.sh

# Просмотр логов
./scripts/view_logs.sh

# Восстановление (если что-то сломалось)
./scripts/restore.sh
```

## 🤖 MCP (AI в Cursor)

### Первая настройка

```bash
# 1. Создать конфигурацию из примера
cp .cursor/mcp.json.example .cursor/mcp.json

# 2. Получить токен Home Assistant
# Откройте: http://YOUR_HA_IP:8123/profile/security
# Создайте Long-Lived Access Token

# 3. Отредактировать конфигурацию
nano .cursor/mcp.json
# Замените YOUR_HA_TOKEN и YOUR_HA_URL
```

### Использование

Просто спросите AI в Cursor:

```text
"Какая температура в доме?"
"Включи свет на кухне"
"Покажи все термостаты"
"Создай автоматизацию для вечернего освещения"
```

**MCP работает через:**

- 🌐 HTTP API - напрямую к вашему HA
- 🔒 Безопасно - токен только локально

## 🛡️ Безопасность

Все чувствительные данные (`config.yml`, `.cursor/mcp.json`, `.ssh/`) **исключены из Git** через `.gitignore`.

Перед публикацией проверьте: `./scripts/check_security.sh`

---

## 📚 Документация

- 📖 **[Полная документация](https://gfermoto.github.io/HASSio_Cursor)** ← начните здесь!
- ⚡ [Быстрый старт](docs/setup/quickstart.md) - 5 минут
- 🔬 [Первый аудит](docs/guides/first-audit.md) - оцените систему
- 🌡️ [Оптимизация отопления](docs/guides/heating-optimization.md) - экономьте до 30%
- 🔒 [Безопасность](docs/guides/security.md) - умные оповещения
- 📋 [Справочник команд](docs/reference/COMMANDS.md) - все команды

---

## 🤝 Вклад в проект

Мы рады любой помощи! См. [CONTRIBUTING.md](CONTRIBUTING.md)

- 🐛 [Сообщить об ошибке](https://github.com/Gfermoto/HASSio_Cursor/issues/new)
- 💡 [Предложить улучшение](https://github.com/Gfermoto/HASSio_Cursor/issues/new)
- 📖 [Улучшить документацию](https://github.com/Gfermoto/HASSio_Cursor/edit/main/docs/)

---

## 📄 Лицензия

[MIT License](LICENSE) - используйте свободно!

---

## 🔗 Полезные ссылки

- 📚 [Документация](https://gfermoto.github.io/HASSio_Cursor)
- 📦 [Releases](https://github.com/Gfermoto/HASSio_Cursor/releases)
- 📝 [Changelog](CHANGELOG.md)
- 🔒 [Security Policy](SECURITY.md)
- 🤝 [Contributing Guide](CONTRIBUTING.md)

---

## 🌟 Поддержка проекта

Если проект был полезен:

- ⭐ Поставьте звезду на GitHub
- 📢 Расскажите друзьям
- 🐛 Сообщите об ошибках
- 💡 Предложите улучшения

**Спасибо за использование HASSio Cursor!** 🎉

## 📊 Статус

- **MCP:** ✅ Работает
- **SSH:** 🔧 Требует настройки (см. docs/SETUP.md)
- **SAMBA:** 🔧 Требует настройки (см. docs/SETUP.md)

## 🔗 Ссылки

После настройки `config.yml`:

- Home Assistant: см. `config.yml`
- MCP Server: см. `.cursor/mcp.json`

[docs]: https://gfermoto.github.io/HASSio_Cursor
