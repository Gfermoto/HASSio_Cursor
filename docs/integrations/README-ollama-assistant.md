# 🤖 Текстовый ассистент для Home Assistant с Ollama

Управление Home Assistant через естественный язык в Telegram. Использует **Ollama** (100% локально) + **Langchain Agent** с памятью.

---

## 🎯 Возможности

- ✅ **Управление светом:** включение/выключение, яркость
- ✅ **Управление климатом:** установка температуры
- ✅ **Запуск сцен:** активация автоматизаций
- ✅ **Получение статуса:** информация с датчиков
- ✅ **Естественный язык:** пишите как удобно
- ✅ **Память диалога:** помнит 10 последних сообщений
- ✅ **100% локально:** работает без интернета
- ✅ **Приватность:** данные не покидают вашу сеть

---

## 💰 Стоимость

| Сервис | Цена | Требования |
|--------|------|------------|
| **Ollama** | ✅ **Бесплатно навсегда** | GPU 4GB+ |
| **Telegram** | ✅ Бесплатно | Без лимитов |
| **Home Assistant** | ✅ Бесплатно | Без лимитов |

**Итого: ₽0/месяц, работает БЕЗ интернета!** 🎉

---

## 📊 Архитектура

```text
```text
Telegram (текст)
   ↓
Langchain Agent
   ├─ Ollama (phi3:mini локально)
   ├─ Memory (10 сообщений)
   └─ 5 HA Tools
   ↓
Home Assistant
   ↓
Telegram (ответ)
```text

**16 узлов** - Langchain подход с локальным AI!

---

## 📋 Требования

### Установленное ПО

1. **Ollama на Proxmox с GPU** - см. [OLLAMA-PROXMOX-SETUP.md](./OLLAMA-PROXMOX-SETUP.md)
2. **n8n** - любая версия с Langchain узлами
3. **Home Assistant** - доступен по API
4. **Telegram Bot** - создан через [@BotFather](https://t.me/botfather)

### Модель Ollama

**Для GTX 1050 Ti (4GB):**
- `phi3:mini` (рекомендуется) - 2.3GB
- `llama3.2:3b` - 2GB
- `qwen2.5:3b` - 2GB

**Для GTX 1060 (6GB):**
- `llama3.1:8b` (рекомендуется) - 4.7GB

---

## 🚀 Установка

### Шаг 1: Установите Ollama

Следуйте инструкции: [OLLAMA-PROXMOX-SETUP.md](./OLLAMA-PROXMOX-SETUP.md)

Убедитесь что:
- ✅ Ollama работает на `http://<IP>:11434`
- ✅ Модель скачана: `ollama list`
- ✅ API доступен: `curl http://<IP>:11434/api/tags`

### Шаг 2: Создайте Telegram Bot

```bash
```bash
# 1. Откройте @BotFather в Telegram
# 2. Отправьте: /newbot
# 3. Укажите имя: "My Home Assistant Bot"
# 4. Укажите username: "my_ha_bot" (должен заканчиваться на _bot)
# 5. Получите токен: 123456789:ABCdefGHIjklMNOpqrsTUVwxyz

# 6. Узнайте свой Telegram ID
# Откройте @userinfobot и отправьте любое сообщение
# ID будет примерно: 154544865
```text

### Шаг 3: Настройте n8n Credentials

#### 3.1 Telegram Bot

```bash
```bash
n8n → Credentials → Add Credential → Telegram API
```text

Введите:
- **Access Token:** `123456789:ABCdefGHI...` (от BotFather)
- **Name:** `Telegram Bot`

#### 3.2 Home Assistant API

```bash
```bash
n8n → Credentials → Add Credential → HTTP Header Auth
```text

Введите:
- **Name:** `Authorization`
- **Value:** `Bearer YOUR_HA_LONG_LIVED_TOKEN`
- **Credential Name:** `Home Assistant API`

Получить токен HA:
1. Home Assistant → Профиль (внизу слева)
2. Scroll вниз → **Long-Lived Access Tokens**
3. **Create Token** → введите имя: `n8n`
4. Скопируйте токен

### Шаг 4: Импортируйте workflow

1. Скопируйте содержимое `n8n-voice-assistant-ollama.json`
2. В n8n → **Import from File** → вставьте JSON
3. Откроется workflow с предупреждениями

### Шаг 5: Замените параметры

**ОБЯЗАТЕЛЬНО замените:**

1. **Telegram Trigger (узел 1):**
   - `userIds`: ваш Telegram ID (например `154544865`)
   - `credentials`: выберите созданный Telegram credential

2. **Ollama Model (узел 8):**
   - `baseURL`: `http://YOUR_OLLAMA_IP:11434` (IP LXC контейнера)
   - `model`: `phi3:mini` (или ваша модель)

