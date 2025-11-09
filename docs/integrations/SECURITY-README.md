# Безопасность и чувствительные данные

## 🔒 Система защиты

Все чувствительные данные (токены, пароли, API ключи) **НЕ должны попадать в Git!**

### Структура файлов

Для каждого workflow/конфига существует **2 версии**:

#### 1. **Публичная версия** (в Git)
- Файл: `workflow-name.json`
- Содержит: плейсхолдеры вместо реальных данных
- Примеры:
  - `YOUR_BOT_TOKEN`
  - `YOUR_HA_CREDENTIAL_ID`
  - `YOUR_TELEGRAM_CHAT_ID`
  - `YOUR_API_KEY`

#### 2. **Локальная версия** (НЕ в Git)
- Файл: `workflow-name.local.json`
- Содержит: реальные токены и данные
- **Автоматически игнорируется** через `.gitignore`

---

## 📋 Примеры

### n8n Workflows

```bash
# Публичный шаблон (в Git)
docs/integrations/n8n-voice-assistant-control-ollama.json

# Рабочая версия (НЕ в Git)
docs/integrations/n8n-voice-assistant-control-ollama.local.json
```

### MCP конфигурация

```bash
# Публичный шаблон (в Git)
.cursor/mcp.json

# Рабочая версия (НЕ в Git)
.cursor/mcp.local.json
```

### ESPHome

```bash
# Публичный шаблон (в Git)
esphome/device.yaml

# Чувствительные данные (НЕ в Git)
esphome/secrets.yaml
```

---

## 🛡️ Что защищается

### 1. Токены и ключи
- ❌ Telegram Bot Token
- ❌ Home Assistant Long-Lived Access Token
- ❌ OpenAI / GigaChat API Keys
- ❌ Yandex Weather API Key
- ❌ OAuth credentials

### 2. Персональные данные
- ❌ Chat IDs (Telegram)
- ❌ IP адреса (внутренние/внешние)
- ❌ Координаты GPS
- ❌ Имена и названия мест

### 3. Конфигурации
- ❌ WiFi пароли
- ❌ SSH ключи
- ❌ SAMBA credentials
- ❌ Database passwords

---

## ✅ Как работать с workflow

### Первичная настройка

1. **Скопируй публичный шаблон в локальный:**
```bash
cp n8n-workflow.json n8n-workflow.local.json
```

2. **Замени плейсхолдеры на реальные данные** в `.local.json`:
   - `YOUR_BOT_TOKEN` → реальный токен бота
   - `YOUR_HA_CREDENTIAL_ID` → ID credential из n8n
   - `YOUR_TELEGRAM_CHAT_ID` → твой chat ID

3. **Импортируй в n8n** файл `.local.json`

4. **Настрой credentials в n8n** (они не экспортируются)

### Обновление workflow

Когда меняешь логику workflow:

1. **Экспортируй из n8n** → сохрани как `.local.json`

2. **Создай публичную версию:**
```bash
cp workflow.local.json workflow.json
```

3. **Замени чувствительные данные на плейсхолдеры** в `workflow.json`:
```bash
# Пример с sed
sed -i 's/bot[0-9]*:[A-Za-z0-9_-]*/botYOUR_BOT_TOKEN/g' workflow.json
sed -i 's/eyJ[A-Za-z0-9_-]*\.[A-Za-z0-9_-]*\.[A-Za-z0-9_-]*/YOUR_HA_TOKEN/g' workflow.json
```

4. **Commit только публичный файл:**
```bash
git add workflow.json
git commit -m "Update workflow logic"
```

---

## 🔍 Проверка перед commit

### Автоматическая проверка

Используй pre-commit hook:

```bash
# .git/hooks/pre-commit
#!/bin/bash

# Проверка на токены
if git diff --cached | grep -iE '(bot[0-9]{9,}:[A-Za-z0-9_-]{35}|eyJ[A-Za-z0-9_-]{100,})'; then
    echo "❌ ОШИБКА: Найден токен в коммите!"
    echo "Используйте .local.json файлы для чувствительных данных"
    exit 1
fi

echo "✅ Проверка токенов пройдена"
exit 0
```

### Ручная проверка

Перед `git push`:

```bash
# Проверить что нет .local файлов
git status | grep ".local"

# Проверить содержимое staged файлов
git diff --cached | grep -iE "(token|password|secret|key|credential)"
```

---

## 📝 .gitignore правила

Текущие правила (в `.gitignore`):

```gitignore
# n8n workflows с реальными данными
*.local.json
**/*.local.json

# MCP конфигурация
.cursor/mcp.json
.cursor/mcp.local.json

# ESPHome секреты
**/esphome/secrets.yaml

# API ключи
*key*.json
*token*.json
*secret*.json

# Credentials
**/credentials.json
**/*.credentials.json

# Environment
.env
*.local
*.local.*
```

---

## 🚨 Если токен попал в Git

### 1. Немедленно отозвать токен
- Telegram Bot: @BotFather → revoke token
- Home Assistant: Profile → Long-Lived Tokens → Delete

### 2. Удалить из истории Git

**⚠️ ВНИМАНИЕ:** Это перепишет историю!

```bash
# Используй BFG Repo-Cleaner
git clone --mirror https://github.com/user/repo.git
bfg --replace-text passwords.txt repo.git
cd repo.git
git reflog expire --expire=now --all
git gc --prune=now --aggressive
git push --force
```

### 3. Создать новый токен

Всегда создавай новые токены после компрометации.

---

## 📚 Дополнительно

### Шаблоны плейсхолдеров

Используй понятные плейсхолдеры:

- `YOUR_BOT_TOKEN` - Telegram Bot Token
- `YOUR_HA_CREDENTIAL_ID` - Home Assistant credential ID из n8n
- `YOUR_HA_TOKEN` - Home Assistant Long-Lived Access Token
- `YOUR_TELEGRAM_CHAT_ID` - Telegram Chat ID
- `YOUR_API_KEY` - Любой API ключ
- `YOUR_IP` - IP адрес
- `YOUR_LATITUDE` / `YOUR_LONGITUDE` - Координаты

### Документирование

В README каждого workflow указывай:

```markdown
## Настройка

1. Скопируй `workflow.json` в `workflow.local.json`
2. Замени следующие плейсхолдеры:
   - `YOUR_BOT_TOKEN` → получи от @BotFather
   - `YOUR_HA_TOKEN` → создай в HA Profile → Long-Lived Tokens
3. Импортируй `workflow.local.json` в n8n
```

---

**Помни: Безопасность > Удобство! 🔒**

Лучше потратить 2 минуты на создание `.local` копии, чем потом менять все токены.
