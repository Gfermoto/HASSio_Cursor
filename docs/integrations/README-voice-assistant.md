# 🤖 Текстовый ассистент для Home Assistant (100% бесплатно)

Управление Home Assistant через естественный язык в Telegram. Использует только бесплатные сервисы - GigaChat + Telegram.

---

## 🎯 Возможности

- ✅ **Управление светом:** включение/выключение, яркость
- ✅ **Управление климатом:** установка температуры
- ✅ **Запуск сцен:** активация автоматизаций
- ✅ **Получение статуса:** информация с датчиков
- ✅ **Естественный язык:** пишите как удобно
- ✅ **Контекст:** помнит предыдущие сообщения

---

## 💰 Стоимость

| Сервис | Цена |
|--------|------|
| **GigaChat** | ✅ **Бесплатно навсегда** |
| **Telegram** | ✅ Бесплатно |
| **Home Assistant** | ✅ Бесплатно |

**Итого: ₽0/месяц** 🎉

---

## 📊 Архитектура

```text
Telegram (текст)
   ↓
GigaChat + HA Tools
   ↓
Home Assistant
   ↓
Telegram (ответ)
```

**Всего 16 узлов** - простой и понятный workflow

---

## 🚀 Установка

### Шаг 1: Импорт workflow

```bash
n8n → Import from File → n8n-voice-assistant-free.local.json
```

### Шаг 2: Проверьте credentials

Workflow уже настроен с вашими ключами:
- ✅ GigaChat Authorization
- ✅ Telegram Bot
- ✅ Home Assistant

### Шаг 3: Активируйте

```bash
n8n → Active: ON
```

### Шаг 4: Протестируйте

Отправьте боту в Telegram:

```text
/help
```

---

## 💬 Примеры команд

### Управление светом

```text
Включи свет на кухне
Выключи свет в спальне
Сделай ярче в гостиной
Установи яркость 50% на кухне
Выключи все светильники
```

### Управление климатом

```text
Сделай теплее в спальне
Установи 22 градуса в детской
Какая температура в гостиной?
```

### Сцены

```text
Запусти сцену Вечер
Включи вечерний режим
Активируй режим кино
```

### Статус устройств

```text
Включен ли свет в гараже?
Какая температура на улице?
Покажи статус климата
```

### Системные команды

```text
/help - справка по командам
/clear - очистить контекст диалога
```

---

## 🔧 Home Assistant Tools

Workflow реализует 5 инструментов:

### 1. turn_on_light

Включает свет с опциональной яркостью

```javascript
{
  entity_id: "light.kitchen",
  brightness: 200  // 0-255, опционально
}
```

### 2. turn_off_light

Выключает свет

```javascript
{
  entity_id: "light.kitchen"
}
```

### 3. set_temperature

Устанавливает температуру

```javascript
{
  entity_id: "climate.bedroom",
  temperature: 22
}
```

### 4. activate_scene

Запускает сцену

```javascript
{
  entity_id: "scene.evening"
}
```

### 5. get_state

Получает состояние устройства

```javascript
{
  entity_id: "sensor.temperature"
}
```

---

## 🧠 Контекст

Ассистент помнит **последние сообщения** в диалоге.

**Пример:**

```text
Вы: Включи свет на кухне
Бот: ✅ Свет на кухне включен

Вы: А теперь сделай ярче
Бот: ✅ Установил яркость 100% на кухне

Вы: Выключи
Бот: ✅ Свет на кухне выключен
```

**Очистка:**

```bash
/clear
```

---

## 🆘 Troubleshooting

### Бот не отвечает

**Проблема:** Workflow неактивен

**Решение:**

```bash
n8n → Workflows → Активируйте workflow
```

### "Не понял команду"

**Проблема:** Неправильное название устройства

**Решение:**

1. Проверьте `entity_id` в HA → Developer Tools → States
2. Используйте полные названия: "свет на кухне", а не "кухня"
3. Очистите контекст: `/clear`

### Команда не выполняется

**Проблема:** Нет прав у токена HA

**Решение:**

```yaml
# В Home Assistant:
# Profile → Long-Lived Access Tokens → Create Token
# Скопируйте в n8n credentials
```

---

## ➕ Добавление новых команд

### Шаг 1: Добавьте функцию

Откройте узел **"GigaChat: Prepare Request"** и добавьте в массив `functions`:

```javascript
{
  name: "open_cover",
  description: "Открыть штору",
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
```

### Шаг 2: Добавьте обработку

В узле **"Execute: HA Command"** добавьте case:

```javascript
case 'open_cover':
  domain = 'cover';
  service = 'open_cover';
  serviceData = { entity_id: args.entity_id };
  break;
```

---

## 🗺️ Roadmap

**Подробный план развития:** [VOICE-ASSISTANT-ROADMAP.md](./VOICE-ASSISTANT-ROADMAP.md)

### Поколение 2 (с OLLAMA)

- [ ] **Голосовые команды** - Whisper (HA add-on)
- [ ] **OLLAMA** - локальный LLM (llama3, mistral)
- [ ] **Голосовые ответы** - Piper TTS
- [ ] **Больше устройств** - шторы, замки, медиа (8 tools)

### Поколение 3 (расширенное)

- [ ] **Google Assistant** - управление через колонку
- [ ] **Групповые команды** - "выключи весь свет"
- [ ] **Планировщик** - отложенные действия
- [ ] **Агентная система** - сложные сценарии

### Поколение 4 (автономное)

- [ ] **Предвидение** - проактивные действия
- [ ] **Обучение** - адаптация к привычкам
- [ ] **Computer Vision** - анализ камер
- [ ] **100% offline** - полная автономность

**Всё бесплатно!** Детали в [VOICE-ASSISTANT-ROADMAP.md](./VOICE-ASSISTANT-ROADMAP.md)

---

## 📚 Файлы

| Файл | Описание |
|------|----------|
| `n8n-voice-assistant-free.json` | Шаблон (с заглушками) |
| `n8n-voice-assistant-free.local.json` | Рабочий (с ключами, не в git) |
| `README-voice-assistant.md` | Эта документация |

---

## 🔗 Полезные ссылки

- [GigaChat Docs](https://developers.sber.ru/docs/ru/gigachat/api/overview)
- [n8n Home Assistant](https://docs.n8n.io/integrations/builtin/app-nodes/n8n-nodes-base.homeassistant/)
- [HA REST API](https://developers.home-assistant.io/docs/api/rest/)
- [Telegram Bot API](https://core.telegram.org/bots/api)

---

## 📝 Changelog

### v2.0 (2025-10-09) - 100% Бесплатная версия

- ✅ Убран Yandex Cloud (платный)
- ✅ Только GigaChat (бесплатный)
- ✅ Только текст (голос добавим с OLLAMA)
- ✅ Упрощенный workflow (16 узлов вместо 20+)
- ✅ 5 Home Assistant tools
- ✅ Полная документация

---

**Готово к использованию!** 🚀

Импортируйте `n8n-voice-assistant-free.local.json` и управляйте домом через Telegram! 💬
