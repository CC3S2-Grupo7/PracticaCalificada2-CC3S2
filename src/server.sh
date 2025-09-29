#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$(dirname "$0")"
source "$BASE_DIR/logger.sh"
source "$BASE_DIR/check-env.sh"

# Validar configuracion
if ! validate_env; then
    log_error "Configuracion invalida"
    exit 1
fi

# Servidor no implementado
log_warn "Servidor HTTP no esta implementado aun"
log_info "Puerto configurado: $PORT"
log_info "Release: $RELEASE"
log_error "Servidor terminando"

# Salir inmediatamente
exit 1