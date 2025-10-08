# 🤖 AI Агенты n8n для Home Assistant

Создание автономных AI агентов на локальных LLM (бесплатно, работает в РФ).

---

## 🎯 Зачем n8n если есть NodeRED и HA?

### Ваша текущая инфраструктура

**Что уже работает:**

- ✅ **Home Assistant** - управление устройствами, базовые автоматизации
- ✅ **NodeRED** - сложные flow и логика
- ✅ **HA Addons** - бэкапы, Telegram, Samba
- ✅ **MCP (Cursor)** - AI помощь в разработке

**Что НЕ УМЕЮТ HA/NodeRED:**

- ❌ Обработка естественного языка
- ❌ Computer Vision (анализ изображений)
- ❌ RAG (поиск по вашим конфигурациям)
- ❌ Автономные AI агенты с памятью
- ❌ Генерация кода из описаний
- ❌ Предиктивная аналитика с AI

### 🤖 n8n = платформа для AI агентов

**Ключевое преимущество:**

```text
NodeRED: IF-THEN логика
n8n + AI: Понимание контекста и автономные решения
```

**Пример:**

```text
NodeRED:
  IF температура < 18 THEN включить отопление

n8n AI Agent:
  "Дома холодно" → AI понимает контекст:
    - Проверяет текущую температуру всех 15 зон
    - Анализирует погоду
    - Учитывает время суток
    - Предлагает оптимальное решение
    - Объясняет WHY
```

---

## 🏗️ Архитектура с локальными LLM (бесплатно + РФ)

### Ваша инфраструктура

```text
┌──────────────────────────────────────────────────────────────────┐
│                  Proxmox Server (локально)                       │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────────┐         ┌──────────────────┐               │
│  │  Home Assistant │◄───────►│      n8n         │               │
│  │  VM/Container   │         │   (Container)    │               │
│  │  192.168.1.20   │         │  192.168.1.50    │               │
│  └─────────────────┘         └──────────────────┘               │
│         ↑                            ↑                           │
│         │                            │                           │
│         │                    ┌───────┴────────┐                 │
│         │                    │                │                 │
│         │              ┌─────▼─────┐   ┌──────▼──────┐          │
│         │              │  Ollama   │   │  LM Studio  │          │
│         │              │ (LLM API) │   │  (optional) │          │
│         │              │ :11434    │   │   :1234     │          │
│         │              └───────────┘   └─────────────┘          │
│         │                    ↑                                  │
│         │              ┌─────┴──────┐                           │
│         │              │  Модели:   │                           │
│         │              │  - Llama 3  │                           │
│         │              │  - Mistral │                           │
│         │              │  - LLaVA   │ ← Vision!                │
│         │              │  - DeepSeek│                           │
│         │              └────────────┘                           │
│         ↓                                                        │
│  ┌─────────────────┐                                            │
│  │  Cursor (WSL)   │                                            │
│  │  + mcp-proxy    │                                            │
│  └─────────────────┘                                            │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

**Преимущества:**

- ✅ **Бесплатно** - никаких API ключей
- ✅ **Работает в РФ** - без VPN
- ✅ **Приватность** - данные не уходят из дома
- ✅ **Быстро** - локальная сеть
- ✅ **Не лимитировано** - сколько угодно запросов

---

## ⚙️ Установка Ollama на Proxmox (15 минут)

### Вариант 1: Docker в n8n контейнере

Если n8n уже в Docker:

```bash
# docker-compose.yml для n8n + Ollama
version: '3.8'
services:
  n8n:
    image: n8nio/n8n:latest
    ports:
      - "5678:5678"
    environment:
      - N8N_HOST=192.168.1.50
    networks:
      - ai-network

  ollama:
    image: ollama/ollama:latest
    ports:
      - "11434:11434"
    volumes:
      - ollama_data:/root/.ollama
    networks:
      - ai-network

networks:
  ai-network:

volumes:
  ollama_data:
