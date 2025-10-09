# 🗣️ Голосовой ассистент для Home Assistant

Полнофункциональный голосовой ассистент с управлением Home Assistant через Telegram. Использует российские AI сервисы: Yandex SpeechKit, YandexGPT и GigaChat.

---

## 🎯 Возможности

### Управление устройствами
- ✅ **Свет:** включение/выключение, регулировка яркости
- ✅ **Климат:** установка температуры, смена режимов
- ✅ **Сцены:** запуск автоматизаций
- ✅ **Датчики:** получение текущих значений

### Интеллектуальные функции
- ✅ **Голосовые команды:** распознавание русской речи
- ✅ **Текстовые команды:** стандартный ввод
- ✅ **Контекст диалога:** помнит предыдущие 10 сообщений
- ✅ **Естественный язык:** понимает вариации команд

### AI модели
- ✅ **YandexGPT** - основной (быстрый, бесплатная квота)
- ✅ **GigaChat** - резервный (автоматический fallback)
- 🔄 **OLLAMA** - в планах (локальный запуск)

---

## 📊 Архитектура

```text
┌──────────────┐
│   Telegram   │ (текст или голос)
└──────┬───────┘
       ↓
┌──────────────┐
│ Yandex STT   │ (если голос → текст)
└──────┬───────┘
       ↓
┌──────────────┐
│ YandexGPT    │ ← HA Tools (8 функций)
│ + Memory     │
└──────┬───────┘
       ↓ (если ошибка)
┌──────────────┐
│  GigaChat    │ ← HA Tools (fallback)
└──────┬───────┘
       ↓
┌──────────────┐
│ Home         │ (выполнение команд)
│ Assistant    │
└──────┬───────┘
       ↓
┌──────────────┐
│   Telegram   │ (ответ пользователю)
└──────────────┘
```

**Компоненты:**
- **20+ узлов** n8n
- **2 LLM** (YandexGPT + GigaChat)
- **8 инструментов** Home Assistant
- **Function calling** для точного управления
- **BufferWindowMemory** для контекста

---

## 📋 Требования

### API ключи

