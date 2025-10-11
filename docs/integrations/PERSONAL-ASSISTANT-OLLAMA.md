# Персональный ассистент с памятью (Ollama + Home Assistant)

Образовательный пример AI агента с памятью диалога на базе архитектуры n8n Voice Assistant.

**Основа:** Ollama (локальный LLM) + Langchain Agent + Memory Buffer  
**Функционал:** Вопросы о состоянии умного дома с памятью контекста

---

## Архитектура

```text
Telegram → Agent (Memory + Ollama) → HA Tools → Telegram

11 nodes:
- Telegram Trigger
- Check Commands (/help, /clear)
- HA Get States
- Ollama Chat Model (phi3:mini)
- Memory Buffer (10 messages)
- Agent
- 2 HA Tools (read-only)
- Telegram Response
```

---

## Что нужно

1. **Ollama VM** - следуйте [OLLAMA-PROXMOX-COMPLETE-GUIDE.md](./OLLAMA-PROXMOX-COMPLETE-GUIDE.md)
2. **Модель phi3:mini** загружена в Ollama
3. **Telegram Bot** (отдельный персональный)
4. **Home Assistant API** token

---

## Установка

### 1. Импорт workflow

```text
n8n → Import from File → n8n-personal-assistant-ollama.json
```

### 2. Замените параметры

**Node "Ollama Model":**
- Base URL: `http://OLLAMA_VM_IP:11434`
- Model: `phi3:mini`

**Node "HA Get States":**
- URL: `http://HA_IP:8123/api/states`
- Credential: Home Assistant (Header Auth с Bearer token)

**Все Telegram nodes:**
- User ID: ваш Telegram ID
- Credential: Telegram Bot

### 3. Создайте 2 Tool workflows

**Tool 1: Get Sensor (входящие параметры: entity_id)**

```json
Node: HTTP Request
Method: GET
URL: http://HA_IP:8123/api/states/={{ $json.entity_id }}
Auth: HA Bearer token
```

**Tool 2: List Devices (входящие параметры: domain)**

```json
Node: HTTP Request → Code
1. GET http://HA_IP:8123/api/states
2. Filter где entity_id начинается с domain
3. Return список
```

### 4. Активируйте workflow

---

## Примеры использования

```text
Вы: Какая температура в гостиной?
Бот: 22.5°C

Вы: А в спальне?
Бот: 21°C (помнит контекст!)

Вы: Какие датчики движения сработали?
Бот: Коридор - 2 мин назад, Кухня - 5 мин назад

Вы: /clear
Бот: 🗑️ Память очищена

Вы: А в спальне?
Бот: Уточните пожалуйста - что вы хотите узнать о спальне? (память очищена)
```

---

## Как работает Memory

**Memory Buffer Window:**
- Хранит последние 10 сообщений (5 пар user-assistant)
- Session key = chat_id (каждый пользователь свою историю)
- Автоматически передается в Agent как контекст
- Команда `/clear` очищает память для этого chat_id

**Преимущества:**
- Естественный диалог
- Понимает продолжения вопросов
- Не нужно повторять контекст

---

**Требуется:** Ollama установлен (см. OLLAMA-PROXMOX-COMPLETE-GUIDE.md)  
**Модель:** phi3:mini (2.3GB, GTX 1050 Ti 4GB)  
**Workflow:** 11 nodes  
**Производительность:** 2-4 сек на ответ с памятью

