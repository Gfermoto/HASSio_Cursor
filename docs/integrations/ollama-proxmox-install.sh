#!/bin/bash
#
# Автоматическая установка Ollama на Proxmox LXC с NVIDIA GPU
# Версия: 1.0
# Дата: Октябрь 2025
#

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функции для вывода
info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# Проверка что запущен на Proxmox
check_proxmox() {
    info "Проверка Proxmox..."

    if [ ! -f /etc/pve/.version ]; then
        error "Этот скрипт должен быть запущен на Proxmox хосте!"
    fi

    success "Proxmox обнаружен"
}

# Проверка GPU
check_gpu() {
    info "Проверка NVIDIA GPU..."

    if ! lspci | grep -i nvidia > /dev/null; then
        error "NVIDIA GPU не обнаружен!"
    fi

    GPU_INFO=$(lspci | grep -i nvidia | head -1)
    success "Обнаружен: $GPU_INFO"
}

# Установка NVIDIA драйверов на хост
install_nvidia_host() {
    info "Установка NVIDIA драйверов на Proxmox хост..."

    # Проверка уже установлен ли nvidia-smi
    if command -v nvidia-smi &> /dev/null; then
        warning "NVIDIA драйверы уже установлены"
        nvidia-smi
        read -p "Переустановить? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return
        fi
    fi

    # Добавить non-free репозитории
    info "Добавление non-free репозиториев..."
    sed -i 's/main$/main contrib non-free non-free-firmware/' /etc/apt/sources.list
    apt update

    # Установить заголовки ядра
    info "Установка заголовков ядра..."
    apt install -y "pve-headers-$(uname -r)"

    # Установить NVIDIA драйверы
    info "Поиск доступных версий NVIDIA драйверов..."
    NVIDIA_VERSIONS=$(apt-cache search --names-only '^nvidia-driver-[0-9]+$' | awk '{print $1}' | sort -V | tail -3)
    
    if [ -z "$NVIDIA_VERSIONS" ]; then
        error "NVIDIA драйверы не найдены в репозиториях. Проверьте что добавлены non-free репозитории."
    fi
    
    info "Доступные версии:"
    echo "$NVIDIA_VERSIONS"
    
    # Выбор последней стабильной версии (535 или выше)
    NVIDIA_DRIVER=$(echo "$NVIDIA_VERSIONS" | grep -E 'nvidia-driver-(535|545|550)' | tail -1)
    
    if [ -z "$NVIDIA_DRIVER" ]; then
        # Fallback на самую новую версию
        NVIDIA_DRIVER=$(echo "$NVIDIA_VERSIONS" | tail -1)
    fi
    
    info "Установка $NVIDIA_DRIVER..."
    apt install -y "$NVIDIA_DRIVER" nvidia-smi

    # Blacklist nouveau
    info "Отключение nouveau..."
    echo "blacklist nouveau" > /etc/modprobe.d/blacklist-nouveau.conf
    echo "options nouveau modeset=0" >> /etc/modprobe.d/blacklist-nouveau.conf
    update-initramfs -u

    success "NVIDIA драйверы установлены"
    warning "ТРЕБУЕТСЯ ПЕРЕЗАГРУЗКА ХОСТА!"
    warning "Запустите: reboot"
    warning "После перезагрузки запустите скрипт снова с опцией --create-lxc"

    exit 0
}

