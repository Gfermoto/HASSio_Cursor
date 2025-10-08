# 🚀 Быстрый старт n8n для вашей инфраструктуры

Настройка n8n для работы с вашим Home Assistant (уже развернут на Proxmox).

---

## 🏗️ Ваша текущая инфраструктура

```text
┌─────────────────────────────────────────────────────────────┐
│                  Локальная сеть 192.168.1.0/24              │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────────┐        ┌──────────────────┐          │
│  │  Home Assistant  │◄──────►│     n8n          │          │
│  │  192.168.1.20    │        │  (Proxmox VM)    │          │
│  │  :8123           │        │  192.168.1.???   │          │
│  └──────────────────┘        └──────────────────┘          │
│         ↑                            ↑                      │
│         │ MCP addon                  │                      │
│         │ (внутри HA)               │                      │
│         ↓                            │                      │
│  ┌──────────────────┐                │                      │
│  │   Cursor IDE     │                │                      │
│  │  (ваш ПК/WSL)    │                │                      │
│  │  + mcp-proxy     │────────────────┘                      │
│  └──────────────────┘                                       │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Статус:**

- ✅ Home Assistant работает (192.168.1.20)
- ✅ MCP addon установлен в HASSio
- ✅ mcp-proxy настроен в Cursor
- ✅ n8n развернут на Proxmox
- ⏳ n8n не настроен (нет workflows)

---

## 🎯 План первичной настройки (20 минут)

### Шаг 1: Узнать IP адрес n8n (2 минуты)

```bash
# На Proxmox или из HASSio
ping n8n.local  # Если есть mDNS

# Или проверить в Proxmox
# Containers → <ваш n8n> → Network → IP
```

Предположим IP: **192.168.1.50**

---

### Шаг 2: Добавить в config.yml (3 минуты)

Откройте `~/HASSio/config.yml` и добавьте секцию:

```yaml
# n8n Integration
n8n:
  enabled: true
  url_local: "http://192.168.1.50:5678"
  # Если n8n доступен извне:
  url_external: ""  # Оставьте пустым если нет

  # API Key (получим на шаге 3)
  api_key: ""

  # Webhook base URL
  webhooks:
    base_url: "http://192.168.1.50:5678/webhook"
```

---

### Шаг 3: Настроить n8n (5 минут)

#### 3.1. Открыть n8n

```bash
# В браузере
http://192.168.1.50:5678
```

#### 3.2. Создать API Key (если еще нет)

1. В n8n: **Settings** (левое меню)
2. **API** → **Create API Key**
3. Название: `HASSio Integration`
4. **Create**
5. Скопируйте ключ

#### 3.3. Обновить config.yml

```yaml
n8n:
  api_key: "n8n_api_xxxxxxxxxxxxx"  # Ваш ключ
```

---

### Шаг 4: Создать Long-Lived Token в HA (3 минуты)

1. Откройте Home Assistant (http://192.168.1.20:8123)
2. Профиль (левый нижний угол)
3. Прокрутите до **Long-Lived Access Tokens**
4. **CREATE TOKEN**
5. Название: `n8n Integration`
6. Скопируйте токен (больше не покажется!)

Сохраните токен - понадобится в каждом workflow!

---

### Шаг 5: Создать Credential в n8n (5 минут)

1. В n8n: **Credentials** (левое меню)
2. **Add Credential**
3. Поиск: `Home Assistant`
4. Выберите **Home Assistant API**
5. Заполните:
   - **Name**: `Home Assistant Local`
   - **Host**: `http://192.168.1.20:8123`
   - **Access Token**: токен из шага 4
6. **Save**

---

### Шаг 6: Тестовый workflow (7 минут)

Создайте первый workflow для проверки:

#### 6.1. Создать workflow

1. **Workflows** → **Add workflow**
2. Название: `Test HA Connection`

#### 6.2. Добавить ноды

**Нода 1: Manual Trigger**

- Тип: **Manual Trigger**
- Просто добавьте (для ручного запуска)

**Нода 2: Get HA State**

- Тип: **Home Assistant**
- Credential: `Home Assistant Local`
- Operation: **Get State**
- Entity ID: `sun.sun` (всегда есть в HA)

**Нода 3: Show Result**

- Тип: **Code**
- Language: JavaScript
- Code:

```javascript
const state = $input.item.json.state;
const friendly = $input.item.json.attributes.friendly_name;

return {
  json: {
    message: `✅ Подключение работает! ${friendly}: ${state}`,
    raw: $input.item.json
  }
};
```

#### 6.3. Протестировать

