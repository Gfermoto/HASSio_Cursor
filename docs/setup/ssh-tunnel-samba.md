# 🔒 SSH туннель для SAMBA (безопасный доступ)

Как безопасно монтировать Home Assistant config через интернет без проброса SAMBA портов.

---

## 🎯 Проблема

**Проброс SAMBA (порты 139, 445) напрямую = критическая уязвимость!**

**Риски:**

- ❌ SMB эксплойты (WannaCry, EternalBlue)
- ❌ Нет шифрования трафика
- ❌ Легко взломать пароль
- ❌ DDoS атаки

**Решение:** SSH туннель для SAMBA!

---

## ✅ SSH туннель: Как это работает

```text
┌──────────────────────────────────────────────────────────────┐
│                                                              │
│  Cursor (WSL) ──┐                                            │
│                 │                                            │
│                 ↓ SSH (зашифровано) ✅                       │
│                                                              │
│  ┌──────────────┴────────────┐                              │
│  │   SSH туннель (port 2222)  │                              │
│  │   localhost:8445 ──→ HA:445│                              │
│  └──────────────┬────────────┘                              │
│                 │                                            │
│                 ↓ SAMBA (внутри туннеля) 🔒                 │
│                                                              │
│  Home Assistant (192.168.1.20:445)                           │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

**Преимущества:**

- ✅ SAMBA трафик шифруется через SSH
- ✅ Порт 445 НЕ открыт в интернет
- ✅ Используется SSH аутентификация (ключи)
- ✅ Безопасно как SSH

---

## 🚀 Быстрый старт (5 минут)

### Шаг 1: Проброс SSH на MikroTik

**На роутере MikroTik:**

```routeros
/ip firewall nat
add action=netmap chain=dstnat \
    comment="SSH to HA (non-standard port)" \
    dst-address=YOUR_WHITE_IP \
    dst-port=2222 \
    protocol=tcp \
    to-addresses=192.168.1.20 \
    to-ports=22
```

**Замените:**

- `YOUR_WHITE_IP` → ваш белый IP (например: `203.0.113.10`)

### Шаг 2: Защита от brute-force

```routeros
/ip firewall filter
add action=add-src-to-address-list address-list=ssh_stage1 \
    address-list-timeout=1m chain=forward connection-state=new \
    dst-address=192.168.1.20 dst-port=22 protocol=tcp

add action=add-src-to-address-list address-list=ssh_stage2 \
    address-list-timeout=5m chain=forward connection-state=new \
    dst-address=192.168.1.20 dst-port=22 protocol=tcp \
    src-address-list=ssh_stage1

add action=add-src-to-address-list address-list=ssh_blacklist \
    address-list-timeout=1d chain=forward connection-state=new \
    dst-address=192.168.1.20 dst-port=22 protocol=tcp \
    src-address-list=ssh_stage2

add action=drop chain=forward dst-address=192.168.1.20 \
    dst-port=22 protocol=tcp src-address-list=ssh_blacklist
```

**Результат:** 3 неудачных попытки за минуту = бан на сутки

### Шаг 3: Создать SSH туннель в Cursor

**В Cursor (WSL):**

```bash
# Создать SSH туннель для SAMBA
ssh -p 2222 -L 8445:192.168.1.20:445 root@YOUR_WHITE_IP -N -f

# Проверить что туннель работает
ps aux | grep "ssh.*8445"
# Должен показать процесс SSH туннеля
```

**Параметры:**

- `-p 2222` - порт SSH
- `-L 8445:192.168.1.20:445` - локальный порт 8445 → HA порт 445
- `-N` - не выполнять команды, только туннель
- `-f` - запустить в фоне

### Шаг 4: Монтировать SAMBA через туннель

```bash
# Монтировать config через SSH туннель
sudo mount -t cifs //localhost:8445/config ~/HASSio/config \
  -o username=homeassistant,password=YOUR_SAMBA_PASSWORD,port=8445

# Проверить
ls ~/HASSio/config/
# Должны увидеть configuration.yaml, automations.yaml, и т.д.
```

---

## 🔧 Интеграция с scripts/mount.sh

### Обновить mount.sh для SSH туннеля

**Добавить в `scripts/mount.sh`:**

```bash
#!/bin/bash

# Режим работы (local или remote)
MODE=${MODE:-"local"}

if [ "$MODE" = "remote" ]; then
    # Удаленный доступ через SSH туннель

    echo "🌐 Создание SSH туннеля..."

    # Параметры (замените на свои!)
    REMOTE_HOST="YOUR_WHITE_IP"
    SSH_PORT="2222"
    LOCAL_TUNNEL_PORT="8445"
    HA_IP="192.168.1.20"
    HA_SAMBA_PORT="445"

    # Проверить что туннель не создан
    if pgrep -f "ssh.*${LOCAL_TUNNEL_PORT}:${HA_IP}:${HA_SAMBA_PORT}" > /dev/null; then
        echo "✅ SSH туннель уже создан"
    else
        # Создать туннель
        ssh -p "${SSH_PORT}" \
            -L "${LOCAL_TUNNEL_PORT}:${HA_IP}:${HA_SAMBA_PORT}" \
            -o ConnectTimeout=10 \
            -o ServerAliveInterval=60 \
            -o ServerAliveCountMax=3 \
            root@"${REMOTE_HOST}" \
            -N -f

        if [ $? -eq 0 ]; then
            echo "✅ SSH туннель создан"
        else
            echo "❌ Ошибка создания SSH туннеля"
            exit 1
        fi
    fi

    # Монтировать через туннель
    SAMBA_HOST="localhost"
    SAMBA_PORT="${LOCAL_TUNNEL_PORT}"
