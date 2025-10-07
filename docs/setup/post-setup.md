# 🚀 После установки setup.sh

Что делать дальше после запуска `./scripts/setup.sh`

---

## ✅ Что уже готово

После `setup.sh` у вас есть:

- ✅ SSH ключ в `.ssh/id_hassio.pub`
- ✅ Pre-commit хуки установлены
- ✅ Все скрипты исполняемые
- ✅ Системные пакеты установлены

---

## 📋 Шаг 1: Настроить SSH и SAMBA

Следуйте **[полной инструкции](SETUP.md)** начиная с шага 2.

**Кратко:**

1. Установите в HA add-on: **Terminal & SSH**
2. Добавьте ваш SSH ключ (показан после setup.sh)
3. Установите в HA add-on: **Samba share**
4. Настройте порты на роутере (если нужен доступ извне)

---

## 🤖 Шаг 2: Настроить MCP для AI

```bash
# 1. Создать конфигурацию
cp .cursor/mcp.json.example .cursor/mcp.json

# 2. Получить токен Home Assistant
# Откройте: http://YOUR_HA_IP:8123/profile/security
# Создайте Long-Lived Access Token

# 3. Отредактировать
nano .cursor/mcp.json
```

Замените:

- `YOUR_HA_TOKEN` → ваш токен
- `YOUR_HA_URL` → `http://192.168.1.XXX:8123` или внешний URL

---

## 🔧 Шаг 3: Создать config.yml

```bash
# 1. Создать из примера
cp config.yml.example config.yml

# 2. Отредактировать
nano config.yml
```

Заполните:

```yaml
home_assistant:
  local_ip: "192.168.1.XXX"     # IP вашего HA
  local_port: 8123
  hostname: "your-domain.com"   # если есть
  global_port: 8123

ssh:
  username: "root"
  port: 22
  local_ip: "192.168.1.XXX"     # тот же IP

samba:
  username: "homeassistant"     # из настроек Samba add-on
  password: "your_password"     # из настроек Samba add-on
```

---

## 🎯 Шаг 4: Проверить подключение

```bash
./scripts/check.sh
```

Должно показать:

- ✅ SSH подключение работает
- ✅ SAMBA доступна
- ✅ Home Assistant отвечает

---

## 🔌 Шаг 5: Смонтировать и начать работу

```bash
# Запустить главное меню
./ha

# Выбрать:
# 2) Смонтировать конфиги
# 3) Проверить статус
```

Теперь можете редактировать в Cursor!

---

## 🆘 Если что-то не работает

- **SSH не подключается** → см. [SETUP.md](SETUP.md#troubleshooting)
- **SAMBA не монтируется** → проверьте username/password
- **MCP не работает** → проверьте токен и URL

---

## 📚 Полезные ссылки

- 📖 [Полная инструкция](SETUP.md)
- 🌐 [Проброс портов MikroTik](portforward-mikrotik.md)
- 🔐 [ZeroTier + Смешанный режим](zerotier-mixed-mode.md)
- 🔬 [Первый аудит](../guides/first-audit.md)
- 🔒 [Безопасность](../guides/security.md)
- 📋 [Справочник команд](../reference/COMMANDS.md)
