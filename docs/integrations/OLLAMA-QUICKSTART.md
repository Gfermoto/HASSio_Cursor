# ⚡ Ollama Quick Start - За 15 минут

Быстрый старт Ollama на Proxmox с GPU для голосового ассистента Home Assistant.

---

## 🎯 Что получите

- ✅ Локальный AI (phi3:mini или llama3.1:8b)
- ✅ Работает БЕЗ интернета
- ✅ 100% приватно
- ✅ Интеграция с n8n и Home Assistant
- ✅ Telegram бот для управления

**Время установки:** 15-20 минут

---

## 📋 Что нужно

### Железо
- Proxmox VE 7.x или 8.x
- NVIDIA GPU: GTX 1050 Ti (4GB) или GTX 1060 (6GB)
- 8GB+ RAM свободно

### ПО (уже есть)
- Home Assistant
- n8n
- Telegram Bot

---

## 🚀 Установка (3 шага)

### Шаг 1: Скопируйте скрипт на Proxmox хост

**Вариант 1: Через SCP (рекомендуется)**

```bash
# С вашей локальной машины (из директории HASSio)
scp docs/integrations/ollama-proxmox-install.sh root@YOUR_PROXMOX_IP:/root/

# SSH в Proxmox хост
ssh root@YOUR_PROXMOX_IP

# Дать права на выполнение
cd /root
chmod +x ollama-proxmox-install.sh
```

**Вариант 2: Создать вручную**

```bash
# SSH в Proxmox хост
ssh root@YOUR_PROXMOX_IP

# Создать скрипт (скопируйте содержимое из файла)
nano /root/ollama-proxmox-install.sh
# Вставьте содержимое из docs/integrations/ollama-proxmox-install.sh
# Ctrl+O, Enter, Ctrl+X

chmod +x ollama-proxmox-install.sh
```

**Вариант 3: Через Git (если есть репозиторий)**

```bash
# SSH в Proxmox хост
ssh root@YOUR_PROXMOX_IP

# Клонировать репозиторий
git clone https://github.com/Gfermoto/HASSio_Cursor.git
cd HASSio_Cursor/docs/integrations/
chmod +x ollama-proxmox-install.sh
```

### Шаг 2: Установите NVIDIA драйверы на хост

```bash
# Запустить установку драйверов
./ollama-proxmox-install.sh --install-host

# Скрипт установит драйверы и попросит перезагрузить
reboot

# После перезагрузки проверить
nvidia-smi
# Должна показаться информация о GPU
```

### Шаг 3: Создайте LXC контейнер с Ollama

```bash
# Запустить создание контейнера
./ollama-proxmox-install.sh --create-lxc

# Ответить на вопросы:
# CT ID [200]: 200
# Hostname [ollama]: ollama
# Password: ********
# Storage [local-lvm]: local-lvm
# Disk size GB [50]: 50
# Memory MB [8192]: 8192
# Cores [4]: 4

# Скрипт автоматически:
# - Создаст LXC контейнер
# - Настроит GPU passthrough
# - Установит Ollama
# - Настроит systemd сервис
```

**Готово!** Ollama запущен и доступен по адресу: `http://IP_контейнера:11434`

---

## 📥 Скачивание модели

### Для GTX 1050 Ti (4GB):

```bash
# Автоматически (через скрипт)
./ollama-proxmox-install.sh --install-model
# Выберите: 1) phi3:mini

# ИЛИ вручную
pct enter 200
ollama pull phi3:mini
```

### Для GTX 1060 (6GB):

```bash
# Автоматически
./ollama-proxmox-install.sh --install-model
# Выберите: 5) llama3.1:8b

# ИЛИ вручную
pct enter 200
ollama pull llama3.1:8b
```

---

## ✅ Проверка

### Автоматическая проверка:

```bash
./ollama-proxmox-install.sh --check
```

### Ручная проверка:

