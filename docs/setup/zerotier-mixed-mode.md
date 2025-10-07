# 🌐 ZeroTier + Смешанный режим

Гибридная сеть: локальный доступ + ZeroTier VPN для удалённой работы

---

## 🎯 Ваша конфигурация

```text
┌─────────────────────────────────────────────────────────────┐
│                      ZeroTier Network                        │
│                    (виртуальная сеть)                        │
└─────────────────────────────────────────────────────────────┘
         ↓                    ↓                    ↓
    ┌────────┐          ┌────────┐          ┌────────┐
    │ Локация│          │ Локация│          │ Ноутбук│
    │   #1   │          │   #2   │          │(в пути)│
    └────────┘          └────────┘          └────────┘
         ↓                    ↓                    ↓
    MikroTik            MikroTik         Прямой доступ
    + ZeroTier          + ZeroTier        к ZeroTier
         ↓                    ↓
  Home Assistant     Home Assistant
   192.168.1.X         192.168.2.X
```

**Преимущества:**

✅ **Локально** - быстрый доступ через локальную сеть (SSH/SAMBA)
✅ **Удалённо** - безопасный доступ через ZeroTier VPN
✅ **Автоматическое** - скрипты сами определяют где вы находитесь
✅ **Без проброса портов** - ZeroTier создаёт прямое P2P соединение

---

## 🔧 Архитектура смешанного режима

### Три режима работы скриптов

**1. Local (Локальный)**

```text
Компьютер ──[SSH/SAMBA]──> Home Assistant
  (дома)     192.168.1.X      (прямое подключение)
```

**2. Global (Глобальный)**

```text
Компьютер ──[Internet]──> Белый IP ──> MikroTik ──> Home Assistant
 (в пути)    Порты 22/443                  192.168.1.X
```

**3. Mixed (Смешанный) ← Ваш случай!**

```text
Если дома:
  Компьютер ──[SSH/SAMBA]──> 192.168.1.X (быстро, прямо)

Если не дома:
  Компьютер ──[ZeroTier]──> 10.147.X.X ──> Home Assistant
              (VPN туннель)  (ZeroTier IP)
```

---

## 🚀 Настройка ZeroTier

### Шаг 1: Создать сеть ZeroTier

1. Зарегистрироваться: <https://my.zerotier.com>
2. Создать новую сеть: **Create A Network**
3. Записать **Network ID**: `abcdef1234567890`

### Шаг 2: Настроить ZeroTier на MikroTik

#### Установка ZeroTier на RouterOS v7+

```bash
# Через терминал MikroTik
/system package print
# Убедитесь что версия 7.0+

# Включить ZeroTier
/zerotier enable

# Подключиться к сети
/zerotier join network=abcdef1234567890
```

#### Настройка маршрутизации через static routes

```bash
# Узнать ZeroTier интерфейс
/interface print
# Найдите zt-abcdef (ZeroTier интерфейс)

# Добавить маршрут через ZeroTier
# Например, чтобы добраться до локации #2
/ip route add \
  dst-address=192.168.2.0/24 \
  gateway=10.147.X.X \
  comment="Route to Location #2 via ZeroTier"

# Где 10.147.X.X - ZeroTier IP роутера локации #2
```

#### Разрешить трафик через ZeroTier

```bash
# Firewall: разрешить ZeroTier
/ip firewall filter add \
  chain=input \
  in-interface=zt-abcdef \
  action=accept \
  comment="Allow ZeroTier"

/ip firewall filter add \
  chain=forward \
  in-interface=zt-abcdef \
  action=accept \
  comment="Forward ZeroTier"
```

### Шаг 3: Настроить ZeroTier на компьютере (Linux)

```bash
# Установить ZeroTier
curl -s https://install.zerotier.com | sudo bash

# Подключиться к сети
sudo zerotier-cli join abcdef1234567890

# Проверить статус
sudo zerotier-cli listnetworks
```

### Шаг 4: Авторизовать устройства в панели ZeroTier