3. **HA: Get All States (узел 6):**
   - `url`: `http://YOUR_HA_IP:8123/api/states`
   - `credentials`: выберите Home Assistant credential

4. **Все Telegram узлы:**
   - `credentials`: выберите Telegram credential

5. **Tools (узлы 10-14):**
   - Создайте отдельные workflows для каждого инструмента (см. ниже)
   - Замените `YOUR_WORKFLOW_ID_*` на ID созданных workflows

---

## 🔧 Создание Tool Workflows

Каждый инструмент (Tool) - это отдельный простой workflow.

### Tool 1: Turn On Light

Создайте новый workflow:

```json
```json
{
  "nodes": [
    {
      "parameters": {
        "method": "POST",
        "url": "http://YOUR_HA_IP:8123/api/services/light/turn_on",
        "authentication": "genericCredentialType",
        "genericAuthType": "httpHeaderAuth",
        "sendBody": true,
        "bodyParameters": {
          "parameters": [
            {
              "name": "entity_id",
              "value": "={{ $json.entity_id }}"
            }
          ]
        }
      },
      "name": "HA: Turn On",
      "type": "n8n-nodes-base.httpRequest",
      "typeVersion": 4.2,
      "position": [240, 300],
      "credentials": {
        "httpHeaderAuth": {
          "id": "YOUR_HA_CREDENTIAL_ID",
          "name": "Home Assistant API"
        }
      }
    }
  ]
}
```text

Сохраните, скопируйте ID workflow и вставьте в `Tool: Turn On Light`

### Tool 2: Turn Off Light

Аналогично Tool 1, но:
- `url`: `.../light/turn_off`

### Tool 3: Set Temperature

```json
```json
{
  "bodyParameters": {
    "parameters": [
      {
        "name": "entity_id",
        "value": "={{ $json.entity_id }}"
      },
      {
        "name": "temperature",
        "value": "={{ $json.temperature }}"
      }
    ]
  }
}
```text

- `url`: `.../climate/set_temperature`

### Tool 4: Activate Scene

- `url`: `.../scene/turn_on`
- Параметр: `entity_id`

### Tool 5: Get Sensor State

```json
```json
{
  "method": "GET",
  "url": "http://YOUR_HA_IP:8123/api/states/={{ $json.entity_id }}"
}
```text

Возвращает JSON с состоянием сенсора.

---

## ✅ Активация

1. **Сохраните** все workflows (главный + 5 tools)
2. **Активируйте** главный workflow (переключатель справа вверху)
3. **Откройте Telegram** → найдите своего бота
4. Отправьте `/start`

Должно прийти приветствие! 🎉

---

## 💬 Примеры использования

### Управление светом

```text
```text
Вы: Включи свет на кухне
AI: Свет на кухне включен ✅

Вы: Выключи все светильники в спальне
AI: Выключил 3 светильника в спальне
```text

### Управление климатом

```text
```text
Вы: Сделай в гостиной 22 градуса
AI: Установил температуру 22°C в гостиной

Вы: Сделай потеплее
AI: Повысил температуру до 23°C
```text

### Запуск сцен

```text
```text
Вы: Запусти вечерний режим
AI: Активировал сцену "Вечерний режим" ✅

Вы: Включи утренний сценарий
AI: Запустил сцену "Утро"
```text

### Получение информации

```text
```text
Вы: Какая температура в комнате?
AI: Температура в комнате: 21.5°C

Вы: Покажи статус всех датчиков движения
AI: Датчик в коридоре: движение обнаружено
    Датчик в спальне: нет движения
```text

### Системные команды

```text
```text
/help - показать справку
/clear - очистить историю диалога
```text

