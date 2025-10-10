# Ollama на Proxmox с GPU - Пошаговая установка

Непрерывная инструкция по развертыванию Ollama в LXC контейнере на Proxmox VE с NVIDIA GPU для локального AI.

**Время установки:** 20-30 минут  
**Уровень:** Intermediate (требуется опыт работы с Linux и Proxmox)

---

## Конфигурация

**Текущее оборудование:**
- Proxmox VE (любая версия 7.x / 8.x)
- NVIDIA GTX 1050 Ti (4GB VRAM)
- Рекомендуемая модель: `phi3:mini` (2.3GB)

**После апгрейда на GTX 1060:**
- VRAM: 6GB
- Рекомендуемая модель: `llama3.1:8b` (4.7GB)

---

## Шаг 1: Подключение к Proxmox хосту

```bash
ssh root@<PROXMOX_IP>
```

Замените `<PROXMOX_IP>` на IP адрес вашего Proxmox сервера.

---

## Шаг 2: Исправление репозиториев для NVIDIA драйверов

Proxmox требует настройки Debian репозиториев с non-free компонентами для установки проприетарных NVIDIA драйверов.

### 2.1 Скачивание скрипта настройки репозиториев

```bash
wget https://raw.githubusercontent.com/Gfermoto/HASSio_Cursor/main/docs/integrations/fix-proxmox-nvidia-repos.sh
chmod +x fix-proxmox-nvidia-repos.sh
```

### 2.2 Запуск скрипта

```bash
./fix-proxmox-nvidia-repos.sh
```

Скрипт выполнит:
- Определение версии Debian (bookworm/bullseye)
- Создание backup текущего sources.list
- Добавление main, contrib, non-free, non-free-firmware в sources.list
- Отключение enterprise репозитория (требует подписку)
- Обновление индекса пакетов (apt update)
- Поиск доступных версий NVIDIA драйверов
- Установку оптимальной версии (535+)
- Установку pve-headers для текущего ядра
- Настройку blacklist для nouveau драйвера
- Обновление initramfs

При запросе подтверждения введите: `y`

### 2.3 Перезагрузка хоста

После завершения скрипта:

```bash
reboot
```

Хост перезагрузится (~1-2 минуты).

---

## Шаг 3: Проверка NVIDIA драйвера

После перезагрузки подключитесь к хосту:

```bash
ssh root@<PROXMOX_IP>
```

Проверка установки драйвера:

```bash
nvidia-smi
```

Ожидаемый вывод:
```text
+-----------------------------------------------------------------------------+
| NVIDIA-SMI 535.xxx      Driver Version: 535.xxx      CUDA Version: 12.2    |
|-------------------------------+----------------------+----------------------+
| GPU  Name        Persistence-M| Bus-Id        Disp.A | Volatile Uncorr. ECC |
|   0  GeForce GTX 105...  Off  | 00000000:01:00.0 Off |                  N/A |
+-----------------------------------------------------------------------------+
```

Проверка device nodes:

```bash
ls -la /dev/nvidia*
```

Должны быть видны: `nvidia0`, `nvidiactl`, `nvidia-uvm`, `nvidia-modeset`

---

## Шаг 4: Создание LXC контейнера с Ollama

### 4.1 Скачивание основного скрипта установки

```bash
wget https://raw.githubusercontent.com/Gfermoto/HASSio_Cursor/main/docs/integrations/ollama-proxmox-install.sh
chmod +x ollama-proxmox-install.sh
```

### 4.2 Запуск создания контейнера

```bash
./ollama-proxmox-install.sh --create-lxc
```

Скрипт запросит параметры контейнера. Рекомендуемые значения:

```text
CT ID [200]: 200
Hostname [ollama]: ollama
Password: <введите_надежный_пароль>
Storage [local-lvm]: local-lvm
Disk size GB [50]: 50
Memory MB [8192]: 8192
Cores [4]: 4
```

Скрипт автоматически:
1. Создаст привилегированный LXC контейнер Ubuntu 24.04
2. Определит major/minor номера NVIDIA устройств
3. Настроит GPU passthrough в `/etc/pve/lxc/200.conf`
4. Запустит контейнер
5. Установит NVIDIA Container Toolkit внутри контейнера
6. Установит Ollama
7. Настроит systemd сервис для автозапуска
8. Выведет IP адрес контейнера

Запишите IP адрес контейнера из вывода скрипта.

---

## Шаг 5: Проверка работы Ollama

Проверка статуса сервиса:

```bash
pct exec 200 -- systemctl status ollama.service
```

Должно быть: `active (running)`

Проверка API endpoint:

```bash
CONTAINER_IP=$(pct exec 200 -- hostname -I | awk '{print $1}')
curl "http://$CONTAINER_IP:11434/api/tags"
```

