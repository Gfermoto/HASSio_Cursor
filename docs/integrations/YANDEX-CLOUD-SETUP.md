# 🔑 Получение API ключей Yandex Cloud

Пошаговая инструкция по регистрации в Yandex Cloud и получению API ключей для YandexGPT и SpeechKit.

---

## 📋 Что понадобится

- **Яндекс аккаунт** (Yandex ID)
- **Банковская карта** для верификации (списаний не будет, есть бесплатная квота)
- **10-15 минут** времени

---

## 🚀 Шаг 1: Регистрация в Yandex Cloud

### 1.1 Переход на сайт

Откройте [console.cloud.yandex.ru](https://console.cloud.yandex.ru/)

### 1.2 Вход в аккаунт

Войдите через ваш Яндекс аккаунт (или создайте новый)

### 1.3 Активация пробного периода

При первом входе вам предложат:
- ✅ **60 дней пробного периода**
- ✅ **~₽4000 грантовых средств**
- ✅ **Бесплатная квота после окончания гранта**

**Важно:** Привяжите банковскую карту для верификации. Автосписаний не будет!

---

## 📁 Шаг 2: Создание каталога (Folder)

### 2.1 Создайте новый каталог

1. В консоли нажмите **"Создать каталог"**
2. Введите имя: `homeassistant` (или любое другое)
3. Нажмите **"Создать"**

### 2.2 Запишите Folder ID

```bash
# Скопируйте ID каталога из адресной строки:
# https://console.cloud.yandex.ru/folders/b1gXXXXXXXXXXXXXXXXX
#                                      ^^^^^^^^^^^^^^^^^^^^
# Это ваш FOLDER_ID
```

**Сохраните:** `b1gXXXXXXXXXXXXXXXXX`

---

## 🔐 Шаг 3: Создание API ключа

### 3.1 Перейдите в раздел IAM

1. Откройте меню (☰) → **"Управление доступом"** → **"Сервисные аккаунты"**
2. Нажмите **"Создать сервисный аккаунт"**

### 3.2 Настройки сервисного аккаунта

- **Имя:** `n8n-voice-assistant`
- **Роли:**
  - `ai.languageModels.user` (для YandexGPT)
  - `ai.speechkit-stt.user` (для SpeechKit STT)

Нажмите **"Создать"**

### 3.3 Создайте API ключ

1. Откройте созданный сервисный аккаунт
2. Перейдите на вкладку **"API ключи"**
3. Нажмите **"Создать ключ"** → **"API ключ"**
4. **ВАЖНО:** Скопируйте ключ СРАЗУ! Он больше не будет показан.

```bash
# Пример API ключа:
AQVN1HHJRkqfvJXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
```

**Сохраните:** `AQVN1HHJRkqf...`

---

## 💰 Шаг 4: Бесплатная квота (важно!)

### 4.1 Квоты YandexGPT

**YandexGPT Lite** (бесплатная модель):
- ✅ **Первые 2 месяца:** неограниченно
- ✅ **После гранта:** 10,000 токенов/день (≈200-300 запросов)

**YandexGPT** (полная модель):
- 💎 Платная после гранта (~₽0.3 за 1000 токенов)

### 4.2 Квоты SpeechKit

**Распознавание речи (STT):**
- ✅ **Первые 2 месяца:** 3,000 минут
- ✅ **После гранта:** 180 минут/месяц бесплатно

---

## 🧪 Шаг 5: Тестирование API

### 5.1 Тест YandexGPT

```bash
# Замените переменные на свои значения
export FOLDER_ID="b1gXXXXXXXXXXXXXXXXX"
export API_KEY="AQVN1HHJRkqf..."

curl -X POST \
  https://llm.api.cloud.yandex.net/foundationModels/v1/completion \
  -H "Authorization: Api-Key ${API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "modelUri": "gpt://'"${FOLDER_ID}"'/yandexgpt-lite",
    "completionOptions": {
      "stream": false,
      "temperature": 0.6,
      "maxTokens": 100
    },
    "messages": [
      {
        "role": "system",
        "text": "Ты помощник умного дома"
      },
      {
        "role": "user",
        "text": "Привет! Как дела?"
      }
    ]
  }'
```

**Ожидаемый результат:**
```json
{
  "result": {
    "alternatives": [
      {
        "message": {
          "role": "assistant",
          "text": "Привет! У меня всё отлично, спасибо..."
        }
      }
    ]
  }
}
```

### 5.2 Тест SpeechKit (опционально)

Для теста нужен аудиофайл в формате OGG/OPUS:

```bash
curl -X POST \
  https://stt.api.cloud.yandex.net/speech/v1/stt:recognize \
  -H "Authorization: Api-Key ${API_KEY}" \
  -F "audio=@test.ogg" \
  -F "lang=ru-RU" \
  -F "folderId=${FOLDER_ID}"
```

---

## ✅ Итого: Что сохранить

Запишите эти значения, они понадобятся для n8n:

| Параметр | Пример значения | Где использовать |
|----------|----------------|------------------|
| **Folder ID** | `b1gXXXXXXXXXXXXXXXXX` | Все API запросы |
| **API Key** | `AQVN1HHJRkqf...` | Authorization заголовок |

---

## 📚 Настройка в n8n

После получения ключей переходите к настройке workflow:

1. Откройте `n8n-voice-assistant.json`
2. Замените `YOUR_YANDEX_FOLDER_ID` на ваш Folder ID
3. Замените `YOUR_YANDEX_CLOUD_API_KEY` на ваш API Key
4. Сохраните и активируйте workflow

---

## 🆘 Troubleshooting

### Ошибка: "Invalid API key"

**Причина:** Неверный API ключ или он не привязан к нужному каталогу

**Решение:**
1. Проверьте что скопировали ключ целиком
2. Убедитесь что сервисному аккаунту назначены роли `ai.languageModels.user` и `ai.speechkit-stt.user`

### Ошибка: "Folder not found"

**Причина:** Неверный Folder ID

**Решение:**
1. Скопируйте ID из адресной строки консоли
2. Должен начинаться с `b1g`

### Ошибка: "Quota exceeded"

**Причина:** Превышен дневной лимит запросов

**Решение:**
1. Подождите до следующего дня (квота обновляется в 00:00 UTC+3)
2. Или подключите платный тариф

---

## 💡 Советы по экономии квоты

1. **Используйте YandexGPT Lite** вместо полной версии
2. **Ограничьте maxTokens** в запросах (100-200 достаточно для команд)
3. **Добавьте кэширование** частых запросов в n8n
4. **Используйте GigaChat как fallback** для снижения нагрузки на YandexGPT

---

## 🔗 Полезные ссылки

- [Документация YandexGPT](https://cloud.yandex.ru/docs/yandexgpt/)
- [Документация SpeechKit](https://cloud.yandex.ru/docs/speechkit/)
- [Тарифы и квоты](https://cloud.yandex.ru/docs/yandexgpt/pricing)
- [Примеры API запросов](https://cloud.yandex.ru/docs/yandexgpt/quickstart)

---

**Готово!** Теперь можно приступать к настройке n8n workflow 🚀
