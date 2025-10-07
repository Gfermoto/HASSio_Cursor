#!/bin/bash
# Библиотека для логирования

# Определить корень проекта
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_FILE="$PROJECT_ROOT/logs/actions.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log_success() {
    log "✅ $1"
}

log_error() {
    log "❌ $1"
}

log_warning() {
    log "⚠️  $1"
}

log_info() {
    log "ℹ️  $1"
}
