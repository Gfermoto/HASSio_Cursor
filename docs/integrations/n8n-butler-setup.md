# 🤵 AI Дворецкий: Пошаговое развертывание

Полное руководство по установке и настройке AI дворецкого с голосовыми сообщениями.

Основано на вашей конфигурации: **NVIDIA P106-100 (6GB)** + **Ollama** + **n8n**.

---

## 🎯 Что получим

### 🤵 AI Дворецкий

- Telegram бот (текст + голос)
- Естественный язык: "Дома холодно" → действие
- Понимает контекст 15 зон отопления

### 📊 Аналитик паттернов

- Еженедельный анализ данных
- Отчеты с YAML рекомендациями
- Вы пишете код в Cursor

### 🎙️ Возможности

- **STT** (Speech-to-Text): Whisper, русский
- **TTS** (Text-to-Speech): опционально

---

## ✅ Требования

**Железо:**

- Proxmox сервер
- **NVIDIA P106-100 (6GB)** или GTX 1060 8GB
- CPU: 4+ cores, RAM: 16+ GB

**Софт:**

- Proxmox VE 7.0+
- Home Assistant (192.168.1.20)
- n8n (Docker)
- Telegram бот

---

## 🚀 Шаг 1: Установка Ollama + GPU

### 1.1. Создать VM на Proxmox

```bash
# CLI команды на Proxmox хосте
qm create 200 --name ollama-ai --memory 8192 --cores 4
```

### 1.2. Установить Ubuntu 22.04

Скачать и установить Ubuntu Server 22.04 на VM 200.

### 1.3. Пробросить GPU

**Proxmox Web UI:** VM 200 → Hardware → Add → PCI Device → NVIDIA P106-100

**CLI:**

```bash
qm set 200 -hostpci0 01:00,pcie=1
```

### 1.4. Установить NVIDIA драйверы

**SSH в VM:**

```bash
apt update && apt upgrade -y
apt install -y nvidia-driver-535
reboot
```

**Проверка:**

```bash
nvidia-smi
# Должна показать таблицу с P106-100
```

### 1.5. Установить Ollama

```bash
curl -fsSL https://ollama.com/install.sh | sh

# Открыть доступ из сети
mkdir -p /etc/systemd/system/ollama.service.d
cat > /etc/systemd/system/ollama.service.d/override.conf << 'EOF'
[Service]
Environment="OLLAMA_HOST=0.0.0.0:11434"
Environment="OLLAMA_KEEP_ALIVE=24h"
EOF

systemctl daemon-reload
systemctl restart ollama
```

**Узнать IP:** `hostname -I` (например: 192.168.1.51)

---

## 🧠 Шаг 2: Установка AI моделей

**SSH в Ollama VM:**

```bash
# Llama 3 (8B) - дворецкий + аналитик
ollama pull llama3:8b-instruct-q4_0

# Whisper - распознавание голоса
ollama pull whisper:base

# Проверка
ollama list
```

**VRAM:** ~5.2 GB (обе модели влезут в 6GB!)

---

## 🔧 Шаг 3: Настройка n8n

### 3.1. Установка n8n

```bash
mkdir -p /opt/n8n && cd /opt/n8n
cat > docker-compose.yml << 'EOF'
version: '3.8'
services:
  n8n:
    image: n8nio/n8n:latest
    ports:
      - "5678:5678"
    environment:
      - N8N_HOST=192.168.1.50
      - GENERIC_TIMEZONE=Europe/Moscow
    volumes:
      - n8n_data:/home/node/.n8n
volumes:
  n8n_data:
EOF

docker-compose up -d
```

**Открыть:** <http://192.168.1.50:5678>

### 3.2. Создать Telegram бота

1. Найти в Telegram: `@BotFather`
2. `/newbot` → имя → username
3. Получить токен

### 3.3. Credentials в n8n

**Telegram:**
- Name: Telegram Bot
- Access Token: [токен от BotFather]

**Home Assistant:**
- Host: <http://192.168.1.20:8123>
- Access Token: [создать в HA Profile → Security]

---

## 🤵 Шаг 4: Workflow Дворецкий

### Структура workflow