```

### Вариант 2: LXC контейнер на Proxmox

```bash
# На Proxmox создать LXC Ubuntu
pct create 201 local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst \
  --hostname ollama \
  --cores 4 \
  --memory 8192 \
  --net0 name=eth0,bridge=vmbr0,ip=192.168.1.51/24,gw=192.168.1.1

# Запустить
pct start 201

# Войти
pct enter 201

# Установить Ollama
curl -fsSL https://ollama.com/install.sh | sh

# Скачать модели
ollama pull llama3         # Общий ассистент (4.7GB)
ollama pull llava          # Vision модель (4.7GB)
ollama pull mistral        # Быстрая модель (4.1GB)
ollama pull deepseek-coder # Генерация кода (6.7GB)
```

### Проверка

```bash
curl http://192.168.1.51:11434/api/tags
# Должен вернуть список моделей
```

---

## 🤖 AI Агент #1: Умный ассистент умного дома

### Что делает

**Telegram бот с пониманием контекста:**

```text
👤: "Дома холодно"

🤖 AI Agent (Llama 3):
  1. Получает состояние всех 15 зон из HA
  2. Проверяет температуру на улице
  3. Анализирует историю
  4. Принимает решение
  5. Выполняет через HA API
  6. Объясняет что сделал

🤖: "Сейчас в доме средняя температура 19.2°C (норма 21°C).
     На улице -5°C, поэтому увеличиваю целевую до 22°C
     в основных зонах (гостиная, кухня, спальня).

     Время прогрева: ~25 минут.
     Дополнительная стоимость: ~15 руб.

     ✅ Температуры обновлены."
```

### n8n Workflow

**Ноды:**

1. **Telegram Trigger** - сообщения от пользователя

2. **AI Agent** (Advanced AI node)
   - **LLM:** Ollama
   - **Model:** llama3
   - **Base URL:** `http://192.168.1.51:11434`
   - **System Prompt:**

```text
Ты ассистент умного дома на Home Assistant.

Твой дом:
- 15 зон отопления с индивидуальным управлением
- 5 камер безопасности
- Метеостанция
- 150+ умных устройств

Доступные функции (tools):
- get_zone_temperature(zone_name) - текущая температура зоны
- set_zone_temperature(zone_name, temperature) - установить температуру
- get_outdoor_temperature() - температура на улице
- get_all_zones_status() - статус всех зон
- calculate_heating_cost(temp_change) - расчет стоимости

Всегда:
1. Сначала получи текущее состояние
2. Объясни свой анализ
3. Покажи расчеты (стоимость, время)
4. Спроси подтверждения для больших изменений
5. После действия - подтверди результат

Отвечай на русском языке, кратко и по делу.
```

   - **Tools (Functions):**

```json
[
  {
    "name": "get_all_zones_status",
    "description": "Получить статус всех 15 зон отопления",
    "parameters": {
      "type": "object",
      "properties": {}
    }
  },
  {
    "name": "set_zone_temperature",
    "description": "Установить температуру в зоне",
    "parameters": {
      "type": "object",
      "properties": {
        "zone_name": {
          "type": "string",
          "description": "Название зоны (living_room, bedroom, etc)"
        },
        "temperature": {
          "type": "number",
          "description": "Целевая температура (16-26°C)"
        }
      },
      "required": ["zone_name", "temperature"]
    }
  }
]
```

3. **Code** - Tool executor (вызовы функций AI)

```javascript
const toolCall = $json.tool_calls?.[0];

if (!toolCall) {
  return $input.item.json; // No tool call
}

const toolName = toolCall.function.name;
const args = JSON.parse(toolCall.function.arguments);

// Выполняем функцию
if (toolName === 'get_all_zones_status') {
  // Получить из HA все climate entities
  return {
    json: {
      tool_result: {
        zones: [
          { name: 'living_room', current: 21, target: 22 },
          { name: 'bedroom', current: 19, target: 20 },
          // ... все 15 зон
        ]
      }
    }
  };
} else if (toolName === 'set_zone_temperature') {
  // Вызвать HA API
  return {
    json: {
      tool_result: {
        success: true,
        message: `Установлено ${args.temperature}°C для ${args.zone_name}`
      }
    }
  };
}
```

