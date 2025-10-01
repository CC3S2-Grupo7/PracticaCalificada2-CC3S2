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

	if ((PORT < 1024 || PORT > 65535)); then
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
		ERRORS+=("$var_name debe ser ruta no vacía, actual: 'no definido'")
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

#validacion de runtime_mode
validate_runtime_mode() {
	local valid_modes=("debug" "production")
	local found=0

	# Itera sobre los modos válidos y compara con el valor actual
	for mode in "${valid_modes[@]}"; do
		# Comparamos el valor de RUNTIME_MODE (usando :- para evitar error si no está definida, aunque ya la definimos)
		if [[ "${RUNTIME_MODE:-}" == "$mode" ]]; then
			found=1
			break
		fi
	done

	if ((found == 0)); then
		# Si no se encuentra el modo en la lista, registra un error crítico
		ERRORS+=("RUNTIME_MODE debe ser 'debug' o 'production', actual: ${RUNTIME_MODE:-'no definido'}")
		return 1
	fi

	return 0
}
# Validar todas las variables de entorno necesarias
validate_env() {
	ERRORS=() # Limpiar los errores anteriores
	local status=0

	# Se usa una variable status ya que queremos reportar todos los errores juntos
	validate_port || status=1
	validate_release || status=1
	validate_directory OUT_DIR || status=1
	validate_directory DIST_DIR || status=1
	# Llama a la nueva validación:
	validate_runtime_mode || status=1
	# Reportar errores
	if ((${#ERRORS[@]} > 0)); then
		log_error "Errores encontrados:"
		for err in "${ERRORS[@]}"; do
			log_error "  - $err"
		done
		return 1
	fi

	# Reportar advertencias
	if ((${#WARNINGS[@]} > 0)); then
		log_warn "Advertencias encontradas:"
		for warn in "${WARNINGS[@]}"; do
			log_warn "  - $warn"
		done
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
