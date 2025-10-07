# 🔧 Пошаговая настройка подключения

Полная инструкция по настройке MCP, SSH и SAMBA для работы с Home Assistant через Cursor AI.

---

## Предварительные требования

- ✅ Home Assistant доступен в вашей сети (домен или локальный IP)
- ✅ Есть доступ к роутеру для проброса портов
- ✅ WSL2/Linux окружение

---

## 📦 Шаг 1: Установка зависимостей (WSL)

Выполните:

```bash
cd /home/gfer/HASSio
chmod +x scripts/*.sh
./scripts/setup.sh
```text

**Что произойдёт:**

- Установятся системные пакеты (ssh, cifs-utils, git)
- Установятся Python пакеты (yamllint, pyyaml, requests)
- Создастся SSH ключ в `.ssh/id_hassio`
- Покажется публичный ключ для копирования

**В конце скопируйте SSH ключ!** Он выглядит так:

```text
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBsd... hassio-20251007
```text

---

## 🔐 Шаг 2: Установка SSH add-on в Home Assistant

### 2.1. Открыть Home Assistant

Откройте в браузере: **ваш_домен_или_IP**

### 2.2. Перейти в Add-ons

1. Нажмите ⚙️ **Settings** (слева внизу в меню)
2. Нажмите **Add-ons**
3. Нажмите синюю кнопку **ADD-ON STORE** (справа внизу)

### 2.3. Найти и установить Terminal & SSH

1. В поле поиска вверху наберите: `ssh`
2. Найдите **Terminal & SSH** (официальный add-on от Home Assistant)
3. Нажмите на него
4. Нажмите синюю кнопку **INSTALL**
5. Дождитесь установки (2-5 минут, внизу будет прогресс)

### 2.4. Настроить SSH add-on

1. После установки перейдите на вкладку **Configuration** (вверху)
2. Вставьте следующую конфигурацию:

```yaml
authorized_keys:
  - "ssh-ed25519 ВАААШ_КЛЮЧ_ИЗ_ШАГА_1 hassio-20251007"
password: "ваш_надёжный_пароль_123"
apks: []
server:
  tcp_forwarding: false
```text

**ВАЖНО:**

    - Замените `ssh-ed25519 ВАААШ_КЛЮЧ...` на **ВАШ ключ из шага 1.1** (всю строку целиком!)
    - Замените `ваш_надёжный_пароль_123` на свой пароль
    - Ключ должен быть **одной строкой** (Home Assistant может разбить его при сохранении - это нормально!)

3. Нажмите **SAVE** (справа вверху)

### 2.5. Запустить SSH add-on

1. Перейдите на вкладку **Info**
2. Включите следующие опции:
   - ☑️ **Start on boot** (автозапуск)
   - ☑️ **Watchdog** (автоперезапуск при сбое)
3. Нажмите синюю кнопку **START**
4. Перейдите на вкладку **Log**
5. Найдите строку: `Server listening on :: port 22`
   - ✅ Если есть - SSH запущен успешно!
   - ❌ Если ошибки - скопируйте их и спросите AI в Cursor

---

## 📁 Шаг 3: Установка Samba add-on в Home Assistant

### 3.1. Вернуться в Add-on Store

1. **Settings** → **Add-ons** → **ADD-ON STORE**

### 3.2. Найти и установить Samba share

1. Поиск: `samba`
2. Найдите **Samba share** (официальный)
3. Нажмите на него
4. **INSTALL**
5. Дождитесь установки

### 3.3. Настроить Samba

1. Вкладка **Configuration**
2. Вставьте:

```yaml
username: homeassistant
password: your_secure_password
workgroup: WORKGROUP
local_master: false
enabled_shares:
  - config
  - backup
compatibility_mode: false
apple_compatibility_mode: false
veto_files:
  - ._*
  - .DS_Store
  - Thumbs.db
allow_hosts:
  - 10.0.0.0/8
  - 172.16.0.0/12
  - 192.168.0.0/16
  - fe80::/10
interface: ""
```text

**Пояснения:**

    - `username` - имя пользователя для подключения
    - `password` - пароль (можете изменить на свой!)
    - `enabled_shares` - открываем только config и backup (безопасно)

3. Нажмите **SAVE**

### 3.4. Запустить Samba

1. Вкладка **Info**
2. Включите: ☑️ **Start on boot**, ☑️ **Watchdog**
3. Нажмите **START**
4. Вкладка **Log** → проверьте: `smbd version ... started` ✅

---

