# Ollama на Proxmox VE с NVIDIA GPU - Technical Guide

Техническая документация по развертыванию Ollama в LXC контейнере на Proxmox VE с GPU passthrough для локального inference LLM моделей.

---

## Содержание

- [Архитектура решения](#архитектура-решения)
- [Требования](#требования)
- [Подготовка Proxmox хоста](#подготовка-proxmox-хоста)
- [Создание LXC контейнера](#создание-lxc-контейнера)
- [Установка и конфигурация Ollama](#установка-и-конфигурация-ollama)
- [Выбор и оптимизация моделей](#выбор-и-оптимизация-моделей)
- [Мониторинг и обслуживание](#мониторинг-и-обслуживание)
- [Troubleshooting](#troubleshooting)

---

## Архитектура решения

### Выбор LXC vs VM

**LXC контейнер (выбрано):**
- ✅ Прямой доступ к GPU без полного passthrough
- ✅ Минимальный overhead (~2-5% vs bare metal)
- ✅ Простое управление через `pct` CLI
- ✅ Быстрое создание и клонирование

**VM (не рекомендуется):**
- ❌ Требует PCI passthrough (IOMMU groups, VT-d)
- ❌ Overhead эмуляции (~10-15%)
- ❌ Сложнее миграция и backup
- ❌ Требует dedicated GPU

### Компоненты системы

```text
┌─────────────────────────────────────────┐
│         Proxmox VE Host                 │
│  ┌───────────────────────────────────┐  │
│  │    NVIDIA Driver (host)           │  │
│  │    nvidia-smi, kernel modules     │  │
│  └───────────────────────────────────┘  │
│              │ (device nodes)           │
│              ↓                           │
│  ┌───────────────────────────────────┐  │
│  │    LXC Container (privileged)     │  │
│  │  ┌─────────────────────────────┐  │  │
│  │  │ NVIDIA Container Toolkit    │  │  │
│  │  │ libnvidia-container         │  │  │
│  │  └─────────────────────────────┘  │  │
│  │  ┌─────────────────────────────┐  │  │
│  │  │ Ollama Service              │  │  │
│  │  │ API: 0.0.0.0:11434          │  │  │
│  │  │ Models: /root/.ollama       │  │  │
│  │  └─────────────────────────────┘  │  │
│  └───────────────────────────────────┘  │
└─────────────────────────────────────────┘
           │ (network: vmbr0)
           ↓
  ┌────────────────────┐
  │  n8n / Clients     │
  │  HTTP API calls    │
  └────────────────────┘
```

---

## Требования

### Аппаратное обеспечение

**Минимум:**
- CPU: 4 cores (host + container)
- RAM: 16GB total (8GB для container)
- GPU: NVIDIA Pascal+ (GTX 1050 Ti, GTX 1060+)
- Storage: 50GB для контейнера + models

**Рекомендуется:**
- CPU: 8+ cores
- RAM: 32GB+ total
- GPU: NVIDIA Turing+ (RTX 2060+)
- Storage: NVMe SSD для моделей

### Программное обеспечение

**Proxmox хост:**
- Proxmox VE 7.4+ или 8.x
- Kernel 5.15+ или 6.x
- NVIDIA Driver 535.xx или новее

**LXC контейнер:**
- Ubuntu 22.04 LTS или 24.04 LTS
- Ollama latest (устанавливается автоматически)

---

## Получение скрипта автоматизации

Данная документация описывает ручную установку для понимания процесса. Для автоматизации используйте скрипт `ollama-proxmox-install.sh` из GitHub репозитория.

### Скачивание с GitHub

Скрипт доступен в публичном репозитории: [HASSio_Cursor/docs/integrations](https://github.com/Gfermoto/HASSio_Cursor/tree/main/docs/integrations)

```bash
# SSH на Proxmox хост
ssh root@<PROXMOX_IP>

# Скачивание скрипта напрямую с GitHub
wget https://raw.githubusercontent.com/Gfermoto/HASSio_Cursor/main/docs/integrations/ollama-proxmox-install.sh \
  -O /root/ollama-proxmox-install.sh

# Установка прав на выполнение
chmod +x /root/ollama-proxmox-install.sh

# Проверка скрипта
ls -lh /root/ollama-proxmox-install.sh
head -20 /root/ollama-proxmox-install.sh  # Просмотр начала скрипта
```

### Использование скрипта

**Интерактивный режим (рекомендуется для первого раза):**

```bash
./ollama-proxmox-install.sh
```

Откроется меню:
```text
1) Установить NVIDIA драйверы на хост
2) Создать LXC контейнер с Ollama
3) Установить модель в контейнер
4) Проверить установку
5) Выход
```

**CLI режим (для автоматизации):**

```bash
# Установка NVIDIA драйверов на хост (первый запуск)
./ollama-proxmox-install.sh --install-host

# После перезагрузки хоста: создание LXC контейнера
./ollama-proxmox-install.sh --create-lxc

# Установка модели
./ollama-proxmox-install.sh --install-model

# Проверка системы
./ollama-proxmox-install.sh --check
```

**Примечание:** Далее описана ручная установка для понимания всех шагов. Для production используйте скрипт автоматизации.

---

## Подготовка Proxmox хоста

### 1. Проверка GPU

```bash
lspci | grep -i nvidia
# Вывод: 01:00.0 VGA compatible controller: NVIDIA Corporation GP107 [GeForce GTX 1050 Ti]
```

Проверка IOMMU (опционально для LXC, но полезно знать):

```bash
dmesg | grep -i iommu
# Если пусто, IOMMU отключен (для LXC не критично)
```

### 2. Конфигурация APT репозиториев

Proxmox использует Debian, нужно добавить `non-free` для проприетарных драйверов:

```bash
# Backup текущей конфигурации
cp /etc/apt/sources.list /etc/apt/sources.list.backup

# Добавление non-free и non-free-firmware
sed -i 's/main$/main contrib non-free non-free-firmware/' /etc/apt/sources.list

# Для Proxmox 8 (Debian Bookworm)
cat /etc/apt/sources.list
# Должно содержать: deb http://deb.debian.org/debian bookworm main contrib non-free non-free-firmware

apt update
```

### 3. Установка NVIDIA драйверов

```bash
# Установка headers для текущего ядра
apt install -y "pve-headers-$(uname -r)"

# Поиск доступных версий драйверов
apt-cache search --names-only '^nvidia-driver-[0-9]+$'

# Обычно доступны версии: 525, 535, 545, 550
# Рекомендуется 535+ (поддержка CUDA 12.2+)

# Установка конкретной версии (замените 535 на доступную в вашей системе)
apt install -y nvidia-driver-535 nvidia-smi

# Для автоматического выбора последней версии:
NVIDIA_DRIVER=$(apt-cache search --names-only '^nvidia-driver-[0-9]+$' | \
  awk '{print $1}' | sort -V | tail -1)
apt install -y "$NVIDIA_DRIVER" nvidia-smi

# Blacklist nouveau (открытый драйвер)
cat > /etc/modprobe.d/blacklist-nouveau.conf << EOF
blacklist nouveau
options nouveau modeset=0
EOF

# Обновление initramfs
update-initramfs -u

# Перезагрузка хоста
reboot
```

### 4. Верификация установки

После перезагрузки:

```bash
# Проверка драйвера
nvidia-smi

# Должен показать:
# - GPU model
# - Driver Version: 535.xx.xx
# - CUDA Version: 12.2
# - GPU Memory: используется / total
# - Processes: пусто (если никто не использует)

# Проверка kernel modules
lsmod | grep nvidia
# Должны быть: nvidia, nvidia_uvm, nvidia_modeset, nvidia_drm

# Проверка device nodes
ls -la /dev/nvidia*
# /dev/nvidia0        - основное GPU устройство
# /dev/nvidiactl      - control устройство
# /dev/nvidia-uvm     - unified memory
# /dev/nvidia-modeset - mode setting
```

### 5. Определение device numbers

Для конфигурации LXC нужны major/minor номера устройств:

```bash
stat -c 'Major: %t, Minor: %T' /dev/nvidia0
stat -c 'Major: %t, Minor: %T' /dev/nvidiactl
stat -c 'Major: %t, Minor: %T' /dev/nvidia-uvm

# Конвертация из hex в decimal для lxc.cgroup2.devices.allow
# Обычно:
# nvidia0:    195 (major), 0 (minor)
# nvidiactl:  195 (major), 255 (minor)
# nvidia-uvm: 508 или 511 (major), 0 (minor)
```

---

## Создание LXC контейнера

### 1. Создание через pct CLI

```bash
# Скачивание template (если еще нет)
pveam update
pveam download local ubuntu-24.04-standard_24.04-2_amd64.tar.zst

# Создание контейнера
pct create 200 \
  local:vztmpl/ubuntu-24.04-standard_24.04-2_amd64.tar.zst \
  --hostname ollama \
  --password <STRONG_PASSWORD> \
  --cores 4 \
  --memory 8192 \
  --swap 2048 \
  --storage local-lvm \
  --rootfs local-lvm:50 \
  --net0 name=eth0,bridge=vmbr0,ip=dhcp,firewall=1 \
  --unprivileged 0 \
  --features nesting=1 \
  --onboot 1 \
  --ostype ubuntu
```

**Важно:** `--unprivileged 0` создает привилегированный контейнер, необходимый для доступа к GPU.

### 2. Конфигурация GPU passthrough

Редактирование `/etc/pve/lxc/200.conf`:

```bash
cat >> /etc/pve/lxc/200.conf << 'EOF'

# ================== GPU Passthrough ==================
# Device cgroup permissions
lxc.cgroup2.devices.allow: c 195:* rwm
lxc.cgroup2.devices.allow: c 508:* rwm

# Mount NVIDIA device nodes
lxc.mount.entry: /dev/nvidia0 dev/nvidia0 none bind,optional,create=file
lxc.mount.entry: /dev/nvidiactl dev/nvidiactl none bind,optional,create=file
lxc.mount.entry: /dev/nvidia-uvm dev/nvidia-uvm none bind,optional,create=file
lxc.mount.entry: /dev/nvidia-modeset dev/nvidia-modeset none bind,optional,create=file
lxc.mount.entry: /dev/nvidia-uvm-tools dev/nvidia-uvm-tools none bind,optional,create=file

# Security settings for GPU access
lxc.apparmor.profile: unconfined
lxc.cap.drop:
lxc.cgroup2.devices.allow: a
lxc.mount.auto: proc:rw sys:rw
EOF
```

**Примечание:** Если major номера отличаются, замените `195` и `508` на актуальные значения из step 5 предыдущего раздела.

### 3. Запуск и первичная настройка

```bash
# Запуск контейнера
pct start 200

# Проверка статуса
pct status 200

# Вход в контейнер
pct enter 200

# Внутри контейнера: проверка GPU devices
ls -la /dev/nvidia*
# Должны быть видны все device nodes
```

---

## Установка и конфигурация Ollama

### 1. Подготовка контейнера

Внутри LXC контейнера (после `pct enter 200`):

```bash
# System update
apt update && apt upgrade -y

# Базовые утилиты
apt install -y curl wget gnupg2 software-properties-common ca-certificates

# Проверка connectivity
curl -I https://ollama.ai
```

### 2. Установка NVIDIA Container Toolkit

NVIDIA Container Toolkit обеспечивает runtime для GPU в контейнерах без полной установки драйверов:

```bash
# Определение дистрибутива
distribution=$(. /etc/os-release; echo "$ID$VERSION_ID")

# Добавление NVIDIA GPG ключа
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | \
  gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg

# Добавление репозитория
curl -s -L "https://nvidia.github.io/libnvidia-container/$distribution/libnvidia-container.list" | \
  sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
  tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

# Установка
apt update
apt install -y nvidia-container-toolkit

# Верификация
nvidia-container-cli --version
```

### 3. Установка Ollama

```bash
# Официальный install script
curl -fsSL https://ollama.ai/install.sh | sh

# Проверка установки
ollama --version
which ollama  # /usr/local/bin/ollama
```

### 4. Конфигурация systemd сервиса

Ollama автоматически создает systemd unit, но нужно настроить сетевой binding:

```bash
# Создание override для systemd unit
systemctl edit ollama.service
```

Добавить в редакторе:

```ini
[Service]
Environment="OLLAMA_HOST=0.0.0.0:11434"
Environment="OLLAMA_ORIGINS=*"
Environment="OLLAMA_MODELS=/root/.ollama/models"
Environment="CUDA_VISIBLE_DEVICES=0"
Restart=always
RestartSec=3
```

Применение изменений:

```bash
systemctl daemon-reload
systemctl enable ollama.service
systemctl start ollama.service

# Проверка статуса
systemctl status ollama.service

# Проверка логов
journalctl -u ollama.service -f
```

### 5. Верификация API endpoint

```bash
# Внутри контейнера
curl http://localhost:11434/api/tags

# С хоста Proxmox (замените IP на IP контейнера)
CONTAINER_IP=$(pct exec 200 -- ip -4 addr show eth0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
curl "http://$CONTAINER_IP:11434/api/tags"

# Должен вернуть JSON: {"models":[]}
```

---

## Выбор и оптимизация моделей

### Матрица совместимости моделей

#### GTX 1050 Ti (4GB VRAM)

| Модель | Size | VRAM | Quantization | Tokens/s | Use Case |
|--------|------|------|--------------|----------|----------|
| **phi3:mini** | 2.3GB | ~2.5GB | Q4_K_M | 40-60 | General, HA commands |
| **llama3.2:3b** | 2GB | ~2.2GB | Q4_K_M | 50-70 | Fast responses |
| **qwen2.5:3b** | 2GB | ~2.2GB | Q4_K_M | 40-60 | Multilingual |
| **gemma2:2b** | 1.6GB | ~1.8GB | Q4_K_M | 80+ | Simple tasks |
| llama3.1:8b | 4.7GB | ~5GB | Q4_K_M | N/A | ❌ OOM |

**Рекомендация:** `phi3:mini` для production use.

#### GTX 1060 (6GB VRAM)

| Модель | Size | VRAM | Quantization | Tokens/s | Use Case |
|--------|------|------|--------------|----------|----------|
| **llama3.1:8b** | 4.7GB | ~5GB | Q4_K_M | 30-50 | Best quality |
| **qwen2.5:7b** | 4.7GB | ~5GB | Q4_K_M | 30-50 | Multilingual |
| phi3:mini | 2.3GB | ~2.5GB | Q4_K_M | 60-80 | Fast, good quality |
| mixtral:8x7b | 26GB | ~28GB | Q4_K_M | N/A | ❌ OOM |

**Рекомендация:** `llama3.1:8b` после апгрейда GPU.

### Установка модели

```bash
# Внутри контейнера
pct enter 200

# Для GTX 1050 Ti
ollama pull phi3:mini

# Мониторинг загрузки
watch -n 1 'du -sh /root/.ollama/models/*'

# После загрузки - тест
ollama run phi3:mini "Напиши короткое приветствие на русском"
```

### Оптимизация параметров

Создание Modelfile для custom конфигурации:

```bash
cat > /root/phi3-optimized.Modelfile << 'EOF'
FROM phi3:mini

# System prompt для Home Assistant
SYSTEM """Ты русскоязычный ассистент умного дома. Отвечай кратко и по делу. 
Используй предоставленные функции для управления устройствами."""

# Параметры generation
PARAMETER temperature 0.7
PARAMETER top_p 0.9
PARAMETER top_k 40
PARAMETER repeat_penalty 1.1
PARAMETER num_ctx 4096
PARAMETER num_predict 512

# Stop tokens
PARAMETER stop <|end|>
PARAMETER stop <|im_end|>
EOF

# Создание custom модели
ollama create phi3-ha -f /root/phi3-optimized.Modelfile

# Использование
ollama run phi3-ha "Тест оптимизированной модели"
```

---

## Мониторинг и обслуживание

### Мониторинг GPU

```bash
# Real-time monitoring
watch -n 1 nvidia-smi

# Парсинг для метрик
nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total,temperature.gpu \
  --format=csv,noheader,nounits
```

### Мониторинг Ollama

```bash
# Логи в реальном времени
journalctl -u ollama.service -f

# Статистика запросов через API
curl http://localhost:11434/api/ps
```

### Backup и восстановление

```bash
# На хосте Proxmox

# Backup контейнера (snapshot)
pct snapshot 200 ollama-backup-$(date +%Y%m%d)

# Backup моделей отдельно
pct exec 200 -- tar -czf /root/ollama-models-backup.tar.gz /root/.ollama/models
pct pull 200 /root/ollama-models-backup.tar.gz ./ollama-models-backup.tar.gz

# Восстановление моделей
pct push 200 ./ollama-models-backup.tar.gz /root/ollama-models-backup.tar.gz
pct exec 200 -- tar -xzf /root/ollama-models-backup.tar.gz -C /
```

### Обновление Ollama

```bash
pct enter 200

# Ollama обновляется тем же install script
curl -fsSL https://ollama.ai/install.sh | sh

# Рестарт сервиса
systemctl restart ollama.service

# Проверка версии
ollama --version
```

---

## Troubleshooting

### NVIDIA драйвер не найден при установке

**Симптомы:**
```text
E: Package 'nvidia-driver' has no installation candidate
E: Package 'nvidia-smi' has no installation candidate
```

**Причина:**  
В Debian/Proxmox пакет называется не `nvidia-driver`, а с указанием версии: `nvidia-driver-XXX`

**Решение:**

1. Поиск доступных версий:
```bash
apt-cache search --names-only '^nvidia-driver-[0-9]+$'
# Вывод: nvidia-driver-525, nvidia-driver-535, nvidia-driver-545, etc.
```

2. Установка конкретной версии:
```bash
# Рекомендуется 535+ для CUDA 12.2+ support
apt install -y nvidia-driver-535 nvidia-smi
```

3. Автоматический выбор последней версии:
```bash
NVIDIA_DRIVER=$(apt-cache search --names-only '^nvidia-driver-[0-9]+$' | \
  awk '{print $1}' | sort -V | tail -1)
echo "Устанавливаю: $NVIDIA_DRIVER"
apt install -y "$NVIDIA_DRIVER" nvidia-smi
```

4. Если драйверы вообще не найдены, проверьте репозитории:
```bash
# Проверка non-free в sources.list
grep 'non-free' /etc/apt/sources.list

# Должно содержать: main contrib non-free non-free-firmware
# Если нет, добавьте:
sed -i 's/main$/main contrib non-free non-free-firmware/' /etc/apt/sources.list
apt update
```

**Примечание:** Скрипт `ollama-proxmox-install.sh` автоматически определяет и устанавливает правильную версию.

### GPU не виден в контейнере

**Симптомы:**
```bash
ls /dev/nvidia*
# ls: cannot access '/dev/nvidia*': No such file or directory
```

**Решение:**

1. Проверка на хосте:
```bash
ls -la /dev/nvidia*
# Должны быть видны устройства
```

2. Проверка major/minor номеров:
```bash
stat -c '%t:%T' /dev/nvidia0
# Например: c3:0 (hex) = 195:0 (decimal)
```

3. Проверка конфигурации контейнера:
```bash
cat /etc/pve/lxc/200.conf | grep -A 15 "GPU Passthrough"
```

4. Пересоздание device nodes вручную (workaround):
```bash
pct enter 200

# Создание device nodes с правильными номерами
mknod /dev/nvidia0 c 195 0
mknod /dev/nvidiactl c 195 255
mknod /dev/nvidia-uvm c 508 0
mknod /dev/nvidia-modeset c 195 254

chmod 666 /dev/nvidia*
```

5. Рестарт контейнера:
```bash
pct stop 200
pct start 200
```

### Ollama не использует GPU

**Симптомы:**
- Медленный inference (CPU mode)
- `nvidia-smi` показывает 0% GPU utilization

**Диагностика:**

```bash
pct enter 200

# Проверка видимости GPU для Ollama
CUDA_VISIBLE_DEVICES=0 nvidia-smi

# Проверка переменных окружения
systemctl cat ollama.service | grep Environment

# Тест с явным указанием GPU
CUDA_VISIBLE_DEVICES=0 ollama run phi3:mini "test"
```

**Решение:**

```bash
# Добавление CUDA_VISIBLE_DEVICES в systemd unit
systemctl edit ollama.service

# Добавить:
[Service]
Environment="CUDA_VISIBLE_DEVICES=0"

systemctl daemon-reload
systemctl restart ollama.service
```

### Out of Memory (OOM)

**Симптомы:**
- Ollama крашится при загрузке модели
- Kernel OOM killer убивает процесс

**Решение:**

1. Проверка доступной VRAM:
```bash
nvidia-smi --query-gpu=memory.free --format=csv,noheader,nounits
```

2. Использование меньшей модели или другой квантизации:
```bash
# Вместо Q4_K_M использовать Q3_K_M (меньше VRAM, хуже качество)
ollama pull phi3:mini-q3_K_M  # если доступна

# Или меньшую модель
ollama pull gemma2:2b
```

3. Увеличение swap в контейнере:
```bash
# На хосте
pct set 200 --swap 4096
pct reboot 200
```

### API Connection Refused

**Симптомы:**
```bash
curl http://<CONTAINER_IP>:11434/api/tags
# curl: (7) Failed to connect to <IP> port 11434: Connection refused
```

**Решение:**

1. Проверка статуса сервиса:
```bash
pct exec 200 -- systemctl status ollama.service
```

2. Проверка binding:
```bash
pct exec 200 -- ss -tlnp | grep 11434
# Должно показать: 0.0.0.0:11434 (не 127.0.0.1)
```

3. Проверка переменной OLLAMA_HOST:
```bash
pct exec 200 -- systemctl cat ollama.service | grep OLLAMA_HOST
# Должно быть: Environment="OLLAMA_HOST=0.0.0.0:11434"
```

4. Проверка firewall (если включен):
```bash
pct exec 200 -- ufw status
# Если active, добавить правило:
pct exec 200 -- ufw allow 11434/tcp
```

### Медленный inference

**Ожидается:** 40-60 tokens/s на GTX 1050 Ti  
**Наблюдается:** <10 tokens/s

**Диагностика:**

```bash
# Во время inference запустить nvidia-smi
nvidia-smi dmon -s u

# Проверить GPU utilization
# Должно быть >80% во время generation
```

**Возможные причины:**

1. Работает на CPU (см. "Ollama не использует GPU")
2. Thermal throttling:
```bash
nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader
# Если >85°C, проверить cooling
```

3. Power limit:
```bash
nvidia-smi -q -d POWER
# Если Current Power близко к Power Limit, карта throttles
```

---

## Performance Tuning

### Kernel parameters

На Proxmox хосте:

```bash
cat >> /etc/sysctl.conf << 'EOF'
# NVIDIA performance tuning
vm.swappiness=10
vm.dirty_ratio=10
vm.dirty_background_ratio=5
EOF

sysctl -p
```

### NVIDIA persistence mode

```bash
# На хосте
nvidia-smi -pm 1

# Сохранить настройку после reboot
cat > /etc/systemd/system/nvidia-persistenced.service << 'EOF'
[Unit]
Description=NVIDIA Persistence Daemon
Wants=syslog.target

[Service]
Type=forking
PIDFile=/var/run/nvidia-persistenced/nvidia-persistenced.pid
Restart=always
ExecStart=/usr/bin/nvidia-persistenced --user root --persistence-mode --verbose
ExecStopPost=/bin/rm -rf /var/run/nvidia-persistenced

[Install]
WantedBy=multi-user.target
EOF

systemctl enable nvidia-persistenced.service
systemctl start nvidia-persistenced.service
```

### CPU pinning

Для уменьшения latency можно pin контейнер к specific CPU cores:

```bash
# На хосте
# Предположим, у вас 8 cores (0-7)
# Pin контейнер к cores 4-7
pct set 200 --cpuunits 2048 --cpulimit 4
```

Редактировать `/etc/pve/lxc/200.conf`:

```bash
# Добавить
lxc.cgroup2.cpuset.cpus: 4-7
```

---

## Security Considerations

### Привилегированный контейнер

LXC контейнер запущен в привилегированном режиме (`unprivileged 0`), что означает:

- ⚠️ Root в контейнере = root на хосте
- ⚠️ Потенциальный escape to host
- ⚠️ Не рекомендуется для untrusted workloads

**Mitigation:**

1. Network isolation:
```bash
# Создать отдельный bridge для AI workloads
# /etc/network/interfaces
auto vmbr1
iface vmbr1 inet static
    address 10.0.100.1/24
    bridge-ports none
    bridge-stp off
    bridge-fd 0
    post-up iptables -t nat -A POSTROUTING -s 10.0.100.0/24 -o vmbr0 -j MASQUERADE
```

2. Firewall rules в Proxmox Firewall UI

3. Регулярные updates контейнера:
```bash
pct exec 200 -- apt update && apt upgrade -y
```

### API access control

По умолчанию Ollama API не имеет authentication. Для production:

1. **Reverse proxy с authentication** (Nginx/Caddy)
2. **Network isolation** (доступ только из trusted networks)
3. **API rate limiting** (через reverse proxy)

Пример Nginx конфигурации:

```nginx
upstream ollama {
    server 10.0.100.2:11434;
}

server {
    listen 443 ssl http2;
    server_name ollama.local;

    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;

    # Basic auth
    auth_basic "Ollama API";
    auth_basic_user_file /etc/nginx/.htpasswd;

    # Rate limiting
    limit_req_zone $binary_remote_addr zone=ollama:10m rate=10r/s;
    limit_req zone=ollama burst=20;

    location / {
        proxy_pass http://ollama;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_read_timeout 300s;
    }
}
```

---

## Заключение

Данная конфигурация обеспечивает:

- ✅ Production-ready deployment Ollama на Proxmox
- ✅ Оптимальное использование GPU без VM overhead
- ✅ Простое управление через `pct` и `systemd`
- ✅ Scalability (можно создать несколько LXC с разными моделями)
- ✅ Backup и disaster recovery через Proxmox встроенные инструменты

**Документация проверена на:**
- Proxmox VE 8.1.4
- NVIDIA Driver 535.154.05
- Ubuntu 24.04 LTS (container)
- Ollama 0.11.10
- GTX 1050 Ti 4GB

---

**Автор:** AI Assistant (Technical Writer & DevOps)  
**Последнее обновление:** Октябрь 2025  
**Версия:** 2.0