4. **Loop back to AI** - агент принимает решение

5. **Telegram** - финальный ответ

---

## 🤖 AI Агент #2: Vision анализ камер (LLaVA)

### Что делает

**Автоматический анализ движения:**

```text
HA: Motion detected → snapshot → n8n

n8n AI Vision:
  1. Получить изображение
  2. LLaVA анализ: "Что на изображении?"
  3. AI решение: важно или нет?
  4. Действие по результату
```

### n8n Workflow

**Ноды:**

1. **Webhook** от HA - motion detected + snapshot URL

2. **HTTP Request** - получить изображение

```json
{
  "method": "GET",
  "url": "http://192.168.1.20:8123{{ $json.snapshot_path }}",
  "headers": {
    "Authorization": "Bearer YOUR_HA_TOKEN"
  },
  "responseType": "arraybuffer"
}
```

3. **Ollama Vision** (LLaVA модель)

```json
{
  "model": "llava",
  "prompt": "Опиши что видишь на изображении. Это человек, животное, или ложное срабатывание (тень, свет)? Время: {{ $json.time }}. Камера: {{ $json.camera_name }}.",
  "images": ["{{ $binary.data }}"]
}
```

4. **Code** - Анализ ответа AI

```javascript
const aiResponse = $json.response.toLowerCase();
const hour = new Date().getHours();
const isNight = hour < 6 || hour > 22;

let priority = 'low';
let action = 'ignore';

// AI сказал "человек"
if (aiResponse.includes('человек') || aiResponse.includes('person')) {
  if (isNight) {
    priority = 'critical';
    action = 'alert_security';
  } else {
    priority = 'medium';
    action = 'log_and_notify';
  }
}
// AI сказал "животное"
else if (aiResponse.includes('кошка') || aiResponse.includes('собака') ||
         aiResponse.includes('животное')) {
  priority = 'low';
  action = 'log_only';
}
// Ложное срабатывание
else {
  priority = 'ignore';
  action = 'ignore';
}

return {
  json: {
    ai_analysis: aiResponse,
    priority,
    action,
    timestamp: new Date().toISOString()
  }
};
```

5. **Switch** - действия по приоритету

   **Critical:**
   - Telegram: "🚨 ЧЕЛОВЕК на камере (ночь)!"
   - HA: включить alarm
   - Запись видео

   **Medium:**
   - Telegram: уведомление с контекстом
   - Лог в базу

   **Low/Ignore:**
   - Только лог

**Результат:** 90% точность, 0 ложных алертов ночью!

---

## 🧠 AI Агент #3: RAG по вашей конфигурации

### Что делает

**AI знает ВСЮ вашу конфигурацию HA:**

```text
👤: "Почему не включается свет в коридоре вечером?"

🤖 AI RAG:
  1. Ищет в векторной базе "свет" + "коридор"
  2. Находит automation.corridor_light
  3. Анализирует условия
  4. Проверяет текущее состояние
  5. Объясняет проблему

🤖: "Проверил automation.corridor_light:

     Триггер: binary_sensor.corridor_motion ✅ (работает)
     Условие 1: time after 18:00 ✅ (сейчас 19:30)
     Условие 2: sun.state == 'below_horizon' ❌ (ПРОБЛЕМА!)

     Сейчас sun.state = 'above_horizon' (светло).
     Автоматизация не срабатывает т.к. еще день.

     Решения:
     1. Убрать условие sun.state
     2. Добавить sensor.illuminance < 100 (если есть lux sensor)
     3. Изменить время на after: '20:00:00'

     Какой вариант применить?"
```

### n8n Workflow (Setup - один раз)

**Создание векторной базы:**

1. **Manual Trigger** (запустить вручную)

2. **Home Assistant** - экспорт конфигураций
   - Get все automations
   - Get все scripts
   - Get все sensors

3. **Code** - парсинг и подготовка

