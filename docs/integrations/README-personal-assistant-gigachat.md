# 🏠 Персональный ассистент мониторинга Home Assistant с GigaChat

Образовательный пример AI агента с памятью диалога для мониторинга умного дома на базе архитектуры n8n Voice Assistant.

**Ключевые особенности:**
- 🧠 **Память диалога** - помнит последние 10 сообщений
- 🤖 **Langchain Agent** - использует Memory Buffer как в примере n8n
- 🇷🇺 **GigaChat** - бесплатный российский LLM (работает без VPN)
- 📊 **Только мониторинг** - вопросы о доме (без управления)
- 💬 **Естественный диалог** - понимает продолжения типа "А в спальне?"

---

## Чем отличается от других ваших workflow

| Workflow | Назначение | LLM | Memory | HA | Бот |
|----------|------------|-----|--------|----|----|
| `n8n-voice-assistant-free.local` | Управление HA | GigaChat | ❌ Нет | ✅ Команды | Рабочий |
| `n8n-meteostation-ai.local` | Погода | GigaChat | ❌ Нет | ❌ Нет | Рабочий |
| **n8n-ha-monitoring-assistant** | **Мониторинг HA** | **GigaChat** | ✅ **Да** | ✅ **Вопросы** | **Персональный** |

**Этот workflow - образовательный пример реализации Memory + Agent с GigaChat!**

---

## Архитектура (как в n8n Voice Assistant примере)

```text
Telegram Message
    ↓
System Commands Check (/help, /clear)
    ↓
HA: Get All States
    ↓
Filter Monitoring Devices
    ↓
┌─────────────────────────────────┐
│ Langchain Agent                 │
│ ┌─────────────────────────────┐ │
│ │ GigaChat Chat Model         │ │
│ │ (HTTP Generic)              │ │
│ └─────────────────────────────┘ │
│ ┌─────────────────────────────┐ │
│ │ Memory Buffer Window        │ │
│ │ (10 messages, session=chat) │ │
│ └─────────────────────────────┘ │
│ ┌─────────────────────────────┐ │
│ │ 3 HA Tools (read-only)      │ │
│ │ - Get Sensor State          │ │
│ │ - Get Device List           │ │
│ │ - Get History               │ │
│ └─────────────────────────────┘ │
└─────────────────────────────────┘
    ↓
Telegram Answer
```

**Итого:** 13 nodes с Langchain Agent и Memory

---

## Требования

### Сервисы

1. **n8n** с установленным Langchain package
2. **Home Assistant** с доступным API
3. **Telegram Bot** (создайте отдельного персонального бота)
4. **GigaChat API** (бесплатная регистрация на developers.sber.ru)

### Credentials

1. Telegram Bot Token (от @BotFather)
2. Home Assistant Long-Lived Token
3. GigaChat Client ID и Secret

---

## Установка

### Шаг 1: Регистрация GigaChat

