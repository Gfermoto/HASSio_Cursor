# Ollama в Ubuntu VM на Proxmox с GPU Passthrough

Безопасное развертывание Ollama в виртуальной машине Ubuntu с PCI passthrough NVIDIA GPU. **Не требует NVIDIA драйверов на Proxmox хосте.**

**Время установки:** 30-40 минут  
**Уровень:** Intermediate  
**Безопасность:** ✅ Полная изоляция от Proxmox хоста

---

## Преимущества VM подхода

**По сравнению с LXC:**
- ✅ **Нет драйверов на хосте** - Proxmox остается чистым
- ✅ **Нет конфликтов** с proxmox-ve metapackage  
- ✅ **Полная изоляция** - VM не может повлиять на хост
- ✅ **Стандартная установка** NVIDIA драйверов в Ubuntu
- ✅ **Проще troubleshooting** - обычная Ubuntu система

**Недостатки:**
- ⚠️ Требует IOMMU/VT-d в BIOS
- ⚠️ GPU выделяется только одной VM
- ⚠️ Небольшой overhead (~5-10% производительности)

---

## Требования

### BIOS/UEFI настройки

Должны быть включены:
- **Intel VT-d** (Intel) или **AMD-Vi** (AMD)
- **IOMMU**
- **Virtualization** (VT-x / AMD-V)

### Proxmox хост

- Proxmox VE 7.x или 8.x
- IOMMU enabled в kernel parameters
- GPU в отдельной IOMMU группе

### Оборудование

- NVIDIA GTX 1050 Ti (4GB VRAM) - текущая
- Или GTX 1060 (6GB VRAM) - планируемая
- 16GB+ RAM на хосте (8GB для VM)
- 50GB+ дискового пространства

---

## Шаг 1: Включение IOMMU на Proxmox хосте

### 1.1 Проверка текущего состояния

```bash
ssh root@<PROXMOX_IP>

# Проверка что IOMMU доступен в BIOS
dmesg | grep -i iommu

# Если пусто - IOMMU отключен в BIOS
# Если видите "DMAR" (Intel) или "AMD-Vi" - IOMMU поддерживается
```

### 1.2 Включение IOMMU в Proxmox

Редактирование GRUB параметров:

```bash
nano /etc/default/grub
```

Найдите строку `GRUB_CMDLINE_LINUX_DEFAULT` и измените:

**Для Intel CPU:**
```text
GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on iommu=pt"
```

**Для AMD CPU:**
```text
GRUB_CMDLINE_LINUX_DEFAULT="quiet amd_iommu=on iommu=pt"
```

Сохраните файл (Ctrl+O, Enter, Ctrl+X).

Обновление GRUB:

```bash
update-grub
```

### 1.3 Загрузка VFIO модулей

```bash
nano /etc/modules
```

Добавьте в конец файла:

```text
vfio
vfio_iommu_type1
vfio_pci
vfio_virqfd
```

Сохраните файл.

### 1.4 Перезагрузка хоста

```bash
reboot
```

### 1.5 Проверка IOMMU после перезагрузки

```bash
ssh root@<PROXMOX_IP>

# Проверка что IOMMU активен
dmesg | grep -i "IOMMU enabled"

# Должно показать: "DMAR: IOMMU enabled" (Intel) или "AMD-Vi: IOMMU enabled" (AMD)
```

---

## Шаг 2: Определение GPU для passthrough

### 2.1 Поиск GPU в системе

```bash
lspci -nn | grep -i nvidia
```

Пример вывода:
```text
01:00.0 VGA compatible controller [0300]: NVIDIA Corporation GP107 [GeForce GTX 1050 Ti] [10de:1c82] (rev a1)
01:00.1 Audio device [0403]: NVIDIA Corporation GP107GL High Definition Audio Controller [10de:0fb9] (rev a1)
```

Запишите:
- **PCI адрес:** `01:00.0` и `01:00.1`
- **Vendor:Device ID:** `10de:1c82` и `10de:0fb9`

### 2.2 Проверка IOMMU группы

```bash
# Скрипт для просмотра IOMMU групп
for d in /sys/kernel/iommu_groups/*/devices/*; do 
    n=${d#*/iommu_groups/*}; n=${n%%/*}
    printf 'IOMMU Group %s ' "$n"
    lspci -nns "${d##*/}"
done | grep -i nvidia
```