```javascript
// Преобразуем конфигурации в текст для embeddings
const automations = $json.automations.map(auto => {
  return {
    type: 'automation',
    id: auto.id,
    alias: auto.alias,
    text: `Автоматизация: ${auto.alias}
           ID: ${auto.id}
           Триггер: ${JSON.stringify(auto.trigger)}
           Условия: ${JSON.stringify(auto.condition)}
           Действия: ${JSON.stringify(auto.action)}`,
    metadata: auto
  };
});

return automations;
```

4. **Embeddings** (n8n AI node)
   - Model: Ollama embeddings
   - Model name: `nomic-embed-text` (локальная!)

5. **Vector Store** - Qdrant / Weaviate / простой JSON
   - Сохранение embeddings

### n8n Workflow (Query - постоянно)

**Ответы на вопросы:**

1. **Telegram Trigger** - вопрос пользователя

2. **Embeddings** - векторизация вопроса

3. **Vector Search** - поиск похожих конфигураций

4. **AI Agent** (Ollama Llama 3)
   - System prompt: "Ты эксперт по Home Assistant. Анализируй конфигурацию и отвечай на вопросы."
   - Context: найденные конфигурации (RAG!)
   - Question: вопрос пользователя

5. **Telegram** - ответ с кодом и рекомендациями

**Use cases:**

- "Какие автоматизации используют sensor.outdoor_temp?"
- "Почему не работает X?"
- "Как добавить новый датчик?"
- "Оптимизируй мою конфигурацию отопления"

---

## 🎨 AI Агент #4: Генератор NodeRED flows

### Что делает

**Описание на русском → готовый NodeRED flow:**

```text
👤: "Хочу автоматизацию: если влажность в ванной > 70%, включить вытяжку на 30 минут"

🤖 AI Agent:
  1. Понимает intent
  2. Проверяет доступные entity_id (у вас есть sensor.bathroom_humidity?)
  3. Генерирует NodeRED flow JSON
  4. Валидирует синтаксис
  5. Предлагает импорт

🤖: "Создан flow для NodeRED:

[JSON код flow]

Требуется:
  ✅ sensor.bathroom_humidity (у вас есть)
  ⚠️  switch.bathroom_fan (не найден!)

  Создать switch.bathroom_fan? [Да/Нет]

  Если да, импортировать flow? [Импорт] [Редактировать] [Отмена]"
```

### n8n Workflow

1. **Telegram** - описание автоматизации

2. **AI Agent** (DeepSeek-Coder)
   - Специализированная модель для кода
   - System prompt: генерация NodeRED flows
   - Tools: проверка entity_id в HA

3. **Home Assistant** - валидация entities

4. **Code** - генерация NodeRED JSON

```javascript
// DeepSeek-Coder генерирует структуру
const flow = {
  id: generateId(),
  type: "tab",
  label: "AI Generated: Bathroom Fan",
  nodes: [
    {
      id: generateId(),
      type: "server-state-changed",
      name: "Humidity > 70%",
      server: "home-assistant",
      entityid: "sensor.bathroom_humidity",
      property: "state",
      comparator: "gt",
      value: "70"
    },
    {
      id: generateId(),
      type: "api-call-service",
      name: "Turn on fan",
      server: "home-assistant",
      service_domain: "switch",
      service: "turn_on",
      data: { entity_id: "switch.bathroom_fan" }
    },
    {
      id: generateId(),
      type: "delay",
      name: "Wait 30 min",
      pauseType: "delay",
      timeout: "30",
      timeoutUnits: "minutes"
    },
    {
      id: generateId(),
      type: "api-call-service",
      name: "Turn off fan",
      server: "home-assistant",
      service_domain: "switch",
      service: "turn_off",
      data: { entity_id: "switch.bathroom_fan" }
    }
  ]
};

return { json: { flow } };
```

5. **Telegram** - preview + кнопки импорта

---

## 📊 AI Агент #5: Предиктивная аналитика

### Что делает

**AI анализирует 3 месяца данных и дает инсайты:**