## 🌐 Шаг 4: Узнать IP адрес Home Assistant

### В Home Assistant

1. **Settings** (⚙️)
2. **System**
3. **Network**
4. Найдите первый IP адрес в списке

**Пример:** `192.168.1.50`

**ЗАПИШИТЕ ЕГО - он понадобится дальше!**

---

## 💻 Шаг 5: Локальная настройка (WSL)

### 5.1. Настроить SAMBA credentials

Выполните:

```bash
cd /home/gfer/HASSio
chmod +x scripts/*.sh
./scripts/setup_samba.sh
```text

**Что произойдёт:**

- Создастся файл `.samba-credentials` с логином и паролем
- Покажется содержимое для проверки

### 5.2. Обновить SSH config с вашим IP

Выполните:

```bash
nano .ssh/config
```text

Найдите строку:

```text
HostName 192.168.1.50
```text

Замените `192.168.1.50` на **ВАШ IP из шага 4**!

**Сохранить:**

- Нажмите `Ctrl+O`
- Нажмите `Enter`
- Нажмите `Ctrl+X`

---

## 🌍 Шаг 6: Проброс портов на роутере

> 📖 **Для MikroTik:** См. [подробную инструкцию для MikroTik с Reverse Proxy](portforward-mikrotik.md)

### 6.1. Войти в роутер

Откройте в браузере адрес роутера:

- Обычно: `192.168.1.1` или `192.168.0.1` или `192.168.88.1`
- Введите логин и пароль администратора роутера

### 6.2. Найти раздел Port Forwarding

Ищите один из разделов (зависит от роутера):

- **Port Forwarding**
- **Virtual Server**
- **NAT Forwarding**
- **Firewall → NAT** (Mikrotik)

### 6.3. Создать правило для SSH

**Добавить новое правило:**

```text
Название/Name: HA-SSH
Внешний порт/External Port: 2222
Внутренний IP/Internal IP: 192.168.X.X  ← ВАШ IP из шага 4!
Внутренний порт/Internal Port: 22
Протокол/Protocol: TCP
Статус/Status: Включено/Enabled
```text

### 6.4. Создать правила для SAMBA

**Добавить 4 правила:**

**Правило 1:**

```text
Название: HA-SAMBA-445
Внешний порт: 445
Внутренний IP: 192.168.X.X  ← ВАШ IP!
Внутренний порт: 445
Протокол: TCP
```text

**Правило 2:**

```text
Название: HA-SAMBA-139
Внешний порт: 139
Внутренний IP: 192.168.X.X
Внутренний порт: 139
Протокол: TCP
```text

**Правило 3:**

```text
Название: HA-SAMBA-137
Внешний порт: 137
Внутренний IP: 192.168.X.X
Внутренний порт: 137
Протокол: UDP
```text

**Правило 4:**

```text
Название: HA-SAMBA-138
Внешний порт: 138
Внутренний IP: 192.168.X.X
Внутренний порт: 138
Протокол: UDP
```text

### 6.5. Сохранить настройки

Нажмите **Save** / **Apply** / **OK** (зависит от роутера)

---

## ✅ Шаг 7: Проверка SSH подключения

### 7.1. Первое подключение

Выполните:

```bash
cd /home/gfer/HASSio
ssh -F .ssh/config hassio
```text

**Что должно произойти:**

1. Появится вопрос: `Are you sure you want to continue connecting (yes/no)?`
   - Напечатайте: `yes`
   - Нажмите `Enter`
2. Вы должны попасть в консоль Home Assistant
3. Приветствие: `Welcome to the Home Assistant command line.`

### 7.2. Проверка работы

Выполните в консоли HA:

```bash
ha core info
```text

Должна показаться информация о версии Home Assistant.

### 7.3. Выход

```bash
exit
```text

**Если подключение не удалось:**

- `Connection refused` → проверьте проброс портов (шаг 6)
- `Permission denied` → проверьте SSH ключ в add-on (шаг 2.4)
- `Connection timed out` → проверьте что add-on запущен

---

## 📁 Шаг 8: Монтирование SAMBA

### 8.1. Монтирование

Выполните:

```bash
cd /home/gfer/HASSio
./mount.sh
```text

**Что должно произойти:**

```text
🔌 Монтирование шары 'config'...
✅ Смонтировано!
✅ Создана ссылка: /home/gfer/HASSio/config → /mnt/hassio

📂 Содержимое /mnt/hassio (папка config из HA):
configuration.yaml
automations.yaml
scripts.yaml
...
```text

