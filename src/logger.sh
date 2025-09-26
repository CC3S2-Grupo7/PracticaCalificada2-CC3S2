#!/bin/bash
# Funciones de logging con colores ANSI

# Niveles: 0=ERROR, 1=WARN, 2=INFO, 3=DEBUG
LOG_LEVEL=${LOG_LEVEL:-2}  # Por defecto INFO

# Colores
RED="\033[0;31m"
YELLOW="\033[0;33m"
GREEN="\033[0;32m"
BLUE="\033[0;34m"
GRAY="\033[0;90m"
RESET="\033[0m"

_log() {
    local level_num=$1
    local level_name=$2
    local color=$3
    shift 3
    local msg="$*"

    # Timestamp en formato YYYY-MM-DD HH:MM:SS
    local ts
    ts=$(date +"%Y-%m-%d %H:%M:%S")

    if [[ $LOG_LEVEL -ge $level_num ]]; then
        echo -e "$ts ${color}[${level_name}]${RESET} $msg" >&2
    fi
}

log_error()   { _log 0 "ERROR" "$RED" "$@"; }
log_warn()    { _log 1 "WARN"  "$YELLOW" "$@"; }
log_info()    { _log 2 "INFO"  "$BLUE" "$@"; }
log_debug()   { _log 3 "DEBUG" "$GRAY" "$@"; }
log_success() { _log 2 "SUCCESS" "$GREEN" "$@"; }