1. Перейти: <https://my.zerotier.com>
2. Открыть вашу сеть
3. Прокрутить до **Members**
4. Поставить ✅ **Auth** для каждого устройства
5. Присвоить понятные имена (MikroTik-Home, MikroTik-Office, Laptop)

---

## 📝 Настройка config.yml для смешанного режима

```yaml
# /home/gfer/HASSio/config.yml

mode: "mixed"  # Автоматическое определение

home_assistant:
  # Локальный доступ (когда дома)
  local_ip: "192.168.1.20"
  local_port: 8123

  # ZeroTier доступ (когда не дома)
  zerotier_ip: "10.147.20.100"  # ZeroTier IP вашего HA
  zerotier_port: 8123

  # Глобальный доступ (через белый IP)
  hostname: "hassio.yourdomain.com"
  global_ip: "YOUR_WHITE_IP"
  global_port: 443

ssh:
  username: "root"
  port: 22

  # Локально
  local_ip: "192.168.1.20"

  # Через ZeroTier
  zerotier_ip: "10.147.20.100"

  # Глобально
  global_ip: "YOUR_WHITE_IP"
  global_port: 22

samba:
  username: "homeassistant"
  password: "your_password"

  # Локально
  local_ip: "192.168.1.20"

  # Через ZeroTier
  zerotier_ip: "10.147.20.100"

# Настройки определения режима
detection:
  # IP адрес для проверки локальной сети
  local_gateway: "192.168.1.1"

  # ZeroTier сеть
  zerotier_network: "abcdef1234567890"
```

---

## 🔧 Как работает автоопределение

Скрипты проверяют подключение в следующем порядке:

### 1. Проверка локальной сети

```bash
# Пингуем локальный шлюз
ping -c 1 -W 1 192.168.1.1 >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "Локальная сеть доступна → используем LOCAL"
fi
```

### 2. Проверка ZeroTier

```bash
# Проверяем ZeroTier интерфейс
if zerotier-cli listnetworks | grep -q "OK"; then
    echo "ZeroTier активен → используем ZEROTIER"
fi
```

### 3. Fallback на глобальный

```bash
# Если ни локальная, ни ZeroTier недоступны
echo "Используем глобальный доступ → GLOBAL"
```

---

## 🧪 Тестирование смешанного режима

### Проверка локального доступа

```bash
# Пинг локального HA
ping 192.168.1.20

# SSH локально
ssh root@192.168.1.20

# SAMBA локально
mount | grep hassio
```

### Проверка ZeroTier доступа

```bash
# Проверить статус ZeroTier
sudo zerotier-cli listnetworks
# Должно показать: OK PRIVATE abcdef1234567890

# Узнать ваш ZeroTier IP
ip addr show zt0
# Или
sudo zerotier-cli listnetworks | grep "10.147"

# Пинг HA через ZeroTier
ping 10.147.20.100

# SSH через ZeroTier
ssh root@10.147.20.100

# Home Assistant через ZeroTier
curl http://10.147.20.100:8123
```

### Проверка глобального доступа

```bash
# Через домен
curl https://hassio.yourdomain.com

# SSH через белый IP
ssh root@YOUR_WHITE_IP
```

---

## 📊 Сравнение методов подключения

| Параметр | Локальный | ZeroTier | Глобальный |
|----------|-----------|----------|------------|
| **Скорость** | ⚡⚡⚡ Быстро | ⚡⚡ Средне | ⚡ Медленно |
| **Безопасность** | 🔒 Сеть защищена роутером | 🔒🔒 VPN шифрование | 🔒 Зависит от настройки |
| **Требует интернет** | ❌ Нет | ✅ Да | ✅ Да |
| **Проброс портов** | ❌ Не нужен | ❌ Не нужен | ✅ Нужен |
| **Работает везде** | ❌ Только дома | ✅ Везде | ✅ Везде |
| **NAT traversal** | - | ✅ P2P | ❌ Нужен белый IP |

---