Ожидаемый ответ: `{"models":[]}`

---

## Шаг 6: Установка модели

### 6.1 Запуск скрипта установки модели

```bash
./ollama-proxmox-install.sh --install-model
```

### 6.2 Выбор модели

При запросе `CT ID:` введите: `200`

При выборе модели для GTX 1050 Ti (4GB) выберите: `1` (phi3:mini)

Скрипт скачает модель (~2.3GB) и выполнит тестовый запрос.

---

## Шаг 7: Финальная проверка системы

Запуск комплексной проверки:

```bash
./ollama-proxmox-install.sh --check
```

Скрипт проверит:
- GPU device nodes в контейнере
- Статус ollama.service
- Список установленных моделей
- Доступность API

Все проверки должны пройти успешно.

---

## Шаг 8: Тестирование модели

Вход в контейнер:

```bash
pct enter 200
```

Тест модели через CLI:

```bash
ollama run phi3:mini "Привет! Представься кратко на русском языке как AI ассистент"
```

Модель должна ответить на русском языке.

Выход из контейнера:

```bash
exit
```

Тест API с хоста:

```bash
CONTAINER_IP=$(pct exec 200 -- hostname -I | awk '{print $1}')

curl "http://$CONTAINER_IP:11434/api/generate" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "phi3:mini",
    "prompt": "Привет! Ответь кратко на русском",
    "stream": false
  }'
```

Должен вернуть JSON с полем `response` содержащим ответ на русском.

---

## Шаг 9: Интеграция с n8n

### 9.1 Получение файла workflow

Скачайте workflow из GitHub:

```bash
wget https://raw.githubusercontent.com/Gfermoto/HASSio_Cursor/main/docs/integrations/n8n-voice-assistant-ollama.json
```

### 9.2 Импорт в n8n

1. Откройте n8n Web UI
2. Нажмите **Workflows** → **Import from File**
3. Загрузите файл `n8n-voice-assistant-ollama.json`
4. Workflow импортирован с 16 узлами

### 9.3 Конфигурация параметров

Отредактируйте следующие узлы:

**Узел "Ollama: Model":**
- Параметр `baseURL`: `http://<CONTAINER_IP>:11434`
- Параметр `model`: `phi3:mini`

**Узел "HA: Get All States":**
- Параметр `url`: `http://<HA_IP>:8123/api/states`
- Credential: создайте HTTP Header Auth с `Authorization: Bearer <HA_TOKEN>`

**Узел "Telegram: Trigger":**
- Параметр `userIds`: ваш Telegram ID (получите через @userinfobot)
- Credential: создайте Telegram API с токеном от @BotFather

### 9.4 Создание Home Assistant credentials

В n8n:

```text
Credentials → Add Credential → HTTP Header Auth
Name: Authorization
Value: Bearer <YOUR_HA_LONG_LIVED_TOKEN>
Credential Name: Home Assistant API
```

Получение Home Assistant токена:
1. Home Assistant → Профиль (левый нижний угол)
2. Scroll вниз → Long-Lived Access Tokens
3. Create Token → Name: `n8n-ollama`
4. Скопируйте токен

### 9.5 Создание Telegram credentials

В n8n:

```text
Credentials → Add Credential → Telegram API
Access Token: <TOKEN_FROM_BOTFATHER>
Credential Name: Telegram Bot
```

Создание Telegram бота:
1. Откройте @BotFather в Telegram
2. Отправьте: `/newbot`
3. Укажите имя и username
4. Скопируйте полученный токен

Получение вашего Telegram ID:
1. Откройте @userinfobot в Telegram
2. Отправьте любое сообщение
3. Скопируйте ваш ID

### 9.6 Создание Tool workflows

Для работы Agent необходимо создать 5 sub-workflows. Подробные инструкции в [README-ollama-assistant.md](./README-ollama-assistant.md), раздел "Создание Tool Workflows".

Минимальный пример для Tool "Turn On Light":

1. Создайте новый workflow
2. Добавьте узел HTTP Request:
   - Method: POST
   - URL: `http://<HA_IP>:8123/api/services/light/turn_on`
   - Authentication: HTTP Header Auth (Home Assistant API)
   - Body: `{"entity_id": "{{ $json.entity_id }}"}`
3. Сохраните workflow
4. Скопируйте ID workflow и вставьте в параметр `workflowId` узла "Tool: Turn On Light"

Повторите для остальных 4 инструментов.

### 9.7 Активация workflow

1. Сохраните главный workflow
2. Активируйте переключателем справа вверху
3. Откройте Telegram → найдите вашего бота
4. Отправьте: `/start`

Бот должен ответить приветственным сообщением.

---

## Шаг 10: Тестирование интеграции