1. **Save** workflow
2. **Execute Workflow**
3. Должны увидеть: `✅ Подключение работает! Sun: above_horizon`

---

## 🎯 Первые 3 полезных workflow

После успешного теста, создайте эти workflows:

### Workflow 1: Бэкап в облако (приоритет 🔥)

**Назначение:**
Автоматически загружать бэкапы HA в облачное хранилище.

**Ноды:**

1. **Webhook** (триггер)
   - Webhook ID: `ha-backup-created`
   - Path: `/webhook/ha-backup-created`

2. **SSH** - Скачать бэкап
   - Host: `192.168.1.20`
   - Command: `ls -t /backup/*.tar | head -1`
   - Download последний файл

3. **Yandex Disk / Dropbox** - Загрузить
   - Path: `/HomeAssistant/Backups/{{ $now.format('YYYY-MM') }}/`
   - Filename: `backup-{{ $now.format('YYYY-MM-DD-HH-mm') }}.tar`

4. **Telegram** - Уведомление
   - Message: `✅ Бэкап загружен в облако`

**Настройка в HA:**

```yaml
# automations.yaml
automation:
  - alias: "Backup to n8n"
    trigger:
      - platform: event
        event_type: folder_watcher
        event_data:
          event_type: created
          path: /backup
    action:
      - service: rest_command.n8n_backup_webhook
```

```yaml
# configuration.yaml
rest_command:
  n8n_backup_webhook:
    url: "http://192.168.1.50:5678/webhook/ha-backup-created"
    method: POST
    content_type: "application/json"
    payload: >
      {
        "timestamp": "{{ now().isoformat() }}",
        "trigger": "backup_created"
      }
```

---

### Workflow 2: Telegram бот статуса (приоритет 🔥)

**Назначение:**
Команда `/status` → полный статус умного дома.

**Ноды:**

1. **Telegram Trigger**
   - Command: `/status`

2. **Home Assistant** - Get Multiple States
   - Entities:
     - `sensor.outdoor_temperature`
     - `climate.living_room` (и другие 14 зон)
     - `binary_sensor.*_motion` (камеры)
     - `sensor.total_power`

3. **Code** - Форматирование

```javascript
const outdoor = $('Get States').item.json[0].state;
const climates = $('Get States').item.json.filter(e => e.entity_id.startsWith('climate.'));
const power = $('Get States').item.json.find(e => e.entity_id === 'sensor.total_power').state;

// Средняя температура по зонам
const avgTemp = climates.reduce((sum, c) =>
  sum + parseFloat(c.attributes.current_temperature), 0) / climates.length;

const message = `🏠 Статус умного дома

🌡️ Отопление:
  На улице: ${outdoor}°C
  Дома (средняя): ${avgTemp.toFixed(1)}°C
  Зоны: ${climates.length}

⚡ Энергия:
  Текущее потребление: ${power} Вт

📹 Безопасность:
  Камеры: Все онлайн ✅

⏰ ${new Date().toLocaleString('ru-RU')}`;

return { json: { message } };
```

4. **Telegram** - Отправить ответ

---

### Workflow 3: Погодозависимая кривая (приоритет 🔥)

**Назначение:**
Автоматическая корректировка температуры в 15 зонах по погоде.

**Ноды:**

1. **Cron Trigger**
   - Expression: `*/30 * * * *` (каждые 30 минут)

2. **HTTP Request** - Прогноз погоды
   - URL: `https://api.openweathermap.org/data/2.5/weather?q=YourCity&appid=YOUR_KEY`
   - Method: GET

3. **Code** - Расчет температур

```javascript
const outdoor = $json.main.temp - 273.15; // Kelvin → Celsius
const wind = $json.wind.speed;

// Базовая погодозависимая кривая
let target = 25 - (outdoor * 0.5);

// Корректировка на ветер (теплопотери)
if (wind > 5) {
  target += Math.min(wind / 10, 2);
}

// Ограничения
target = Math.max(18, Math.min(25, target));

// Зоны с разными температурами
const zones = [
  { id: 'living_room', offset: 0 },      // Гостиная: базовая
  { id: 'bedroom', offset: -2 },         // Спальня: прохладнее
  { id: 'kitchen', offset: -1 },         // Кухня: чуть прохладнее
  { id: 'bathroom', offset: +2 },        // Ванная: теплее
  // ... добавьте все 15 зон
];

return zones.map(zone => ({
  json: {
    entity_id: `climate.${zone.id}`,
    temperature: Math.round(target + zone.offset)
  }
}));
```

