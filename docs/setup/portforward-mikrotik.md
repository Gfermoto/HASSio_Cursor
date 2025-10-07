# 🌐 Проброс портов на MikroTik с Reverse Proxy

Настройка для белого IP, доменного имени и Reverse Proxy

---

## 🎯 Ваша конфигурация

✅ **Белый статический IP** - прямой доступ из интернета
✅ **Доменное имя** - удобный адрес вместо IP
✅ **Reverse Proxy** - централизованный вход через HTTPS

---

## 📋 Рекомендуемая схема подключения

```text
Интернет
    ↓
[Белый IP / Домен]
    ↓
MikroTik Router (Проброс портов)
    ↓
┌─────────────────────────────────┐
│  Reverse Proxy (Nginx/Traefik)  │  ← Единая точка входа
│  - SSL сертификаты               │
│  - Маршрутизация по доменам      │
└─────────────────────────────────┘
    ↓
┌─────────────────────────────────┐
│  Home Assistant                  │
│  192.168.1.XXX:8123              │
└─────────────────────────────────┘
```

---

## 🔧 Вариант 1: С Reverse Proxy (Рекомендуется)

### Преимущества

✅ Один SSL сертификат для всех сервисов
✅ Автоматическое обновление Let's Encrypt
✅ Защита от DDoS
✅ Централизованные логи
✅ Проще управлять безопасностью

### Порты для проброса

| Сервис | Внешний порт | → | Внутренний порт | IP | Назначение |
|--------|--------------|---|-----------------|-----|------------|
| **HTTPS** | 443 | → | 443 | Reverse Proxy | Весь HTTPS трафик |
| **HTTP** | 80 | → | 80 | Reverse Proxy | Redirect на HTTPS |
| **SSH** | 22 | → | 22 | Home Assistant | Прямой SSH доступ |

### Команды MikroTik

```bash
# Замените:
# - ether1 на ваш WAN интерфейс
# - 192.168.1.5 на IP вашего Reverse Proxy
# - 192.168.1.20 на IP вашего Home Assistant

# 1. HTTPS на Reverse Proxy
/ip firewall nat add \
  chain=dstnat \
  action=dst-nat \
  protocol=tcp \
  dst-port=443 \
  in-interface=ether1 \
  to-addresses=192.168.1.5 \
  to-ports=443 \
  comment="HTTPS to Reverse Proxy"

# 2. HTTP на Reverse Proxy (для редиректа)
/ip firewall nat add \
  chain=dstnat \
  action=dst-nat \
  protocol=tcp \
  dst-port=80 \
  in-interface=ether1 \
  to-addresses=192.168.1.5 \
  to-ports=80 \
  comment="HTTP to Reverse Proxy"

# 3. SSH напрямую к Home Assistant
/ip firewall nat add \
  chain=dstnat \
  action=dst-nat \
  protocol=tcp \
  dst-port=22 \
  in-interface=ether1 \
  to-addresses=192.168.1.20 \
  to-ports=22 \
  comment="SSH to Home Assistant"
```

### Настройка Reverse Proxy (Nginx)

#### /etc/nginx/sites-available/homeassistant

```nginx
# Redirect HTTP to HTTPS
server {
    listen 80;
    server_name hassio.yourdomain.com;
    return 301 https://$server_name$request_uri;
}

# Home Assistant
server {
    listen 443 ssl http2;
    server_name hassio.yourdomain.com;

    # SSL сертификаты (Let's Encrypt)
    ssl_certificate /etc/letsencrypt/live/hassio.yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/hassio.yourdomain.com/privkey.pem;

    # Современные SSL настройки
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    # Безопасность
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;

    # Proxy к Home Assistant
    location / {
        proxy_pass http://192.168.1.20:8123;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # WebSocket поддержка
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
```

#### Получение SSL сертификата

```bash
# Установить certbot
sudo apt install certbot python3-certbot-nginx

# Получить сертификат
sudo certbot --nginx -d hassio.yourdomain.com

# Автообновление (уже настроено)
sudo certbot renew --dry-run
```

---

## 🔧 Вариант 2: Прямой доступ (без Reverse Proxy)

Если Reverse Proxy не используется, пробросьте порты напрямую:

