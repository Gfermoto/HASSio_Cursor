# 📚 n8n Интеграции

Документация по интеграции n8n с Home Assistant.

---

## 🌤️ Метеостанция + AI прогноз

**Файл**: [README-meteostation.md](./README-meteostation.md)

Автоматический ежедневный прогноз погоды в Telegram:
- Локальная метеостанция + Яндекс.Погода
- AI анализ через GigaChat
- Практичные рекомендации (одежда, зонт, авто, дом, огород)
- Расписание: каждый день в 07:00

**Workflow:** `n8n-meteostation-ai.json` (шаблон) или `n8n-meteostation-ai.local.json` (рабочий)

---

## 🗣️ Голосовой ассистент

**Файл**: [README-voice-assistant.md](./README-voice-assistant.md)

Полнофункциональный голосовой ассистент для управления Home Assistant:
- Голосовые команды через Telegram (Yandex SpeechKit)
- Управление светом, климатом, сценами, датчиками
- YandexGPT (основной) + GigaChat (резерв)
- Контекст диалога (10 сообщений)
- Function calling для точного управления

**Workflow:** `n8n-voice-assistant.json` (шаблон) или `n8n-voice-assistant.local.json` (рабочий)

**Setup:** [YANDEX-CLOUD-SETUP.md](./YANDEX-CLOUD-SETUP.md) - получение API ключей

---

## 🤖 AI Агенты для Home Assistant

**Файл**: [n8n-ai-agents.md](./n8n-ai-agents.md)

7 примеров AI агентов на локальных LLM (Ollama):
1. Умный ассистент умного дома (голосовое управление)
2. AI анализ камер (дополнение к Frigate)
3. RAG по конфигурациям (поиск по YAML)
4. Генератор NodeRED flows
5. Предиктивная аналитика
6. Отладчик автоматизаций
7. Оптимизатор отопления (15 зон)

---

## 🤵 AI Дворецкий

**Файл**: [n8n-butler-setup.md](./n8n-butler-setup.md)

Пошаговое развертывание AI дворецкого:
- Голосовое управление (Whisper STT)
- Управление 15 зонами отопления
- Telegram бот с естественным языком
- NVIDIA P106-100 + Ollama

---

## 🔗 Общая интеграция n8n

**Файл**: [n8n-integration.md](./n8n-integration.md)

Руководство по подключению n8n к Home Assistant:
- Настройка credentials
- Webhook триггеры
- REST API команды
- Примеры workflow
- Troubleshooting

---

## 🚀 Быстрый старт

### Что выбрать?

**Хотите голосовое управление HA через Telegram?** ⭐
→ [README-voice-assistant.md](./README-voice-assistant.md)

**Хотите прогноз погоды с AI?**
→ [README-meteostation.md](./README-meteostation.md)

**Хотите AI дворецкого с полным контролем дома?**
→ [n8n-butler-setup.md](./n8n-butler-setup.md)

**Хотите все возможности AI (7 агентов)?**
→ [n8n-ai-agents.md](./n8n-ai-agents.md)

**Просто подключить n8n к HA?**
→ [n8n-integration.md](./n8n-integration.md)

---

**Все workflow используют локальные/российские LLM - бесплатно, без VPN!** 🇷🇺