else
    # Локальный доступ (как обычно)
    SAMBA_HOST="192.168.1.20"
    SAMBA_PORT="445"
fi

# Монтирование
echo "📁 Монтирование config..."

sudo mount -t cifs "//${SAMBA_HOST}:${SAMBA_PORT}/config" ~/HASSio/config \
    -o username=homeassistant,password="${SAMBA_PASSWORD}",port="${SAMBA_PORT}"

if [ $? -eq 0 ]; then
    echo "✅ Config смонтирован"
else
    echo "❌ Ошибка монтирования"
    exit 1
fi
```

**Использование:**

```bash
# Локально (дома)
./scripts/mount.sh

# Удаленно (через SSH туннель)
MODE=remote ./scripts/mount.sh
```

---

## 🔒 Безопасность

### На MikroTik:

**✅ Что настроено:**

1. SSH на нестандартном порту (2222, не 22)
2. Fail2ban: 3 попытки = бан на сутки
3. SAMBA порт 445 **НЕ проброшен** (безопасно!)

### На Home Assistant:

**Обязательно настроить:**

```bash
# SSH в HA
nano /etc/ssh/sshd_config

# Изменить:
PasswordAuthentication no  # Только ключи!
PubkeyAuthentication yes
PermitRootLogin prohibit-password

# Применить
systemctl restart ssh

# Fail2ban (опционально)
apt install fail2ban
systemctl enable fail2ban
```

---

## 🐛 Troubleshooting

### Проблема: Туннель не создается

**Проверка:**

```bash
# Тест SSH подключения
ssh -p 2222 root@YOUR_WHITE_IP

# Если работает - туннель тоже должен работать
```

**Решение:**

```bash
# Убить старый туннель
pkill -f "ssh.*8445"

# Создать заново
ssh -p 2222 -L 8445:192.168.1.20:445 root@YOUR_WHITE_IP -N -f
```

### Проблема: SAMBA не монтируется

**Проверка:**

```bash
# Проверить что туннель работает
netstat -tlnp | grep 8445
# Должно показать: tcp 0 0 127.0.0.1:8445 ... LISTEN

# Тест SAMBA через туннель
smbclient -p 8445 -L //localhost -U homeassistant
```

**Решение:**

```bash
# Переподключить туннель
pkill -f "ssh.*8445"
ssh -p 2222 -L 8445:192.168.1.20:445 root@YOUR_WHITE_IP -N -f

# Попробовать монтировать
sudo mount -t cifs //localhost:8445/config ~/HASSio/config \
  -o username=homeassistant,password=YOUR_PASSWORD,port=8445
```

### Проблема: Туннель падает

**Автоматическое пересоздание:**

```bash
# Добавить в crontab
crontab -e

# Проверять каждые 5 минут
*/5 * * * * pgrep -f "ssh.*8445" || ssh -p 2222 -L 8445:192.168.1.20:445 root@YOUR_WHITE_IP -N -f
```

---

## 📊 Сравнение методов доступа

| Метод | Безопасность | Скорость | Сложность | Работает в РФ |
|-------|--------------|----------|-----------|---------------|
| **ZeroTier** | ⭐⭐⭐⭐⭐ | Быстро | Простая | ❌ Не в мобильных |
| **SSH туннель** | ⭐⭐⭐⭐ | Быстро | Средняя | ✅ Везде |
| **Прямой SAMBA** | ⭐ | Быстро | Простая | ❌ ОПАСНО! |
| **VPN (WireGuard)** | ⭐⭐⭐⭐⭐ | Быстро | Сложная | ✅ Везде |

---

## 💡 Рекомендации

### **Дома (WiFi):**

```bash
# ZeroTier работает!
ssh root@192.168.1.20
sudo mount -t cifs //192.168.1.20/config ~/HASSio/config
```

### **В дороге (мобильный интернет РФ):**

```bash
# SSH туннель (ZeroTier заблокирован)
ssh -p 2222 -L 8445:192.168.1.20:445 root@YOUR_WHITE_IP -N -f
sudo mount -t cifs //localhost:8445/config ~/HASSio/config -o port=8445
```

### **Универсальный скрипт:**

Автоматически определяет где вы:

```bash
# scripts/smart_mount.sh

# Проверить доступность ZeroTier
if ping -c 1 -W 2 192.168.1.20 &>/dev/null; then
    # ZeroTier работает (или дома)
    echo "✅ Локальный доступ / ZeroTier"
    MODE=local ./scripts/mount.sh
else
    # Используем SSH туннель
    echo "🌐 SSH туннель"
    MODE=remote ./scripts/mount.sh
fi
```

---

## 🔐 Важные напоминания

### ⚠️ НИКОГДА не делайте:

- ❌ Проброс SAMBA портов 139, 445 напрямую
- ❌ Использование слабых паролей для SAMBA
- ❌ SSH на стандартном порту 22

### ✅ ВСЕГДА делайте:

- ✅ SSH на нестандартном порту (2222, 2233, и т.д.)
- ✅ Только SSH ключи (не пароли)
- ✅ SAMBA через SSH туннель
- ✅ Fail2ban защита

---

## 📚 См. также

- [Настройка SSH в HA](./SETUP.md#ssh) - первичная настройка
- [Настройка SAMBA](./SETUP.md#samba) - конфигурация addon
- [Смешанный режим ZeroTier](./zerotier-mixed-mode.md) - альтернатива туннелю

---

**SSH туннель = безопасный способ работы с SAMBA через интернет!** 🔒✨
