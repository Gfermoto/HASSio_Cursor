# 🏠 Home Assistant Cursor Integration

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Documentation](https://img.shields.io/badge/docs-MkDocs-blue)](https://gfermoto.github.io/HASSio_Cursor)
[![Pre-commit](https://img.shields.io/badge/pre--commit-enabled-brightgreen?logo=pre-commit)](https://github.com/pre-commit/pre-commit)
[![Home Assistant](https://img.shields.io/badge/Home%20Assistant-Compatible-41BDF5.svg)](https://www.home-assistant.io/)
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

```
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
- 🔀 **Смешанный** - SSH/SAMBA локально, MCP глобально (рекомендуется!)

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

MCP уже настроен и работает! Просто спросите AI:

```
"Какая температура в доме?"
"Включи свет на кухне"
"Покажи все термостаты"
```

## 🛡️ Безопасность

Все чувствительные данные (`config.yml`, `.cursor/mcp.json`, `.ssh/`) **исключены из Git** через `.gitignore`.

Перед публикацией проверьте: `./scripts/check_security.sh`

---

## 📚 Документация

- 📖 [Полная документация](https://gfermoto.github.io/HASSio_Cursor)
- ⚡ [Быстрый старт](docs/setup/quickstart.md)
- 🔬 [Первый аудит](docs/guides/first-audit.md)
- 📋 [Справочник команд](docs/reference/COMMANDS.md)

---

## 🤝 Вклад в проект

Мы рады любой помощи! См. [CONTRIBUTING.md](CONTRIBUTING.md)

---

## 📄 Лицензия

[MIT License](LICENSE) - используйте свободно!

---

## 🌟 Поддержка проекта

Если проект был полезен, поставьте ⭐ на GitHub!

## 📊 Статус

- **MCP:** ✅ Работает
- **SSH:** 🔧 Требует настройки (см. docs/SETUP.md)
- **SAMBA:** 🔧 Требует настройки (см. docs/SETUP.md)

## 🔗 Ссылки

После настройки `config.yml`:
- Home Assistant: см. `config.yml`
- MCP Server: см. `.cursor/mcp.json`
