#!/bin/bash
set -euo pipefail

# Importar funciones de log
source "$(dirname "$0")/logger.sh"

# Array global para acumular errores
declare -a ERRORS=()
declare -a WARNINGS=()

# Validar PORT
validate_port() {
    if [[ ! "${PORT:-}" =~ ^[0-9]+$ ]]; then
        ERRORS+=("PORT debe ser numérico, actual: ${PORT:-'no definido'}")
        return 1
    fi

    if (( PORT < 1024 || PORT > 65535 )); then
        ERRORS+=("PORT debe estar entre 1024-65535, actual: $PORT")
        return 1
    fi

    return 0
}

# Validar RELEASE
validate_release() {
    local semver_regex='^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-[0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?$'
    if [[ ! "${RELEASE:-}" =~ $semver_regex ]]; then
        ERRORS+=("RELEASE debe seguir formato semántico (x.y.z[-sufijo][+build]), actual: ${RELEASE:-'no definido'}")
        return 1
    fi
    return 0
}

# Validar un directorio específico
validate_directory() {
    local var_name="$1"
    local value="${!var_name:-}"

    if [[ -z "$value" ]]; then
        ERRORS+=("$var_name debe ser ruta relativa no vacía, actual: 'no definido'")
        return 1
    fi

    if [[ "$value" =~ ^/ ]]; then
        ERRORS+=("$var_name debe ser ruta relativa, actual: $value")
        return 1
    fi

    if [[ ! -d "$value" ]]; then
        WARNINGS+=("$var_name apunta a un directorio inexistente: $value")
        return 0
    fi

    return 0
}

# Validar todas las variables de entorno necesarias
validate_env() {
    ERRORS=()  # Limpiar los errores anteriores
    local status=0

    # Se usa una variable status ya que queremos reportar todos los errores juntos
    validate_port    || status=1
    validate_release || status=1
    validate_directory OUT_DIR || status=1
    validate_directory DIST_DIR || status=1

    if ((${#ERRORS[@]} > 0)); then
        log_error "Configuración inválida:"
        for err in "${ERRORS[@]}"; do
            log_error "  - $err"
        done
        return 1
    fi

    return $status
}

# Ejecutar si se llama directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    log_info "=== Validando configuración ==="
    if validate_env; then
        log_success "Configuración válida"
        log_info "Puerto: $PORT, Release: $RELEASE, Directorios: $OUT_DIR, $DIST_DIR"
    else
        log_error "Configuración inválida (ver detalles arriba)"
        exit 1
    fi
fi
