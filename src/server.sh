#!/usr/bin/env bash

set -euo pipefail

# Variables de entorno por defecto
HOST="${HOST:-127.0.0.1}"
PORT="${PORT:-8080}"
SERVER_START=$(date +%s)

# Generar respuesta HTTP
generate_response() {
    local status_code="$1"
    local content="$2"
    local content_type="${3:-application/json}"

    cat << EOF
HTTP/1.1 $status_code
Content-Type: $content_type
Content-Length: ${#content}
Connection: close

$content

EOF
}

# Endpoint /salud
health_endpoint() {
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    local json_response
    json_response=$(cat << EOF
{
    "status": "OK",
    "timestamp": "$timestamp",
    "uptime_seconds": $(($(date +%s) - SERVER_START)) 
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
    json_response=$(cat << EOF
{
    "error": "Not Found"
    "message": "Endpoint $path no encontrado"
    "timestamp": "$timestamp"
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
    read -r method path protocol <<< "$request_line"

    echo "Procesando request: $method $path" >&2

    case "$path" in
        "/salud"|"/salud/")
            if [[ "$method" == "GET" ]]; then
                health_endpoint
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
    echo "Iniciando servidor en $HOST:$PORT" >&2

    # Verificar que el puerto no esté en uso
    if nc -z "$HOST" "$PORT" 2>/dev/null; then
        echo "Error: Puerto $PORT se encuentra en uso en $HOST" >&2
        exit 2
    fi

    # Crear FIFO
    local fifo=$(mktemp -u)
    mkfifo "$fifo"
    trap "rm -f '$fifo'" EXIT

    # Servidor principal
    while true; do
        echo "Esperando conexión" >&2
        
        nc -l -s "$HOST" -p "$PORT" < "$fifo" | (
            process_request > "$fifo"
        )
    done
}

main() {
    start_server
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