### Порты для проброса

| Сервис | Внешний порт | → | Внутренний порт | IP | Назначение |
|--------|--------------|---|-----------------|-----|------------|
| **Home Assistant** | 8123 | → | 8123 | Home Assistant | Веб-интерфейс |
| **SSH** | 22 | → | 22 | Home Assistant | SSH доступ |
| **SAMBA** | 445 | → | 445 | Home Assistant | Файлы (опасно!) |

⚠️ **Не рекомендуется!** SAMBA через интернет небезопасен!

### Команды MikroTik

```bash
# 1. Home Assistant
/ip firewall nat add \
  chain=dstnat \
  action=dst-nat \
  protocol=tcp \
  dst-port=8123 \
  in-interface=ether1 \
  to-addresses=192.168.1.20 \
  to-ports=8123 \
  comment="HA Web Direct"

# 2. SSH
/ip firewall nat add \
  chain=dstnat \
  action=dst-nat \
  protocol=tcp \
  dst-port=22 \
  in-interface=ether1 \
  to-addresses=192.168.1.20 \
  to-ports=22 \
  comment="SSH Direct"
```

---

## 🔒 Дополнительная безопасность MikroTik

### 1. Защита SSH от брутфорса

```bash
# Создать address list для блокировки
/ip firewall filter add \
  chain=input \
  protocol=tcp \
  dst-port=22 \
  src-address-list=ssh_blacklist \
  action=drop \
  comment="Block SSH attackers"

# Добавлять в blacklist при 3+ попытках
/ip firewall filter add \
  chain=input \
  protocol=tcp \
  dst-port=22 \
  connection-state=new \
  src-address-list=ssh_stage3 \
  action=add-src-to-address-list \
  address-list=ssh_blacklist \
  address-list-timeout=1d

/ip firewall filter add \
  chain=input \
  protocol=tcp \
  dst-port=22 \
  connection-state=new \
  src-address-list=ssh_stage2 \
  action=add-src-to-address-list \
  address-list=ssh_stage3 \
  address-list-timeout=1m

/ip firewall filter add \
  chain=input \
  protocol=tcp \
  dst-port=22 \
  connection-state=new \
  src-address-list=ssh_stage1 \
  action=add-src-to-address-list \
  address-list=ssh_stage2 \
  address-list-timeout=1m

/ip firewall filter add \
  chain=input \
  protocol=tcp \
  dst-port=22 \
  connection-state=new \
  action=add-src-to-address-list \
  address-list=ssh_stage1 \
  address-list-timeout=1m
```

### 2. Rate limiting для веб-доступа

```bash
# Ограничить количество подключений с одного IP
/ip firewall filter add \
  chain=forward \
  protocol=tcp \
  dst-port=443 \
  connection-limit=50,32 \
  action=drop \
  comment="Limit HTTPS connections per IP"
```

### 3. Разрешить только из определённых стран (опционально)

```bash
# Скачать GeoIP базу
/tool fetch url="https://download.mikrotik.com/routeros/geoip.dat"

# Разрешить только из России
/ip firewall address-list add list=allowed_countries address=0.0.0.0/0 comment="Russia" address-list=geoip-c-ru

# Блокировать всё остальное
/ip firewall filter add \
  chain=forward \
  protocol=tcp \
  dst-port=443 \
  src-address-list=!allowed_countries \
  action=drop \
  comment="Block non-RU"
```

---

## 📝 Настройка DNS

### Если у вас есть доменное имя

#### A-запись для домена

В панели управления доменом (например, CloudFlare, Reg.ru):

```text
Тип: A
Имя: hassio
Значение: ВАШ_БЕЛЫЙ_IP
TTL: 300
```

Результат: `hassio.yourdomain.com` → `ВАШ_БЕЛЫЙ_IP`

#### Проверка DNS

```bash
# Linux/Mac
dig hassio.yourdomain.com

# Windows
nslookup hassio.yourdomain.com
```

---

## 🔧 Обновление config.yml

После настройки обновите `config.yml`:

