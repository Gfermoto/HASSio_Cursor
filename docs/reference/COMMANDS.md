# 💻 Справочник команд

Все доступные команды и скрипты для работы с Home Assistant.

---

## 🔧 Основные скрипты

### setup.sh

Установка всех зависимостей (выполняется один раз).

```bash
./setup.sh
```text

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
```text

**Что делает:**

- Монтирует `//your-server/config` в `/mnt/hassio`
- Создаёт символическую ссылку `config/` в проекте
- Показывает содержимое

**Размонтировать:**

```bash
sudo umount /mnt/hassio
```text

---

### check.sh

Проверка состояния окружения.

```bash
./check.sh
```text

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
```text

**Создаёт:** `.samba-credentials` с username/password

---

### scripts/deploy.sh

Безопасное развертывание изменений.

```bash
./scripts/deploy.sh
```text

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
```text

**Создаёт:** `backups/config_YYYYMMDD_HHMMSS.tar.gz`
**Хранение:** 7 дней (старые удаляются автоматически)

---

### scripts/restore.sh

Восстановление из резервной копии.

```bash
./scripts/restore.sh
```text

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
```text

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
```text

### Выполнение команды без входа

```bash
ssh -F .ssh/config hassio "КОМАНДА"
```text

### Полезные команды HA

**Информация о системе:**

```bash
ssh -F .ssh/config hassio "ha core info"
ssh -F .ssh/config hassio "ha host info"
ssh -F .ssh/config hassio "ha os info"
```text

**Управление:**

```bash
ssh -F .ssh/config hassio "ha core restart"
ssh -F .ssh/config hassio "ha core check"
ssh -F .ssh/config hassio "ha core update"
ssh -F .ssh/config hassio "ha core rebuild"
```text

**Add-ons:**

```bash
ssh -F .ssh/config hassio "ha addons list"
ssh -F .ssh/config hassio "ha addons info ADDON"
ssh -F .ssh/config hassio "ha addons restart ADDON"
```text

**Логи:**

```bash
ssh -F .ssh/config hassio "tail -f /config/home-assistant.log"
ssh -F .ssh/config hassio "grep ERROR /config/home-assistant.log"
ssh -F .ssh/config hassio "ha core logs"
```text

**Снапшоты:**

```bash
ssh -F .ssh/config hassio "ha backups list"
ssh -F .ssh/config hassio "ha backups new --name='manual'"
ssh -F .ssh/config hassio "ha backups restore SLUG"
```text

---

## 📁 SAMBA операции

### Монтирование

```bash
./mount.sh                          # Монтировать
sudo umount /mnt/hassio             # Размонтировать
mountpoint /mnt/hassio              # Проверить статус
```text

### Работа с файлами

```bash
ls config/                          # Список файлов
cat config/configuration.yaml       # Просмотр файла
code config/                        # Открыть в Cursor
nano config/automations.yaml        # Редактировать в nano
```text

### Проверка

```bash
df -h | grep hassio                 # Информация о монтировании
mount | grep hassio                 # Детали монтирования
```text

---

## 📝 YAML валидация

### Проверка синтаксиса

```bash
yamllint config/configuration.yaml
yamllint config/*.yaml
yamllint -d relaxed config/*.yaml   # Мягкая проверка
```text

### Проверка через HA

```bash
ssh -F .ssh/config hassio "ha core check"
```text

---

## 🗂️ Git команды

### Инициализация (делается автоматически)

```bash
cd config/
git init
git config user.name "Your Name"
git config user.email "your@email.com"
```text

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
```text

### Откат изменений

```bash
git checkout -- configuration.yaml  # Откатить файл
git revert HEAD                     # Откатить последний коммит
git reset --hard HEAD~1             # Удалить последний коммит (осторожно!)
```text

---

## 🤖 MCP команды (через AI в Cursor)

Просто спрашивайте AI в Cursor:

**Мониторинг:**

```text
"Какая температура в доме?"
"Покажи все устройства"
"Какая влажность?"
"Покажи все термостаты"
```text

**Управление:**

```text
"Включи свет SONOFF"
"Выключи свет на кухне"
"Установи температуру 22 градуса в спальне"
"Включи отопление"
```text

**Камеры:**

```text
"Покажи снимок с входной камеры"
"Сделай снапшот с камеры в саду"
```text

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
```text

**Применить:**

```bash
source ~/.bashrc
```text

**Использование:**

```bash
ha              # = ssh hassio
halog           # = логи в реальном времени
hacheck         # = проверить конфиг
harestart       # = перезагрузить
hamount         # = смонтировать
haedit          # = открыть в Cursor
hadeploy        # = развернуть изменения
```text

---

## 📊 Проверка статуса

### Быстрая проверка

```bash
./check.sh
```text

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
```text

---

## 🔄 Копирование файлов

### С сервера на локальный

```bash
scp -F .ssh/config hassio:/config/secrets.yaml ./backup/
```text

### С локального на сервер

```bash
scp -F .ssh/config ./new_automation.yaml hassio:/config/
```text

**Или через SAMBA (проще):**

```bash
cp new_file.yaml config/
```text

---

## 📈 Мониторинг

### Проверка доступности

```bash
curl -sf https://your-domain.com && echo "✅ Доступен" || echo "❌ Недоступен"
```text

### Использование ресурсов

```bash
ssh -F .ssh/config hassio "top -bn1 | head -20"
ssh -F .ssh/config hassio "free -h"
ssh -F .ssh/config hassio "df -h"
```text

### Логи в реальном времени

```bash
./scripts/view_logs.sh
# Выбрать пункт 5
```text

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
```text
