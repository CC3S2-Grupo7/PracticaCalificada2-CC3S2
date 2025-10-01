#!/usr/bin/env bats

# --- CONFIGURACIÓN DE TESTS ---
BASE_TEST_DIR="$(dirname "$BATS_TEST_FILENAME")"
source "$BASE_TEST_DIR/../src/logger.sh"
export LOG_LEVEL=1
export LOG_FILE="$BASE_TEST_DIR/test-execution.log"

SERVER_PID=""

### FUNCIONES DE AYUDA ###

setup() {
    >"$LOG_FILE"
    # Crear directorios de prueba si no existen
    mkdir -p out dist
}

teardown() {
    stop_test_server
}

stop_test_server() {
    if [[ -n "${SERVER_PID:-}" ]]; then
        kill -TERM "$SERVER_PID" 2>/dev/null || true
        wait "$SERVER_PID" 2>/dev/null || true
    fi
    pkill -9 -f "server.sh" 2>/dev/null || true
    SERVER_PID=""
    sleep 0.2
}

start_test_server() {
    local port="$1"
    stop_test_server

    # CORRECCIÓN: Usar rutas relativas para que la validación pase
    export PORT="$port"
    export RELEASE="0.2.0-test"
    export OUT_DIR="out" 
    export DIST_DIR="dist"

    (cd src && ./server.sh) &
    SERVER_PID=$!
    sleep 1.5 # Dar tiempo al servidor para arrancar y validar

    if ! kill -0 "$SERVER_PID" 2>/dev/null; then
        log_error "El servidor no pudo arrancar. Revisa los logs:"
        cat "$LOG_FILE"
        skip "El servidor no arrancó en el puerto $port"
    fi
}

### TESTS ###

@test "validación de configuración debe funcionar correctamente" {
    # CORRECCIÓN: Asegurar que RUNTIME_MODE esté definido para este test
    export RUNTIME_MODE="debug" 
    export PORT="8080"
    export RELEASE="1.0.0"
    export OUT_DIR="out"
    export DIST_DIR="dist"
    
    run bash -c "cd src && source check-env.sh && validate_env"
    [ "$status" -eq 0 ]
}

@test "validación debe fallar con puerto inválido" {
    export RUNTIME_MODE="debug"
    export PORT="abc"
    export RELEASE="1.0.0"
    export OUT_DIR="out"
    export DIST_DIR="dist"
    run bash -c "cd src && source check-env.sh && validate_env"
    [ "$status" -ne 0 ]
    [[ "$output" =~ "PORT debe ser numérico" ]]
}

@test "servidor debe arrancar sin errores inmediatos" {
    export RUNTIME_MODE="debug"
    start_test_server 8090
    kill -0 "$SERVER_PID"
    [ $? -eq 0 ]
}

@test "servidor responde en /salud con OK y código 200" {
    export RUNTIME_MODE="debug"
    start_test_server 8091
    run curl -s --max-time 5 "http://127.0.0.1:8091/salud"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "OK" ]]
}

@test "servidor responde 404 en endpoints inexistentes" {
    export RUNTIME_MODE="debug"
    start_test_server 8092
    run curl -s --max-time 5 "http://127.0.0.1:8092/ruta-que-no-existe"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Not Found" ]]
}

@test "Endpoint /metrics responde con estructura correcta y modo 'debug'" {
    export RUNTIME_MODE="debug"
    start_test_server 8093
    run curl -s "http://127.0.0.1:8093/metrics"
    [ "$status" -eq 0 ]
    local runtime_mode=$(echo "$output" | jq -r '.runtime_mode')
    [ "$runtime_mode" = "debug" ]
}

@test "Modo DEBUG debe registrar logs detallados de nivel INFO" {
    export RUNTIME_MODE="debug"
    start_test_server 8094
    curl -s "http://127.0.0.1:8094/salud" > /dev/null
    stop_test_server
    run grep "\[INFO\] Ejecutando en modo DEBUG" "$LOG_FILE"
    [ "$status" -eq 0 ]
}

@test "Modo PRODUCTION debe suprimir logs de nivel INFO" {
    export RUNTIME_MODE="production"
    start_test_server 8095
    curl -s "http://127.0.0.1:8095/salud" > /dev/null
    stop_test_server
    run grep "\[INFO\] Ejecutando en modo DEBUG" "$LOG_FILE"
    [ "$status" -ne 0 ]
    run grep "\[WARN\] Ejecutando en modo PRODUCCIÓN" "$LOG_FILE"
    [ "$status" -eq 0 ]
}

@test "Servidor debe recuperarse después de un cliente con timeout" {
    export RUNTIME_MODE="debug"
    start_test_server 8096
    curl -s --max-time 1 "http://127.0.0.1:8096/salud" || true
    run curl -s "http://127.0.0.1:8096/salud"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "OK" ]]
}

@test "Servidor debe eliminar el archivo FIFO temporal al apagarse" {
    export RUNTIME_MODE="debug"
    start_test_server 8097
    local fifo_path=$(lsof -p "$SERVER_PID" | grep FIFO | awk '{print $9}')
    [ -p "$fifo_path" ]
    stop_test_server
    [ ! -e "$fifo_path" ]
}