Отправьте боту команды для проверки:

```text
/help
```

Должна вернуться справка.

```text
Включи свет на кухне
```

Если у вас есть entity `light.kitchen`, бот выполнит команду.

```text
Какая температура?
```

Бот запросит данные сенсоров из Home Assistant.

---

## Производительность

**GTX 1050 Ti + phi3:mini:**
- Latency (cold start): 3-5 секунд
- Latency (warm): 1-2 секунды
- Throughput: 40-60 tokens/sec
- VRAM usage: ~2.5GB / 4GB

**Мониторинг GPU:**

```bash
# На Proxmox хосте
watch -n 1 nvidia-smi

# Во время inference должно показывать:
# GPU-Util: 80-100%
# Memory-Usage: ~2500MB / 4096MB
```

---

## Обслуживание

### Проверка состояния

```bash
# Статус контейнера
pct status 200

# Статус Ollama сервиса
pct exec 200 -- systemctl status ollama.service

# Список моделей
pct exec 200 -- ollama list
```

### Обновление Ollama

```bash
pct enter 200
curl -fsSL https://ollama.ai/install.sh | sh
systemctl restart ollama.service
exit
```

### Backup контейнера

```bash
# Snapshot контейнера
pct snapshot 200 "before-model-update-$(date +%Y%m%d)"

# Backup в файл
vzdump 200 --mode snapshot --storage local --compress gzip
```

### Добавление новой модели

После апгрейда на GTX 1060 (6GB):

```bash
pct enter 200
ollama pull llama3.1:8b
ollama list
exit
```

Обновите параметр `model` в n8n узле "Ollama: Model" на `llama3.1:8b`.

---

## Troubleshooting

### Проблема: nvidia-smi не найден после перезагрузки

```bash
# Проверка установленного драйвера
dpkg -l | grep nvidia-driver

# Переустановка nvidia-utils
DRIVER_VER=$(dpkg -l | grep nvidia-driver | awk '{print $2}' | grep -oP '\d+$')
apt install -y "nvidia-utils-$DRIVER_VER"
```

### Проблема: GPU не виден в контейнере

```bash
# На хосте: проверка device nodes
ls -la /dev/nvidia*

# Проверка конфигурации контейнера
cat /etc/pve/lxc/200.conf | grep -A 10 "GPU Passthrough"

# Рестарт контейнера
pct stop 200
pct start 200

# Проверка в контейнере
pct exec 200 -- ls -la /dev/nvidia*
```

### Проблема: Ollama медленно отвечает

```bash
# Проверка использования GPU
pct enter 200
ollama run phi3:mini "test" &
nvidia-smi

# GPU-Util должно быть >80%
# Если 0%, проверьте:
systemctl cat ollama.service | grep CUDA_VISIBLE_DEVICES
```

Если переменная не установлена:

```bash
systemctl edit ollama.service
```

Добавьте:
```ini
[Service]
Environment="CUDA_VISIBLE_DEVICES=0"
```

Сохраните и перезапустите:

```bash
systemctl daemon-reload
systemctl restart ollama.service
exit
```

### Проблема: n8n не может подключиться к Ollama

```bash
# Проверка что Ollama слушает на 0.0.0.0
pct exec 200 -- ss -tlnp | grep 11434

# Должно быть: 0.0.0.0:11434
# Если 127.0.0.1:11434, исправьте:

pct exec 200 -- systemctl edit ollama.service
```

Добавьте:
```ini
[Service]
Environment="OLLAMA_HOST=0.0.0.0:11434"
Environment="OLLAMA_ORIGINS=*"
```

Сохраните:

```bash
pct exec 200 -- systemctl daemon-reload
pct exec 200 -- systemctl restart ollama.service
```

---

## Следующие шаги

1. ✅ NVIDIA драйверы установлены на Proxmox хост
2. ✅ LXC контейнер создан и настроен
3. ✅ Ollama запущен с GPU support
4. ✅ Модель phi3:mini загружена
5. ✅ API доступен по сети
6. ✅ n8n workflow импортирован
7. ✅ Telegram бот настроен
8. 🔄 Создайте 5 Tool workflows для Home Assistant
9. 🔄 Протестируйте команды управления
10. 🔄 После апгрейда GPU установите llama3.1:8b

---

## Дополнительная документация

- [OLLAMA-PROXMOX-SETUP.md](./OLLAMA-PROXMOX-SETUP.md) - техническая документация
- [README-ollama-assistant.md](./README-ollama-assistant.md) - детали n8n интеграции
- [OLLAMA-SUMMARY.md](./OLLAMA-SUMMARY.md) - сводка и сравнение решений

---

**Установка завершена!** Теперь у вас локальный AI для Home Assistant без зависимости от облачных сервисов.
