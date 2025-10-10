# ⚡ Ollama на Proxmox с GPU - Quick Start

Развертывание Ollama в LXC контейнере на Proxmox VE с NVIDIA GPU passthrough для локального AI в Home Assistant.

---

## Предварительные требования

### Аппаратное обеспечение
- Proxmox VE 7.x или 8.x
- NVIDIA GPU с архитектурой Pascal или новее (GTX 1050 Ti / GTX 1060+)
- Минимум 8GB RAM свободно
- 50GB+ свободного дискового пространства

### Текущая конфигурация
- GPU: GTX 1050 Ti (4GB VRAM)
- Планируемый апгрейд: GTX 1060 (6GB VRAM)

### Рекомендуемые модели

**GTX 1050 Ti (4GB VRAM):**
- `phi3:mini` (2.3GB, ~40-60 tok/s) - рекомендуется
- `llama3.2:3b` (2GB, ~50-70 tok/s) - быстрее
- `qwen2.5:3b` (2GB, ~40-60 tok/s) - альтернатива

**GTX 1060 (6GB VRAM):**
- `llama3.1:8b` (4.7GB, ~30-50 tok/s) - рекомендуется после апгрейда

---

## Установка

### 1. Скачивание скрипта установки на Proxmox

Скрипт доступен в GitHub репозитории: [HASSio_Cursor/docs/integrations](https://github.com/Gfermoto/HASSio_Cursor/tree/main/docs/integrations)

**Скачивание напрямую с GitHub:**

```bash
# SSH на Proxmox хост
ssh root@<PROXMOX_IP>

# Скачивание скрипта с GitHub
wget https://raw.githubusercontent.com/Gfermoto/HASSio_Cursor/main/docs/integrations/ollama-proxmox-install.sh -O /root/ollama-proxmox-install.sh

# Установка прав на выполнение
chmod +x /root/ollama-proxmox-install.sh

# Проверка скрипта
ls -lh /root/ollama-proxmox-install.sh
```

### 2. Установка NVIDIA драйверов на хост

**Важно:** Этот шаг выполняется один раз на Proxmox хосте.

```bash
./ollama-proxmox-install.sh --install-host
```

Скрипт выполнит:
- Добавление non-free репозиториев в APT
- Установку `pve-headers` для текущего ядра
- Установку `nvidia-driver` и `nvidia-smi`
- Blacklist драйвера `nouveau`
- Обновление `initramfs`

После завершения потребуется перезагрузка хоста:

```bash
reboot
```

Проверка после перезагрузки:

```bash
nvidia-smi
```

Ожидаемый вывод: таблица с информацией о GPU, драйвере и CUDA версией.

### 3. Создание LXC контейнера с Ollama

После успешной установки драйверов и перезагрузки:

```bash
./ollama-proxmox-install.sh --create-lxc
```

Параметры контейнера (значения по умолчанию):
- **CT ID:** 200
- **Hostname:** ollama
- **Password:** задается пользователем
- **Storage:** local-lvm
- **Disk:** 50GB
- **Memory:** 8192MB
- **Swap:** 2048MB
- **Cores:** 4
- **Network:** vmbr0 (DHCP)

Скрипт автоматически:
1. Создаст привилегированный LXC контейнер (Ubuntu 24.04)
2. Настроит GPU passthrough в `/etc/pve/lxc/<CTID>.conf`:
   - Device cgroup permissions для NVIDIA устройств
   - Mount entries для `/dev/nvidia*`
   - AppArmor unconfined profile
3. Установит NVIDIA Container Toolkit внутри контейнера
4. Установит и настроит Ollama как systemd сервис
5. Откроет API на `0.0.0.0:11434`

После завершения будет выведен IP адрес контейнера.

### 4. Установка модели

Для GTX 1050 Ti:

```bash
./ollama-proxmox-install.sh --install-model
```

Выберите модель: **1** (phi3:mini)

Скрипт:
- Скачает модель (~2.3GB)
- Выполнит тестовый запрос на русском языке
- Проверит работу GPU

### 5. Проверка системы

Комплексная проверка установки:

```bash
./ollama-proxmox-install.sh --check
```

Проверяется:
- Наличие GPU device nodes в контейнере
- Статус systemd сервиса `ollama.service`
- Список установленных моделей
- Доступность API endpoint

---

## Интеграция с n8n

### Импорт workflow

```bash
# Локально
cd /home/gfer/HASSio
# Файл: docs/integrations/n8n-voice-assistant-ollama.json
```

В n8n Web UI:
1. **Workflows** → **Import from File**
2. Выберите `n8n-voice-assistant-ollama.json`
3. Workflow импортирован с 16 узлами

### Конфигурация параметров

**Ollama Chat Model Node:**
- Base URL: `http://<CONTAINER_IP>:11434`
- Model: `phi3:mini`

**Home Assistant HTTP Request Node:**
- URL: `http://<HA_IP>:8123/api/states`
- Authentication: HTTP Header Auth
- Header: `Authorization: Bearer <LONG_LIVED_TOKEN>`

**Telegram Trigger Node:**
- User IDs: ваш Telegram ID (получить через @userinfobot)
- Credential: Telegram Bot Token (от @BotFather)

**Tool Workflows:**

Создайте 5 отдельных sub-workflows для Home Assistant operations:
- `turn_on_light` - POST to `/api/services/light/turn_on`
- `turn_off_light` - POST to `/api/services/light/turn_off`
- `set_temperature` - POST to `/api/services/climate/set_temperature`
- `activate_scene` - POST to `/api/services/scene/turn_on`
- `get_sensor_state` - GET from `/api/states/<entity_id>`

Подробная конфигурация: [README-ollama-assistant.md](./README-ollama-assistant.md)

### Активация

1. Сохраните все workflows
2. Активируйте главный workflow (toggle справа вверху)
3. Отправьте `/start` боту в Telegram

---

## Производительность

### GTX 1050 Ti + phi3:mini

| Метрика | Значение |
|---------|----------|
| Latency (cold) | 3-5s |
| Latency (warm) | 1-2s |
| Throughput | 40-60 tokens/s |
| VRAM Usage | ~2.5GB / 4GB |
| Context Window | 4096 tokens |

### GTX 1060 + llama3.1:8b (после апгрейда)

| Метрика | Значение |
|---------|----------|
| Latency (cold) | 4-7s |
| Latency (warm) | 2-3s |
| Throughput | 30-50 tokens/s |
| VRAM Usage | ~5GB / 6GB |
| Context Window | 8192 tokens |

---

## Troubleshooting

### GPU не виден в контейнере

```bash
# На Proxmox хосте
ls -la /dev/nvidia*

# Проверить major/minor номера
stat -c '%t:%T' /dev/nvidia0 /dev/nvidiactl

# Проверить конфигурацию контейнера
cat /etc/pve/lxc/<CTID>.conf | grep -A 10 "GPU Passthrough"

# Рестарт контейнера
pct stop <CTID> && pct start <CTID>
```

### Ollama не отвечает

```bash
# В контейнере
pct enter <CTID>

# Проверить статус сервиса
systemctl status ollama.service

# Проверить логи
journalctl -u ollama.service -n 50 --no-pager

# Проверить порт
ss -tlnp | grep 11434
```

### API недоступен из сети

```bash
# В контейнере
systemctl cat ollama.service | grep Environment

# Должно быть:
# Environment="OLLAMA_HOST=0.0.0.0:11434"
# Environment="OLLAMA_ORIGINS=*"

# Если нет, редактируем
systemctl edit ollama.service
# Добавить в [Service]:
# Environment="OLLAMA_HOST=0.0.0.0:11434"
# Environment="OLLAMA_ORIGINS=*"

systemctl daemon-reload
systemctl restart ollama.service
```

---

## Дополнительная документация

- [OLLAMA-PROXMOX-SETUP.md](./OLLAMA-PROXMOX-SETUP.md) - детальная техническая документация
- [README-ollama-assistant.md](./README-ollama-assistant.md) - полная конфигурация n8n
- [OLLAMA-SUMMARY.md](./OLLAMA-SUMMARY.md) - сводка и сравнение решений

---

**Время развертывания:** 15-20 минут  
**Требуемый уровень:** Intermediate (знание Linux, Proxmox, networking)  
**Результат:** Production-ready локальный AI для Home Assistant
