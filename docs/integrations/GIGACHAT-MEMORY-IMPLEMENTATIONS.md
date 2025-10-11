# GigaChat с Memory - Варианты реализации

Технические варианты реализации памяти диалога (Memory) для GigaChat в n8n.

---

## Проблема

n8n Langchain не имеет нативного GigaChat Chat Model node.  
Стандартные LLM nodes в n8n:
- OpenAI
- Anthropic
- Google (Gemini)
- Ollama
- Groq
- HuggingFace

GigaChat отсутствует в списке.

---

## Решение 1: DeepSeek (рекомендуется для образовательного примера)

**DeepSeek** - OpenAI-compatible API с хорошей поддержкой русского языка.

### Проверка доступности из РФ

```bash
curl -I https://api.deepseek.com
# Если 200 OK - работает
```

### Регистрация

1. [platform.deepseek.com](https://platform.deepseek.com) (может требовать VPN для регистрации)
2. Sign Up
3. API Keys → Create new key
4. Скопируйте: `sk-deepseek-xxx...`

### Использование в n8n

**Node type:** `@n8n/n8n-nodes-langchain.lmChatOpenAi`

**Параметры:**
- Custom API Base: `https://api.deepseek.com/v1`
- API Key: `sk-deepseek-xxx...`
- Model: `deepseek-chat`

**С этим node работает:**
- ✅ Memory Buffer Window (из коробки)
- ✅ Langchain Agent (из коробки)
- ✅ Conversation context

### Пример workflow node:

```json
{
  "parameters": {
    "model": "deepseek-chat",
    "options": {
      "baseURL": "https://api.deepseek.com/v1",
      "temperature": 0.7,
      "maxTokens": 500
    }
  },
  "name": "DeepSeek: Chat Model",
  "type": "@n8n/n8n-nodes-langchain.lmChatOpenAi",
  "typeVersion": 1.2,
  "credentials": {
    "openAiApi": {
      "id": "YOUR_DEEPSEEK_CREDENTIAL",
      "name": "DeepSeek API"
    }
  }
}
```

**Преимущества:**
- ✅ OpenAI-compatible = работает с n8n Langchain
- ✅ Memory Buffer Window из коробки
- ✅ Хорошее качество русского языка
- ✅ Бесплатная квота (проверить актуальность)

**Недостатки:**
- ⚠️ Может требовать VPN для регистрации
- ⚠️ Неизвестна доступность API из РФ (нужно тестировать)

---

## Решение 2: Ручная реализация Memory для GigaChat

Если DeepSeek недоступен, реализуем Memory вручную через n8n Code nodes.

### Архитектура

```text
Telegram → Store Message → Get History (10 msg) → Build Prompt → GigaChat API → Store Response → Telegram
```

### Хранилище истории

**Опции:**

**A. n8n Workflow Static Data**
```javascript
// В Code node
const chatId = $input.item.json.chat_id;
const staticData = getWorkflowStaticData('global');

if (!staticData.conversations) {
  staticData.conversations = {};
}

if (!staticData.conversations[chatId]) {
  staticData.conversations[chatId] = [];
}

// Добавить сообщение
staticData.conversations[chatId].push({
  role: 'user',
  content: text,
  timestamp: Date.now()
});

// Оставить только последние 10
if (staticData.conversations[chatId].length > 10) {
  staticData.conversations[chatId] = staticData.conversations[chatId].slice(-10);
}
```

**B. External Storage (Redis, PostgreSQL)**
- Более надежно для production
- Требует дополнительную инфраструктуру

### Пример Code node для Memory management

```javascript
// Node: Store and Retrieve Conversation History

const chatId = $input.item.json.chat_id;
const userMessage = $input.item.json.text;
const staticData = getWorkflowStaticData('global');

// Инициализация хранилища
if (!staticData.conversations) {
  staticData.conversations = {};
}

if (!staticData.conversations[chatId]) {
  staticData.conversations[chatId] = {
    messages: [],
    created: Date.now()
  };
}

// Добавление нового сообщения пользователя
staticData.conversations[chatId].messages.push({
  role: 'user',
  content: userMessage,
  timestamp: Date.now()
});

// Ограничение до 10 последних сообщений (20 с учетом assistant ответов)
const maxMessages = 20; // 10 пар user-assistant
if (staticData.conversations[chatId].messages.length > maxMessages) {
  staticData.conversations[chatId].messages = 
    staticData.conversations[chatId].messages.slice(-maxMessages);
}

// Получение истории для контекста
const history = staticData.conversations[chatId].messages;

return [{
  json: {
    chat_id: chatId,
    current_message: userMessage,
    conversation_history: history,
    history_length: history.length
  }
}];
```

### Команда /clear для очистки истории

```javascript
// Очистка истории для chat_id
const chatId = $input.item.json.chat_id;
const staticData = getWorkflowStaticData('global');

if (staticData.conversations && staticData.conversations[chatId]) {
  delete staticData.conversations[chatId];
}

return [{ json: { chat_id: chatId, cleared: true } }];
```

---

## Решение 3: Ollama (идеальное, но требует setup)

После настройки GPU passthrough (OLLAMA-PROXMOX-COMPLETE-GUIDE.md):

### Workflow node

```json
{
  "parameters": {
    "model": "phi3:mini",
    "options": {
      "baseURL": "http://OLLAMA_VM_IP:11434",
      "temperature": 0.7,
      "maxTokens": 500
    }
  },
  "name": "Ollama: Chat Model",
  "type": "@n8n/n8n-nodes-langchain.lmChatOllama",
  "typeVersion": 1
}
```

**Memory Buffer Window:**

```json
{
  "parameters": {
    "sessionIdType": "customKey",
    "sessionKey": "={{ $('Telegram: Trigger').first().json.message.chat.id }}",
    "contextWindowLength": 10
  },
  "name": "Memory",
  "type": "@n8n/n8n-nodes-langchain.memoryBufferWindow",
  "typeVersion": 1.3
}
```

**Преимущества:**
- ✅ Нативная поддержка в n8n Langchain
- ✅ Memory работает из коробки
- ✅ Полная приватность (локально)
- ✅ Работает БЕЗ интернета

---

## Сравнение решений

| Решение | Сложность | Memory | Качество RU | Доступность РФ | Стоимость |
|---------|-----------|--------|-------------|----------------|-----------|
| **DeepSeek** | Низкая | ✅ Авто | ⭐⭐⭐⭐ | ❓ Проверить | ✅ Бесплатно |
| **GigaChat ручной** | Средняя | 🔧 Ручная | ⭐⭐⭐⭐⭐ | ✅ Да | ✅ Бесплатно |
| **Ollama** | Средняя | ✅ Авто | ⭐⭐⭐⭐ | ✅ Да | ✅ Бесплатно |

---

## Рекомендация

**Для образовательного примера Memory + Agent:**

1. **Попробуйте DeepSeek** (если доступен из РФ)
   - Самый простой вариант
   - OpenAI-compatible = работает с Langchain
   - Memory из коробки

2. **Если DeepSeek недоступен:** Создам полный пример ручной Memory для GigaChat
   - Образовательно полезно понять как работает Memory
   - Полный контроль над логикой

3. **Или подождите Ollama**
   - После GPU setup будет работать идеально
   - 100% как в примере n8n Voice Assistant

---

**Автор:** AI Assistant (Langchain Expert)  
**Дата:** Октябрь 2025