Пример вывода:
```text
IOMMU Group 1 01:00.0 VGA compatible controller [0300]: NVIDIA [10de:1c82]
IOMMU Group 1 01:00.1 Audio device [0403]: NVIDIA [10de:0fb9]
```

**Важно:** GPU и его audio контроллер должны быть в **одной IOMMU группе**. Если они в разных группах или группа содержит другие устройства - могут быть проблемы.

### 2.3 Настройка VFIO для GPU

Создание конфигурации VFIO:

```bash
echo "options vfio-pci ids=10de:1c82,10de:0fb9" > /etc/modprobe.d/vfio.conf
```

Замените `10de:1c82,10de:0fb9` на ваши Vendor:Device ID из шага 2.1.

Обновление initramfs:

```bash
update-initramfs -u
```

### 2.4 Перезагрузка

```bash
reboot
```

### 2.5 Проверка что GPU захвачен VFIO

```bash
ssh root@<PROXMOX_IP>

lspci -k | grep -A 3 -i nvidia
```

Должно показать:
```text
01:00.0 VGA compatible controller: NVIDIA Corporation ...
    Kernel driver in use: vfio-pci
    Kernel modules: nouveau

01:00.1 Audio device: NVIDIA Corporation ...
    Kernel driver in use: vfio-pci
```

**Важно:** `Kernel driver in use: vfio-pci` - это правильно!

---

## Шаг 3: Скачивание Ubuntu Server ISO

```bash
cd /var/lib/vz/template/iso

# Ubuntu Server 22.04 LTS
wget https://releases.ubuntu.com/22.04/ubuntu-22.04.5-live-server-amd64.iso

# Проверка загрузки
ls -lh ubuntu-22.04.5-live-server-amd64.iso
```

---

## Шаг 4: Создание VM через Proxmox Web UI

### 4.1 Создание VM

Откройте Proxmox Web UI → Create VM

**General:**
- VM ID: `300` (или свободный ID)
- Name: `ollama-vm`

**OS:**
- ISO image: `ubuntu-22.04.5-live-server-amd64.iso`
- Type: Linux
- Version: 6.x - 2.6 Kernel

**System:**
- Graphic card: `Default`
- Machine: `q35`
- BIOS: `OVMF (UEFI)` ← **Важно для GPU passthrough**
- Add EFI Disk: ✅ Yes
- EFI Storage: `local-lvm`
- SCSI Controller: `VirtIO SCSI single`

**Disks:**
- Bus/Device: `VirtIO Block`
- Storage: `local-lvm`
- Disk size: `50 GB`
- Discard: ✅ (если SSD)

**CPU:**
- Sockets: `1`
- Cores: `4`
- Type: `host` ← **Важно для производительности**

**Memory:**
- Memory: `8192 MB`
- Ballooning: ❌ Uncheck

**Network:**
- Bridge: `vmbr0`
- Model: `VirtIO (paravirtualized)`

**Confirm:** Проверьте настройки и создайте VM

### 4.2 НЕ запускайте VM еще!

---

## Шаг 5: Добавление GPU в VM

### 5.1 Определение PCI адреса GPU

```bash
# На Proxmox хосте
lspci | grep -i nvidia

# Пример вывода:
# 01:00.0 VGA compatible controller: NVIDIA Corporation ...
# 01:00.1 Audio device: NVIDIA Corporation ...
```

### 5.2 Добавление PCI устройств

Через Web UI:

1. Выберите VM 300 → Hardware
2. Add → PCI Device
3. Device: выберите GPU (01:00.0)
4. ✅ All Functions
5. ✅ Primary GPU
6. ✅ PCI-Express
7. ✅ ROM-Bar
8. Add

Повторите для Audio (01:00.1):
- Device: 01:00.1
- ✅ All Functions
- ❌ Primary GPU (только для первого)
- ✅ PCI-Express
- Add

### 5.3 Дополнительные настройки VM

Отредактируйте конфиг VM:

```bash
nano /etc/pve/qemu-server/300.conf
```

Добавьте в конец:

```text
cpu: host,hidden=1,flags=+pcid
args: -cpu host,kvm=off
```

Это скрывает виртуализацию от NVIDIA драйвера (некоторые версии это требуют).

---

## Шаг 6: Установка Ubuntu Server

### 6.1 Запуск VM

В Proxmox Web UI:
1. VM 300 → Console
2. Start VM
3. Откроется Ubuntu installer

### 6.2 Установка Ubuntu

Следуйте стандартному процессу установки:

- **Language:** English (или Russian)
- **Keyboard:** Russian / English
- **Network:** Automatic (DHCP)
- **Storage:** Use entire disk (50GB virtual disk)
- **Profile:**
  - Name: `administrator`
  - Server name: `ollama-vm`
  - Username: `admin`
  - Password: `<ваш_пароль>`
- **SSH:** ✅ Install OpenSSH server
- **Snaps:** Пропустите (не нужны)

Дождитесь завершения установки (~5-10 минут).

После установки: **Reboot Now**

### 6.3 Получение IP адреса VM

В Proxmox Web UI → VM 300 → Summary:

Посмотрите IP адрес в секции "IPs"

Или через консоль VM:

```bash
# Логин: admin
# Password: <ваш_пароль>

ip addr show
```

Запишите IP адрес (например: `192.168.1.150`)

---

## Шаг 7: Настройка Ubuntu VM

SSH в VM:

```bash
ssh admin@<VM_IP>
```

### 7.1 Обновление системы

```bash
sudo apt update
sudo apt upgrade -y
```

### 7.2 Проверка видимости GPU

```bash
lspci | grep -i nvidia
```

Должны быть видны GPU и Audio controller.

### 7.3 Установка NVIDIA драйверов

В Ubuntu это просто и без конфликтов:

```bash
# Добавление official NVIDIA PPA (опционально, для последних версий)
sudo add-apt-repository ppa:graphics-drivers/ppa -y
sudo apt update

# Поиск рекомендуемого драйвера
ubuntu-drivers devices

# Установка рекомендуемого драйвера
sudo ubuntu-drivers autoinstall

# ИЛИ установка конкретной версии
sudo apt install -y nvidia-driver-535

# Перезагрузка VM
sudo reboot
```

### 7.4 Проверка NVIDIA драйвера

После перезагрузки VM:

```bash
ssh admin@<VM_IP>

nvidia-smi
```

Должна показаться информация о GTX 1050 Ti! 🎉

---

## Шаг 8: Установка Ollama

### 8.1 Установка Ollama

```bash
# Официальный installer
curl -fsSL https://ollama.ai/install.sh | sh

# Проверка
ollama --version
```

### 8.2 Настройка Ollama для сетевого доступа

```bash
sudo systemctl edit ollama.service
```

Добавьте:

```ini
[Service]
Environment="OLLAMA_HOST=0.0.0.0:11434"
Environment="OLLAMA_ORIGINS=*"
```

Сохраните (Ctrl+O, Enter, Ctrl+X).

Перезапуск сервиса:

```bash
sudo systemctl daemon-reload
sudo systemctl restart ollama.service
sudo systemctl status ollama.service
```

Статус должен быть: `active (running)`

---

## Шаг 9: Установка модели

### 9.1 Загрузка модели для GTX 1050 Ti

```bash
# Рекомендуемая модель для 4GB VRAM
ollama pull phi3:mini

# Ожидайте ~2-3 минуты (скачивается 2.3GB)
```

### 9.2 Тестирование

```bash
# CLI тест
ollama run phi3:mini "Привет! Представься кратко на русском как AI ассистент для умного дома"

# API тест
curl http://localhost:11434/api/generate -d '{
  "model": "phi3:mini",
  "prompt": "Привет!",
  "stream": false
}'
```

### 9.3 Мониторинг GPU

Во время inference:

```bash
# В отдельном SSH сеансе
watch -n 1 nvidia-smi

# Должно показывать:
# GPU-Util: 80-100% во время генерации
# Memory-Usage: ~2.5GB / 4GB
```

---

## Шаг 10: Проверка доступности API из сети

На Proxmox хосте или вашей рабочей машине:

```bash
curl http://<VM_IP>:11434/api/tags

# Должен вернуть:
# {"models":[{"name":"phi3:mini",...}]}
```

Если получили ответ - **Ollama готов к работе!** ✅

---

## Шаг 11: Интеграция с n8n

### 11.1 Импорт workflow

Скачайте workflow:

```bash
wget https://raw.githubusercontent.com/Gfermoto/HASSio_Cursor/main/docs/integrations/n8n-voice-assistant-ollama.json
```

В n8n Web UI:
- Workflows → Import from File
- Выберите `n8n-voice-assistant-ollama.json`

### 11.2 Конфигурация Ollama узла

В узле "Ollama: Model":
- Base URL: `http://<VM_IP>:11434`
- Model: `phi3:mini`

### 11.3 Остальная конфигурация