### 8.2. Проверка

Выполните:

```bash
ls config/
```text

Должны увидеть файлы конфигурации Home Assistant:

- configuration.yaml
- automations.yaml
- scripts.yaml
- и т.д.

**Если ошибка:**

- Проверьте что Samba add-on запущен (шаг 3.4)
- Проверьте пароль в `.samba-credentials`
- Проверьте проброс портов SAMBA (шаг 6.4)

---

## ✅ Шаг 9: Финальная проверка

Выполните:

```bash
./check.sh
```text

**Должно показать:**

```text
✅ SSH работает
✅ SAMBA смонтирован
✅ Доступ к configuration.yaml
✅ MCP настроен
```text

**Если всё ✅ - поздравляю, настройка завершена!** 🎉

---

## 🎯 Начало работы

Теперь можете:

```bash
# Редактировать конфиги
code config/configuration.yaml

# Развернуть изменения
./scripts/deploy.sh

# Просмотр логов
./scripts/view_logs.sh
```text

---

## 🆘 Решение проблем

### SSH не подключается

#### Проверка 1: Add-on запущен?

```text
Home Assistant → Add-ons → Terminal & SSH → вкладка Info
Статус должен быть: "Started"
```text

#### Проверка 2: Порт открыт?

```bash
nc -zv your-domain.com 2222
# Должно быть: succeeded!
```text

#### Проверка 3: Ключ добавлен?

```bash
cat .ssh/id_hassio.pub
# Убедитесь что этот ключ в Configuration add-on
```text

#### Проверка 4: Попробуйте с паролем

```bash
ssh -F .ssh/config -o PreferredAuthentications=password hassio
# Введите пароль из configuration add-on
```text

---

### SAMBA не монтируется

#### Проверка 1: Add-on запущен?

```text
Home Assistant → Add-ons → Samba share → Info
Статус: "Started"
```text

#### Проверка 2: Credentials правильные?

```bash
cat .samba-credentials
# Должно совпадать с Configuration add-on
```text

#### Проверка 3: Порт открыт?

```bash
nc -zv your-domain.com 445
# Должно быть: succeeded!
```text

#### Проверка 4: Попробуйте вручную

```bash
sudo mount -t cifs //your-domain.com/config /mnt/hassio \
  -o username=homeassistant,password=your_password,uid=1000,gid=1000
```text

---

### MCP не работает

**Проверка: Файл конфигурации**

```bash
cat .cursor/mcp.json
```text

Должен содержать:

```json
{
  "mcpServers": {
    "home-assistant": {
      "command": "mcp-proxy",
      "args": ["https://your-domain.com/mcp_server/sse"],
      "env": {
        "API_ACCESS_TOKEN": "..."
      }
    }
  }
}
```text

**Перезапустите Cursor** если MCP не работает.

---

## 📝 Важные заметки

### О SAMBA монтировании

- `/mnt/hassio` - физическая точка монтирования
- `/home/gfer/HASSio/config/` - символическая ссылка на `/mnt/hassio`
- Оба пути ведут к **одним и тем же файлам**!

### О SSH ключах

- Приватный ключ: `.ssh/id_hassio` (никому не показывайте!)
- Публичный ключ: `.ssh/id_hassio.pub` (можно делиться)
- Публичный ключ добавляется в Home Assistant

### О паролях

- SSH пароль - запасной вариант если ключ не работает
- SAMBA пароль - для монтирования конфигов
- Оба пароля можно менять в любой момент

---

## ✅ Чек-лист настройки

Отметьте выполненные пункты:

- [ ] Выполнен `./setup.sh`
- [ ] SSH ключ скопирован
- [ ] SSH add-on установлен в HA
- [ ] SSH ключ добавлен в Configuration
- [ ] SSH add-on запущен
- [ ] Samba add-on установлен в HA
- [ ] Samba add-on запущен
- [ ] IP адрес Home Assistant узнан
- [ ] Проброс портов SSH настроен
- [ ] Проброс портов SAMBA настроен
- [ ] `.samba-credentials` создан
- [ ] SSH config обновлен с правильным IP
- [ ] SSH подключение работает
- [ ] SAMBA монтируется
- [ ] `./check.sh` показывает все ✅

---

## 🎓 Дополнительная информация

- **[COMMANDS.md](COMMANDS.md)** - Справочник всех команд
- **[WORKFLOW.md](WORKFLOW.md)** - Рабочий процесс разработки
- **README.md** - Обзор проекта
