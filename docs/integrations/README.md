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

## 🤖 Текстовый ассистент (100% бесплатно)

### Вариант 1: GigaChat (облачный)

**Файл**: [README-voice-assistant.md](./README-voice-assistant.md)

Управление Home Assistant через естественный язык в Telegram:
- Текстовые команды (голос добавится с OLLAMA)
- GigaChat AI (полностью бесплатный)
- Управление светом, климатом, сценами, датчиками
- Function calling для точного управления
- Контекст диалога

**Workflow:** `n8n-voice-assistant-free.json` (шаблон) или `n8n-voice-assistant-free.local.json` (рабочий)

**Roadmap:** [VOICE-ASSISTANT-ROADMAP.md](./VOICE-ASSISTANT-ROADMAP.md) - план развития по поколениям

**Стоимость:** ✅ **₽0/месяц** - всё бесплатно!

### Вариант 2: Ollama (локальный, приватный) 🔒

**Файлы**:
- [OLLAMA-QUICKSTART.md](./OLLAMA-QUICKSTART.md) - за 15 минут
- [OLLAMA-PROXMOX-SETUP.md](./OLLAMA-PROXMOX-SETUP.md) - полная документация
- [README-ollama-assistant.md](./README-ollama-assistant.md) - интеграция с n8n

Локальный AI на вашем GPU (GTX 1050 Ti / GTX 1060):
- ✅ 100% локально - работает БЕЗ интернета
- ✅ 100% приватно - данные не покидают вашу сеть
- ✅ Модели: phi3:mini (4GB), llama3.1:8b (6GB)
- ✅ Скорость: 40-60 tokens/sec
- ✅ LXC контейнер на Proxmox

**Workflow:** `n8n-voice-assistant-ollama.json`

**Скрипт установки:** `ollama-proxmox-install.sh` - автоматическая установка

**Стоимость:** ✅ **₽0/месяц** - единоразовые затраты только на GPU!

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

**Хотите управлять HA через Telegram текстом?** ⭐ (100% бесплатно)
- С интернетом: [README-voice-assistant.md](./README-voice-assistant.md) (GigaChat)
- Локально БЕЗ интернета: [OLLAMA-QUICKSTART.md](./OLLAMA-QUICKSTART.md) 🔒

**Хотите прогноз погоды с AI?**
→ [README-meteostation.md](./README-meteostation.md)

**Есть NVIDIA GPU и хотите локальный AI?** 🚀
→ [OLLAMA-QUICKSTART.md](./OLLAMA-QUICKSTART.md) - за 15 минут

**Хотите AI дворецкого с полным контролем дома?**
→ [n8n-butler-setup.md](./n8n-butler-setup.md)

**Хотите все возможности AI (7 агентов)?**
→ [n8n-ai-agents.md](./n8n-ai-agents.md)

**Просто подключить n8n к HA?**
→ [n8n-integration.md](./n8n-integration.md)

---

**Все workflow используют локальные/российские LLM - бесплатно, без VPN!** 🇷🇺
