# 🤝 Вклад в проект

Спасибо за интерес к улучшению HASSio Cursor!

---

## 🎯 Как помочь проекту

### 1. Сообщить об ошибке

Нашли баг? [Создайте issue](https://github.com/Gfermoto/HASSio_Cursor/issues/new) с описанием:

- Что вы делали
- Что ожидали увидеть
- Что произошло на самом деле
- Версия Home Assistant
- Вывод команды (если есть)

### 2. Предложить улучшение

Есть идея? [Создайте issue](https://github.com/Gfermoto/HASSio_Cursor/issues/new) с тегом `enhancement`:

- Опишите проблему, которую решает ваша идея
- Предложите решение
- Добавьте примеры использования

### 3. Улучшить документацию

Документация в `docs/` - помогите сделать её лучше:

```bash
git clone https://github.com/Gfermoto/HASSio_Cursor.git
cd HASSio_Cursor
# Редактируйте docs/*.md
git add docs/
git commit -m "docs: улучшена секция X"
git push
```

### 4. Добавить код

1. **Fork** репозитория
2. **Создайте ветку**: `git checkout -b feature/amazing-feature`
3. **Внесите изменения**
4. **Протестируйте**: `./scripts/check.sh`
5. **Коммит**: `git commit -m "feat: добавлена новая фича"`
6. **Push**: `git push origin feature/amazing-feature`
7. **Создайте Pull Request**

---

## 📋 Стандарты кода

### Скрипты (Bash)

```bash
#!/bin/bash
# Описание скрипта

# Загрузить библиотеки
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib_paths.sh"
source "$SCRIPT_DIR/lib_config.sh"

# Ваш код...
```

**Требования:**

- ✅ Использовать переменные из `config.yml`
- ✅ Добавить комментарии
- ✅ Проверить ошибки (`set -e` или явные проверки)
- ✅ Пройти `shellcheck`

### Документация (Markdown)

```markdown
# Заголовок

Краткое описание

---

## Секция 1

Содержание...

## Секция 2

Содержание...
```

**Требования:**

- ✅ Заголовки начинаются с `#`
- ✅ Примеры кода в блоках с подсветкой
- ✅ Эмодзи для визуальных акцентов
- ✅ Нет реальных IP/паролей/токенов

### Коммиты

Используем [Conventional Commits](https://www.conventionalcommits.org/):

```text
feat: добавлена новая команда для ...
fix: исправлена ошибка в ...
docs: обновлена документация по ...
style: форматирование кода
refactor: рефакторинг скрипта X
test: добавлены тесты для ...
chore: обновлены зависимости
```

---

## 🧪 Тестирование

Перед отправкой PR:

```bash
# Проверить скрипты
shellcheck scripts/*.sh

# Проверить Markdown
markdownlint docs/**/*.md

# Проверить безопасность
./scripts/check_security.sh

# Запустить pre-commit
pre-commit run --all-files
```

---

## 🔒 Безопасность

**НИКОГДА НЕ КОММИТЬТЕ:**

- ❌ Реальные IP-адреса
- ❌ Пароли
- ❌ Токены
- ❌ SSH ключи
- ❌ Домены

Используйте placeholders:

- ✅ `YOUR_HA_IP`
- ✅ `YOUR_PASSWORD`
- ✅ `YOUR_TOKEN`

---

## 📝 Процесс Review

1. Ваш PR будет проверен на:
   - Соответствие стандартам кода
   - Отсутствие утечек данных
   - Работоспособность
   - Качество документации

2. Могут быть запрошены изменения

3. После одобрения - merge в `main`

---

## 💬 Вопросы?

- 💬 [GitHub Discussions](https://github.com/Gfermoto/HASSio_Cursor/discussions)
- 📧 Email: <gfermoto@gmail.com>
- 🐛 [Issues](https://github.com/Gfermoto/HASSio_Cursor/issues)

---

## 🌟 Участники

Спасибо всем, кто помогает проекту!

Ваше имя будет добавлено в список контрибьюторов.

---

**Ещё раз спасибо за вклад!** 🎉