1. Перейдите на [developers.sber.ru](https://developers.sber.ru/studio/workspaces)
2. Войдите через Сбер ID
3. Создайте проект
4. API → GigaChat API → Создать новые данные
5. Скопируйте:
   - Client ID: `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`
   - Client Secret: `yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy`

### Шаг 2: Создание Base64 токена

```bash
# На вашей машине
echo -n "CLIENT_ID:CLIENT_SECRET" | base64

# Пример:
# echo -n "62228c4da-a6a5-418b-8690-afd2b2baf902:31e9e96d-e192-4909-af3f-f895b64fdbc2" | base64
# Результат: NjIyOGM0ZGEtYTZhNS00MThiLTg2OTAtYWZkMmIyYmFmOTAyOjMxZTllOTZkLWUxOTItNDkwOS1hZjNmLWY4OTViNjRmZGJjYg==
```

Сохраните этот Base64 токен.

### Шаг 3: Создание персонального Telegram бота

```text
1. Telegram → @BotFather → /newbot
2. Name: My Personal Home Assistant
3. Username: my_personal_ha_bot (уникальное имя)
4. Скопируйте Token: 123456789:ABCdefGHIjklMNO...
```

### Шаг 4: Получение вашего Telegram ID

```text
1. Telegram → @userinfobot
2. Отправьте любое сообщение
3. Скопируйте Id: 154544865
```

### Шаг 5: Создание Home Assistant Token

```text
1. Home Assistant → Профиль (левый нижний угол)
2. Long-Lived Access Tokens → Create Token
3. Name: n8n-personal-monitor
4. Скопируйте token
```

### Шаг 6: Импорт workflow в n8n

1. Скопируйте `n8n-ha-monitoring-assistant-gigachat.json`
2. n8n → Workflows → Import from File
3. Вставьте JSON

### Шаг 7: Настройка credentials в n8n

#### 7.1 Telegram Bot Credential

```text
n8n → Credentials → Add Credential → Telegram API
Access Token: 123456789:ABCdef... (от BotFather)
Name: Telegram Bot Personal
```

#### 7.2 Home Assistant Credential

```text
n8n → Credentials → Add Credential → HTTP Header Auth
Name: Authorization
Value: Bearer YOUR_HA_LONG_LIVED_TOKEN
Credential Name: Home Assistant API
```

### Шаг 8: Замена параметров в workflow

**Обязательно замените:**

1. **Node "Telegram: Trigger":**
   - `userIds`: ваш Telegram ID
   - `credentials`: выберите Telegram Bot Personal

2. **Node "HA: Get All States":**
   - `url`: `http://YOUR_HA_IP:8123/api/states`
   - `credentials`: выберите Home Assistant API

3. **Node "GigaChat: Get OAuth Token":**
   - Header `Authorization`: `Basic ВАШ_BASE64_ТОКЕН`

4. **Все Telegram nodes:**
   - `credentials`: Telegram Bot Personal

---

## Проблема: n8n не имеет Generic HTTP Chat Model

**⚠️ Важное открытие:**

n8n Langchain может не иметь `lmChatGeneric` (HTTP Chat Model) node.

### Решение A: Использовать OpenAI-compatible endpoint

Если GigaChat поддерживает OpenAI-compatible API:

```text
Node: OpenAI Chat Model
Base URL: https://gigachat.devices.sberbank.ru/api/v1
API Key: Bearer token от OAuth
Model: GigaChat
```

### Решение B: Ручная реализация Memory

Без Langchain Agent, через Code nodes:
1. Хранить историю в workflow variables
2. Передавать последние 10 сообщений в каждом запросе GigaChat
3. Обрабатывать ответы вручную

### Решение C: Использовать Ollama (когда установите)

Ollama точно работает с n8n Langchain:
- `@n8n/n8n-nodes-langchain.lmChatOllama` существует
- Memory Buffer Window поддерживается
- Agent работает из коробки

---

## Альтернативный подход: DeepSeek

**DeepSeek** - китайский LLM с хорошей поддержкой русского:

### Проверка доступности:

```bash
# Проверьте доступен ли из РФ
curl -I https://api.deepseek.com

# Если 200 OK - работает!
```

### Регистрация:

1. [platform.deepseek.com](https://platform.deepseek.com/)
2. Sign up (может потребоваться VPN для регистрации)
3. API Keys → Create
4. Скопируйте ключ

### В n8n:

```text
Node: OpenAI Chat Model
Base URL: https://api.deepseek.com/v1
API Key: sk-deepseek-xxx
Model: deepseek-chat
```

DeepSeek использует OpenAI-compatible API, поэтому работает с n8n Langchain!

---

## Рекомендация

**Для образовательного примера с Memory:**

**Вариант 1 (проще):** Создайте пример на базе Ollama
- Точно работает с Langchain
- Memory Buffer из коробки
- После установки GPU passthrough

**Вариант 2 (сейчас):** Попробуйте DeepSeek
- Может работать из РФ (проверить)
- OpenAI-compatible API
- Прямая интеграция с n8n Langchain

**Вариант 3 (сложно):** Ручная реализация Memory для GigaChat
- Без Langchain Agent
- Custom Code nodes для управления историей
- Больше кода, но образовательно

---

## Следующие шаги

**Что делать:**

1. **Проверьте DeepSeek:** Доступен ли из РФ?
2. **Если да:** Создам полный пример с DeepSeek + Memory + Agent
3. **Если нет:** Создам ручную реализацию Memory для GigaChat
4. **Или:** Сделаем пример на Ollama (после GPU setup)

**Какой вариант предпочитаете?**

---

**Автор:** AI Assistant  
**Дата:** Октябрь 2025  
**Статус:** 🔄 Требует выбора подхода

