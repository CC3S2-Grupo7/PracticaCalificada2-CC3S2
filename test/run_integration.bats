#!/usr/bin/env bats

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

# Usamos un puerto diferente (8081) para asegurar que no interfiera con otros tests
HOST="127.0.0.1"
PORT="8081" 
SERVER_PID=""

# Define la variable de entorno PORT para el script
export PORT="$PORT"

setup() {
    # Verificar que el puerto no esté en uso antes de la prueba
    if nc -z "$HOST" "$PORT" 2>/dev/null; then
        skip "El puerto $PORT ya está en uso. Limpie procesos."
    fi
}

teardown() {
    # Aseguramos que el servidor se detenga después de cada prueba
    if [[ -n "$SERVER_PID" ]]; then
        # Enviar SIGINT al proceso Make, que a su vez activa el trap de server.sh
        kill -SIGINT "$SERVER_PID" 2>/dev/null || true
        wait "$SERVER_PID" 2>/dev/null || true # Esperar que termine
        
        # Opcional: Verificar que el puerto esté libre después de la limpieza
        ! nc -z "$HOST" "$PORT" 2>/dev/null
    fi
}

@test "Endpoint /salud responde 200 OK y devuelve JSON válido" {
    # Arrange: Ya configurado en setup y export PORT

    # Act: Iniciar el servidor en segundo plano



    # Usamos nohup para desacoplar el proceso de la terminal de Bats y capturar el PID de Make.
    # Lanzamos 'make run' y capturamos su PID.
    nohup make run > /dev/null 2>&1 &
    SERVER_PID=$!
    
    # Esperar un momento para que el servidor inicie y el listener se active
    sleep 1.5

    # Assert 1: Validar código de respuesta HTTP (Requisito 83)
    http_code=$(curl -s -o /dev/null -w "%{http_code}" "http://$HOST:$PORT/salud")
    assert_equal "$http_code" "200"

    # Assert 2: Validar contenido (status OK y formato JSON)
    json_response=$(curl -s "http://$HOST:$PORT/salud")
    run jq -e '(.status == "OK")' <<< "$json_response" # Usa jq para verificar el campo 'status'
    assert_success

    # Assert 3: Validar código de respuesta HTTP 404
    http_code_404=$(curl -s -o /dev/null -w "%{http_code}" "http://$HOST:$PORT/ruta-no-existe")
    assert_equal "$http_code_404" "404"
}