# Быстрая справка - Ollama + Whisper на Proxmox

**Дата:** Ноябрь 8, 2025
**Статус:** ✅ Production Ready

---

## 📍 Конфигурация

### Сеть
- **Proxmox Host:** 192.168.1.124
- **VM 103 (ollama-vm):** 192.168.1.131

### Сервисы
- **Ollama API:** http://192.168.1.131:11434
- **Whisper API:** http://192.168.1.131:9000

### Ресурсы VM
- **CPU:** 4 cores (AMD Ryzen 5 2600)
- **RAM:** 10GB
- **Disk:** 64GB
- **GPU:** NVIDIA P106-100 (6GB VRAM, passthrough)

---

## 🤖 Ollama

### Модели
```bash
# Список моделей
curl http://192.168.1.131:11434/api/tags

# Установлено:
- llama3.1:8b (4.7GB) - основная
- phi3:mini (2.3GB) - резервная
```

### Тест
```bash
# Простой запрос
curl http://192.168.1.131:11434/api/generate -d '{
  "model": "llama3.1:8b",
  "prompt": "Привет! Как дела?",
  "stream": false
}'

# Производительность: 35-45 tokens/sec
```

### Управление
```bash
# SSH в VM
ssh gfer@192.168.1.131

# Статус
systemctl status ollama.service

# Логи
journalctl -u ollama.service -f

# GPU мониторинг
watch -n 1 nvidia-smi
```

---

## 🎤 Whisper

### API Endpoints
```bash
# Health check
curl http://192.168.1.131:9000/health
# {"status":"ok"}

# Транскрибация
curl -X POST http://192.168.1.131:9000/transcribe \
  -F "audio=@file.wav"
# {"text":"..."}
```

### Производительность
- **11 сек аудио → 0.56 сек** (19x realtime)
- **2.2 сек аудио → 0.44 сек** (5x realtime)
- **CUDA:** ✅ GPU ускорение работает

### Управление
```bash
# Статус
sudo systemctl status whisper-api.service

# Логи
sudo journalctl -u whisper-api.service -f

# Рестарт
sudo systemctl restart whisper-api.service
```

---

## 🔧 Proxmox VM Management

### Управление VM 103
```bash
# SSH в Proxmox
ssh root@192.168.1.124

# Статус VM
qm status 103

# Старт/Стоп
qm start 103
qm stop 103
qm shutdown 103

# Конфиг
cat /etc/pve/qemu-server/103.conf

# Консоль
qm terminal 103
```

### Увеличение памяти
```bash
# Остановить VM
qm shutdown 103

# Изменить RAM (в MB)
qm set 103 --memory 12288  # 12GB

# Запустить
qm start 103
```

### Backup/Snapshot
```bash
# Создать snapshot
qm snapshot 103 before-update

# Список snapshots
qm listsnapshot 103

# Восстановить
qm rollback 103 before-update

# Backup
vzdump 103 --mode snapshot --storage local --compress zstd
```

---

## 🐛 Troubleshooting

### Ollama не отвечает
```bash
ssh gfer@192.168.1.131

# Проверить сервис
systemctl status ollama.service

# Проверить порт
ss -tlnp | grep 11434

# Перезапустить
sudo systemctl restart ollama.service

# Проверить GPU
nvidia-smi
```

### Whisper не отвечает
```bash
# Проверить сервис
sudo systemctl status whisper-api.service

# Проверить порт
sudo ss -tlnp | grep 9000

# Перезапустить
sudo systemctl restart whisper-api.service

# Тест CLI
cd ~/whisper.cpp
./build/bin/whisper-cli -m models/ggml-base.bin -f samples/jfk.wav
```

### VM не запускается
```bash
# На Proxmox хосте
ssh root@192.168.1.124

# Логи VM
qm status 103
journalctl -xe | grep -i "103"

# Проверить память хоста
free -h

# Проверить GPU binding
lspci -nnk | grep -A 3 nvidia
# Должно быть: Kernel driver in use: vfio-pci
```

### GPU не используется
```bash
# В VM
ssh gfer@192.168.1.131

# Проверить что GPU виден
lspci | grep -i nvidia

# Проверить драйвер
nvidia-smi

# Проверить Ollama переменные
systemctl show ollama.service | grep CUDA

# Проверить Whisper
ldd ~/whisper.cpp/build/bin/whisper-cli | grep cuda
```

---

## 📊 Производительность

### Общая архитектура

```text
Telegram Voice (10 сек)
    ↓
Whisper API (0.5 сек) ← GPU
    ↓
llama3.1:8b (2-5 сек) ← GPU
    ↓
Telegram Response

Итого: 3-6 сек 🚀
```

### Метрики
- **Whisper:** 19x realtime на GPU
- **Ollama:** 35-45 tok/s на GPU
- **VRAM:**
  - Ollama: ~5GB
  - Whisper: ~1GB
  - Свободно: ~0GB (используется на максимум)

---

## 🔗 Документация

- **[OLLAMA-PROXMOX-COMPLETE-GUIDE.md](./OLLAMA-PROXMOX-COMPLETE-GUIDE.md)** - Установка Ollama + GPU
- **[WHISPER-SETUP.md](./WHISPER-SETUP.md)** - Установка Whisper
- **[n8n-personal-assistant-ollama-simple.json](./n8n-personal-assistant-ollama-simple.json)** - n8n workflow (ready to import)

---

## ✅ Checklist для новой установки

### Proxmox хост
- [ ] IOMMU enabled в BIOS
- [ ] GRUB обновлен (`iommu=pt`)
- [ ] VFIO модули загружены
- [ ] GPU привязан к vfio-pci

### VM 103
- [ ] Ubuntu 22.04.5 установлен
- [ ] GPU виден в VM (`lspci | grep nvidia`)
- [ ] NVIDIA драйвер установлен (`nvidia-smi`)
- [ ] Ollama установлен и запущен
- [ ] llama3.1:8b загружен
- [ ] CUDA toolkit установлен
- [ ] Whisper.cpp собран с CUDA
- [ ] Whisper API запущен

### Проверка работы
- [ ] `curl http://192.168.1.131:11434/api/tags` работает
- [ ] `curl http://192.168.1.131:9000/health` работает
- [ ] GPU используется в nvidia-smi
- [ ] Whisper транскрибирует за < 1 сек

---

**Версия:** 1.0
**Последнее обновление:** Ноябрь 8, 2025
**Автор:** AI Assistant + Community
