# Персональный ассистент с памятью (Ollama + Home Assistant)

Образовательный пример AI агента с памятью диалога на базе архитектуры n8n Voice Assistant.  
**Использует только официальные n8n интеграции.**

---

## Архитектура

```text
Telegram → Agent (Memory + Ollama) → HA Tools → Telegram

11 nodes (все официальные n8n):
- Telegram Trigger (официальный)
- Home Assistant node (официальный n8n-nodes-base.homeAssistant)
- Ollama Chat Model (официальный @n8n/n8n-nodes-langchain.lmChatOllama)
- Memory Buffer (официальный @n8n/n8n-nodes-langchain.memoryBufferWindow)
- Langchain Agent (официальный @n8n/n8n-nodes-langchain.agent)
- Tool Workflow (официальный @n8n/n8n-nodes-langchain.toolWorkflow)
```

---

## Требования

1. **Ollama VM** - установлен по [OLLAMA-PROXMOX-COMPLETE-GUIDE.md](./OLLAMA-PROXMOX-COMPLETE-GUIDE.md)
2. **Модель phi3:mini** загружена
3. **n8n** с установленными @n8n/n8n-nodes-langchain пакетами
4. **Home Assistant** с API доступом
5. **Telegram Bot** (персональный)

---

## Установка

### Шаг 1: Импорт главного workflow

```text
n8n → Workflows → Import from File
→ n8n-personal-assistant-ollama.json
```

### Шаг 2: Настройка credentials

**Telegram Bot:**
```text
n8n → Credentials → Add → Telegram API
Access Token: (от @BotFather)
```

**Home Assistant:**
```text
n8n → Credentials → Add → Home Assistant
Host: http://HA_IP:8123
Access Token: (Long-Lived Token из HA)
```

### Шаг 3: Замена параметров в главном workflow

**Node "Ollama Model":**
- Base URL: `http://OLLAMA_VM_IP:11434`
- Model: `phi3:mini`

**Node "HA Get All States":**
- Credential: выберите Home Assistant

**Все Telegram nodes:**
- User ID: ваш Telegram ID
- Credential: выберите Telegram Bot

### Шаг 4: Создание Tool sub-workflows

Создайте 2 отдельных workflow для инструментов Agent.

#### Tool 1: Get Sensor Value

**Создайте новый workflow:** "Tool: Get Sensor Value"

**Nodes:**

1. **Start Node** (автоматически создается)

2. **Home Assistant** node:
   - Resource: `State`
   - Operation: `Get`
   - Entity ID: `={{ $json.entity_id }}`
   - Credential: Home Assistant

3. **Code** node (форматирование ответа):
```javascript
const state = $input.item.json;
const value = state.state;
const unit = state.attributes.unit_of_measurement || '';
const name = state.attributes.friendly_name || state.entity_id;

return [{
  json: {
    result: `${name}: ${value}${unit}`
  }
}];
```

**Сохраните workflow**, скопируйте его ID из URL.

В главном workflow:
- Node "Tool Get Sensor" → `workflowId`: вставьте скопированный ID

#### Tool 2: List Devices

**Создайте новый workflow:** "Tool: List Devices"

**Nodes:**

1. **Start Node**

2. **Home Assistant** node:
   - Resource: `State`
   - Operation: `Get All`
   - Credential: Home Assistant

3. **Code** node (фильтрация по domain):
```javascript
const domain = $json.domain || 'sensor';
const allStates = $input.all();

const filtered = allStates.filter(item => {
  const entityId = item.json.entity_id;
  return entityId.startsWith(domain + '.');
});

const devices = filtered.map(item => ({
  entity_id: item.json.entity_id,
  name: item.json.attributes.friendly_name || item.json.entity_id,
  state: item.json.state
}));

return [{
  json: {
    domain: domain,
    count: devices.length,
    devices: devices
  }
}];
```

**Сохраните workflow**, скопируйте ID.

В главном workflow:
- Node "Tool List Devices" → `workflowId`: вставьте ID

### Шаг 5: Активация

1. Сохраните главный workflow
2. Активируйте (toggle справа вверху)
3. Telegram → ваш бот → `/start`

---

## Примеры с Memory

```text
Вы: Какая температура в гостиной?
Бот: Температура в гостиной: 22.5°C

Вы: А в спальне?
Бот: В спальне 21°C

(Бот помнит что речь о температуре!)

Вы: Какие датчики движения сработали?
Бот: Движение обнаружено:
     • Коридор - 2 минуты назад
     • Кухня - активно сейчас

Вы: А датчики дверей?
Бот: Все двери закрыты

(Бот помнит что речь о датчиках!)

Вы: /clear
Бот: 🗑️ Память очищена

Вы: А в спальне?
Бот: Уточните пожалуйста - что вы хотите узнать о спальне?

(Память очищена, контекст потерян)
```

---

## Как работает Memory

**Memory Buffer Window node:**
- Хранит последние 10 сообщений (пары user-assistant)
- Session key = `chat_id` (каждый пользователь свою историю)
- Автоматически передается в Agent как контекст
- `/clear` очищает память для этого chat_id

**Официальный n8n Langchain node** - работает из коробки, без ручного кода!

---

## Используемые официальные nodes

| Node | Type | Назначение |
|------|------|------------|
| Telegram Trigger | `n8n-nodes-base.telegramTrigger` | Прием сообщений |
| Home Assistant | `n8n-nodes-base.homeAssistant` | HA операции |
| Ollama Chat Model | `@n8n/n8n-nodes-langchain.lmChatOllama` | LLM |
| Memory Buffer | `@n8n/n8n-nodes-langchain.memoryBufferWindow` | Память |
| Agent | `@n8n/n8n-nodes-langchain.agent` | Агент |
| Tool Workflow | `@n8n/n8n-nodes-langchain.toolWorkflow` | Инструменты |
| Code | `n8n-nodes-base.code` | Логика |
| If | `n8n-nodes-base.if` | Условия |
| Set | `n8n-nodes-base.set` | Данные |

**Никаких сторонних плагинов - все из официальной поставки n8n!**

---

**Требует:** Ollama установлен по инструкции OLLAMA-PROXMOX-COMPLETE-GUIDE.md  
**Модель:** phi3:mini (2.3GB для GTX 1050 Ti 4GB)  
**Nodes:** 11 (все официальные)  
**Производительность:** 2-4 сек на ответ с памятью