```yaml
home_assistant:
  # Локальный доступ
  local_ip: "192.168.1.20"
  local_port: 8123

  # Глобальный доступ
  hostname: "hassio.yourdomain.com"  # Ваш домен
  global_ip: "ВАШ_БЕЛЫЙ_IP"          # Ваш белый IP
  global_port: 443                    # Через Reverse Proxy (HTTPS)
  use_ssl: true                       # Если через Reverse Proxy

ssh:
  username: "root"
  port: 22
  local_ip: "192.168.1.20"
  global_ip: "ВАШ_БЕЛЫЙ_IP"

samba:
  # SAMBA только локально! Не через интернет!
  username: "homeassistant"
  password: "your_password"
  local_ip: "192.168.1.20"
```

---

## 🧪 Тестирование

### 1. Проверка портов

```bash
# Проверить что порты открыты
nmap -p 443,80,22 ВАШ_БЕЛЫЙ_IP

# Или онлайн
# https://www.yougetsignal.com/tools/open-ports/
```

### 2. Проверка доступа

```bash
# HTTPS
curl -I https://hassio.yourdomain.com

# SSH
ssh root@ВАШ_БЕЛЫЙ_IP

# Или через домен
ssh root@hassio.yourdomain.com
```

### 3. Проверка SSL сертификата

```bash
# Проверить сертификат
openssl s_client -connect hassio.yourdomain.com:443 -servername hassio.yourdomain.com

# Или через браузер
# https://www.ssllabs.com/ssltest/
```

---

## 🆘 Решение проблем

### Порты не открываются

```bash
# Проверить NAT правила
/ip firewall nat print

# Проверить firewall filter
/ip firewall filter print

# Проверить WAN интерфейс
/interface print
```

### SSL не работает

1. Проверьте что DNS настроен правильно
2. Проверьте Nginx конфигурацию: `sudo nginx -t`
3. Проверьте сертификат: `sudo certbot certificates`
4. Проверьте логи: `sudo tail -f /var/log/nginx/error.log`

### Home Assistant недоступен через Reverse Proxy

1. Добавьте в `configuration.yaml`:

   ```yaml
   http:
     use_x_forwarded_for: true
     trusted_proxies:
       - 192.168.1.5  # IP вашего Reverse Proxy
   ```

2. Перезапустите Home Assistant

---

## 📊 Мониторинг

### Логи MikroTik

```bash
# Смотреть логи
/log print

# Смотреть активные подключения
/ip firewall connection print where dst-port=443
```

### Логи Nginx

```bash
# Access log
sudo tail -f /var/log/nginx/access.log

# Error log
sudo tail -f /var/log/nginx/error.log

# Только ошибки HA
sudo tail -f /var/log/nginx/error.log | grep hassio
```

---

## 🔗 Полезные ссылки

- [MikroTik NAT Documentation](https://wiki.mikrotik.com/wiki/Manual:IP/Firewall/NAT)
- [Nginx Reverse Proxy](https://docs.nginx.com/nginx/admin-guide/web-server/reverse-proxy/)
- [Let's Encrypt](https://letsencrypt.org/)
- [Home Assistant Reverse Proxy](https://www.home-assistant.io/docs/configuration/remote/)

---

## 📋 Чек-лист настройки

- [ ] DNS A-запись настроена → `hassio.yourdomain.com`
- [ ] MikroTik: Порты 80, 443, 22 проброшены
- [ ] Reverse Proxy: Nginx установлен и настроен
- [ ] SSL: Сертификат Let's Encrypt получен
- [ ] Home Assistant: `trusted_proxies` настроен
- [ ] Безопасность: SSH брутфорс защита включена
- [ ] Тесты: Доступ работает через домен
- [ ] config.yml обновлён с доменом

---

## ⚠️ Важные рекомендации

1. **Используйте Reverse Proxy!**
   - Один SSL сертификат
   - Лучшая безопасность
   - Проще управление

2. **НЕ открывайте SAMBA в интернет!**
   - Используйте только локально
   - Или через VPN

3. **Регулярно обновляйте:**
   - Home Assistant
   - Nginx
   - MikroTik RouterOS
   - SSL сертификаты (автоматически)

4. **Мониторьте логи:**
   - Nginx access/error logs
   - Home Assistant logs
   - MikroTik logs

---

**Готово!** Теперь у вас безопасный доступ к Home Assistant через доменное имя с SSL! 🔒
