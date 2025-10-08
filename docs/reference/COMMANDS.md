# 💻 Справочник команд

Все доступные команды и скрипты для работы с Home Assistant.

---

## 📑 Содержание

- [🔧 Основные скрипты](#основные-скрипты)
  - [setup.sh](#setupsh)
  - [mount.sh](#mountsh)
  - [check.sh](#checksh)
- [📦 Скрипты в scripts/](#скрипты-в-scripts)
  - [scripts/setup_samba.sh](#scriptssetup_sambash)
  - [scripts/deploy.sh](#scriptsdeploysh)
  - [scripts/backup.sh](#scriptsbackupsh)
  - [scripts/restore.sh](#scriptsrestoresh)
  - [scripts/view_logs.sh](#scriptsview_logssh)
- [🔐 SSH команды](#ssh-команды)
  - [Подключение](#подключение)
  - [Выполнение команды без входа](#выполнение-команды-без-входа)
  - [Полезные команды HA](#полезные-команды-ha)
- [📁 SAMBA операции](#samba-операции)
  - [Монтирование](#монтирование)
  - [Работа с файлами](#работа-с-файлами)
  - [Проверка](#проверка)
- [📝 YAML валидация](#yaml-валидация)
  - [Проверка синтаксиса](#проверка-синтаксиса)
  - [Проверка через HA](#проверка-через-ha)
- [🗂️ Git команды](#git-команды)
  - [Инициализация (делается автоматически)](#инициализация-делается-автоматически)
  - [Ежедневное использование](#ежедневное-использование)
  - [Откат изменений](#откат-изменений)
- [🤖 MCP команды (через AI в Cursor)](#mcp-команды-через-ai-в-cursor)
- [🛠️ Полезные алиасы](#полезные-алиасы)
- [📊 Проверка статуса](#проверка-статуса)
  - [Быстрая проверка](#быстрая-проверка)
  - [Детальная проверка](#детальная-проверка)
- [🔄 Копирование файлов](#копирование-файлов)
  - [С сервера на локальный](#с-сервера-на-локальный)
  - [С локального на сервер](#с-локального-на-сервер)
- [📈 Мониторинг](#мониторинг)
  - [Проверка доступности](#проверка-доступности)
  - [Использование ресурсов](#использование-ресурсов)
  - [Логи в реальном времени](#логи-в-реальном-времени)
- [🎯 Быстрая справка](#быстрая-справка)

---

## 🔧 Основные скрипты

### setup.sh

Установка всех зависимостей (выполняется один раз).

```bash
./setup.sh
```

**Что делает:**

- Устанавливает системные пакеты
- Устанавливает Python пакеты
- Создаёт SSH ключ
- Создаёт директории

---

### mount.sh

Монтирование конфигов Home Assistant через SAMBA.

```bash
./mount.sh
```

**Что делает:**

- Монтирует `//your-server/config` в `/mnt/hassio`
- Создаёт символическую ссылку `config/` в проекте
- Показывает содержимое

**Размонтировать:**

```bash
sudo umount /mnt/hassio
```

---

### check.sh

Проверка состояния окружения.

```bash
./check.sh
```

**Проверяет:**

- SSH подключение
- SAMBA монтирование
- Доступ к configuration.yaml
- MCP конфигурацию

---

## 📦 Скрипты в scripts/

### scripts/setup_samba.sh

Создание файла с SAMBA credentials.

```bash
./scripts/setup_samba.sh
```

**Создаёт:** `.samba-credentials` с username/password

---

### scripts/deploy.sh

Безопасное развертывание изменений.

```bash
./scripts/deploy.sh
```

**Что делает (автоматически):**

1. Создаёт бэкап
2. Проверяет YAML синтаксис
3. Валидирует конфигурацию HA
4. Коммитит в Git
5. Перезагружает Home Assistant
6. Проверяет что всё запустилось

---

### scripts/backup.sh

Создание резервной копии конфигурации.

```bash
./scripts/backup.sh
```

**Создаёт:** `backups/config_YYYYMMDD_HHMMSS.tar.gz`
**Хранение:** 7 дней (старые удаляются автоматически)

---

### scripts/restore.sh

Восстановление из резервной копии.

```bash
./scripts/restore.sh
```

**Интерактивно:**

1. Показывает список доступных бэкапов
2. Просит выбрать номер
3. Запрашивает подтверждение
4. Создаёт бэкап текущей конфигурации
5. Восстанавливает выбранный бэкап

---

### scripts/view_logs.sh

Просмотр логов Home Assistant.

```bash
./scripts/view_logs.sh
```

**Интерактивное меню:**

1. Последние 50 строк
2. Последние 100 строк
3. Только ошибки (ERROR)
4. Только предупреждения (WARNING)
5. В реальном времени (tail -f)
6. Поиск по тексту

---

## 🔐 SSH команды

### Подключение

```bash
ssh -F .ssh/config hassio
```

### Выполнение команды без входа

```bash
ssh -F .ssh/config hassio "КОМАНДА"
```

### Полезные команды HA

**Информация о системе:**

```bash
ssh -F .ssh/config hassio "ha core info"
ssh -F .ssh/config hassio "ha host info"
ssh -F .ssh/config hassio "ha os info"
```

**Управление:**

```bash
ssh -F .ssh/config hassio "ha core restart"
ssh -F .ssh/config hassio "ha core check"
ssh -F .ssh/config hassio "ha core update"
ssh -F .ssh/config hassio "ha core rebuild"
```

**Add-ons:**

```bash
ssh -F .ssh/config hassio "ha addons list"
ssh -F .ssh/config hassio "ha addons info ADDON"
ssh -F .ssh/config hassio "ha addons restart ADDON"
```

**Логи:**

```bash
ssh -F .ssh/config hassio "tail -f /config/home-assistant.log"
ssh -F .ssh/config hassio "grep ERROR /config/home-assistant.log"
ssh -F .ssh/config hassio "ha core logs"
```

**Снапшоты:**

```bash
ssh -F .ssh/config hassio "ha backups list"
ssh -F .ssh/config hassio "ha backups new --name='manual'"
ssh -F .ssh/config hassio "ha backups restore SLUG"
```

---

## 📁 SAMBA операции

### Монтирование

```bash
./mount.sh                          # Монтировать
sudo umount /mnt/hassio             # Размонтировать
mountpoint /mnt/hassio              # Проверить статус
```

### Работа с файлами

```bash
ls config/                          # Список файлов
cat config/configuration.yaml       # Просмотр файла
code config/                        # Открыть в Cursor
nano config/automations.yaml        # Редактировать в nano
```

### Проверка

```bash
df -h | grep hassio                 # Информация о монтировании
mount | grep hassio                 # Детали монтирования
```

---

## 📝 YAML валидация

### Быстрая проверка всех YAML

```bash
./scripts/validate_yaml.sh  # Проверить все YAML файлы в проекте
```

**Или через меню:**

```bash
./ha
# Выберите: 9) 📝 Проверить YAML
```

---

## 📚 Валидация документации

### Проверка качества Markdown файлов

```bash
python3 scripts/validate_docs.py  # Проверить всю документацию
```

**Или через меню:**

```bash
./ha
# Выберите: 10) 📚 Проверить документацию
```

**Что проверяется:**

- ✅ Сломанные блоки кода (закрывающий и сразу открывающий fence)
- ✅ Отсутствие пустой строки между блоками
- ✅ Trailing spaces после fence markers
- ✅ Пустые блоки кода
- ✅ Незакрытые fence markers
- ✅ Hardcoded пути пользователей (~/path вместо /home/username/path)

**Автоматическая проверка:**

Валидатор интегрирован в pre-commit hooks и запускается автоматически при каждом коммите!

### Проверка конкретного файла

```bash
yamllint config.yml                 # Стандартная проверка
yamllint -d relaxed config.yml      # Мягкая проверка
yamllint --print-config             # Показать текущие правила
```

### Проверка конфигураций Home Assistant

```bash
yamllint config/configuration.yaml
yamllint config/*.yaml
yamllint config/automations.yaml    # Конкретный файл
```

### Проверка через Home Assistant

```bash
ssh -F .ssh/config hassio "ha core check"
```

### Настройка правил

Правила валидации настраиваются в `.yamllint`:

```yaml
# Основные правила
- Отступы: 2 пробела
- Длина строки: 120 символов (warning)
- Кавычки: только когда необходимо
- Булевы значения: on/off, yes/no, true/false
```

**Проверить правила:**

```bash
yamllint --print-config
```

---

## 🗂️ Git команды

### Инициализация (делается автоматически)

```bash
cd config/
git init
git config user.name "Your Name"
git config user.email "your@email.com"
```

### Ежедневное использование

```bash
cd config/

git status                          # Что изменилось
git diff                            # Детали изменений
git diff configuration.yaml         # Изменения в файле

git add configuration.yaml          # Добавить файл
git add .                           # Добавить всё

git commit -m "Описание изменений"  # Закоммитить

git log --oneline                   # История
git log --oneline --graph           # История с графом
```

### Откат изменений

```bash
git checkout -- configuration.yaml  # Откатить файл
git revert HEAD                     # Откатить последний коммит
git reset --hard HEAD~1             # Удалить последний коммит (осторожно!)
```

---

## 🤖 MCP команды (через AI в Cursor)

Просто спрашивайте AI в Cursor:

**Мониторинг:**

"Какая температура в доме?"
"Покажи все устройства"
"Какая влажность?"
"Покажи все термостаты"

**Управление:**

"Включи свет SONOFF"
"Выключи свет на кухне"
"Установи температуру 22 градуса в спальне"
"Включи отопление"

**Камеры:**

"Покажи снимок с входной камеры"
"Сделай снапшот с камеры в саду"

---

## 🛠️ Полезные алиасы

Добавьте в `~/.bashrc`:

```bash
# Home Assistant
alias ha='ssh -F ~/HASSio/.ssh/config hassio'
alias halog='ssh -F ~/HASSio/.ssh/config hassio "tail -f /config/home-assistant.log"'
alias harestart='ssh -F ~/HASSio/.ssh/config hassio "ha core restart"'
alias hacheck='ssh -F ~/HASSio/.ssh/config hassio "ha core check"'
alias hamount='cd ~/HASSio && ./mount.sh'
alias haedit='code ~/HASSio/config/'
alias hadeploy='cd ~/HASSio && ./scripts/deploy.sh'
```

**Применить:**

```bash
source ~/.bashrc
```

**Использование:**

```bash
ha              # = ssh hassio
halog           # = логи в реальном времени
hacheck         # = проверить конфиг
harestart       # = перезагрузить
hamount         # = смонтировать
haedit          # = открыть в Cursor
hadeploy        # = развернуть изменения
```

---

## 📊 Проверка статуса

### Быстрая проверка

```bash
./check.sh
```

### Детальная проверка

```bash
# SSH
ssh -F .ssh/config hassio "ha core info"

# SAMBA
mountpoint /mnt/hassio && echo "✅" || echo "❌"

# Место на диске
ssh -F .ssh/config hassio "df -h /config"

# Версия HA
ssh -F .ssh/config hassio "ha core info" | grep version
```

---

## 🔄 Копирование файлов

### С сервера на локальный

```bash
scp -F .ssh/config hassio:/config/secrets.yaml ./backup/
```

### С локального на сервер

```bash
scp -F .ssh/config ./new_automation.yaml hassio:/config/
```

**Или через SAMBA (проще):**

```bash
cp new_file.yaml config/
```

---

## 📈 Мониторинг

### Проверка доступности

```bash
curl -sf https://your-domain.com && echo "✅ Доступен" || echo "❌ Недоступен"
```

### Использование ресурсов

```bash
ssh -F .ssh/config hassio "top -bn1 | head -20"
ssh -F .ssh/config hassio "free -h"
ssh -F .ssh/config hassio "df -h"
```

### Логи в реальном времени

```bash
./scripts/view_logs.sh
# Выбрать пункт 5
```

---

## 🎯 Быстрая справка

```bash
# Установка (1 раз)
./setup.sh

# Монтирование
./mount.sh

# Проверка
./check.sh

# Редактирование
code config/

# Развертывание
./scripts/deploy.sh

# Логи
./scripts/view_logs.sh

# Бэкап
./scripts/backup.sh

# Восстановление
./scripts/restore.sh
```