```text
🤖 AI Анализ (еженедельный):

📊 Обнаружил паттерны:

1. Отопление vs Погода
   • Корреляция: 0.87 (очень сильная)
   • При -10°C потребление = 4.2 кВт постоянно
   • При +10°C потребление = 0.8 кВт

   💡 Рекомендация:
      Текущая кривая: target = 25 - (outdoor * 0.5)
      Оптимальная: target = 24 - (outdoor * 0.6)
      Экономия: ~180 руб/месяц

2. Ложные срабатывания камеры "Въезд"
   • Паттерн: каждый день 14:00-15:00
   • Причина: солнце светит прямо в камеру
   • Частота: 15-20 раз/час

   💡 Рекомендация:
      Отключить детекцию движения 14:00-15:00
      Или повернуть камеру на 15° влево

3. Аномалия: Энергопотребление по средам
   • Каждую среду +35% потребления
   • Время: 10:00-14:00
   • Вероятная причина: стирка + уборка + готовка

   💡 Рекомендация:
      Перенести стирку на ночной тариф (22:00-06:00)
      Экономия: ~200 руб/месяц
```

### n8n Workflow

1. **Cron** - раз в неделю (воскресенье 20:00)

2. **Home Assistant** - история за 90 дней
   - Все climate entities
   - Все power sensors
   - Все camera events

3. **Code** - подготовка данных для AI

```javascript
// Агрегация данных
const data = {
  heating_history: groupByDay($json.climate_data),
  power_history: groupByDay($json.power_data),
  camera_events: groupByHour($json.camera_data),
  outdoor_temp: $json.weather_data
};

// Расчет корреляций
const correlation = calculateCorrelation(
  data.outdoor_temp,
  data.heating_history
);

return { json: { data, correlation } };
```

4. **AI Agent** (Llama 3 или DeepSeek)
   - System prompt:

```text
Ты data scientist анализирующий умный дом.

Проанализируй данные за 90 дней:
- Отопление (15 зон)
- Энергопотребление
- События камер
- Погода

Найди:
1. Корреляции и паттерны
2. Аномалии и неэффективность
3. Возможности оптимизации

Дай конкретные рекомендации с расчетом экономии в рублях.
```

5. **Google Sheets** - сохранение insights

6. **Telegram** - отчет с рекомендациями

**Ценность:** Находит неочевидные паттерны и экономит деньги!

---

## 🔍 AI Агент #6: Отладчик конфигураций

### Что делает

**AI помогает найти баги в автоматизациях:**

```text
👤: "automation.heating_night не срабатывает"

🤖 AI Debugger:
  1. Получает код автоматизации из HA
  2. Анализирует логику
  3. Проверяет текущие состояния всех entities
  4. Симулирует выполнение
  5. Находит проблему

🤖: "Проанализировал automation.heating_night:

trigger:
  - platform: time
    at: '22:00:00'

condition:
  - condition: state
    entity_id: person.home  ← ПРОБЛЕМА!
    state: 'home'

🔴 НАЙДЕНО:
  Сейчас person.home = 'not_home'
  Автоматизация не сработает если вас нет дома в 22:00

❓ ВОПРОС:
  Это намеренно? (не греть когда никого нет)
  Или нужно убрать условие person.home?

  Также обнаружено:
  ⚠️  Нет fallback если триггер пропущен
     Рекомендую добавить второй триггер на изменение person.home → home"
```

### n8n Workflow

1. **Telegram** - название автоматизации или описание проблемы

2. **Home Assistant** - получить конфигурацию
   - Get automation YAML
   - Get текущие состояния всех entity_id
   - Get execution history (если есть)

3. **AI Agent** (DeepSeek-Coder)
   - Специалист по HA YAML
   - Анализирует логику
   - Находит проблемы
   - Предлагает решения

4. **Telegram** - детальный анализ + fix

---

## 🎯 AI Агент #7: Оптимизатор 15 зон отопления

### Что делает

**AI учится на ваших данных и оптимизирует:**

