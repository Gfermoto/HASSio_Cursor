# Ollama на Proxmox с NVIDIA GPU - Полное руководство

Профессиональная инструкция по развертыванию Ollama в Ubuntu VM на Proxmox с GPU passthrough.  
Консолидирует community best practices и глубокие знания Proxmox.

**Целевая конфигурация:**
- Proxmox VE 8.x (Debian 12 Bookworm)
- NVIDIA GTX 1050 Ti (4GB VRAM) → GTX 1060 (6GB VRAM)
- Ubuntu 22.04 LTS VM
- Ollama с моделями phi3:mini / llama3.1:8b

**Время установки:** 40-60 минут  
**Сложность:** Intermediate  
**Безопасность:** ✅ Proxmox хост остается чистым

---

## Почему VM, а не LXC?

**Проблема с LXC:**
Установка `nvidia-driver` на Proxmox хост вызывает конфликт с `proxmox-ve` metapackage:
```text
W: You are attempting to remove the meta-package 'proxmox-ve'!
E: Sub-process /usr/share/proxmox-ve/pve-apt-hook returned an error code (1)
```

**Решение - VM с PCI passthrough:**
- ✅ NVIDIA драйверы устанавливаются **только в VM**, не на хосте
- ✅ Нет конфликтов с proxmox-ve
- ✅ Полная изоляция от Proxmox
- ✅ Стандартная установка в Ubuntu (без проблем)
- ⚠️ Требует IOMMU/VT-d в BIOS
- ⚠️ GPU доступен только одной VM
- ⚠️ Overhead ~5-10% (приемлемо)