# Получить device nodes
get_device_nodes() {
    info "Определение NVIDIA device nodes..."

    NVIDIA0_MAJOR=$(stat -c '%t' /dev/nvidia0)
    NVIDIA0_MINOR=$(stat -c '%T' /dev/nvidia0)
    NVIDIACTL_MAJOR=$(stat -c '%t' /dev/nvidiactl)
    NVIDIACTL_MINOR=$(stat -c '%T' /dev/nvidiactl)

    # Конвертация из hex в decimal
    NVIDIA0_MAJOR=$((16#$NVIDIA0_MAJOR))
    NVIDIA0_MINOR=$((16#$NVIDIA0_MINOR))
    NVIDIACTL_MAJOR=$((16#$NVIDIACTL_MAJOR))
    NVIDIACTL_MINOR=$((16#$NVIDIACTL_MINOR))

    success "nvidia0: major=$NVIDIA0_MAJOR, minor=$NVIDIA0_MINOR"
    success "nvidiactl: major=$NVIDIACTL_MAJOR, minor=$NVIDIACTL_MINOR"
}

# Создание LXC контейнера
create_lxc() {
    info "Создание LXC контейнера для Ollama..."

    # Параметры контейнера
    read -r -p "CT ID [200]: " CTID
    CTID=${CTID:-200}

    read -r -p "Hostname [ollama]: " HOSTNAME
    HOSTNAME=${HOSTNAME:-ollama}

    read -r -p "Password: " -s PASSWORD
    echo

    read -r -p "Storage [local-lvm]: " STORAGE
    STORAGE=${STORAGE:-local-lvm}

    read -r -p "Disk size GB [50]: " DISK_SIZE
    DISK_SIZE=${DISK_SIZE:-50}

    read -r -p "Memory MB [8192]: " MEMORY
    MEMORY=${MEMORY:-8192}

    read -r -p "Cores [4]: " CORES
    CORES=${CORES:-4}

    # Проверка существования контейнера
    if pct status "$CTID" &> /dev/null; then
        error "Контейнер $CTID уже существует!"
    fi

    # Создание контейнера
    info "Создание контейнера $CTID..."

    pct create "$CTID" \
        local:vztmpl/ubuntu-24.04-standard_24.04-2_amd64.tar.zst \
        --hostname "$HOSTNAME" \
        --password "$PASSWORD" \
        --cores "$CORES" \
        --memory "$MEMORY" \
        --swap 2048 \
        --storage "$STORAGE" \
        --rootfs "$STORAGE:$DISK_SIZE" \
        --net0 name=eth0,bridge=vmbr0,ip=dhcp \
        --unprivileged 0 \
        --features nesting=1 \
        --onboot 1

    success "Контейнер $CTID создан"

    # Настройка GPU passthrough
    info "Настройка GPU passthrough..."

    get_device_nodes

    cat >> /etc/pve/lxc/"${CTID}".conf << EOF

# GPU Passthrough для NVIDIA
lxc.cgroup2.devices.allow: c ${NVIDIA0_MAJOR}:* rwm
lxc.cgroup2.devices.allow: c ${NVIDIACTL_MAJOR}:* rwm
lxc.mount.entry: /dev/nvidia0 dev/nvidia0 none bind,optional,create=file
lxc.mount.entry: /dev/nvidiactl dev/nvidiactl none bind,optional,create=file
lxc.mount.entry: /dev/nvidia-uvm dev/nvidia-uvm none bind,optional,create=file
lxc.mount.entry: /dev/nvidia-modeset dev/nvidia-modeset none bind,optional,create=file
lxc.mount.entry: /dev/nvidia-uvm-tools dev/nvidia-uvm-tools none bind,optional,create=file

# Features
lxc.apparmor.profile: unconfined
lxc.cap.drop:
lxc.cgroup2.devices.allow: a
lxc.mount.auto: proc:rw sys:rw
EOF

    success "GPU passthrough настроен"

    # Запуск контейнера
    info "Запуск контейнера..."
    pct start "$CTID"
    sleep 5

    success "Контейнер $CTID запущен"

    # Установка Ollama внутри контейнера
    info "Установка Ollama в контейнере..."

    pct exec "$CTID" -- bash << 'INNERSCRIPT'
set -e

echo "[INFO] Обновление системы..."
apt update && apt upgrade -y

echo "[INFO] Установка базовых пакетов..."
apt install -y curl wget gnupg2 software-properties-common

echo "[INFO] Установка NVIDIA Container Toolkit..."
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -s -L https://nvidia.github.io/libnvidia-container/$distribution/libnvidia-container.list | \
  sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
  tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
apt update
apt install -y nvidia-container-toolkit

echo "[INFO] Установка Ollama..."
curl -fsSL https://ollama.ai/install.sh | sh

echo "[INFO] Настройка Ollama сервиса..."
cat > /etc/systemd/system/ollama.service << 'EOF'
[Unit]
Description=Ollama Service
After=network-online.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/ollama serve
Environment="OLLAMA_HOST=0.0.0.0:11434"
Environment="OLLAMA_ORIGINS=*"
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable ollama
systemctl start ollama

sleep 3

echo "[INFO] Проверка GPU..."
ls -la /dev/nvidia* || echo "GPU devices not found yet"

echo "[OK] Ollama установлен и запущен!"
INNERSCRIPT

    success "Ollama установлен в контейнере $CTID"

    # Получить IP контейнера
    CONTAINER_IP=$(pct exec "$CTID" -- ip addr show eth0 | grep "inet " | awk '{print $2}' | cut -d/ -f1)

    success "==================================="
    success "Установка завершена!"
    success "==================================="
    success "Контейнер ID: $CTID"
    success "IP адрес: $CONTAINER_IP"
    success "Ollama API: http://${CONTAINER_IP}:11434"
    success ""
    info "Следующие шаги:"
    info "1. Войдите в контейнер: pct enter $CTID"
    info "2. Скачайте модель: ollama pull phi3:mini"
    info "3. Протестируйте: ollama run phi3:mini 'Привет!'"
    info "4. Проверьте API: curl http://${CONTAINER_IP}:11434/api/tags"
}

# Установка модели
install_model() {
    read -r -p "CT ID: " CTID

    if ! pct status "$CTID" &> /dev/null; then
        error "Контейнер $CTID не существует!"
    fi

    echo ""
    echo "Доступные модели для вашей GPU:"
    echo ""
    echo "Для GTX 1050 Ti (4GB VRAM):"
    echo "  1) phi3:mini       - 2.3GB (рекомендуется)"
    echo "  2) llama3.2:3b     - 2GB"
    echo "  3) qwen2.5:3b      - 2GB"
    echo "  4) gemma2:2b       - 1.6GB"
    echo ""
    echo "Для GTX 1060 (6GB VRAM):"
    echo "  5) llama3.1:8b     - 4.7GB (рекомендуется)"
    echo "  6) qwen2.5:7b      - 4.7GB"
    echo ""

    read -r -p "Выберите модель (1-6): " MODEL_CHOICE

    case $MODEL_CHOICE in
        1) MODEL="phi3:mini" ;;
        2) MODEL="llama3.2:3b" ;;
        3) MODEL="qwen2.5:3b" ;;
        4) MODEL="gemma2:2b" ;;
        5) MODEL="llama3.1:8b" ;;
        6) MODEL="qwen2.5:7b" ;;
        *) error "Неверный выбор!" ;;
    esac

    info "Скачивание модели $MODEL в контейнере $CTID..."
    info "Это может занять 5-10 минут..."

    pct exec "$CTID" -- ollama pull $MODEL

    success "Модель $MODEL скачана!"

    info "Тестирование модели..."
    pct exec "$CTID" -- ollama run $MODEL "Привет! Представься кратко на русском языке"

    success "Модель работает!"
}

# Проверка установки
check_installation() {
    read -r -p "CT ID: " CTID

    if ! pct status "$CTID" &> /dev/null; then
        error "Контейнер $CTID не существует!"
    fi

    info "Проверка установки в контейнере $CTID..."

    # Проверка GPU
    info "Проверка GPU devices..."
    pct exec "$CTID" -- ls -la /dev/nvidia* || warning "GPU devices не найдены"

    # Проверка Ollama
    info "Проверка Ollama сервиса..."
    pct exec "$CTID" -- systemctl status ollama --no-pager || warning "Ollama не запущен"

    # Проверка моделей
    info "Список установленных моделей..."
    pct exec "$CTID" -- ollama list

    # Проверка API
    CONTAINER_IP=$(pct exec "$CTID" -- ip addr show eth0 | grep "inet " | awk '{print $2}' | cut -d/ -f1)
    info "Проверка API на http://${CONTAINER_IP}:11434..."

    curl -s "http://${CONTAINER_IP}:11434/api/tags" | jq . || warning "API недоступен"

    success "Проверка завершена!"
}

# Главное меню
show_menu() {
    echo ""
    echo "=========================================="
    echo "  Ollama Proxmox Installer"
    echo "=========================================="
    echo ""
    echo "1) Установить NVIDIA драйверы на хост"
    echo "2) Создать LXC контейнер с Ollama"
    echo "3) Установить модель в контейнер"
    echo "4) Проверить установку"
    echo "5) Выход"
    echo ""
    read -r -p "Выберите действие (1-5): " choice

    case $choice in
        1)
            check_proxmox
            check_gpu
            install_nvidia_host
            ;;
        2)
            check_proxmox
            check_gpu
            if ! command -v nvidia-smi &> /dev/null; then
                error "Сначала установите NVIDIA драйверы на хост (опция 1)"
            fi
            create_lxc
            ;;
        3)
            install_model
            ;;
        4)
            check_installation
            ;;
        5)
            exit 0
            ;;
        *)
            error "Неверный выбор!"
            ;;
    esac

    show_menu
}

# Парсинг аргументов командной строки
if [ "$1" == "--install-host" ]; then
    check_proxmox
    check_gpu
    install_nvidia_host
elif [ "$1" == "--create-lxc" ]; then
    check_proxmox
    check_gpu
    create_lxc
elif [ "$1" == "--install-model" ]; then
    install_model
elif [ "$1" == "--check" ]; then
    check_installation
elif [ "$1" == "--help" ] || [ "$1" == "-h" ]; then
    echo "Использование:"
    echo "  $0                    - интерактивное меню"
    echo "  $0 --install-host     - установить NVIDIA драйверы на хост"
    echo "  $0 --create-lxc       - создать LXC контейнер с Ollama"
    echo "  $0 --install-model    - установить модель"
    echo "  $0 --check            - проверить установку"
    echo "  $0 --help             - показать эту справку"
    exit 0
else
    # Интерактивное меню
    show_menu
fi
