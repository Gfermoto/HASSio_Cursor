#!/bin/bash
#
# Исправление репозиториев Proxmox для установки NVIDIA драйверов
# Использование: ./fix-proxmox-nvidia-repos.sh
#
# Автор: AI Assistant (DevOps)
# Версия: 1.0
# Дата: Октябрь 2025
#

set -e

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# Проверка что запущено на Proxmox
if [ ! -f /etc/pve/.version ]; then
    error "Этот скрипт должен быть запущен на Proxmox VE хосте"
fi

info "Proxmox VE версия: $(pveversion | head -1)"

# Определение Debian версии
DEBIAN_VERSION=$(cat /etc/debian_version | cut -d. -f1)

case $DEBIAN_VERSION in
    12)
        DEBIAN_CODENAME="bookworm"
        ;;
    11)
        DEBIAN_CODENAME="bullseye"
        ;;
    *)
        DEBIAN_CODENAME=$(grep VERSION_CODENAME /etc/os-release | cut -d= -f2)
        warning "Нестандартная версия Debian, использую: $DEBIAN_CODENAME"
        ;;
esac

info "Debian $DEBIAN_VERSION ($DEBIAN_CODENAME)"
echo ""

# Backup
info "Создание backup текущей конфигурации..."
BACKUP_FILE="/etc/apt/sources.list.backup.$(date +%Y%m%d_%H%M%S)"
cp /etc/apt/sources.list "$BACKUP_FILE"
success "Backup: $BACKUP_FILE"

# Создание правильного sources.list
info "Настройка Debian репозиториев с non-free..."

cat > /etc/apt/sources.list << EOF
# Debian $DEBIAN_CODENAME - основные репозитории
deb http://deb.debian.org/debian $DEBIAN_CODENAME main contrib non-free non-free-firmware
deb http://deb.debian.org/debian $DEBIAN_CODENAME-updates main contrib non-free non-free-firmware

# Debian Security
deb http://security.debian.org/debian-security $DEBIAN_CODENAME-security main contrib non-free non-free-firmware
EOF

success "Создан /etc/apt/sources.list"

# Proxmox no-subscription репозиторий
if [ ! -f /etc/apt/sources.list.d/pve-no-subscription.list ]; then
    info "Добавление Proxmox no-subscription репозитория..."
    echo "deb http://download.proxmox.com/debian/pve $DEBIAN_CODENAME pve-no-subscription" \
        > /etc/apt/sources.list.d/pve-no-subscription.list
    success "Создан pve-no-subscription.list"
fi

# Отключение enterprise (требует подписку)
if [ -f /etc/apt/sources.list.d/pve-enterprise.list ]; then
    if grep -q "^deb" /etc/apt/sources.list.d/pve-enterprise.list; then
        info "Отключение enterprise репозитория..."
        sed -i 's/^deb/#deb/' /etc/apt/sources.list.d/pve-enterprise.list
        success "Enterprise репозиторий отключен"
    fi
fi

# Обновление индекса пакетов
info "Обновление списка пакетов (apt update)..."
apt update

# Поиск NVIDIA драйверов
info "Поиск доступных NVIDIA драйверов..."
NVIDIA_LIST=$(apt-cache search --names-only 'nvidia-driver' | grep -E 'nvidia-driver-[0-9]+')

if [ -z "$NVIDIA_LIST" ]; then
    error "NVIDIA драйверы не найдены даже после настройки репозиториев. Проверьте интернет соединение."
fi

echo ""
success "Доступные NVIDIA драйверы:"
echo "$NVIDIA_LIST"
echo ""

# Выбор версии (535, 545, 550 - стабильные для CUDA 12+)
NVIDIA_DRIVER=$(echo "$NVIDIA_LIST" | grep -oP 'nvidia-driver-\d+' | \
    grep -E '(535|545|550)' | sort -V | tail -1)

if [ -z "$NVIDIA_DRIVER" ]; then
    # Fallback на последнюю доступную
    NVIDIA_DRIVER=$(echo "$NVIDIA_LIST" | grep -oP 'nvidia-driver-\d+' | sort -V | tail -1)
    warning "Стабильная версия не найдена, использую последнюю: $NVIDIA_DRIVER"
else
    info "Выбрана стабильная версия: $NVIDIA_DRIVER"
fi

echo ""
read -r -p "Установить $NVIDIA_DRIVER? (y/N): " confirm

if [[ ! $confirm =~ ^[Yy]$ ]]; then
    info "Установка отменена"
    exit 0
fi

# Установка
info "Установка pve-headers для ядра $(uname -r)..."
apt install -y "pve-headers-$(uname -r)"

info "Установка $NVIDIA_DRIVER (это займет несколько минут)..."
apt install -y "$NVIDIA_DRIVER"

# nvidia-utils (включает nvidia-smi)
DRIVER_VERSION=$(echo "$NVIDIA_DRIVER" | grep -oP '\d+$')
if ! command -v nvidia-smi &> /dev/null; then
    info "Установка nvidia-utils-${DRIVER_VERSION}..."
    apt install -y "nvidia-utils-${DRIVER_VERSION}" || warning "nvidia-smi уже включен в драйвер"
fi

# Blacklist nouveau
info "Настройка blacklist для nouveau..."
cat > /etc/modprobe.d/blacklist-nouveau.conf << 'EOFBL'
blacklist nouveau
options nouveau modeset=0
EOFBL

# Обновление initramfs
info "Обновление initramfs..."
update-initramfs -u

echo ""
echo "=========================================="
success "Установка завершена успешно!"
echo "=========================================="
echo ""
success "Установлен: $NVIDIA_DRIVER"
success "Backup конфигурации: $BACKUP_FILE"
echo ""
warning "ТРЕБУЕТСЯ ПЕРЕЗАГРУЗКА ХОСТА!"
echo ""
echo "Выполните команду:"
echo "  reboot"
echo ""
echo "После перезагрузки проверьте:"
echo "  nvidia-smi"
echo ""