1. **Telegram Trigger** - входящие сообщения
2. **Filter** - текстовые или голосовые
3. **Whisper STT** (если голос) - преобразовать в текст
4. **AI Agent (Llama 3)** - понимание + действие
5. **Home Assistant API** - выполнение команд
6. **Telegram Reply** - ответ

### System Prompt для Llama 3

```text
Ты дворецкий умного дома с 15 зонами отопления.

Стиль: вежливый, краткий, объясняешь WHY.

Tools:
- get_all_zones() - статус зон
- set_zone_temperature(zone, temp) - изменить

При запросе:
1. Получи текущее состояние
2. Проанализируй
3. Предложи решение + расчеты
4. Спроси подтверждение для больших изменений

Пример:
👤: Дома холодно
🤵: Средняя 19°C (норма 21°C). На улице -5°C.
    Повышаю до 22°C в основных зонах.
    Время ~25 мин, стоимость ~15₽. Применить?
```

**Детали workflow см. в:** [n8n-ai-agents.md](./n8n-ai-agents.md)

---

## 🎙️ Шаг 5: Голосовые сообщения

### Workflow для STT

1. **Telegram Trigger** (voice filter)
2. **Download Audio** - скачать OGG
3. **Whisper API** - <http://192.168.1.51:11434/api/generate>
4. **Extract Text** - получить транскрибированный текст
5. **→ Основной workflow дворецкого**

**Скорость:** ~5 сек на голосовое 30 сек

---

## 📊 Шаг 6: Аналитик паттернов

### Workflow

1. **Cron** - воскресенье 20:00
2. **HA History API** - данные за 7 дней
3. **Aggregate** - агрегация по зонам
4. **AI Analyst (Llama 3)** - анализ + рекомендации
5. **Save Report** - Markdown файл
6. **Telegram** - уведомление

**Результат:** Отчет с готовым YAML кодом для автоматизаций.

---

## 🔊 Шаг 7: TTS (опционально)

### Установка Piper TTS

```bash
wget https://github.com/rhasspy/piper/releases/download/v1.2.0/piper_amd64.tar.gz
tar -xzf piper_amd64.tar.gz && mv piper /usr/local/bin/

# Русская модель
mkdir -p /opt/piper/models && cd /opt/piper/models
wget https://huggingface.co/rhasspy/piper-voices/resolve/main/ru/ru_RU/dmitri/medium/ru_RU-dmitri-medium.onnx
```

**API для n8n:** Flask app на порту 5000

---

## ✅ Тестирование

### Текстовые команды

```text
👤: Привет
🤵: Здравствуйте! Я ваш дворецкий. Чем могу помочь?

👤: Какая температура?
🤵: Средняя 20.5°C. Гостиная 21°C, спальня 20°C. Всё в норме!

👤: Дома холодно
🤵: Средняя 19°C. Рекомендую повысить до 22°C.
    Время ~25 мин, стоимость ~15₽. Применить?

👤: Да
🤵: ✅ Температуры обновлены. Прогрев начат.
```

### Голосовые команды

```text
🎙️ "Дома холодно, сделай потеплее"
   ↓ (~5 сек)
📱 Повышаю до 22°C в основных зонах. ✅
```

---

## 🐛 Troubleshooting

**Ollama не видит GPU:**

```bash
nvidia-smi  # GPU видна?
systemctl restart ollama
```

**Медленная работа:**

```bash
nvidia-smi  # VRAM ~5GB?
ollama ps  # Модели в памяти?
```

**Whisper не распознает русский:**

```bash
ollama rm whisper:base
ollama pull whisper:base
```

---

## 📋 Чек-лист готовности

- ✅ P106-100 проброшена в VM
- ✅ nvidia-smi показывает GPU
- ✅ Ollama установлен
- ✅ Llama 3 + Whisper скачаны
- ✅ n8n установлен
- ✅ Telegram бот создан
- ✅ Workflows созданы и активны
- ✅ Тесты пройдены

---

**Готово! Дворецкий работает!** 🤵✨

**Детали workflow:** см. [n8n-ai-agents.md](./n8n-ai-agents.md)

**Вопросы:** [GitHub Issues](https://github.com/Gfermoto/HASSio_Cursor/issues)