---

## 🔍 Отладка

### Проверка Ollama

```bash
```bash
# На вашей рабочей машине
curl http://YOUR_OLLAMA_IP:11434/api/generate -d '{
  "model": "phi3:mini",
  "prompt": "Привет!",
  "stream": false
}'

# Должен вернуть JSON с ответом
```text

### Проверка HA API

```bash
```bash
curl -H "Authorization: Bearer YOUR_HA_TOKEN" \
  http://YOUR_HA_IP:8123/api/states/light.kitchen

# Должен вернуть JSON с состоянием
```text

### Логи n8n

```bash
```bash
# В n8n → Executions → найдите последний запуск → кликните
# Смотрите ошибки на каждом узле
```text

### Типичные ошибки

**Ошибка: "Connection refused" на Ollama**

Решение:
```bash
```bash
# В LXC контейнере проверить:
systemctl status ollama
ss -tulpn | grep 11434

# Должно показать: 0.0.0.0:11434
```text

**Ошибка: "Unauthorized" на HA API**

Решение:
- Проверьте Home Assistant token
- Пересоздайте Long-Lived Token
- Обновите credential в n8n

**AI не вызывает инструменты**

Решение:
- Проверьте что Tool workflows существуют и активны
- Убедитесь что описания инструментов на русском
- Попробуйте более явную команду: "Используй инструмент turn_on_light для light.kitchen"

**AI отвечает на английском**

Решение:
- Добавьте в system message: "Ты ВСЕГДА отвечаешь ТОЛЬКО на русском языке"
- Увеличьте temperature до 0.8
- Попробуйте другую модель (llama3.2:3b лучше с русским)

---

## 📊 Производительность

### GTX 1050 Ti (4GB) + phi3:mini

- ⏱️ Время ответа: 3-5 секунд
- 🚀 Токены: ~40-60 tokens/sec
- 💾 VRAM: ~2.5GB используется
- 💡 Качество: ⭐⭐⭐⭐⭐ (отлично для команд)

### GTX 1060 (6GB) + llama3.1:8b

- ⏱️ Время ответа: 4-7 секунд
- 🚀 Токены: ~30-50 tokens/sec
- 💾 VRAM: ~5GB используется
- 💡 Качество: ⭐⭐⭐⭐⭐ (лучше понимание контекста)

---

## 🔄 Сравнение с облачными решениями

| Параметр | Ollama (локально) | GigaChat | Groq |
|----------|-------------------|----------|------|
| **Скорость** | ⚡ 40-60 tok/s | 🐌 20-30 tok/s | 🚀 100+ tok/s |
| **Стоимость** | ✅ ₽0 | ✅ ₽0 (квота) | ✅ ₽0 (квота) |
| **Приватность** | ✅ 100% | ❌ Облако | ❌ Облако |
| **Интернет** | ✅ Не нужен | ❌ Нужен | ❌ Нужен |
| **VPN из РФ** | ✅ Не нужен | ✅ Не нужен | ❌ Нужен |
| **Качество (RU)** | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |

**Вывод:**
- Ollama - для приватности и автономности
- GigaChat - для лучшего русского языка (если есть интернет)
- Groq - только если есть постоянный VPN

---

## 🎯 Следующие шаги

1. ✅ Настроили Ollama на Proxmox
2. ✅ Импортировали workflow в n8n
3. ✅ Создали все Tool workflows
4. ✅ Протестировали базовые команды
5. 🔄 Добавьте свои инструменты (освещение по расписанию, уведомления и т.д.)
6. 🔄 Настройте более сложные сценарии
7. 🔄 После апгрейда до GTX 1060 перейдите на llama3.1:8b

---

## 📚 Полезные ссылки

- [Ollama Documentation](https://github.com/ollama/ollama/blob/main/docs/README.md)
- [Ollama API Reference](https://github.com/ollama/ollama/blob/main/docs/api.md)
- [Ollama Models Library](https://ollama.ai/library)
- [n8n Langchain Documentation](https://docs.n8n.io/langchain/)
- [Home Assistant API](https://developers.home-assistant.io/docs/api/rest/)

---

**Автор:** AI Assistant
**Дата:** Октябрь 2025
**Версия:** 1.0
