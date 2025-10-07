# ⚡ Быстрый старт

Запуск проекта за 5 минут

---

## 1. Клонирование проекта

```bash
git clone https://github.com/Gfermoto/HASSio_Cursor.git
cd HASSio_Cursor
```

---

## 2. Настройка конфигурации

```bash
# Скопировать пример
cp config.yml.example config.yml

# Интерактивная настройка
./scripts/configure.sh
```

Вам будет предложено выбрать режим:

- **Local** - только локальная сеть
- **Global** - через интернет
- **Mixed** - комбинированный (рекомендуется)

---

## 3. Монтирование конфигурации

```bash
sudo ./scripts/mount.sh
```

Папка `config/` будет содержать конфигурацию вашего Home Assistant.

---

## 4. Готово

Используйте главное меню:

```bash
./ha
```

**Что делать дальше:**

- 📖 [Полная инструкция](SETUP.md)
- 📋 [Справочник команд](../reference/COMMANDS.md)
- 🔬 [Первый аудит](../guides/first-audit.md)