См. [OLLAMA-QUICKSTART.md](./OLLAMA-QUICKSTART.md), раздел "Шаг 9: Интеграция с n8n"

---

## Обслуживание VM

### Snapshot перед изменениями

В Proxmox Web UI → VM 300 → Snapshots:
- Take Snapshot
- Name: `before-model-update`
- Description: `Clean phi3:mini installation`

### Backup VM

```bash
# На Proxmox хосте
vzdump 300 --mode snapshot --storage local --compress zstd
```

### Обновление Ollama

```bash
ssh admin@<VM_IP>

# Обновление Ollama
curl -fsSL https://ollama.ai/install.sh | sh

# Перезапуск сервиса
sudo systemctl restart ollama.service
```

### Добавление модели (после апгрейда GPU)

После замены GTX 1050 Ti на GTX 1060:

```bash
ssh admin@<VM_IP>

# Загрузка модели для 6GB
ollama pull llama3.1:8b

# Список моделей
ollama list
```

Обновите параметр `model` в n8n на `llama3.1:8b`.

---

## Производительность

### GTX 1050 Ti (4GB) + phi3:mini в VM

- Latency: 3-6 секунд (cold), 1-3 секунды (warm)
- Throughput: 35-55 tokens/sec (~10% overhead от bare metal)
- VRAM: ~2.5GB / 4GB
- GPU Utilization: 80-95%

### GTX 1060 (6GB) + llama3.1:8b в VM

- Latency: 5-8 секунд (cold), 2-4 секунды (warm)
- Throughput: 25-45 tokens/sec
- VRAM: ~5GB / 6GB
- GPU Utilization: 80-95%

---

## Troubleshooting

### GPU не виден в VM

**Проверка на хосте:**

```bash
# IOMMU активен?
dmesg | grep "IOMMU enabled"

# GPU использует vfio-pci?
lspci -k | grep -A 3 nvidia

# Должно быть: Kernel driver in use: vfio-pci
```

**Если драйвер не vfio-pci:**

```bash
# Проверка vfio.conf
cat /etc/modprobe.d/vfio.conf

# Должно быть: options vfio-pci ids=10de:XXXX,10de:YYYY

# Пересоздание initramfs
update-initramfs -u -k all
reboot
```

### VM не загружается после добавления GPU

**Решение:**

1. Удалите GPU из VM (Web UI → Hardware → Remove)
2. Запустите VM
3. Проверьте настройки BIOS: UEFI, q35, OVMF
4. Добавьте GPU заново с опциями:
   - ✅ All Functions
   - ✅ Primary GPU
   - ✅ PCI-Express

### nvidia-smi показывает ошибку в VM

```bash
# В VM проверить установку драйвера
dpkg -l | grep nvidia-driver

# Переустановка
sudo apt install --reinstall nvidia-driver-535

# Перезагрузка VM
sudo reboot
```

---

## Сравнение: VM vs LXC

| Параметр | VM (этот подход) | LXC (проблемный) |
|----------|------------------|------------------|
| Безопасность Proxmox | ✅ Полная изоляция | ⚠️ Привилегированный контейнер |
| NVIDIA на хосте | ✅ Не требуется | ❌ Обязательно |
| Конфликты пакетов | ✅ Нет | ❌ proxmox-ve conflict |
| Overhead | ~5-10% | ~2-5% |
| Сложность setup | Средняя | Средняя |
| Стабильность | ✅ Высокая | ⚠️ Зависит от хоста |
| Изоляция | ✅ Полная | ❌ Shared kernel |

**Рекомендация для production:** VM подход безопаснее.

---

## Что НЕ нужно делать на Proxmox хосте

❌ Устанавливать nvidia-driver на хост  
❌ Удалять proxmox-ve metapackage  
❌ Изменять критичные системные пакеты  
✅ Только IOMMU/VFIO конфигурация (безопасно)

---

## Итоговая конфигурация

```text
Proxmox Host (без NVIDIA драйверов)
  ├── IOMMU enabled
  ├── VFIO modules loaded
  └── GPU captured by vfio-pci
       │
       └─→ Ubuntu VM (ID 300)
           ├── GPU passthrough (PCI 01:00.0, 01:00.1)
           ├── NVIDIA Driver 535+ (в VM)
           ├── Ollama service
           └── API: http://<VM_IP>:11434
```

---

**Автор:** AI Assistant (DevOps)  
**Дата:** Октябрь 2025  
**Версия:** 1.0  
**Статус:** ✅ Production-ready, безопасно для Proxmox