```bash
# 1. Проверка GPU в контейнере
pct enter 200
ls -la /dev/nvidia*
# Должны быть: nvidia0, nvidiactl, nvidia-uvm

# 2. Проверка сервиса
systemctl status ollama
# Должно быть: active (running)

# 3. Проверка моделей
ollama list
# Должна быть: phi3:mini или llama3.1:8b

# 4. Тест модели
ollama run phi3:mini "Привет! Представься кратко"
# Должен ответить на русском

# 5. Проверка API (с хоста)
curl http://IP_КОНТЕЙНЕРА:11434/api/tags
# Должен вернуть JSON со списком моделей
```

---

## 🔗 Интеграция с n8n

### 1. Импортируйте workflow

1. Скопируйте `n8n-voice-assistant-ollama.json`
2. n8n → Import from File
3. Вставьте JSON

### 2. Настройте параметры

**Обязательно замените:**

```text
Ollama Model (узел):
- Base URL: http://IP_КОНТЕЙНЕРА:11434
- Model: phi3:mini

HA Get States (узел):
- URL: http://YOUR_HA_IP:8123/api/states
- Credentials: Home Assistant API

Telegram (узлы):
- User ID: ваш Telegram ID
- Credentials: Telegram Bot
```

### 3. Создайте Tool workflows

См. подробную инструкцию: [README-ollama-assistant.md](./README-ollama-assistant.md)

### 4. Активируйте workflow

1. Сохраните все изменения
2. Активируйте workflow (переключатель справа вверху)
3. Откройте Telegram → найдите бота → `/start`

**Готово!** 🎉

---

## 💬 Первый тест

```text
Вы: /start
Бот: 🤖 Текстовый ассистент Home Assistant + Ollama...

Вы: Привет!
Бот: Привет! Я ваш ассистент умного дома. Готов помочь с управлением...

Вы: Включи свет на кухне
Бот: Свет на кухне включен ✅

Вы: Какая температура?
Бот: Текущая температура в гостиной: 21.5°C
```

---

## 🐛 Troubleshooting

### GPU не виден в контейнере

```bash
# На Proxmox хосте
ls -l /dev/nvidia0 /dev/nvidiactl

# Проверить major/minor номера в конфиге
nano /etc/pve/lxc/200.conf

# Перезапустить контейнер
pct stop 200
pct start 200
```

### Ollama не запускается

```bash
# В контейнере
pct enter 200
journalctl -u ollama -f

# Проверить порт
ss -tulpn | grep 11434
```

### API недоступен из сети

```bash
# В контейнере
systemctl edit ollama

# Добавить:
[Service]
Environment="OLLAMA_HOST=0.0.0.0:11434"
Environment="OLLAMA_ORIGINS=*"

# Перезапустить
systemctl restart ollama
```

---

## 📊 Производительность

| GPU | Модель | Скорость | VRAM | Качество |
|-----|--------|----------|------|----------|
| GTX 1050 Ti | phi3:mini | 40-60 tok/s | ~2.5GB | ⭐⭐⭐⭐⭐ |
| GTX 1060 | llama3.1:8b | 30-50 tok/s | ~5GB | ⭐⭐⭐⭐⭐ |

**Время ответа:** 3-7 секунд на средний запрос

---

## 🎯 Следующие шаги

- ✅ Ollama установлен и работает
- ✅ Модель скачана
- ✅ API доступен
- 🔄 Импортируйте n8n workflow
- 🔄 Создайте Tool workflows
- 🔄 Настройте Telegram бота
- 🔄 Протестируйте команды

---

## 📚 Документация

- [📖 Полная документация](./OLLAMA-PROXMOX-SETUP.md) - детальная инструкция
- [🤖 n8n Интеграция](./README-ollama-assistant.md) - настройка workflow
- [🔧 Скрипт установки](./ollama-proxmox-install.sh) - автоматизация

---

**Время до запуска:** 15-20 минут
**Сложность:** Средняя
**Результат:** Локальный AI для умного дома! 🚀