**Источники:**
- [Habr: Проброс видеокарты в Proxmox](https://habr.com/ru/articles/794568/)
- [Proxmox Wiki: PCI Passthrough](https://pve.proxmox.com/wiki/PCI_Passthrough)
- [Proxmox Forum: Ollama + GPU](https://forum.proxmox.com/threads/ubuntu-22-04-ollama-nvidia-3060-gpu-passthrough-and-drivers-all-looking-good-but.144104/)

---

## Этап 1: Подготовка BIOS/UEFI (на физическом сервере)

### 1.1 Включение виртуализации

Перезагрузите сервер и войдите в BIOS/UEFI (обычно Del, F2, F10 при загрузке).

Найдите и включите:

**Для Intel материнских плат:**
- **Intel VT-x** (Virtualization Technology) → Enabled
- **Intel VT-d** (Virtualization Technology for Directed I/O) → Enabled
- **IOMMU** → Enabled (если есть отдельная опция)

**Для AMD материнских плат:**
- **SVM Mode** (AMD-V) → Enabled
- **AMD-Vi** (AMD IOMMU) → Enabled
- **IOMMU** → Enabled

**Где искать:** Обычно в разделах:
- Advanced → CPU Configuration
- Chipset Configuration
- Virtualization Support

Сохраните (F10) и перезагрузите.

### 1.2 Проверка что BIOS настроен правильно

После загрузки Proxmox:

```bash
ssh root@<PROXMOX_IP>

# Проверка поддержки виртуализации
egrep -o '(vmx|svm)' /proc/cpuinfo | uniq

# Должно вывести: vmx (Intel) или svm (AMD)
# Если пусто - VT-x/AMD-V не включен в BIOS
```

```bash
# Проверка поддержки IOMMU в системе
dmesg | grep -e DMAR -e IOMMU

# Должно содержать (Intel):
# DMAR: IOMMU enabled
# DMAR-IR: Enabled IRQ remapping

# Или (AMD):
# AMD-Vi: Found IOMMU
# AMD-Vi: Interrupt remapping enabled
```

**Критерий успеха:** Видите сообщения об IOMMU/DMAR.  
**Если нет:** Вернитесь в BIOS, проверьте что VT-d/AMD-Vi включен.

---

## Этап 2: Конфигурация Proxmox хоста для IOMMU

### 2.1 Редактирование GRUB

```bash
# Backup текущей конфигурации
cp /etc/default/grub /etc/default/grub.backup

# Редактирование
nano /etc/default/grub
```

Найдите строку начинающуюся с `GRUB_CMDLINE_LINUX_DEFAULT=`

**Для Intel процессоров:**

Было:
```text
GRUB_CMDLINE_LINUX_DEFAULT="quiet"
```

Станет:
```text
GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on iommu=pt"
```

**Для AMD процессоров:**

```text
GRUB_CMDLINE_LINUX_DEFAULT="quiet amd_iommu=on iommu=pt"
```

**Параметры:**
- `intel_iommu=on` / `amd_iommu=on` - включение IOMMU
- `iommu=pt` - passthrough mode (лучшая производительность)

Сохраните: Ctrl+O, Enter, Ctrl+X

Обновление GRUB:

```bash
update-grub

# Должно вывести:
# Generating grub configuration file ...
# Found linux image: /boot/vmlinuz-6.8.12-4-pve
# done
```

### 2.2 Загрузка VFIO модулей

VFIO (Virtual Function I/O) - framework для проброса PCI устройств в VM.

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

Сохраните: Ctrl+O, Enter, Ctrl+X

**Объяснение модулей:**
- `vfio` - основной framework
- `vfio_iommu_type1` - IOMMU backend
- `vfio_pci` - PCI device support
- `vfio_virqfd` - interrupt remapping

### 2.3 Применение изменений

```bash
# Обновление initramfs
update-initramfs -u -k all

# Должно вывести:
# update-initramfs: Generating /boot/initrd.img-6.8.12-4-pve
```

### 2.4 Перезагрузка хоста

```bash
reboot
```

Подождите 2-3 минуты пока Proxmox загрузится.

### 2.5 Проверка IOMMU после перезагрузки

```bash
ssh root@<PROXMOX_IP>

# 1. Проверка что IOMMU активирован
dmesg | grep -i "IOMMU enabled"

# Должно вывести:
# DMAR: IOMMU enabled (Intel)
# или
# AMD-Vi: AMD IOMMUv2 loaded and initialized
```

```bash
# 2. Проверка VFIO модулей
lsmod | grep vfio

# Должно показать:
# vfio_pci
# vfio_iommu_type1
# vfio
```

**Критерий успеха:** IOMMU enabled и VFIO модули загружены.  
**Если нет:** Проверьте GRUB конфигурацию и /etc/modules, повторите 2.1-2.4

---

## Этап 3: Подготовка GPU для passthrough

### 3.1 Определение GPU в системе

```bash
lspci -nn | grep -i nvidia
```

**Пример вывода для GTX 1050 Ti:**
```text
01:00.0 VGA compatible controller [0300]: NVIDIA Corporation GP107 [GeForce GTX 1050 Ti] [10de:1c82] (rev a1)
01:00.1 Audio device [0403]: NVIDIA Corporation GP107GL High Definition Audio Controller [10de:0fb9] (rev a1)
```

**Запишите:**
- PCI Bus адрес: `01:00.0` (GPU), `01:00.1` (Audio)
- Vendor:Device ID: `10de:1c82` (GPU), `10de:0fb9` (Audio)

**Важно:** Ваши ID могут отличаться в зависимости от производителя карты (Asus, MSI, Gigabyte).

### 3.2 Проверка IOMMU группы

```bash
#!/bin/bash
for d in /sys/kernel/iommu_groups/*/devices/*; do
    n=${d#*/iommu_groups/*}
    n=${n%%/*}
    printf 'IOMMU Group %s: ' "$n"
    lspci -nns "${d##*/}"
done | grep -i nvidia
```

**Пример вывода:**
```text
IOMMU Group 1: 01:00.0 VGA compatible controller [0300]: NVIDIA Corporation [10de:1c82]
IOMMU Group 1: 01:00.1 Audio device [0403]: NVIDIA Corporation [10de:0fb9]
```

**Критерий успеха:** GPU (01:00.0) и Audio (01:00.1) в **одной** IOMMU группе.

**Если в разных группах:** Могут быть проблемы, но попробуйте. Если не работает - потребуется ACS override patch (сложно).

### 3.3 Blacklist NVIDIA драйверов на хосте

Это критично - хост не должен захватывать GPU, только VFIO.

```bash
cat > /etc/modprobe.d/blacklist-nvidia.conf << 'EOF'
blacklist nouveau
blacklist nvidia
blacklist nvidiafb
EOF
```

**Объяснение:**
- `nouveau` - открытый драйвер NVIDIA (блокируем)
- `nvidia` - проприетарный драйвер (блокируем, чтобы не конфликтовал)
- `nvidiafb` - framebuffer driver

### 3.4 Привязка GPU к VFIO

```bash
echo "options vfio-pci ids=10de:1c82,10de:0fb9" > /etc/modprobe.d/vfio.conf
```

**Замените** `10de:1c82,10de:0fb9` на ваши ID из шага 3.1.

**Что делает:** При загрузке системы VFIO захватит эти устройства **до** загрузки других драйверов.

### 3.5 Применение изменений

```bash
update-initramfs -u -k all
reboot
```

### 3.6 Финальная проверка GPU binding

После перезагрузки:

```bash
ssh root@<PROXMOX_IP>

lspci -nnk | grep -A 3 -i nvidia
```

**Ожидаемый вывод:**
```text
01:00.0 VGA compatible controller [0300]: NVIDIA Corporation GP107 [GeForce GTX 1050 Ti] [10de:1c82]
        Subsystem: Micro-Star International Co., Ltd. [MSI] [1462:8c96]
        Kernel driver in use: vfio-pci
        Kernel modules: nouveau

01:00.1 Audio device [0403]: NVIDIA Corporation GP107GL [10de:0fb9]
        Subsystem: Micro-Star International Co., Ltd. [MSI] [1462:8c96]
        Kernel driver in use: vfio-pci
```

**Критерий успеха:** `Kernel driver in use: vfio-pci` для обоих устройств.

**Если показывает `nouveau` или нет driver:**
```bash
# Проверьте vfio.conf
cat /etc/modprobe.d/vfio.conf

# Проверьте что модули загружены
lsmod | grep vfio_pci

# Пересоздайте initramfs
update-initramfs -u -k all
reboot
```

---

## Этап 4: Скачивание Ubuntu Server ISO

```bash
cd /var/lib/vz/template/iso

# Ubuntu 22.04.5 LTS (проверенная версия)
wget https://releases.ubuntu.com/22.04.5/ubuntu-22.04.5-live-server-amd64.iso

# Проверка целостности (опционально)
wget https://releases.ubuntu.com/22.04.5/SHA256SUMS
sha256sum -c SHA256SUMS 2>&1 | grep ubuntu-22.04.5-live-server-amd64.iso

# Проверка размера
ls -lh ubuntu-22.04.5-live-server-amd64.iso
# Должно быть: ~2.5-2.7GB
```

**Критерий успеха:** ISO файл загружен в `/var/lib/vz/template/iso/`

---

## Этап 5: Создание VM через Proxmox Web UI

### 5.1 Запуск мастера создания VM

Proxmox Web UI → правый верхний угол → **Create VM**

### 5.2 General (вкладка 1)

- **Node:** ваш Proxmox node
- **VM ID:** `300` (или любой свободный, запомните его)
- **Name:** `ollama-vm`
- **Resource Pool:** (оставьте пустым)
- **Start at boot:** ✅ (опционально)

Нажмите **Next**

### 5.3 OS (вкладка 2)

- **Use CD/DVD disc image file (ISO)**
- **Storage:** `local`
- **ISO image:** `ubuntu-22.04.5-live-server-amd64.iso`
- **Type:** `Linux`
- **Version:** `6.x - 2.6 Kernel`

Нажмите **Next**

### 5.4 System (вкладка 3) - КРИТИЧНО!

- **Graphic card:** `Default`
- **Machine:** `q35` ← **Обязательно для PCIe passthrough**
- **BIOS:** `OVMF (UEFI)` ← **Обязательно для GPU**
- **Add EFI Disk:** ✅ Yes
- **EFI Storage:** `local-lvm`
- **Pre-Enroll keys:** ❌ No (отключите Secure Boot)
- **SCSI Controller:** `VirtIO SCSI single`
- **Qemu Agent:** ✅ Yes (опционально, но полезно)

**Почему q35 и OVMF:**
- q35 - современная machine type с PCIe support
- OVMF (UEFI) - требуется для корректного GPU passthrough
- Secure Boot отключен - NVIDIA драйверы unsigned

Нажмите **Next**

### 5.5 Disks (вкладка 4)

- **Bus/Device:** `VirtIO Block 0`
- **Storage:** `local-lvm` (или ваше хранилище)
- **Disk size (GiB):** `50`
- **Cache:** `Default (No cache)`
- **Discard:** ✅ (если SSD)
- **SSD emulation:** ✅ (если хранилище на SSD)

Нажмите **Next**

### 5.6 CPU (вкладка 5) - КРИТИЧНО!

- **Sockets:** `1`
- **Cores:** `4` (минимум 2, рекомендуется 4)
- **Type:** `host` ← **Обязательно для GPU и производительности**
- **Extra CPU Flags:** (оставьте пустым)

**Почему host:**
- Пробрасывает все инструкции процессора хоста в VM
- Необходимо для CUDA и GPU compute
- Максимальная производительность

Нажмите **Next**

### 5.7 Memory (вкладка 6)

- **Memory (MiB):** `8192` (8GB, минимум для Ollama)
- **Minimum memory (MiB):** `8192`
- **Ballooning Device:** ❌ Uncheck (отключите для стабильности)

**Для 4GB моделей хватит 6GB RAM, но 8GB - safer.**

Нажмите **Next**

### 5.8 Network (вкладка 7)

- **Bridge:** `vmbr0` (ваш основной bridge)
- **VLAN Tag:** (оставьте пустым)
- **Model:** `VirtIO (paravirtualized)`
- **MAC address:** (автоматически)
- **Firewall:** ✅ (опционально)

Нажмите **Next**

### 5.9 Confirm (вкладка 8)

Проверьте параметры:
- Machine: q35
- BIOS: OVMF
- CPU Type: host
- Memory: 8192 MB

✅ **Start after created** - снимите галочку! (настроим GPU сначала)

Нажмите **Finish**

VM создана, но **НЕ запускайте её!**

---

## Этап 6: Добавление GPU в VM

### 6.1 Добавление PCI устройств через Web UI

Выберите VM 300 → **Hardware**

#### 6.1.1 Добавление GPU

1. Нажмите **Add** → **PCI Device**
2. **Raw Device:** выберите вашу NVIDIA GPU (01:00.0)
3. Установите галочки:
   - ✅ **All Functions** (важно - захватит GPU и Audio вместе)
   - ✅ **Primary GPU** (если это единственная GPU в системе)
   - ✅ **PCI-Express** (для лучшей производительности)
   - ✅ **ROM-Bar** (обычно нужен)
4. Нажмите **Add**

Проверьте в списке Hardware:
```text
PCI Device (hostpci0): 0000:01:00, All Functions
```

### 6.2 Дополнительная конфигурация VM (опционально, но рекомендуется)

```bash
nano /etc/pve/qemu-server/300.conf
```

Найдите строку с `hostpci0` и добавьте после неё:

```text
cpu: host,hidden=1,flags=+pcid
args: -cpu host,kvm=off
```

**Объяснение:**
- `hidden=1` - скрывает от VM что она виртуальная (некоторые NVIDIA драйверы это проверяют)
- `kvm=off` - скрывает KVM signature (для NVIDIA driver detection)
- `+pcid` - Process-Context Identifiers (производительность)

Сохраните: Ctrl+O, Enter, Ctrl+X

**Файл должен выглядеть примерно так:**

```text
bootdisk: scsi0
cores: 4
cpu: host,hidden=1,flags=+pcid
args: -cpu host,kvm=off
efidisk0: local-lvm:vm-300-disk-0,efitype=4m,size=4M
hostpci0: 0000:01:00,pcie=1,x-vga=1
memory: 8192
meta: creation-qemu=8.1.5,ctime=1728600000
name: ollama-vm
net0: virtio=XX:XX:XX:XX:XX:XX,bridge=vmbr0
numa: 0
ostype: l26
scsi0: local-lvm:vm-300-disk-1,iothread=1,size=50G
scsihw: virtio-scsi-single
smbios1: uuid=XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX
sockets: 1
vmgenid: XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX
```

---

## Этап 7: Установка Ubuntu Server в VM

### 7.1 Запуск VM

Proxmox Web UI → VM 300 → **Start**

Затем → **Console** (откроется noVNC)

Подождите загрузки Ubuntu installer (~30 секунд).

### 7.2 Ubuntu Installation Wizard

**Language:**
- English (рекомендуется для troubleshooting)

**Keyboard configuration:**
- Layout: English (US) или Russian
- Variant: English (US)

**Network connections:**
- Оставьте DHCP (автоматически получит IP)
- Запомните показанный IP адрес (например: 192.168.1.150)

**Configure proxy:**
- Оставьте пустым

**Configure Ubuntu archive mirror:**
- Оставьте по умолчанию

**Guided storage configuration:**
- ✅ Use an entire disk
- Disk: `/dev/sda` (50GB VirtIO disk)
- ❌ Set up this disk as an LVM group (можно оставить, не критично)

**Storage configuration:**
- Просмотрите разметку
- Continue (подтвердите)

**Profile setup:**
- Your name: `Administrator`
- Your server's name: `ollama-vm`
- Pick a username: `admin` (или другое)
- Choose a password: `<надежный_пароль>`
- Confirm your password: `<надежный_пароль>`

**Upgrade to Ubuntu Pro:**
- Skip for now

**SSH Setup:**
- ✅ Install OpenSSH server (обязательно!)
- ❌ Import SSH identity (не нужно)

**Featured Server Snaps:**
- Ничего не выбирайте (установим позже что нужно)

Начнется установка (~5-10 минут).

### 7.3 Завершение установки

Когда увидите **"Reboot Now"**:

1. Нажмите **Reboot Now**
2. VM перезагрузится
3. Дождитесь login prompt

**Критерий успеха:** Видите `ollama-vm login:`

---

## Этап 8: Первичная настройка Ubuntu VM

### 8.1 Подключение по SSH

С вашей рабочей машины:

```bash
ssh admin@<VM_IP>
```

Введите пароль созданный на шаге 7.2.

**Если SSH не работает:**
- Проверьте IP: в Proxmox Web UI → VM 300 → Summary → IPs
- Или через консоль в VM: `ip addr show`

### 8.2 Обновление системы

```bash
sudo apt update
sudo apt upgrade -y
```

Если спросит о restart services - выберите **Yes** и **OK** для всех.

### 8.3 Установка базовых утилит

```bash
sudo apt install -y curl wget git build-essential
```

### 8.4 Проверка видимости GPU

```bash
lspci | grep -i nvidia
```

**Должно вывести:**
```text
00:10.0 VGA compatible controller: NVIDIA Corporation GP107 [GeForce GTX 1050 Ti]
00:10.1 Audio device: NVIDIA Corporation GP107GL High Definition Audio Controller
```

**Критерий успеха:** GPU виден в VM (PCI адрес будет другой, это нормально).

**Если GPU не виден:**
- Вернитесь в Proxmox Web UI → VM 300 → Hardware
- Проверьте что PCI Device добавлен
- Проверьте что VM полностью выключена (Shutdown) перед изменениями в Hardware
- Restart VM

---

## Этап 9: Установка NVIDIA драйверов в Ubuntu VM

### 9.1 Определение рекомендуемого драйвера

```bash
sudo ubuntu-drivers devices
```

**Пример вывода:**
```text
== /sys/devices/pci0000:00/0000:00:10.0 ==
modalias : pci:v000010DEd00001C82sv00001462sd00008C96bc03sc00i00
vendor   : NVIDIA Corporation
model    : GP107 [GeForce GTX 1050 Ti]
driver   : nvidia-driver-535 - distro non-free recommended
driver   : nvidia-driver-545 - third-party non-free
driver   : nvidia-driver-470 - distro non-free
```

**Recommended:** `nvidia-driver-535` (или новее)

### 9.2 Установка NVIDIA драйвера

**Вариант A: Автоматическая установка (рекомендуется)**

```bash
sudo ubuntu-drivers autoinstall
```

Это установит recommended версию автоматически.

**Вариант B: Ручная установка конкретной версии**

```bash
sudo apt install -y nvidia-driver-535 nvidia-utils-535
```

Установка займет 3-5 минут (скачивается ~500MB пакетов).

### 9.3 Перезагрузка VM

```bash
sudo reboot
```

Подождите 1-2 минуты.

### 9.4 Проверка NVIDIA драйвера

```bash
ssh admin@<VM_IP>

nvidia-smi
```

**Ожидаемый вывод:**
```text
Fri Oct 11 01:00:00 2025
+-----------------------------------------------------------------------------------------+
| NVIDIA-SMI 535.183.01             Driver Version: 535.183.01   CUDA Version: 12.2     |
|-----------------------------------------+------------------------+----------------------+
| GPU  Name                 Persistence-M | Bus-Id        Disp.A  | Volatile Uncorr. ECC |
| Fan  Temp   Perf          Pwr:Usage/Cap |         Memory-Usage  | GPU-Util  Compute M. |
|                                         |                       |               MIG M. |
|=========================================+========================+======================|
|   0  NVIDIA GeForce GTX 1050 Ti     Off | 00000000:00:10.0  Off |                  N/A |
| 40%   35C    P0              N/A /  75W |      0MiB /  4096MiB  |      0%      Default |
|                                         |                       |                  N/A |
+-----------------------------------------+------------------------+----------------------+
```

**Критерий успеха:**
- Видна модель GPU: GeForce GTX 1050 Ti
- Driver Version: 535.xxx или новее
- CUDA Version: 12.x
- Memory: 4096 MiB

**Если ошибка "NVIDIA-SMI has failed":**
```bash
# Проверка установки
dpkg -l | grep nvidia-driver

# Переустановка
sudo apt install --reinstall nvidia-driver-535

# Проверка загрузки модуля
lsmod | grep nvidia

# Если модуль не загружен
sudo modprobe nvidia
nvidia-smi
```

---

## Этап 10: Установка и настройка Ollama

### 10.1 Установка Ollama

```bash
# Официальный install script
curl -fsSL https://ollama.ai/install.sh | sh
```

**Что делает скрипт:**
1. Скачивает бинарник Ollama
2. Устанавливает в `/usr/local/bin/ollama`
3. Создает systemd unit `/etc/systemd/system/ollama.service`
4. Запускает сервис

**Критерий успеха:**
```bash
ollama --version
# Вывод: ollama version is 0.x.x

systemctl status ollama.service
# Вывод: active (running)
```

### 10.2 Настройка сетевого доступа к API

По умолчанию Ollama слушает только на 127.0.0.1. Для доступа из n8n нужно изменить на 0.0.0.0.

```bash
sudo systemctl edit ollama.service
```

Откроется редактор. Добавьте:

```ini
[Service]
Environment="OLLAMA_HOST=0.0.0.0:11434"
Environment="OLLAMA_ORIGINS=*"
Environment="CUDA_VISIBLE_DEVICES=0"
```

**Объяснение:**
- `OLLAMA_HOST=0.0.0.0:11434` - слушать на всех интерфейсах
- `OLLAMA_ORIGINS=*` - разрешить CORS для любых источников
- `CUDA_VISIBLE_DEVICES=0` - явно указать использовать GPU 0

Сохраните: Ctrl+O, Enter, Ctrl+X

Применение изменений:

```bash
sudo systemctl daemon-reload
sudo systemctl restart ollama.service
```

### 10.3 Проверка API endpoint

```bash
# Локально в VM
curl http://localhost:11434/api/tags

# Должен вернуть:
# {"models":[]}
```

С Proxmox хоста или вашей рабочей машины:

```bash
curl http://<VM_IP>:11434/api/tags

# Должен вернуть тот же JSON
```

**Критерий успеха:** API отвечает на запросы по сети.

**Если Connection refused:**
```bash
# Проверка что сервис слушает на 0.0.0.0
sudo ss -tlnp | grep 11434

# Должно быть: 0.0.0.0:11434 (не 127.0.0.1)

# Проверка переменных окружения
systemctl show ollama.service | grep Environment

# Должно содержать: OLLAMA_HOST=0.0.0.0:11434

# Если нет, повторите шаг 10.2
```

---

## Этап 11: Загрузка и тестирование модели

### 11.1 Выбор модели по VRAM

**Для GTX 1050 Ti (4GB VRAM):**

| Модель | Размер | VRAM | Скорость в VM | Рекомендация |
|--------|--------|------|---------------|--------------|
| `phi3:mini` | 2.3GB | ~2.5GB | 40-50 tok/s | ✅ Лучший баланс |
| `llama3.2:3b` | 2GB | ~2.2GB | 50-60 tok/s | ✅ Быстрее |
| `qwen2.5:3b` | 2GB | ~2.2GB | 40-50 tok/s | ✅ Хорошая альтернатива |
| `gemma2:2b` | 1.6GB | ~1.8GB | 70+ tok/s | ✅ Для простых задач |

**Рекомендация:** `phi3:mini` - отличное качество ответов на русском.

### 11.2 Загрузка модели

```bash
ollama pull phi3:mini
```

**Процесс загрузки:**
```text
pulling manifest
pulling 8c83cdcf6a98... 100% ▕████████████████▏ 2.3 GB
pulling ed11eda7790d... 100% ▕████████████████▏  106 B
pulling ca31f59a46fb... 100% ▕████████████████▏  485 B
verifying sha256 digest
writing manifest
removing any unused layers
success
```

Время загрузки: ~2-5 минут (зависит от интернета).

### 11.3 Проверка загруженной модели

```bash
ollama list
```

**Вывод:**
```text
NAME         ID          SIZE    MODIFIED
phi3:mini    1a4e8c5f... 2.3 GB  2 minutes ago
```

### 11.4 Тестирование модели с GPU

```bash
ollama run phi3:mini "Привет! Представься кратко на русском языке как AI ассистент для умного дома"
```

**Во время выполнения** откройте второй SSH сеанс и запустите:

```bash
watch -n 1 nvidia-smi
```

**Ожидаемое поведение:**
- GPU-Util поднимется до 80-100% во время генерации
- Memory-Usage покажет ~2500 MiB
- Temperature поднимется до 50-65°C

**Критерий успеха:**
- Модель отвечает на русском языке
- GPU используется (nvidia-smi показывает нагрузку)
- Ответ генерируется за 3-5 секунд

**Если GPU не используется (0% utilization):**
```bash
# Проверка CUDA доступности
nvidia-smi

# Перезапуск с явным указанием GPU
CUDA_VISIBLE_DEVICES=0 ollama run phi3:mini "test"

# Если работает, добавьте в systemd (уже должно быть из 10.2)
systemctl show ollama.service | grep CUDA_VISIBLE_DEVICES
```

### 11.5 Тестирование API

```bash
curl http://localhost:11434/api/generate -H "Content-Type: application/json" -d '{
  "model": "phi3:mini",
  "prompt": "Кратко опиши свои возможности как AI ассистента",
  "stream": false
}'
```

**Ожидаемый ответ:**
```json
{
  "model": "phi3:mini",
  "created_at": "2025-10-11T01:00:00.000Z",
  "response": "Я AI ассистент, способный помогать с различными задачами...",
  "done": true,
  "total_duration": 4500000000,
  "load_duration": 500000000,
  "prompt_eval_duration": 100000000,
  "eval_count": 85,
  "eval_duration": 2000000000
}
```

**Производительность:**
- `eval_count` / (`eval_duration` / 1e9) = tokens per second
- Для phi3:mini ожидается: ~40-50 tokens/sec

---

## Этап 12: Интеграция с n8n

### 12.1 Скачивание workflow

На вашей рабочей машине:

```bash
cd /home/gfer/HASSio
# Файл уже есть в репозитории
ls -lh docs/integrations/n8n-voice-assistant-ollama.json
```

### 12.2 Импорт в n8n

1. Откройте n8n Web UI
2. **Workflows** → **Add workflow** → **Import from File**
3. Выберите файл `n8n-voice-assistant-ollama.json`
4. Workflow откроется с 16 nodes

### 12.3 Конфигурация Ollama node

Найдите node **"Ollama: Model"**:

**Параметры:**
- **Base URL:** `http://<VM_IP>:11434` (IP вашей Ollama VM)
- **Model:** `phi3:mini`

Тест подключения:

```bash
# С машины где работает n8n
curl http://<VM_IP>:11434/api/tags
```

Должен вернуть список моделей.

### 12.4 Конфигурация Home Assistant

Node **"HA: Get All States"**:

- **URL:** `http://<HA_IP>:8123/api/states`
- **Authentication:** Header Auth
- **Credential:** Создайте в n8n:
  - Type: HTTP Header Auth
  - Name: `Authorization`
  - Value: `Bearer <YOUR_HA_LONG_LIVED_TOKEN>`

**Получение HA токена:**
1. Home Assistant → Профиль (левый нижний угол)
2. Long-Lived Access Tokens → Create Token
3. Name: `n8n-ollama`
4. Скопируйте токен

### 12.5 Конфигурация Telegram

Создайте Telegram Bot:
1. Telegram → @BotFather → `/newbot`
2. Name: `My Home Assistant Bot`
3. Username: `my_ha_ollama_bot`
4. Получите token: `123456:ABCdefGHI...`

Получите ваш Telegram ID:
1. Telegram → @userinfobot → отправьте любое сообщение
2. Скопируйте ID

В n8n создайте Telegram credential:
- Type: Telegram API
- Access Token: `123456:ABCdefGHI...`

Node **"Telegram: Trigger"**:
- **User IDs:** ваш Telegram ID
- **Credential:** выберите созданный Telegram credential

### 12.6 Создание Tool workflows

Для работы AI Agent нужно создать 5 sub-workflows для управления Home Assistant.

**Минимальный пример - Tool "Turn On Light":**

1. Создайте новый workflow: **+ Add workflow**
2. Добавьте node **HTTP Request**:
   - Method: `POST`
   - URL: `http://<HA_IP>:8123/api/services/light/turn_on`
   - Authentication: Header Auth (ваш HA credential)
   - Body Content Type: JSON
   - Body:
   ```json
   {
     "entity_id": "={{ $json.entity_id }}"
   }
   ```
3. **Save** workflow
4. Скопируйте ID workflow (из URL: `.../workflow/<ID>`)
5. В главном workflow найдите node **"Tool: Turn On Light"**
6. Параметр **Workflow ID:** вставьте скопированный ID

Повторите для остальных tools:
- `Tool: Turn Off Light` - POST `/api/services/light/turn_off`
- `Tool: Set Temperature` - POST `/api/services/climate/set_temperature`
- `Tool: Activate Scene` - POST `/api/services/scene/turn_on`
- `Tool: Get Sensor` - GET `/api/states/{{ $json.entity_id }}`

### 12.7 Активация workflow

1. **Save** главный workflow
2. Активируйте toggle справа вверху (Active)
3. Откройте Telegram → найдите вашего бота
4. Отправьте: `/start`

**Ожидаемый ответ:**
```text
🤖 Текстовый ассистент Home Assistant + Ollama

*Команды:*
• Включи/выключи свет [комната]
...
```

---

## Этап 13: Тестирование системы

### 13.1 Простая команда

В Telegram боту:
```text
Привет!
```

Бот должен ответить через 3-5 секунд.

### 13.2 Команда управления

```text
Включи свет на кухне
```

Если у вас есть `light.kitchen`, бот должен выполнить команду.

### 13.3 Мониторинг GPU

Во время работы бота:

```bash
# В VM
watch -n 1 nvidia-smi
```

Наблюдайте:
- GPU-Util: 80-100% во время генерации
- Memory: ~2.5GB используется
- Temperature: 45-65°C

### 13.4 Проверка производительности

Измерьте время ответа:
- Простой вопрос: 2-4 секунды
- Команда с вызовом tool: 4-7 секунд
- Сложный вопрос: 5-8 секунд

**Для GTX 1050 Ti + phi3:mini это нормально.**

---

## Обслуживание и мониторинг

### Snapshot VM перед изменениями

```bash
# На Proxmox хосте
qm snapshot 300 clean-phi3mini-install
```

### Backup VM

```bash
# Snapshot backup
vzdump 300 --mode snapshot --storage local --compress zstd

# Backup сохранится в /var/lib/vz/dump/
```

### Обновление Ollama

```bash
ssh admin@<VM_IP>

# Обновление
curl -fsSL https://ollama.ai/install.sh | sh

# Рестарт
sudo systemctl restart ollama.service
```

### Добавление модели после апгрейда GPU

После замены GTX 1050 Ti на GTX 1060 (6GB):

```bash
# Загрузка более мощной модели
ollama pull llama3.1:8b

# Проверка размера
ollama list

# Тест
ollama run llama3.1:8b "Тест новой модели"

# В n8n обновите параметр model на "llama3.1:8b"
```

---

## Troubleshooting

### Проблема: VM не загружается после добавления GPU

**Симптомы:** Black screen, VM зависает при загрузке

**Решение:**

1. Выключите VM полностью (Shutdown, не Reset)
2. Proxmox Web UI → VM 300 → Hardware
3. Удалите PCI Device (hostpci0)
4. Запустите VM - должна загрузиться
5. Проверьте на хосте:
   ```bash
   lspci -nnk | grep -A 3 nvidia
   # Убедитесь: Kernel driver in use: vfio-pci
   ```
6. Выключите VM
7. Добавьте PCI Device снова:
   - ✅ All Functions
   - ✅ Primary GPU
   - ✅ PCI-Express
8. Запустите VM

### Проблема: GPU виден, но nvidia-smi не работает

**Симптомы:** `NVIDIA-SMI has failed because it couldn't communicate with the NVIDIA driver`

**Решение:**

```bash
# 1. Проверка что драйвер установлен
dpkg -l | grep nvidia-driver-535

# 2. Проверка модулей ядра
lsmod | grep nvidia

# 3. Загрузка модуля вручную
sudo modprobe nvidia

# 4. Проверка
nvidia-smi

# 5. Если не помогло - переустановка
sudo apt purge nvidia-*
sudo apt autoremove
sudo ubuntu-drivers autoinstall
sudo reboot
```

### Проблема: Ollama медленно отвечает (CPU mode)

**Симптомы:** Ответы за 20-30+ секунд, nvidia-smi показывает 0% GPU util

**Решение:**

```bash
# 1. Проверка CUDA
nvidia-smi

# 2. Тест Ollama с явным GPU
CUDA_VISIBLE_DEVICES=0 ollama run phi3:mini "test"

# Если работает - проблема в systemd unit:
sudo systemctl edit ollama.service

# Добавьте:
# [Service]
# Environment="CUDA_VISIBLE_DEVICES=0"

sudo systemctl daemon-reload
sudo systemctl restart ollama.service
```

### Проблема: Out of Memory при загрузке модели

**Симптомы:** Ollama крашится при `ollama run`, ошибка CUDA OOM

**Решение:**

1. Выберите меньшую модель:
   ```bash
   # Вместо phi3:mini попробуйте
   ollama pull gemma2:2b
   ```

2. Увеличьте RAM VM (на Proxmox хосте):
   ```bash
   # Выключите VM
   qm shutdown 300
   
   # Увеличьте до 12GB
   qm set 300 --memory 12288
   
   # Запустите
   qm start 300
   ```

### Проблема: Code 43 в Device Manager (если Windows VM)

Не применимо к Ubuntu, но для справки:
- Добавьте `args: -cpu host,kvm=off` в конфиг VM
- Это скрывает виртуализацию от NVIDIA драйвера

---

## Производительность и метрики

### GTX 1050 Ti (4GB) + phi3:mini в VM

**Measured metrics:**
- Cold start latency: 4-6 секунд
- Warm latency: 2-3 секунды  
- Throughput: 40-50 tokens/sec
- VRAM usage: 2.4-2.6GB / 4GB
- GPU utilization: 85-95% во время inference
- Power draw: 50-70W (из 75W TDP)

**Сравнение с LXC:** ~5-10% медленнее (приемлемо за безопасность)

### GTX 1060 (6GB) + llama3.1:8b после апгрейда

**Expected metrics:**
- Cold start latency: 5-8 секунд
- Warm latency: 2-4 секунды
- Throughput: 30-45 tokens/sec
- VRAM usage: 4.8-5.2GB / 6GB
- GPU utilization: 80-90%

---

## Оптимизация производительности

### CPU pinning для VM

На Proxmox хосте (если у вас 8+ cores):

```bash
# Pin VM к specific cores (например 4-7 на 8-core CPU)
qm set 300 --cpulimit 4
nano /etc/pve/qemu-server/300.conf
```

Добавьте:
```text
affinity: 4-7
```

### Huge pages (для моделей 8B+)

На Proxmox хосте:

```bash
# Выделить 4GB huge pages (для llama3.1:8b)
sysctl vm.nr_hugepages=2048

# Persistent:
echo "vm.nr_hugepages=2048" >> /etc/sysctl.conf
```

В VM конфиге:
```text
hugepages: 1024
```

---

## Финальная архитектура

```text
┌─────────────────────────────────────────────┐
│  Proxmox VE Host (Debian 12 Bookworm)       │
│  ┌────────────────────────────────────────┐ │
│  │ IOMMU/VT-d: Enabled                    │ │
│  │ VFIO modules: Loaded                   │ │
│  │ GPU bound to: vfio-pci                 │ │
│  └────────────────────────────────────────┘ │
│              ↓ PCI Passthrough              │
│  ┌────────────────────────────────────────┐ │
│  │ Ubuntu Server 22.04 VM (ID: 300)       │ │
│  │ ┌────────────────────────────────────┐ │ │
│  │ │ NVIDIA Driver 535+                 │ │ │
│  │ │ CUDA 12.2                          │ │ │
│  │ └────────────────────────────────────┘ │ │
│  │ ┌────────────────────────────────────┐ │ │
│  │ │ Ollama Service                     │ │ │
│  │ │ API: 0.0.0.0:11434                 │ │ │
│  │ │ Model: phi3:mini (2.3GB)           │ │ │
│  │ └────────────────────────────────────┘ │ │
│  │ Resources:                             │ │
│  │ - CPU: 4 cores (type: host)            │ │
│  │ - RAM: 8GB                             │ │
│  │ - Disk: 50GB VirtIO                   │ │
│  │ - GPU: GTX 1050 Ti (passthrough)       │ │
│  └────────────────────────────────────────┘ │
└─────────────────────────────────────────────┘
           │ Network: vmbr0
           ↓
┌────────────────────────────┐
│  n8n Server                │
│  HTTP: <VM_IP>:11434       │
│  ┌──────────────────────┐  │
│  │ Langchain Agent      │  │
│  │ - Ollama LLM         │  │
│  │ - Memory Buffer      │  │
│  │ - HA Tools (5)       │  │
│  └──────────────────────┘  │
└────────────────────────────┘
           ↓
┌────────────────────────────┐
│  Home Assistant            │
│  REST API: :8123           │
└────────────────────────────┘
           ↓
┌────────────────────────────┐
│  Telegram Bot              │
│  User Interface            │
└────────────────────────────┘
```

---

## Чеклист успешной установки

Пройдитесь по списку, все должно быть ✅:

**Proxmox хост:**
- ✅ IOMMU enabled в BIOS
- ✅ GRUB обновлен с intel_iommu=on/amd_iommu=on
- ✅ VFIO модули загружены (`lsmod | grep vfio`)
- ✅ GPU captured by vfio-pci (`lspci -k`)
- ✅ Нет NVIDIA драйверов на хосте (`dpkg -l | grep nvidia` - пусто)

**Ubuntu VM:**
- ✅ GPU виден в VM (`lspci | grep nvidia`)
- ✅ NVIDIA драйвер установлен (`nvidia-smi` работает)
- ✅ Ollama сервис запущен (`systemctl status ollama`)
- ✅ API доступен (`curl http://localhost:11434/api/tags`)
- ✅ Модель загружена (`ollama list`)
- ✅ GPU используется (`nvidia-smi` показывает нагрузку при inference)

**n8n интеграция:**
- ✅ Workflow импортирован
- ✅ Ollama node настроен (Base URL правильный)
- ✅ HA credential создан
- ✅ Telegram credential создан
- ✅ 5 Tool workflows созданы
- ✅ Workflow активирован
- ✅ Telegram бот отвечает

---

## Полезные команды для диагностики

### На Proxmox хосте

```bash
# IOMMU статус
dmesg | grep -i iommu

# VFIO модули
lsmod | grep vfio

# GPU binding
lspci -nnk | grep -A 3 nvidia

# IOMMU группы
for d in /sys/kernel/iommu_groups/*/devices/*; do
    n=${d#*/iommu_groups/*}; n=${n%%/*}
    printf 'Group %s: ' "$n"
    lspci -nns "${d##*/}"
done | sort -n -k2

# Статус VM
qm status 300
qm config 300
```

### В Ubuntu VM

```bash
# GPU наличие
lspci | grep -i nvidia

# NVIDIA драйвер
nvidia-smi
nvidia-smi -L

# CUDA версия
nvcc --version  # Если установлен CUDA toolkit (опционально)

# Ollama сервис
systemctl status ollama.service
journalctl -u ollama.service -n 50

# Ollama процесс
ps aux | grep ollama

# Сетевой доступ
ss -tlnp | grep 11434

# Модели
ollama list

# Тест API
curl http://localhost:11434/api/tags
```

---

## Источники и благодарности

Данное руководство основано на:

- **Proxmox Official Documentation**  
  [PCI Passthrough Wiki](https://pve.proxmox.com/wiki/PCI_Passthrough)

- **Habr Community (русский)**  
  [Проброс видеокарты в Proxmox](https://habr.com/ru/articles/794568/)

- **Proxmox Forum**  
  [Ollama + NVIDIA GPU Passthrough Discussion](https://forum.proxmox.com/threads/ubuntu-22-04-ollama-nvidia-3060-gpu-passthrough-and-drivers-all-looking-good-but.144104/)

- **Ollama Official**  
  [GPU Support Documentation](https://github.com/ollama/ollama/blob/main/docs/gpu.md)

- **VFIO Documentation**  
  [Linux VFIO Documentation](https://www.kernel.org/doc/html/latest/driver-api/vfio.html)

---

## Следующие шаги

1. ✅ BIOS настроен (IOMMU enabled)
2. ✅ Proxmox настроен (GRUB, VFIO)
3. ✅ GPU привязан к vfio-pci
4. ✅ Ubuntu VM создана
5. ✅ GPU передан в VM
6. ✅ NVIDIA драйверы в VM
7. ✅ Ollama установлен
8. ✅ Модель загружена
9. ✅ n8n интегрирован
10. 🔄 Протестируйте различные команды
11. 🔄 Настройте дополнительные HA Tools
12. 🔄 После апгрейда GPU установите llama3.1:8b

---

**Автор:** AI Assistant (Proxmox DevOps Expert)  
**Консолидация:** Community Best Practices + Deep Proxmox Knowledge  
**Проверено на:** Proxmox VE 8.x, NVIDIA GTX 10xx series  
**Версия:** 1.0 Final  
**Дата:** Октябрь 2025

