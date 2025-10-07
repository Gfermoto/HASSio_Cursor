# 🔄 Рабочий процесс

Рекомендации по работе с конфигурацией Home Assistant.

---

## 🎯 Ежедневная работа

### Простой способ (рекомендуется)

```bash
# 1. Смонтировать (если ещё не смонтировано)
./scripts/mount.sh

# 2. Редактировать в Cursor
code config/configuration.yaml

# 3. Развернуть (всё автоматически!)
./scripts/deploy.sh
```

**Скрипт deploy.sh делает:**

- 💾 Создаёт бэкап
- 🔍 Проверяет YAML
- ✅ Валидирует через HA
- 📝 Коммитит в Git
- 🔄 Перезагружает HA
- ✅ Проверяет запуск

---

## 🛡️ Безопасное редактирование

### Перед началом

```bash
# Убедиться что есть свежий снапшот HA
ssh -F .ssh/config hassio "ha backups list"

# Если последний старый - создать новый
ssh -F .ssh/config hassio "ha backups new --name='before-changes'"
```

### Редактирование

```bash
# Открыть в Cursor
code config/

# Или конкретный файл
code config/configuration.yaml
```

### Развертывание

**Автоматический (рекомендуется):**

```bash
./scripts/deploy.sh
```

**Ручной (если хотите контроль):**

```bash
# 1. Бэкап
./scripts/backup.sh

# 2. Проверка YAML
yamllint config/*.yaml

# 3. Проверка HA
ssh -F .ssh/config hassio "ha core check"

# 4. Git коммит
cd config/
git add .
git commit -m "Описание изменений"

# 5. Перезагрузка
ssh -F .ssh/config hassio "ha core restart"

# 6. Логи
./scripts/view_logs.sh
```

---

## 🆘 Если что-то сломалось

### Уровень 1: Git откат (быстро)

```bash
cd config/
git log --oneline              # Найти последний рабочий коммит
git revert HEAD                # Откатить последнее изменение
./scripts/deploy.sh            # Применить откат
```

### Уровень 2: Локальный бэкап

```bash
./scripts/restore.sh
# Выбрать последний рабочий бэкап
# Перезагрузить HA
```

### Уровень 3: Снапшот HA (полное восстановление)

```bash
# Список снапшотов
ssh -F .ssh/config hassio "ha backups list"

# Восстановить
ssh -F .ssh/config hassio "ha backups restore SLUG"
```

---

## 📋 Типичные сценарии

### Добавление новой интеграции

```bash
# 1. Создать снапшот HA (на всякий случай)
ssh -F .ssh/config hassio "ha backups new --name='before-integration'"

# 2. Создать локальный бэкап
./scripts/backup.sh

# 3. Редактировать configuration.yaml
code config/configuration.yaml

# 4. Развернуть
./scripts/deploy.sh

# 5. Проверить логи
./scripts/view_logs.sh
```

### Изменение автоматизации

```bash
# 1. Редактировать
code config/automations.yaml

# 2. Развернуть (бэкап автоматически)
./scripts/deploy.sh

# 3. Проверить что работает
# (тестировать триггеры вручную в HA)
```

### Обновление секретов

```bash
# 1. Редактировать
nano config/secrets.yaml

# 2. Проверить синтаксис
yamllint config/secrets.yaml

# 3. Перезагрузить (secrets не в Git!)
ssh -F .ssh/config hassio "ha core restart"
```

### Массовые изменения

```bash
# 1. Создать ПОЛНЫЙ снапшот HA
ssh -F .ssh/config hassio "ha backups new --name='before-major-changes'"

# 2. Создать ветку в Git
cd config/
git checkout -b experimental

# 3. Редактировать
code .

# 4. Тестировать
./scripts/deploy.sh

# 5. Если всё ОК - смержить
git checkout main
git merge experimental

# 6. Если не ОК - откатить
git checkout main
git branch -D experimental
```

---

## 🔍 Отладка

### Поиск ошибок

```bash
# В логах HA
ssh -F .ssh/config hassio "grep ERROR /config/home-assistant.log | tail -20"

# Конкретный компонент
ssh -F .ssh/config hassio "grep 'homeassistant.components.mqtt' /config/home-assistant.log"

# За последний час
ssh -F .ssh/config hassio "tail -1000 /config/home-assistant.log | grep ERROR"
```

### Проверка конфигурации

```bash
# YAML синтаксис
yamllint config/configuration.yaml

# Конфигурация HA (детально)
ssh -F .ssh/config hassio "ha core check"

# Запуск в debug режиме
# Редактировать configuration.yaml:
logger:
  default: info
  logs:
    homeassistant.core: debug
```

---

## 📊 Git workflow

### Создание feature branch

```bash
cd config/

# Создать ветку
git checkout -b new-feature

# Редактировать
code .

# Коммитить
git add .
git commit -m "Add new feature"

# Тестировать
cd ~/HASSio
./scripts/deploy.sh

# Если OK - смержить
cd config/
git checkout main
git merge new-feature
git branch -d new-feature

# Если не OK - удалить ветку
git checkout main
git branch -D new-feature
```

### Просмотр истории

```bash
cd config/

# Лог
git log --oneline --graph --decorate

# Изменения в файле
git log --follow configuration.yaml

# Кто менял строку
git blame configuration.yaml

# Изменения между коммитами
git diff HEAD~1 HEAD
```

---

## 💡 Best Practices

### Перед каждым изменением

1. ✅ Убедиться что есть свежий снапшот HA (раз в неделю)
2. ✅ Локальный бэкап создастся автоматически через deploy.sh

### При редактировании

1. ✅ Проверять YAML синтаксис
2. ✅ Тестировать на dev ветке (для больших изменений)
3. ✅ Читать логи после развертывания

### После изменения

1. ✅ Проверить что HA запустился
2. ✅ Проверить что устройства работают
3. ✅ Закоммитить в Git

### Регулярно

1. ✅ Создавать полные снапшоты HA (раз в неделю)
2. ✅ Просматривать логи на ошибки
3. ✅ Обновлять Home Assistant

---

## ⚡ Быстрая справка

```bash
./scripts/mount.sh      # Монтировать
code config/            # Редактировать
./scripts/deploy.sh     # Развернуть
./scripts/view_logs.sh  # Логи
./scripts/restore.sh    # Откатить
./scripts/check.sh      # Проверить статус
```