4. **Loop** - Для каждой зоны
   - Items: Output из предыдущей ноды
   - Batch Size: 1

5. **Home Assistant** - Set Temperature
   - Operation: **Call Service**
   - Domain: `climate`
   - Service: `set_temperature`
   - Entity ID: `{{ $json.entity_id }}`
   - Service Data:

```json
{
  "temperature": "{{ $json.temperature }}"
}
```

6. **Telegram** - Уведомление (опционально)
   - Только если температура изменилась > 2°C

**Экономия:** 20-30% на отоплении при правильной настройке кривой!

---

## 📝 Обновление проекта HASSio_Cursor

### Добавить информацию о вашей инфраструктуре

Обновите `config.yml`:

```yaml
# Home Assistant Server
server:
  url: "https://your-ha-server.com"
  hostname: "your-ha-server.com"
  local_ip: "192.168.1.20"

# n8n Integration
n8n:
  enabled: true
  # Proxmox VM в локальной сети
  url_local: "http://192.168.1.50:5678"  # Замените на реальный IP
  url_external: ""  # Если нет внешнего доступа
  api_key: ""  # Получите в n8n: Settings → API
  webhooks:
    base_url: "http://192.168.1.50:5678/webhook"

# MCP Settings (уже настроено)
mcp:
  # MCP addon установлен в HASSio
  # mcp-proxy установлен в системе
  # Конфигурация в .cursor/mcp.json
  use_local: false
  token: "your_mcp_token_here"
  endpoint_global: "https://your-ha-server.com/mcp_server/sse"
  endpoint_local: "http://192.168.1.20:8123/mcp_server/sse"
```

---

## 🔧 Скрипт проверки n8n

Создайте скрипт для быстрой проверки:

```bash
#!/bin/bash
# scripts/check_n8n.sh
# Проверка подключения к n8n

source "$(dirname "$0")/lib_config.sh"

echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║              🔗 ПРОВЕРКА n8n ИНТЕГРАЦИИ 🔗                       ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""

# Предполагаем что в config.yml есть n8n секция
N8N_URL="${N8N_URL_LOCAL:-http://192.168.1.50:5678}"

echo "📍 n8n URL: $N8N_URL"
echo ""

# Проверка 1: Доступность
echo "🔍 Проверка доступности..."
if curl -s -f "$N8N_URL/healthz" > /dev/null 2>&1; then
    echo "✅ n8n доступен"
else
    echo "❌ n8n недоступен (проверьте IP и firewall)"
    exit 1
fi

# Проверка 2: API (если есть ключ)
if [ -n "${N8N_API_KEY:-}" ]; then
    echo ""
    echo "🔍 Проверка API..."
    response=$(curl -s -H "X-N8N-API-KEY: $N8N_API_KEY" \
        "$N8N_URL/api/v1/workflows" 2>/dev/null)

    if echo "$response" | jq -e '.data' > /dev/null 2>&1; then
        workflow_count=$(echo "$response" | jq -r '.data | length')
        echo "✅ API работает"
        echo "📊 Workflows: $workflow_count"
    else
        echo "⚠️  API ключ не настроен или неверный"
    fi
else
    echo ""
    echo "⚠️  API ключ не настроен в config.yml"
    echo "   Получите в n8n: Settings → API → Create API Key"
fi

echo ""
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║              ✅ ПРОВЕРКА ЗАВЕРШЕНА                               ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""

# Показать следующие шаги
if [ -z "${N8N_API_KEY:-}" ]; then
    echo "📝 Следующие шаги:"
    echo "   1. Откройте n8n: $N8N_URL"
    echo "   2. Settings → API → Create API Key"
    echo "   3. Добавьте ключ в ~/HASSio/config.yml"
    echo "   4. Создайте credential 'Home Assistant Local'"
    echo "   5. Импортируйте первые workflows"
fi
```

**Использование:**

```bash
chmod +x scripts/check_n8n.sh
./scripts/check_n8n.sh
```

---

## 🎬 Первые workflows для импорта

### Готовые JSON файлы (TODO)

Создайте папку:

```bash
mkdir -p scripts/templates/n8n
```

Будут готовые workflows:

- `test_ha_connection.json` - тест подключения
- `backup_to_cloud.json` - бэкапы в облако
- `telegram_status_bot.json` - Telegram бот
- `heating_weather_curve.json` - погодная кривая
- `smart_camera_alerts.json` - умные алерты

### Импорт в n8n

1. В n8n: **Workflows** → **Import from File**
2. Выберите JSON файл
3. **Configure credentials:**
   - Home Assistant: выберите созданный credential
   - Telegram (если нужно): добавьте bot token