## 🔧 Примеры использования

### Пример 1: Вы дома

```bash
./ha
# Скрипт определит: Локальная сеть доступна
# → Использует SSH/SAMBA напрямую к 192.168.1.20
# → Быстро, без задержек
```

### Пример 2: Вы в кафе с ноутбуком

```bash
# ZeroTier запущен на ноутбуке
./ha
# Скрипт определит: Локальной сети нет, но ZeroTier активен
# → Использует ZeroTier IP: 10.147.20.100
# → Безопасно через VPN туннель
```

### Пример 3: Вы на чужом компьютере (без ZeroTier)

```bash
# Подключение через браузер
https://hassio.yourdomain.com
# → Идёт через белый IP и Reverse Proxy
# → Работает везде, но медленнее
```

---

## 🛠️ Настройка скрипта configure.sh

Скрипт `configure.sh` автоматически создаёт правильную конфигурацию:

```bash
./scripts/configure.sh

# Выберите режим:
# 1) Local  - только локальная сеть
# 2) Global - только через интернет
# 3) Mixed  - автоматическое определение (рекомендуется)
```

**Mixed режим создаст:**
- SSH config с несколькими хостами
- Скрипты проверки доступности
- Автоматическое переключение

---

## 📝 SSH config для смешанного режима

Файл `.ssh/config` будет содержать:

```text
# Локальный доступ (приоритет 1)
Host hassio-local
    HostName 192.168.1.20
    User root
    Port 22
    IdentityFile /home/gfer/HASSio/.ssh/id_hassio
    ConnectTimeout 2

# ZeroTier доступ (приоритет 2)
Host hassio-zt
    HostName 10.147.20.100
    User root
    Port 22
    IdentityFile /home/gfer/HASSio/.ssh/id_hassio
    ConnectTimeout 5

# Глобальный доступ (приоритет 3)
Host hassio-global
    HostName YOUR_WHITE_IP
    User root
    Port 22
    IdentityFile /home/gfer/HASSio/.ssh/id_hassio

# Автоматический выбор
Host hassio
    HostName 192.168.1.20
    User root
    Port 22
    IdentityFile /home/gfer/HASSio/.ssh/id_hassio
    # Скрипты автоматически изменят HostName
```

---

## 🔒 Безопасность ZeroTier

### Преимущества

✅ **End-to-End шифрование** - трафик зашифрован
✅ **P2P соединения** - прямое подключение между устройствами
✅ **Централизованное управление** - контроль доступа в панели
✅ **NAT traversal** - работает за любым NAT/Firewall

### Рекомендации

1. **Включить Flow Rules:**

   В панели ZeroTier → Networks → Flow Rules:


   ```text
   # Разрешить только известные устройства
   tag trusted
     id YOUR_LAPTOP_ID
     id YOUR_MIKROTIK_ID
   ;

   # Блокировать всё остальное
   drop not tag trusted;
   ```

2. **Регулярно проверять Members:**
   - Удалять старые/неиспользуемые устройства
   - Проверять последнюю активность

3. **Использовать приватную сеть:**
   - Network Access Control: **Private**
   - Требует авторизации для каждого устройства

---

## 🆘 Решение проблем

### ZeroTier не подключается

```bash
# Проверить статус
sudo zerotier-cli info
# Должно показать: 200 info [node_id] [version] ONLINE

# Проверить сети
sudo zerotier-cli listnetworks
# Должно показать: OK PRIVATE [network_id]

# Перезапустить ZeroTier
sudo systemctl restart zerotier-one
```

### Медленное соединение через ZeroTier

```bash
# Проверить тип соединения
sudo zerotier-cli peers
# Ищите DIRECT (прямое P2P) или RELAY (через сервер)

# Если RELAY - проверьте firewall
# ZeroTier использует UDP порты 9993
sudo ufw allow 9993/udp
```

### MikroTik не видит ZeroTier сеть

