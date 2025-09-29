#!/usr/bin/env bats

# Directorio base de los tests
BASE_TEST_DIR="$(dirname "$BATS_TEST_FILENAME")"

# Importar para logging
source "$BASE_TEST_DIR/../src/logger.sh"

# Configuración de logging para tests
export LOG_LEVEL=${LOG_LEVEL:-1} # WARN y ERROR
export LOG_FILE="$BASE_TEST_DIR/test-execution.log"

# Variables globales
TEST_OUT_DIR="$BASE_TEST_DIR/test-out"
TEST_DIST_DIR="$BASE_TEST_DIR/test-dist"
SERVER_PID=""

setup() {
    mkdir -p "$TEST_OUT_DIR" "$TEST_DIST_DIR"
}

teardown() {
    # Detener servidor si está corriendo
    if [[ -n "${SERVER_PID:-}" ]]; then
        kill -9 "$SERVER_PID" 2>/dev/null || true
    fi

    # Limpiar procesos
    pkill -9 -f "server.sh" 2>/dev/null || true

    # Limpiar carpetas de test
    rm -rf "$TEST_OUT_DIR" "$TEST_DIST_DIR" 2>/dev/null || true
}

# Configurar entorno
setup_env() {
    export PORT="$1"
    export RELEASE="0.1.0-test"
    export OUT_DIR="test/test-out"
    export DIST_DIR="test/test-dist"
    mkdir -p "$OUT_DIR" "$DIST_DIR"
}

# Iniciar el servidor
start_server() {
    local port="$1"
    setup_env "$port"
    
    cd src && ./server.sh &
    SERVER_PID=$!
    cd - >/dev/null
    
    sleep 2
}

# Tests basicos - ESTADO ROJO
@test "validacion debe funcionar" {
    setup_env 8080
    run bash -c "cd src && source check-env.sh && validate_env"
    [ "$status" -eq 0 ]
}

@test "servidor debe arrancar" {
    start_server 8090
    
    kill -0 "$SERVER_PID"
    [ $? -eq 0 ]
}

@test "servidor debe responder en /salud" {
    start_server 8091
    
    run curl -s "http://127.0.0.1:8091/salud"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "OK" ]]
}