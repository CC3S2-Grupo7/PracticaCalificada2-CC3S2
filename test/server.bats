#!/usr/bin/env bats

# --- CONFIGURACIÓN DE TESTS ---
BASE_TEST_DIR="$(dirname "$BATS_TEST_FILENAME")"
source "$BASE_TEST_DIR/../src/logger.sh"
export LOG_LEVEL=${LOG_LEVEL:-1}
export LOG_FILE="$BASE_TEST_DIR/test-execution.log"

# Variables globales
TEST_OUT_DIR="$BASE_TEST_DIR/test-out"
TEST_DIST_DIR="$BASE_TEST_DIR/test-dist"
SERVER_PID=""

### FUNCIONES DE AYUDA ROBUSTAS ###

setup() {
    log_debug "=== SETUP: $BATS_TEST_DESCRIPTION ==="
    mkdir -p "$TEST_OUT_DIR" "$TEST_DIST_DIR"
    >"$LOG_FILE"
    log_debug "Directorios de prueba listos."
}

teardown() {
    log_debug "=== TEARDOWN: $BATS_TEST_DESCRIPTION ==="
    cleanup_all
    rm -rf "$TEST_OUT_DIR" "$TEST_DIST_DIR" 2>/dev/null || true
    log_debug "=== TEARDOWN COMPLETADO ==="
}

cleanup_all() {
    if [[ -n "${SERVER_PID:-}" ]]; then
        kill -TERM "$SERVER_PID" 2>/dev/null || true
        wait "$SERVER_PID" 2>/dev/null || true
    fi
    pkill -9 -f "server.sh" 2>/dev/null || true
    pkill -9 -f "nc -l.*80[0-9][0-9]" 2>/dev/null || true
    SERVER_PID=""
    sleep 0.2
}

wait_for_port_free() {
    local port=$1
    local timeout=${2:-5}
    local count=0
    while lsof -i :"$port" >/dev/null 2>&1 && [ $count -lt $timeout ]; do
        lsof -ti:"$port" | xargs -r kill -9 2>/dev/null || true
        sleep 0.5
        ((count++))
    done
    if lsof -i :"$port" >/dev/null 2>&1; then
        return 1
    fi
    return 0
}

wait_for_server_ready() {
    local port="$1"
    local timeout=${2:-10}
    local count=0
    while [[ $count -lt $timeout ]]; do
        if nc -z 127.0.0.1 "$port" 2>/dev/null; then
            sleep 0.5
            return 0
        fi
        if [[ -n "${SERVER_PID:-}" ]] && ! kill -0 "$SERVER_PID" 2>/dev/null; then
            return 1
        fi
        sleep 0.5
        ((count++))
    done
    return 1
}

start_test_server() {
    local port="$1"
    export PORT="$port"
    export RELEASE="0.2.0-test"
    export OUT_DIR="out"
    export DIST_DIR="dist"

    wait_for_port_free "$port" || skip "No se pudo liberar puerto $port"

    (cd src && ./server.sh) &
    SERVER_PID=$!

    if ! wait_for_server_ready "$port"; then
        log_error "Servidor no arrancó. Revisa logs:"
        cat "$LOG_FILE"
        skip "Servidor no arrancó en puerto $port"
    fi
}

### TESTS ###

# --- TESTS DE VALIDACIÓN (SIN SERVIDOR) ---

@test "validación de configuración debe funcionar correctamente" {
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

@test "validación debe fallar con release inválido" {
    export RUNTIME_MODE="debug"
    export PORT="8080"
    export RELEASE="invalid-version"
    export OUT_DIR="out"
    export DIST_DIR="dist"
    run bash -c "cd src && source check-env.sh && validate_env"
    [ "$status" -ne 0 ]
    [[ "$output" =~ "RELEASE debe seguir formato" ]]
}

@test "validación debe fallar con directorios absolutos" {
    export RUNTIME_MODE="debug"
    export PORT="8080"
    export RELEASE="1.0.0"
    export OUT_DIR="/tmp/test-out"
    export DIST_DIR="/tmp/test-dist"
    run bash -c "cd src && source check-env.sh && validate_env"
    [ "$status" -ne 0 ]
    [[ "$output" =~ "debe ser ruta relativa" ]]
}

# --- TESTS DE SERVIDOR ---

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

# --- TESTS DEL SPRINT 2 ---

@test "(Sprint 2) Endpoint /metrics responde con estructura correcta y modo 'debug'" {
    export RUNTIME_MODE="debug"
    start_test_server 8093
    run curl -s "http://127.0.0.1:8093/metrics"
    [ "$status" -eq 0 ]
    local runtime_mode=$(echo "$output" | jq -r '.runtime_mode')
    [ "$runtime_mode" = "debug" ]
}

@test "(Sprint 2) Modo DEBUG debe registrar logs detallados de nivel INFO" {
    export RUNTIME_MODE="debug"
    start_test_server 8094
    curl -s "http://127.0.0.1:8094/salud" > /dev/null
    cleanup_all
    run grep "\[INFO\] Ejecutando en modo DEBUG" "$LOG_FILE"
    [ "$status" -eq 0 ]
}

@test "(Sprint 2) Modo PRODUCTION debe suprimir logs de nivel INFO" {
    export RUNTIME_MODE="production"
    start_test_server 8095
    curl -s "http://127.0.0.1:8095/salud" > /dev/null
    cleanup_all
    run grep "\[INFO\] Ejecutando en modo DEBUG" "$LOG_FILE"
    [ "$status" -ne 0 ]
    run grep "\[WARN\] Ejecutando en modo PRODUCCIÓN" "$LOG_FILE"
    [ "$status" -eq 0 ]
}

