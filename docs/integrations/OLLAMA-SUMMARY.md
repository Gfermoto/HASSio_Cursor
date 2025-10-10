# 📋 Ollama на Proxmox - Сводка

## ✅ Что создано

### Документация

1. **OLLAMA-PROXMOX-SETUP.md** (18KB)
   - Полная инструкция по установке
   - Настройка Proxmox хоста
   - Создание LXC контейнера
   - Установка Ollama с GPU
   - Troubleshooting
   - Сравнение с облачными решениями

2. **OLLAMA-QUICKSTART.md** (7KB)
   - Быстрый старт за 15 минут
   - 3 шага установки
   - Проверка работоспособности
   - Первый тест

3. **README-ollama-assistant.md** (13KB)
   - Интеграция с n8n
   - Настройка workflows
   - Создание Tool workflows
   - Примеры использования
   - Отладка

### Workflows

4. **n8n-voice-assistant-ollama.json** (15KB)
   - Полный workflow для управления HA через Telegram
   - Langchain Agent с Ollama
   - Memory (10 сообщений)
   - 5 Home Assistant Tools
   - 16 узлов

### Скрипты

5. **ollama-proxmox-install.sh** (14KB, executable)
   - Автоматическая установка NVIDIA драйверов
   - Создание LXC контейнера с GPU passthrough
   - Установка Ollama
   - Скачивание моделей
   - Проверка установки
   - Интерактивное меню

### Обновления

6. **README.md**
   - Добавлен раздел "Ollama (локальный, приватный)"
   - Обновлен "Быстрый старт"
   - Ссылки на документацию

---

## 🎯 Рекомендуемые модели

### Для GTX 1050 Ti (4GB VRAM) - текущая карта

| Модель | Размер | VRAM | Качество | Скорость | Рекомендация |
|--------|--------|------|----------|----------|--------------|
| **phi3:mini** | 2.3GB | ~2.5GB | ⭐⭐⭐⭐⭐ | 40-60 tok/s | ✅ **Лучший выбор** |
| llama3.2:3b | 2GB | ~2.2GB | ⭐⭐⭐⭐ | 50-70 tok/s | ✅ Быстрая альтернатива |
| qwen2.5:3b | 2GB | ~2.2GB | ⭐⭐⭐⭐ | 40-60 tok/s | ✅ Качественная |
| gemma2:2b | 1.6GB | ~1.8GB | ⭐⭐⭐ | 80+ tok/s | ✅ Для простых задач |

### Для GTX 1060 (6GB VRAM) - после апгрейда

| Модель | Размер | VRAM | Качество | Скорость | Рекомендация |
|--------|--------|------|----------|----------|--------------|
| **llama3.1:8b** | 4.7GB | ~5GB | ⭐⭐⭐⭐⭐ | 30-50 tok/s | ✅ **Лучший выбор** |
| qwen2.5:7b | 4.7GB | ~5GB | ⭐⭐⭐⭐⭐ | 30-50 tok/s | ✅ Альтернатива |
| phi3:mini | 2.3GB | ~2.5GB | ⭐⭐⭐⭐⭐ | 60-80 tok/s | ✅ Быстрее |

---

## 🚀 Следующие шаги

### Шаг 1: Скачивание и запуск скрипта

```bash
# 1. SSH на Proxmox хост
ssh root@PROXMOX_IP

# 2. Скачивание скрипта с GitHub
wget https://raw.githubusercontent.com/Gfermoto/HASSio_Cursor/main/docs/integrations/ollama-proxmox-install.sh -O /root/ollama-proxmox-install.sh

# 3. Установка прав и запуск
chmod +x /root/ollama-proxmox-install.sh
./ollama-proxmox-install.sh

# Выберите:
# 1) Установить NVIDIA драйверы на хост (первый раз)
# 2) Создать LXC контейнер с Ollama (после перезагрузки)
# 3) Установить модель (phi3:mini для 4GB)
```

### Шаг 2: Проверка

```bash
# Автоматическая проверка
./ollama-proxmox-install.sh --check

# ИЛИ вручную
pct enter 200
ollama list
ollama run phi3:mini "Привет!"
```

### Шаг 3: Интеграция с n8n

1. Импортируйте `n8n-voice-assistant-ollama.json` в n8n
2. Настройте параметры:
   - Ollama IP: `http://IP_КОНТЕЙНЕРА:11434`
   - Home Assistant IP
   - Telegram credentials
3. Создайте 5 Tool workflows
4. Активируйте workflow
5. Тест в Telegram: `/start`

---

## 📊 Сравнение решений

| Параметр | Ollama (локально) | GigaChat | Groq |
|----------|-------------------|----------|------|
| **Скорость** | ⚡ 40-60 tok/s | 🐌 20-30 tok/s | 🚀 100+ tok/s |
| **Стоимость** | ✅ ₽0 навсегда | ✅ ₽0 (квота) | ✅ ₽0 (квота) |
| **Приватность** | ✅ 100% | ❌ Облако | ❌ Облако |
| **Интернет** | ✅ Не нужен | ❌ Нужен | ❌ Нужен |
| **VPN из РФ** | ✅ Не нужен | ✅ Не нужен | ❌ Нужен постоянно |
| **Качество (RU)** | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **GPU нужен** | ✅ Да (4GB+) | ❌ Нет | ❌ Нет |

### Рекомендации по выбору

**Используйте Ollama если:**
- ✅ Есть NVIDIA GPU (4GB+ VRAM)
- ✅ Важна приватность данных
- ✅ Нужна работа БЕЗ интернета
- ✅ Хотите полный контроль над AI

**Используйте GigaChat если:**
- ✅ Нет GPU
- ✅ Важно лучшее качество русского языка
- ✅ Есть стабильный интернет
- ✅ Не важна приватность команд

**НЕ используйте Groq из РФ:**
- ❌ Требует постоянный VPN/прокси
- ❌ Блокируется как сайт, так и API
- ❌ Сложная настройка прокси для n8n

---

## 🔗 Полезные ссылки

### Документация проекта
- [OLLAMA-QUICKSTART.md](./OLLAMA-QUICKSTART.md) - начните здесь
- [OLLAMA-PROXMOX-SETUP.md](./OLLAMA-PROXMOX-SETUP.md) - детальная инструкция
- [README-ollama-assistant.md](./README-ollama-assistant.md) - интеграция с n8n

### Внешние ресурсы
- [Ollama Documentation](https://github.com/ollama/ollama/blob/main/docs/README.md)
- [Ollama Models Library](https://ollama.ai/library)
- [Proxmox LXC GPU Passthrough](https://pve.proxmox.com/wiki/Linux_Container)
- [n8n Langchain](https://docs.n8n.io/langchain/)

---

**Автор:** AI Assistant
**Дата:** Октябрь 2025
**Статус:** ✅ Готово к использованию