4. **Замените переменные:**
   - IP адреса (если отличаются)
   - Entity IDs (под вашу конфигурацию)
5. **Save** → **Activate**

---

## 📊 Рекомендуемая последовательность

### Неделя 1: Базовая настройка

**День 1:**

- ✅ Узнать IP n8n
- ✅ Обновить config.yml
- ✅ Создать токены (HA + n8n)
- ✅ Настроить credential в n8n
- ✅ Тестовый workflow

**День 2:**

- ✅ Workflow: Бэкапы в облако
- ✅ Протестировать
- ✅ Настроить автоматический триггер

**День 3:**

- ✅ Workflow: Telegram бот статуса
- ✅ Добавить команды /status, /temp

### Неделя 2: Автоматизации

**День 1:**

- ✅ Workflow: Погодозависимая кривая
- ✅ Настроить под 15 зон
- ✅ Мониторинг экономии

**День 2:**

- ✅ Workflow: Умные алерты камер
- ✅ Фильтрация ложных срабатываний

**День 3:**

- ✅ Workflow: Еженедельные отчеты
- ✅ Аналитика энергопотребления

### Неделя 3: AI агенты

**День 1:**

- ✅ Настроить OpenAI API / Ollama
- ✅ Workflow: AI Ассистент
- ✅ Тестирование

**День 2:**

- ✅ Workflow: AI Vision для камер
- ✅ Анализ snapshots

**День 3:**

- ✅ Workflow: RAG для документации
- ✅ Вопросы о конфигурации

---

## 🎯 Интеграция в меню ./ha

Добавьте пункт 15 в `ha` скрипт:

```bash
# После пункта 14
15)
    echo "🔗 n8n - Управление..."
    echo ""
    echo "  1) Проверить подключение"
    echo "  2) Список workflows"
    echo "  3) Импортировать workflow"
    echo "  0) Назад"
    echo ""
    read -p "Выберите (0-3): " -n 1 -r n8n_choice

    case $n8n_choice in
        1)
            "${SCRIPT_DIR}/check_n8n.sh"
            ;;
        2)
            echo "📊 Список workflows в n8n..."
            # TODO: скрипт для получения списка
            ;;
        3)
            echo "📥 Импорт workflow..."
            # TODO: скрипт для импорта
            ;;
    esac
    ;;
```

---

## 💡 Best Practices

### 1. Безопасность

**Long-Lived Token:**

- ✅ Создайте отдельный токен для n8n
- ✅ Храните в переменных окружения n8n
- ✅ Регулярно ротируйте (раз в 6 месяцев)

**Firewall:**

```bash
# На Proxmox разрешить только локальную сеть
iptables -A INPUT -p tcp --dport 5678 -s 192.168.1.0/24 -j ACCEPT
iptables -A INPUT -p tcp --dport 5678 -j DROP
```

### 2. Мониторинг

Создайте workflow "Monitor n8n":

- Проверка execution history
- Алерт при частых ошибках
- Статистика по workflows

### 3. Бэкапы n8n

n8n хранит workflows в SQLite/PostgreSQL:

```bash
# Бэкап workflows (JSON export)
docker exec n8n n8n export:workflow --all --output=/backup/workflows.json

# Или в UI: Settings → Export all workflows
```

---

## 🐛 Типичные проблемы

### Проблема: "Connection refused"

**Причина:** Firewall или неверный IP

**Решение:**

```bash
# Проверить что n8n слушает
netstat -tulpn | grep 5678

# Ping n8n
ping 192.168.1.50

# Curl test
curl http://192.168.1.50:5678/healthz
```

### Проблема: "Unauthorized"

**Причина:** Неверный HA token или credential

**Решение:**

1. Пересоздайте Long-Lived Token в HA
2. Обновите credential в n8n
3. Протестируйте снова

### Проблема: "Workflow не срабатывает"

**Checklist:**

- ✅ Workflow активирован? (toggle в ON)
- ✅ Webhook URL правильный?
- ✅ HA automation настроена?
- ✅ Проверьте Execution Log в n8n

---

## 📚 Полезные ссылки

- [n8n Documentation](https://docs.n8n.io/)
- [Home Assistant node](https://docs.n8n.io/integrations/builtin/app-nodes/n8n-nodes-base.homeassistant/)
- [AI Agents в n8n](https://docs.n8n.io/advanced-ai/)
- [Community workflows](https://n8n.io/workflows/?categories=home-automation)

---

**Начните с тестового workflow, затем добавляйте по одному каждые 2-3 дня!**