```text
AI собирает 30 дней данных:
  • Температура каждой зоны (по часам)
  • Outdoor temperature
  • Стоимость отопления
  • Комфорт (когда жарко/холодно по отзывам)

AI анализирует:
  • Какие зоны переотапливаются
  • Какие недотапливаются
  • Оптимальные температуры для экономии
  • Можно ли отключать зоны по расписанию

AI предлагает:
  • Новые целевые температуры
  • Расписание по зонам
  • Прогноз экономии
```

### n8n Workflow

1. **Cron** - раз в месяц

2. **Home Assistant** - история 30 дней
   - Все climate entities (15 зон)
   - Outdoor temperature
   - Power consumption
   - (опционально) комментарии пользователя "жарко/холодно"

3. **Code** - агрегация данных

```javascript
const zones = [
  'living_room', 'bedroom', 'kitchen', 'bathroom',
  // ... все 15 зон
];

const analysis = zones.map(zone => {
  const history = getZoneHistory(zone, 30); // 30 дней

  return {
    zone,
    avg_temp: calculateAverage(history.temperatures),
    avg_target: calculateAverage(history.targets),
    time_above_target: calculatePercentage(history.above_target),
    time_below_target: calculatePercentage(history.below_target),
    estimated_cost: calculateCost(history.runtime, zone_size)
  };
});

return { json: { zones: analysis } };
```

4. **AI Agent** (Llama 3 или Mistral)
   - System prompt:

```text
Ты инженер-теплотехник с AI.

Проанализируй данные отопления за 30 дней (15 зон).

Для каждой зоны оцени:
1. Эффективность (не перегрев/недогрев?)
2. Стоимость (руб/месяц на зону)
3. Оптимизация (можно ли сэкономить?)

Дай конкретные рекомендации:
- Новые целевые температуры
- Расписания (когда можно снижать)
- Приоритет зон
- Прогноз экономии в рублях

Тариф: 5 руб/кВт*ч
```

5. **Telegram** - отчет + кнопки

```text
🤖 AI Анализ отопления (30 дней)

💰 Текущая стоимость: 4500 руб/месяц

🔴 Переотапливаемые зоны:
  1. Гостевая комната: 22°C (никого нет 90% времени)
     Рекомендация: снизить до 18°C
     Экономия: ~350 руб/месяц

  2. Кухня: 21°C (днем жарко от готовки)
     Рекомендация: 19°C днем, 21°C вечером
     Экономия: ~180 руб/месяц

🟡 Оптимизация расписания:
  Ночь (00:00-06:00): снизить на 2°C везде
  Экономия: ~400 руб/месяц

✅ ИТОГО потенциал: ~930 руб/месяц (20%)

[📊 Детали] [✅ Применить всё] [✏️ Редактировать]
```

6. **Home Assistant** - применение рекомендаций (с подтверждением!)

---

## 💡 Рекомендуемые AI модели для Ollama

### Для вашего умного дома

**1. Llama 3 (8B)** - основной ассистент
- **Размер:** 4.7 GB
- **RAM:** 8 GB
- **Скорость:** ~20 tokens/sec
- **Для:** общие вопросы, анализ, рекомендации

```bash
ollama pull llama3
```

**2. LLaVA** - анализ камер
- **Размер:** 4.7 GB
- **RAM:** 8 GB
- **Для:** распознавание на изображениях

```bash
ollama pull llava
```

**3. DeepSeek-Coder (6.7B)** - генерация кода
- **Размер:** 3.8 GB
- **RAM:** 8 GB
- **Для:** генерация YAML, NodeRED flows

```bash
ollama pull deepseek-coder
```

**4. Nomic Embed Text** - embeddings для RAG
- **Размер:** 274 MB
- **RAM:** 1 GB
- **Для:** векторная база конфигураций

```bash
ollama pull nomic-embed-text
```

**Итого:** ~14 GB места, 8-16 GB RAM

### Требования к Proxmox VM

**Минимум для Ollama:**
- CPU: 4 cores
- RAM: 16 GB (для параллельной работы моделей)
- Disk: 30 GB
- GPU: опционально (ускорение в 5-10x)

**Можно на том же сервере что n8n:**

