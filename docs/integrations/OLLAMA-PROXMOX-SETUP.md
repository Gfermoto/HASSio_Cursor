# 🚀 Установка Ollama на Proxmox с NVIDIA GPU

Полная инструкция по установке Ollama в LXC контейнере на Proxmox с поддержкой NVIDIA GPU для локального запуска AI моделей.

---

## 📋 Содержание

- [Требования](#требования)
- [Выбор моделей](#выбор-моделей)
- [Этап 1: Подготовка Proxmox хоста](#этап-1-подготовка-proxmox-хоста)
- [Этап 2: Создание LXC контейнера](#этап-2-создание-lxc-контейнера)
- [Этап 3: Установка Ollama](#этап-3-установка-ollama)
- [Этап 4: Настройка и интеграция](#этап-4-настройка-и-интеграция)
- [Интеграция с n8n](#интеграция-с-n8n)
- [Troubleshooting](#troubleshooting)

---

## 🎯 Требования

### Железо

- **Proxmox VE:** 7.x или 8.x
- **GPU:** NVIDIA GTX 1050 Ti / GTX 1060 (или новее)
- **RAM:** минимум 8GB (рекомендуется 16GB+)
- **Диск:** 50GB+ свободного места для моделей

### Текущая конфигурация

- ✅ **GTX 1050 Ti:** 4GB VRAM (сейчас)
- ✅ **GTX 1060:** 6GB VRAM (после апгрейда)

---

## 📊 Выбор моделей

### Для GTX 1050 Ti (4GB VRAM)

| Модель | Размер | VRAM | Качество | Скорость | Рекомендация |
|--------|--------|------|----------|----------|--------------|
| **phi3:mini** | 2.3GB | ~2.5GB | ⭐⭐⭐⭐⭐ | Средняя | ✅ **Лучший баланс** |
| **llama3.2:3b** | 2GB | ~2.2GB | ⭐⭐⭐⭐ | Быстрая | ✅ Отлично |
| **qwen2.5:3b** | 2GB | ~2.2GB | ⭐⭐⭐⭐ | Средняя | ✅ Хорошая альтернатива |
| **gemma2:2b** | 1.6GB | ~1.8GB | ⭐⭐⭐ | Очень быстрая | ✅ Для простых задач |
| **llama3.1:8b** | 4.7GB | ~5GB | ⭐⭐⭐⭐⭐ | Медленная | ❌ Не поместится |

**Рекомендация:** `phi3:mini` - лучшее качество для 4GB

### Для GTX 1060 (6GB VRAM)

| Модель | Размер | VRAM | Качество | Скорость | Рекомендация |
|--------|--------|------|----------|----------|--------------|
| **llama3.1:8b** | 4.7GB | ~5GB | ⭐⭐⭐⭐⭐ | Средняя | ✅ **Лучший выбор** |
| **phi3:mini** | 2.3GB | ~2.5GB | ⭐⭐⭐⭐⭐ | Быстрая | ✅ Отлично |
| **qwen2.5:7b** | 4.7GB | ~5GB | ⭐⭐⭐⭐⭐ | Средняя | ✅ Альтернатива |
| **mixtral:8x7b** | 26GB | ~28GB | ⭐⭐⭐⭐⭐ | - | ❌ Не поместится |
| **phi3:medium** | 7.9GB | ~8.5GB | ⭐⭐⭐⭐⭐ | - | ❌ Не поместится |

**Рекомендация:** `llama3.1:8b` - отличное качество для 6GB

---

## 🔧 Этап 1: Подготовка Proxmox хоста

### 1.1 Проверка GPU

Подключитесь к Proxmox хосту по SSH:

```bash
# Проверить наличие GPU
lspci | grep -i nvidia

# Должно показать что-то вроде:
# 01:00.0 VGA compatible controller: NVIDIA Corporation GP107 [GeForce GTX 1050 Ti]
```

### 1.2 Установка NVIDIA драйверов на хост

```bash
# Добавить Proxmox no-subscription репозиторий (опционально)
echo "deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription" > /etc/apt/sources.list.d/pve-no-subscription.list

# Обновить систему
apt update && apt upgrade -y

# Установить заголовки ядра
apt install -y pve-headers-$(uname -r)

# Добавить contrib и non-free репозитории для NVIDIA
sed -i 's/main$/main contrib non-free non-free-firmware/' /etc/apt/sources.list
apt update

# Установить NVIDIA драйверы
apt install -y nvidia-driver nvidia-smi

# Загрузить модули blacklist для nouveau
echo "blacklist nouveau" > /etc/modprobe.d/blacklist-nouveau.conf
echo "options nouveau modeset=0" >> /etc/modprobe.d/blacklist-nouveau.conf
update-initramfs -u

# Перезагрузить хост
reboot
```

### 1.3 Проверка установки

После перезагрузки:

```bash
# Проверить работу драйвера
nvidia-smi

# Должно показать информацию о GPU:
# +-----------------------------------------------------------------------------+
# | NVIDIA-SMI 535.xx.xx    Driver Version: 535.xx.xx    CUDA Version: 12.2    |
# |-------------------------------+----------------------+----------------------+
# | GPU  Name        TCC/WDDM | Bus-Id        Disp.A | Volatile Uncorr. ECC |
# | Fan  Temp  Perf  Pwr:Usage/Cap|         Memory-Usage | GPU-Util  Compute M. |
# |===============================+======================+======================|
# |   0  GeForce GTX 105...  Off  | 00000000:01:00.0 Off |                  N/A |
```

### 1.4 Получить device nodes

```bash
# Найти NVIDIA устройства
ls -la /dev/nvidia*

# Обычно это:
# /dev/nvidia0          - GPU устройство
# /dev/nvidia-uvm       - Unified Memory
# /dev/nvidia-uvm-tools - UVM Tools
# /dev/nvidiactl        - Control устройство
# /dev/nvidia-modeset   - Mode setting

# Проверить major/minor номера (нужны для LXC)
ls -l /dev/nvidia0 /dev/nvidiactl /dev/nvidia-uvm
```

---

## 🐧 Этап 2: Создание LXC контейнера

### 2.1 Создание контейнера через Web UI

1. Откройте Proxmox Web UI
2. Нажмите **Create CT**
3. Заполните параметры:

**General:**
- **CT ID:** 200 (или свободный ID)
- **Hostname:** ollama
- **Unprivileged container:** ❌ **НЕ ставить** (нужен привилегированный!)
- **Password:** ваш пароль

**Template:**
- **Storage:** local
- **Template:** ubuntu-22.04-standard или ubuntu-24.04-standard

**Disks:**
- **Disk size:** 50GB (минимум для моделей)

**CPU:**
- **Cores:** 4 (рекомендуется)

**Memory:**
- **Memory:** 8192 MB
- **Swap:** 2048 MB

**Network:**
- **Bridge:** vmbr0
- **IPv4:** DHCP или статический IP
- **IPv6:** DHCP (опционально)

4. **НЕ запускайте** контейнер сразу!

### 2.2 Настройка доступа к GPU

Отредактируйте конфиг контейнера (замените `200` на ваш CT ID):

```bash
# На Proxmox хосте
nano /etc/pve/lxc/200.conf
```

Добавьте в конец файла:

```bash
# GPU Passthrough для NVIDIA
lxc.cgroup2.devices.allow: c 195:* rwm
lxc.cgroup2.devices.allow: c 508:* rwm
lxc.mount.entry: /dev/nvidia0 dev/nvidia0 none bind,optional,create=file
lxc.mount.entry: /dev/nvidiactl dev/nvidiactl none bind,optional,create=file
lxc.mount.entry: /dev/nvidia-uvm dev/nvidia-uvm none bind,optional,create=file
lxc.mount.entry: /dev/nvidia-modeset dev/nvidia-modeset none bind,optional,create=file
lxc.mount.entry: /dev/nvidia-uvm-tools dev/nvidia-uvm-tools none bind,optional,create=file

# Features
lxc.apparmor.profile: unconfined
lxc.cap.drop:
lxc.cgroup2.devices.allow: a
lxc.mount.auto: proc:rw sys:rw
```

**Примечание:** Major номера устройств (`195` и `508`) могут отличаться. Проверьте на вашем хосте:

```bash
# Узнать major номера
ls -l /dev/nvidia0 | awk '{print $5}' | tr -d ','    # обычно 195
ls -l /dev/nvidia-uvm | awk '{print $5}' | tr -d ',' # обычно 508 или 511
```

### 2.3 Запуск контейнера

```bash
# Запустить контейнер
pct start 200

# Войти в контейнер
pct enter 200
```

---

## 🤖 Этап 3: Установка Ollama

### 3.1 Подготовка контейнера

Внутри LXC контейнера:

```bash
# Обновить систему
apt update && apt upgrade -y

# Установить необходимые пакеты
apt install -y curl wget gnupg2 software-properties-common
```

### 3.2 Установка NVIDIA драйверов в контейнере

```bash
# Добавить NVIDIA репозиторий
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -s -L https://nvidia.github.io/libnvidia-container/$distribution/libnvidia-container.list | \
  sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
  tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

apt update

# Установить NVIDIA Container Toolkit (легче чем полные драйверы)
apt install -y nvidia-container-toolkit

# ИЛИ установить полные драйверы (если нужно)
# apt install -y nvidia-driver-535 nvidia-utils-535
```

### 3.3 Проверка GPU в контейнере

```bash
# Проверить доступ к GPU устройствам
ls -la /dev/nvidia*

# Если nvidia-smi установлен, проверить:
nvidia-smi

# Если команда не найдена, это нормально для container toolkit
# GPU будет работать через библиотеки
```

### 3.4 Установка Ollama

```bash
# Установить Ollama одной командой
curl -fsSL https://ollama.ai/install.sh | sh

# Проверить установку
ollama --version
```

### 3.5 Настройка Ollama как сервис

Создайте systemd сервис:

```bash
cat > /etc/systemd/system/ollama.service << 'EOF'
[Unit]
Description=Ollama Service
After=network-online.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/ollama serve
Environment="OLLAMA_HOST=0.0.0.0:11434"
Environment="OLLAMA_ORIGINS=*"
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

# Включить и запустить сервис
systemctl daemon-reload
systemctl enable ollama
systemctl start ollama

# Проверить статус
systemctl status ollama
```

### 3.6 Скачивание моделей

**Для GTX 1050 Ti (4GB):**

```bash
# Рекомендуемая модель: phi3:mini
ollama pull phi3:mini

# Альтернативы:
# ollama pull llama3.2:3b
# ollama pull qwen2.5:3b
# ollama pull gemma2:2b
```

**Для GTX 1060 (6GB) - после апгрейда:**

```bash
# Рекомендуемая модель: llama3.1:8b
ollama pull llama3.1:8b

# Альтернативы:
# ollama pull qwen2.5:7b
```

### 3.7 Тестирование

```bash
# Тест через CLI
ollama run phi3:mini "Привет! Расскажи о себе кратко"

# Тест через API
curl http://localhost:11434/api/generate -d '{
  "model": "phi3:mini",
  "prompt": "Привет! Как дела?",
  "stream": false
}'
```

Если видите ответ - **GPU работает!** 🎉

---

## 🔗 Этап 4: Настройка и интеграция

### 4.1 Открыть доступ к API

Ollama API по умолчанию доступен на `http://<IP_контейнера>:11434`

```bash
# Узнать IP контейнера
ip addr show eth0 | grep "inet " | awk '{print $2}' | cut -d/ -f1

# Пример: 192.168.1.200
```

### 4.2 Проверка с другого хоста

```bash
# С вашей рабочей машины
curl http://192.168.1.200:11434/api/tags

# Должен вернуть список моделей:
# {"models":[{"name":"phi3:mini","size":2300000000,...}]}
```

### 4.3 Настройка firewall (если нужно)

```bash
# В контейнере (если используется ufw)
apt install -y ufw
ufw allow 11434/tcp
ufw enable
```

---

## 🔄 Интеграция с n8n

### Вариант 1: HTTP Chat Model (рекомендуется)

В n8n используйте узел **"Chat Model"** → **"HTTP Chat Model"**:

**Настройки:**

- **Base URL:** `http://192.168.1.200:11434/api`
- **Model:** `phi3:mini` (или ваша модель)
- **Temperature:** `0.7`
- **Max Tokens:** `500`

### Вариант 2: HTTP Request

Пример узла **"HTTP Request"** в n8n:

```json
{
  "method": "POST",
  "url": "http://192.168.1.200:11434/api/generate",
  "body": {
    "model": "phi3:mini",
    "prompt": "{{$json.input_text}}",
    "stream": false,
    "options": {
      "temperature": 0.7,
      "num_predict": 500
    }
  },
  "headers": {
    "Content-Type": "application/json"
  }
}
```

### Вариант 3: Langchain Agent

См. файл `n8n-voice-assistant-ollama.json` для полного примера

---

## 🐛 Troubleshooting

### Проблема: GPU не виден в контейнере

**Симптомы:**
- `ls /dev/nvidia*` ничего не показывает
- `nvidia-smi` не работает

**Решение:**

```bash
# На Proxmox хосте проверить device nodes
ls -la /dev/nvidia*

# Проверить major/minor номера
ls -l /dev/nvidia0 /dev/nvidiactl

# Обновить конфиг контейнера с правильными номерами
nano /etc/pve/lxc/200.conf

# Перезапустить контейнер
pct stop 200
pct start 200
```

### Проблема: Ollama использует CPU вместо GPU

**Симптомы:**
- Модель работает медленно
- `nvidia-smi` показывает 0% GPU usage

**Решение:**

```bash
# Проверить переменные окружения
systemctl edit ollama

# Добавить:
[Service]
Environment="CUDA_VISIBLE_DEVICES=0"

# Перезапустить
systemctl restart ollama
```

### Проблема: Out of memory при загрузке модели

**Симптомы:**
- Ошибка при `ollama pull` или `ollama run`
- "CUDA out of memory"

**Решение:**

```bash
# Выбрать меньшую модель
# Для 4GB: phi3:mini, llama3.2:3b, gemma2:2b
# Для 6GB: llama3.1:8b, qwen2.5:7b

# Очистить кэш
ollama rm <старая_модель>

# Проверить доступную память
nvidia-smi
```

### Проблема: API недоступен из сети

**Симптомы:**
- `curl http://IP:11434` не работает с другого хоста
- Connection refused

**Решение:**

```bash
# Проверить что Ollama слушает 0.0.0.0
systemctl edit ollama

# Убедиться что есть:
[Service]
Environment="OLLAMA_HOST=0.0.0.0:11434"
Environment="OLLAMA_ORIGINS=*"

# Перезапустить
systemctl restart ollama

# Проверить порт
ss -tulpn | grep 11434
```

### Проблема: Модель отвечает на английском вместо русского

**Решение:**

```bash
# В промпте явно указать язык
curl http://localhost:11434/api/generate -d '{
  "model": "phi3:mini",
  "prompt": "Ответь на русском языке: Как дела?",
  "system": "Ты русскоязычный AI ассистент. Всегда отвечай на русском языке.",
  "stream": false
}'
```

---

## 📊 Сравнение производительности

### Ollama vs GigaChat vs Cloud API

| Параметр | Ollama (локально) | GigaChat | Cloud API |
|----------|-------------------|----------|-----------|
| **Скорость** | ⚡ 50-100 tokens/s | 🐌 20-30 tokens/s | 🚀 100+ tokens/s |
| **Стоимость** | ✅ Бесплатно | ✅ Бесплатная квота | 💰 Платно |
| **Приватность** | ✅ 100% локально | ❌ Облако | ❌ Облако |
| **Качество** | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **Доступность** | ✅ Всегда | ⚠️ Интернет нужен | ⚠️ Интернет нужен |
| **VPN из РФ** | ✅ Не нужен | ✅ Не нужен | ❌ Нужен |

**Рекомендация:**
- **Ollama** - для приватных данных, быстрых ответов, работы без интернета
- **GigaChat** - для лучшего качества на русском языке
- **Cloud API** - если нет GPU и нужно лучшее качество

---

## 🎯 Следующие шаги

1. ✅ Установили Ollama с GPU
2. ✅ Скачали модель phi3:mini
3. 🔄 Интегрируйте с n8n (см. примеры выше)
4. 🔄 Создайте workflow для Home Assistant
5. 🔄 После апгрейда до GTX 1060 скачайте llama3.1:8b

**Готово!** Теперь у вас локальный AI без облаков и VPN! 🚀

---

## 📚 Полезные ссылки

- [Ollama Documentation](https://github.com/ollama/ollama/blob/main/docs/README.md)
- [Ollama API Reference](https://github.com/ollama/ollama/blob/main/docs/api.md)
- [Ollama Models Library](https://ollama.ai/library)
- [Proxmox LXC Documentation](https://pve.proxmox.com/wiki/Linux_Container)
- [n8n Ollama Integration](https://docs.n8n.io/integrations/builtin/cluster-nodes/sub-nodes/n8n-nodes-langchain.lmollamaembeddings/)

---

**Автор:** AI Assistant
**Дата:** Октябрь 2025
**Версия:** 1.0
