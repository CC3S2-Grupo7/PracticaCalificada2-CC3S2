#!/usr/bin/env bash
set -euo pipefail

# Importar dependencias
BASE_DIR="$(dirname "$0")"
source "$BASE_DIR/check-env.sh"
source "$BASE_DIR/logger.sh"

# Variables de entorno por defecto
HOST="${HOST:-127.0.0.1}"
PORT="${PORT:-8080}"

# Variables para limpieza y logging
SERVER_START=$(date +%s)
FIFO=""

# Limpieza
cleanup() {
	log_info "Apagando servidor..."
	exit_code=$?
	# Matar procesos hijos
	pkill -TERM -P $$ 2>/dev/null || true # Mandar TERM a hijos
	sleep 0.5
	pkill -KILL -P $$ 2>/dev/null || true # Forzar si no responden

	# Eliminar FIFO
	if [[ -n "$FIFO" && -p "$FIFO" ]]; then
		rm -f "$FIFO"
	fi

	sleep 0.2

	log_success "Servidor detenido correctamente"

	exit $exit_code 

}
trap cleanup SIGINT SIGTERM EXIT

# Generar respuesta HTTP
generate_response() {
	local status_code="$1"
	local content="$2"
	local content_type="${3:-application/json}"

	cat <<EOF
HTTP/1.1 $status_code
Content-Type: $content_type
Content-Length: ${#content}
Connection: close

$content

EOF
}
#Endpoint /metrics 
metrics_endpoint() {
	local timestamp
	timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

	local json_response
	json_response=$(
		cat <<EOF
{
    "service": "pipeline-cle",
    "version": "${RELEASE:-unknown}",
    "status": "up",
    "build_date": "${BUILD_DATE:-unknown}",
    "uptime_seconds": $(($(date +%s) - SERVER_START)),
    "timestamp": "$timestamp"
}
EOF
	)

	generate_response "200 OK" "$json_response"
}

# Endpoint /salud
health_endpoint() {
	local timestamp
	timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

	local json_response
	json_response=$(
		cat <<EOF
{
    "status": "OK",
    "timestamp": "$timestamp",
    "uptime_seconds": $(($(date +%s) - SERVER_START)),
}
EOF
	)

	generate_response "200 OK" "$json_response"
}

# Endpoint 404
not_found_endpoint() {
	local path="$1"
	local timestamp
	timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

	local json_response
	json_response=$(
		cat <<EOF
{
    "error": "Not Found",
    "message": "Endpoint $path no encontrado",
    "timestamp": "$timestamp",
}
EOF
	)

	generate_response "404 Not Found" "$json_response"
}

# Procesar request HTTP
process_request() {


	local request_line
	read -r request_line || return 1

	while read -r header; do
		[[ -z "$header" || "$header" == $'\r' ]] && break
	done

	local method path protocol
    # shellcheck disable=SC2034
	read -r method path protocol <<<"$request_line"
	log_info "Request: $method $path"
	case "$path" in
	"/salud" | "/salud/")
		if [[ "$method" == "GET" ]]; then
			health_endpoint
		else
			generate_response "405 Method Not Allowed" '{"error":"Method Not Allowed"}'
		fi
		;;
	"/metrics" | "/metrics/")
		if [[ "$method" == "GET" ]]; then
			metrics_endpoint
		else
			generate_response "405 Method Not Allowed" '{"error":"Method Not Allowed"}'
		fi
		;;	
	*)
		not_found_endpoint "$path"
		;;
	esac
}

start_server() {
	# Validar entorno antes de iniciar
	if ! validate_env; then
		log_error "Servidor no iniciado: configuracion invalida"
		exit 1
	fi
	
    # 2. Lógica del Modo Debug o roducción
    if [[ "$RUNTIME_MODE" == "production" ]]; then
        # En producción,se usan menos logs para  reducir la carga y el tamaño de los archivos.
        # Nivel 1 = WARN. (Nivel por defecto es 2 = INFO)
        export LOG_LEVEL=1 
        log_warn "Ejecutando en modo PRODUCCIÓN :) ."
    else
        # En debug, usamos el nivel por defecto 
        log_info "Ejecutando en modo DEBUG. Logging detallado."
    fi
    
	# 3. Iniciar el servidor con la configuración ajustada
	log_success "Iniciando servidor en $HOST:$PORT (Modo: $RUNTIME_MODE)"

	# Verificar que el puerto no este en uso
	if nc -z "$HOST" "$PORT" 2>/dev/null; then
		log_error "Puerto $PORT ya esta en uso en $HOST"
		exit 2
	fi

	# Crear FIFO
	FIFO=$(mktemp -u)
	mkfifo "$FIFO"

	# Servidor principal
	while true; do
		log_info "Esperando conexion en $HOST:$PORT"

		# shellcheck disable=SC2094
		nc -l "$HOST" "$PORT" <"$FIFO" | (
			process_request >"$FIFO"
		) &

		# Esperar que termine la conexión
		wait $! 2>/dev/null || true

		# Pausa entre conexiones
		sleep 0.1
	done
}

main() {
	start_server
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	main "$@"
fi