| Сервис | Зачем | Получить | Стоимость |
|--------|-------|----------|-----------|
| **Yandex Cloud** | SpeechKit + YandexGPT | [Инструкция](./YANDEX-CLOUD-SETUP.md) | ✅ Бесплатная квота |
| **GigaChat** | Резервный LLM | [sberdevices.ru/gigachat](https://developers.sber.ru/portal/products/gigachat) | ✅ Бесплатно |
| **Telegram Bot** | Интерфейс | [@BotFather](https://t.me/BotFather) | ✅ Бесплатно |
| **Home Assistant** | Управление устройствами | Ваш HA | ✅ Бесплатно |

### Системные требования

- **n8n** 1.0+ (с Langchain поддержкой)
- **Home Assistant** 2023.1+
- **Node.js** 18+ (для n8n)

---

## 🚀 Установка

### Шаг 1: Получите API ключи

Следуйте инструкции: [YANDEX-CLOUD-SETUP.md](./YANDEX-CLOUD-SETUP.md)

Вам понадобятся:
- ✅ Yandex Cloud API Key
- ✅ Yandex Folder ID
- ✅ GigaChat Authorization Key (если еще нет)
- ✅ Telegram Bot Token

### Шаг 2: Импортируйте workflow

```bash
# В n8n:
Workflows → Import from File → выберите n8n-voice-assistant.json
```

### Шаг 3: Замените параметры

Откройте workflow и замените заглушки на реальные значения:

| Заглушка | Где искать | Что заменить |
|----------|------------|--------------|
| `YOUR_YANDEX_CLOUD_API_KEY` | Узлы: "Yandex: SpeechKit STT", "YandexGPT: Chat" | Ваш API Key |
| `YOUR_YANDEX_FOLDER_ID` | Узлы: "Yandex: SpeechKit STT", "YandexGPT: Chat" | Ваш Folder ID |
| `YOUR_GIGACHAT_AUTHORIZATION_KEY` | Узел: "GigaChat: Get Token" | Base64 ключ |
| `YOUR_TELEGRAM_USER_ID` | Узел: "Telegram: Trigger" | Ваш Telegram ID |
| `YOUR_TELEGRAM_CREDENTIAL_ID` | Все Telegram узлы | n8n Credential ID |
| `YOUR_HA_CREDENTIAL_ID` | Все HA узлы | n8n Credential ID |

**Как получить Telegram User ID:**
```bash
# Напишите @userinfobot в Telegram
# Он пришлет ваш ID
```

### Шаг 4: Настройте credentials в n8n

#### Home Assistant

1. n8n → Credentials → Add Credential → Home Assistant
2. Введите:
   - **Host:** `http://your-ha-ip:8123`
   - **Access Token:** Long-lived access token из HA

#### Telegram

1. n8n → Credentials → Add Credential → Telegram
2. Введите:
   - **Access Token:** От @BotFather

### Шаг 5: Активируйте workflow

```bash
# В n8n:
Workflow → Active: ON
```

---

## 💬 Примеры команд

### Голосовые команды

Просто отправьте голосовое сообщение боту:

- *"Включи свет на кухне"*
- *"Сделай теплее в спальне"*
- *"Запусти сцену 'Вечерний режим'"*
- *"Какая температура в гостиной?"*
- *"Выключи все светильники в доме"*
- *"Установи 22 градуса в детской"*

### Текстовые команды

#### Управление

```text
Включи свет в коридоре
Выключи кухню
Установи яркость 50% в спальне
Сделай в зале 23 градуса
Запусти сцену "Кино"
```

#### Информация

```text
Какая температура на улице?
Включен ли свет в гараже?
Покажи статус климата в спальне
```

#### Системные команды

```text
/lights - список всех светильников
/scenes - доступные сцены
/status - общий статус дома
/help - справка
/clear - очистить контекст диалога
```

---

## 🔧 Home Assistant Tools

Workflow реализует 8 инструментов для управления HA:

### 1. turn_on_light
Включает свет с опциональной яркостью

```javascript
{
  "entity_id": "light.kitchen",
  "brightness": 200  // 0-255, опционально
}
```

### 2. turn_off_light
Выключает свет

```javascript
{
  "entity_id": "light.kitchen"
}
```

### 3. set_temperature
Устанавливает целевую температуру

```javascript
{
  "entity_id": "climate.bedroom",
  "temperature": 22
}
```

### 4. set_climate_mode
Меняет режим климата

```javascript
{
  "entity_id": "climate.bedroom",
  "hvac_mode": "heat"  // heat, cool, heat_cool, off, auto
}
```

### 5. activate_scene
Запускает сцену

```javascript
{
  "entity_id": "scene.evening"
}
```

### 6. get_sensor_state
Получает состояние датчика

```javascript
{
  "entity_id": "sensor.temperature_outdoor"
}
```

### 7. list_lights
Возвращает список всех светильников

```javascript
{}  // без параметров
```

### 8. list_scenes
Возвращает список всех сцен

```javascript
{}  // без параметров
```

---

## 🧠 Контекст и память

Ассистент помнит **последние 10 сообщений** в диалоге.

### Примеры использования контекста

```text
Вы: Включи свет на кухне
Бот: Свет на кухне включен ✅

Вы: А сделай ярче
Бот: Установил яркость 100% на кухне

Вы: Теперь выключи
Бот: Свет на кухне выключен
```

### Очистка контекста

Если ассистент "путается" или помнит старый контекст:

```bash
/clear
```

---

## 🆘 Troubleshooting

### Голосовые сообщения не распознаются

**Проблема:** Ошибка при транскрипции

**Решение:**
1. Проверьте API ключ Yandex Cloud
2. Убедитесь что Folder ID правильный
3. Проверьте квоту SpeechKit (180 мин/месяц после гранта)

```bash
# Тест SpeechKit:
curl -X POST \
  https://stt.api.cloud.yandex.net/speech/v1/stt:recognize \
  -H "Authorization: Api-Key YOUR_KEY" \
  -F "audio=@test.ogg" \
  -F "lang=ru-RU" \
  -F "folderId=YOUR_FOLDER_ID"
```

### YandexGPT не отвечает

**Проблема:** Таймаут или ошибка 401/403

**Решение:**
1. Проверьте API ключ
2. Убедитесь что modelUri правильный: `gpt://FOLDER_ID/yandexgpt-lite`
3. Проверьте квоту (10,000 токенов/день для lite)

**GigaChat автоматически** подхватит если YandexGPT недоступен!

### Команды не выполняются в HA

**Проблема:** Ассистент отвечает, но устройства не реагируют

**Решение:**
1. Проверьте credential Home Assistant в n8n
2. Убедитесь что `entity_id` правильные (проверьте в HA → Developer Tools → States)
3. Проверьте что у токена есть права на управление

```yaml
# В HA создайте long-lived token:
# Profile → Long-Lived Access Tokens → Create Token
```

### Ассистент не понимает команды

**Проблема:** Отвечает невпопад или просит уточнить

**Решение:**
1. Используйте полные названия: "свет на кухне", а не "кухня"
2. Очистите контекст: `/clear`
3. Проверьте что названия устройств в HA соответствуют вашим командам

**Совет:** Используйте friendly names в HA:

```yaml
# configuration.yaml
homeassistant:
  customize:
    light.kitchen_main:
      friendly_name: "Свет на кухне"
```

---

## 🔄 Расширение функционала

### Добавление новых инструментов

1. Откройте узел **"Prepare: HA Tools"**
2. Добавьте новую функцию в массив `tools`:

```javascript
{
  type: "function",
  function: {
    name: "open_cover",
    description: "Открыть штору или жалюзи",
    parameters: {
      type: "object",
      properties: {
        entity_id: {
          type: "string",
          description: "ID шторы (например: cover.bedroom)"
        }
      },
      required: ["entity_id"]
    }
  }
}
```

3. Добавьте обработку в **"Switch: Function Type"**
4. Создайте узел **"HA: Open Cover"**

### Интеграция с другими сервисами

Вы можете добавить инструменты для:
- 🎵 **Sonos/Music** - управление музыкой
- 📺 **Media Players** - ТВ и развлечения
- 🔐 **Locks** - замки и безопасность
- 📹 **Cameras** - просмотр камер
- ⏰ **Timers** - таймеры и будильники

---

## 🗺️ Roadmap

### В разработке

- [ ] **Google Assistant** интеграция
  - Голосовое управление через Google колонку
  - Intent recognition
  - Entity mapping

- [ ] **OLLAMA** поддержка
  - Локальный LLM (llama3, mistral)
  - Локальная транскрипция (Whisper)
  - Полная независимость от облака

- [ ] **Расширенные функции**
  - Мультиязычность (EN, DE, FR)
  - Голосовые ответы (TTS)
  - Персонализация (разные пользователи)
  - Планировщик действий

### Долгосрочные планы

- [ ] **Yandex Station** интеграция (Алиса)
- [ ] **Web UI** для управления
- [ ] **iOS/Android** приложение
- [ ] **Offline режим** (полностью локально)

---

## 💰 Стоимость использования

### Бесплатная квота (первые 2 месяца)

| Сервис | Лимит | Стоимость |
|--------|-------|-----------|
| **YandexGPT Lite** | Неограниченно | ✅ $0 |
| **SpeechKit STT** | 3,000 минут | ✅ $0 |
| **GigaChat** | Неограниченно | ✅ $0 |
| **Telegram** | Неограниченно | ✅ $0 |

### После гранта (с 3-го месяца)

| Сервис | Бесплатный лимит | Цена сверх лимита |
|--------|------------------|-------------------|
| **YandexGPT Lite** | 10,000 токенов/день | ~₽0.15/1K токенов |
| **SpeechKit STT** | 180 мин/месяц | ₽0.70/мин |
| **GigaChat** | Неограниченно | ✅ Бесплатно |

**Практический расчет:**
- **100 команд/день** ≈ 50,000 токенов/месяц ≈ **₽200/мес**
- **10 голосовых/день** ≈ 50 минут/месяц ≈ **в пределах квоты**

**Итого:** ~₽200/мес при активном использовании

---

## 🔗 Полезные ссылки

### Документация API
- [Yandex Cloud Setup](./YANDEX-CLOUD-SETUP.md)
- [YandexGPT Docs](https://cloud.yandex.ru/docs/yandexgpt/)
- [SpeechKit Docs](https://cloud.yandex.ru/docs/speechkit/)
- [GigaChat Docs](https://developers.sber.ru/docs/ru/gigachat/api/overview)

### n8n
- [n8n Home Assistant](https://docs.n8n.io/integrations/builtin/app-nodes/n8n-nodes-base.homeassistant/)
- [n8n Langchain](https://docs.n8n.io/integrations/builtin/cluster-nodes/root-nodes/n8n-nodes-langchain/)
- [Function Calling](https://docs.n8n.io/advanced-ai/examples/function-calling/)

### Home Assistant
- [REST API](https://developers.home-assistant.io/docs/api/rest/)
- [Services](https://www.home-assistant.io/docs/scripts/service-calls/)
- [Long-lived tokens](https://www.home-assistant.io/docs/authentication/)

---

## 📝 Changelog

### v1.0 (2025-10-09)
- ✅ Первый релиз
- ✅ YandexGPT + GigaChat fallback
- ✅ Yandex SpeechKit транскрипция
- ✅ 8 Home Assistant tools
- ✅ BufferWindowMemory контекст
- ✅ Полная документация

---

**Готово к использованию!** 🚀

Если есть вопросы - создайте Issue в репозитории.