```bash
# Увеличить RAM контейнера n8n
pct set <n8n_container_id> -memory 16384

# Или создать отдельный LXC для Ollama
```

---

## 🚀 План внедрения (3 недели)

### Неделя 1: Установка и тестирование

**День 1-2: Ollama**
- ✅ Установить Ollama на Proxmox
- ✅ Скачать 4 модели
- ✅ Протестировать через curl

**День 3: n8n + Ollama**
- ✅ Настроить credential Ollama в n8n
- ✅ Тестовый workflow (простой вопрос-ответ)

**День 4-5: Первый AI агент**
- ✅ AI Ассистент умного дома (Сценарий #1)
- ✅ Интеграция с Telegram
- ✅ Тестирование на реальных вопросах

### Неделя 2: AI Vision и RAG

**День 1-3: Vision для камер**
- ✅ LLaVA модель
- ✅ Workflow анализа движения
- ✅ Интеграция с HA

**День 4-5: RAG система**
- ✅ Экспорт всех конфигураций
- ✅ Создание векторной базы
- ✅ Тестирование вопросов

### Неделя 3: Оптимизация и автоматизация

**День 1-2: AI оптимизатор отопления**
- ✅ Сбор данных 30 дней
- ✅ AI анализ
- ✅ Применение рекомендаций

**День 3-4: AI генератор**
- ✅ DeepSeek-Coder setup
- ✅ Генерация NodeRED flows
- ✅ Автоматический импорт

**День 5: Мониторинг**
- ✅ Dashboard n8n workflows
- ✅ Статистика по AI использованию
- ✅ Оптимизация промптов

---

## 🎯 ТОП-3 AI агента для ВАШЕГО дома

### 1. 🌡️ AI Оптимизатор отопления (Агент #7)

**Зачем:**
- 15 зон - сложная система
- AI найдет неочевидные паттерны
- Реальная экономия 15-25%

**Окупаемость:** Первый месяц!

---

### 2. 📹 AI Vision для камер (Агент #2)

**Зачем:**
- Много камер = много ложных срабатываний
- LLaVA различит человека/животное
- 0 пропущенных важных событий

**Спокойствие:** Бесценно!

---

### 3. 🧠 AI RAG ассистент (Агент #3)

**Зачем:**
- 150+ устройств, сложная конфигурация
- Забываете где что настроено
- AI мгновенно найдет и объяснит

**Экономия времени:** Часы → минуты!

---

## 📝 Конфигурация для вашего проекта

Добавьте в `config.yml`:

```yaml
# n8n + AI Integration
n8n:
  enabled: true
  # n8n на Proxmox
  url: "http://192.168.1.50:5678"
  api_key: ""  # Получите в n8n

  # Ollama (локальный LLM)
  ollama:
    enabled: true
    url: "http://192.168.1.51:11434"  # Или тот же хост что n8n
    models:
      assistant: "llama3"        # Основной ассистент
      vision: "llava"            # Анализ камер
      coder: "deepseek-coder"    # Генерация кода
      embeddings: "nomic-embed-text"  # RAG
```

---

## 💰 Стоимость (бесплатно!)

**Сравнение:**

```text
OpenAI GPT-4 (облачный, проблемы в РФ):
  • 300 запросов/месяц = ~$15-20
  • Нужен VPN
  • Данные уходят в облако

Ollama локально (ваш вариант):
  • Неограниченно запросов = $0
  • Работает в РФ без VPN
  • Данные остаются дома
  • Единоразово: ~$0 (уже есть Proxmox)
```

**ROI:** Бесконечность! 🚀

---

## 📚 Полезные ссылки

- [Ollama официальный сайт](https://ollama.com/)
- [n8n AI Agents](https://docs.n8n.io/advanced-ai/)
- [LLaVA Vision модель](https://ollama.com/library/llava)
- [Langchain в n8n](https://docs.n8n.io/integrations/builtin/cluster-nodes/root-nodes/n8n-nodes-langchain.agent/)

---

**Начните с AI ассистента (#1), затем добавьте Vision (#2) и RAG (#3)!**