```bash
# Проверить интерфейс
/interface print
# Должен быть zt-[network_id]

# Проверить статус
/zerotier print
# Status: enabled

# Перезапустить ZeroTier
/zerotier leave network=abcdef1234567890
/zerotier join network=abcdef1234567890
```

---

## 📊 Мониторинг

### Проверка всех методов подключения

Создайте скрипт `check_connectivity.sh`:

```bash
#!/bin/bash

echo "🔍 Проверка методов подключения..."
echo ""

# 1. Локальная сеть
echo "1️⃣ Локальная сеть (192.168.1.20):"
if ping -c 1 -W 1 192.168.1.20 >/dev/null 2>&1; then
    echo "   ✅ Доступна"
else
    echo "   ❌ Недоступна"
fi

# 2. ZeroTier
echo "2️⃣ ZeroTier (10.147.20.100):"
if ping -c 1 -W 2 10.147.20.100 >/dev/null 2>&1; then
    echo "   ✅ Доступен"
    zerotier-cli peers | grep -A1 "10.147.20.100" | grep "DIRECT\|RELAY"
else
    echo "   ❌ Недоступен"
fi

# 3. Глобальный
echo "3️⃣ Глобальный (hassio.yourdomain.com):"
if curl -s -I https://hassio.yourdomain.com >/dev/null 2>&1; then
    echo "   ✅ Доступен"
else
    echo "   ❌ Недоступен"
fi
```

---

## 📚 Полезные ссылки

- [ZeroTier Documentation](https://docs.zerotier.com/)
- [ZeroTier MikroTik Setup](https://wiki.mikrotik.com/wiki/Manual:ZeroTier)
- [ZeroTier Network Rules](https://docs.zerotier.com/rules/)
- [Основная документация](SETUP.md)
- [Проброс портов MikroTik](portforward-mikrotik.md)

---

## 📋 Чек-лист настройки

- [ ] ZeroTier сеть создана
- [ ] ZeroTier установлен на всех MikroTik
- [ ] ZeroTier установлен на компьютере
- [ ] Все устройства авторизованы в панели ZeroTier
- [ ] Маршруты настроены на MikroTik (via ZeroTier)
- [ ] config.yml настроен с ZeroTier IP
- [ ] Тест: ping работает через ZeroTier
- [ ] Тест: SSH работает через ZeroTier
- [ ] Тест: Home Assistant доступен через ZeroTier
- [ ] Скрипты автоматически определяют режим

---

## 🎯 Итоговая схема вашей сети

```text
┌─────────────────────────────────────────────────────────┐
│               Ваша гибридная инфраструктура             │
└─────────────────────────────────────────────────────────┘

                    ┌──────────────┐
                    │  ZeroTier    │
                    │   Network    │
                    └──────────────┘
                           ↓
         ┌─────────────────┼─────────────────┐
         ↓                 ↓                 ↓
    ┌─────────┐       ┌─────────┐      ┌─────────┐
    │Локация 1│       │Локация 2│      │ Ноутбук │
    │  (дом)  │       │ (офис)  │      │ (в пути)│
    └─────────┘       └─────────┘      └─────────┘
         ↓                 ↓                 ↓
    MikroTik          MikroTik         ZeroTier
    + ZeroTier        + ZeroTier        клиент
         ↓                 ↓
    192.168.1.0       192.168.2.0
         ↓                 ↓
  Home Assistant    Home Assistant
   + SSH/SAMBA      + SSH/SAMBA

Режимы подключения:
━━━━━ Локально (дома): 192.168.1.20 (быстро)
─ ─ ─ ZeroTier: 10.147.20.100 (безопасно, везде)
┈┈┈┈┈ Глобально: hassio.yourdomain.com (fallback)
```

**Вы получаете лучшее из всех миров:**
- 🏠 Быстро дома
- 🌐 Безопасно через ZeroTier в любой точке
- 🔓 Fallback через белый IP если ZeroTier недоступен

---

**Готово!** Теперь у вас продвинутая гибридная сеть с автоматическим выбором лучшего метода подключения! 🎯
