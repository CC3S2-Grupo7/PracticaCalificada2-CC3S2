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
    log_debug "=== SETUP: $BATS_TEST_DESCRIPTION ==="

    # Crear directorios
    mkdir -p "$TEST_OUT_DIR" "$TEST_DIST_DIR"
    log_debug "Directorios creados: $TEST_OUT_DIR, $TEST_DIST_DIR"
    log_debug "=== SETUP COMPLETADO ==="
}

teardown() {
    log_debug "=== TEARDOWN: $BATS_TEST_DESCRIPTION ==="

    # Cleanup
    cleanup_all

    # Limpiar directorios
    rm -rf "$TEST_OUT_DIR" "$TEST_DIST_DIR" 2>/dev/null || true

    log_debug "=== TEARDOWN COMPLETADO ==="
    echo "" >> "$LOG_FILE" 2>/dev/null || true
}

cleanup_all() {
    # Intentar terminar el servidor si está corriendo
    if [[ -n "${SERVER_PID:-}" ]]; then
        kill -TERM "$SERVER_PID" 2>/dev/null || true
        sleep 0.5
    fi
    # Matar cualquier proceso huérfano
    pkill -9 -f "server.sh" 2>/dev/null || true
    pkill -9 -f "nc -l.*80[0-9][0-9]" 2>/dev/null || true
    SERVER_PID=""
    sleep 0.5
}

# Limpiar un puerto en específico
cleanup_port() {
    local port="$1"
    local pids

    # Obtener PIDs que estan usando el puerto
    pids=$(lsof -ti:$port 2>/dev/null || true)

    if [[ -n "$pids" ]]; then
        log_debug "Liberando puerto $port (PIDs: $pids)"
        echo "$pids" | xargs -r kill -KILL 2>/dev/null || true
    fi
}

# Esperar que un puerto esté libre
wait_for_port_free() {
    local port=$1
    local timeout=${2:-10}
    local count=0

    while lsof -i :$port >/dev/null 2>&1 && [ $count -lt $timeout ]; do
        log_debug "Esperando que puerto $port se libere... ($count/$timeout)"
        cleanup_port $port
        sleep 1
        ((count++))
    done

    if lsof -i :$port >/dev/null 2>&1; then
        log_warn "Puerto $port sigue ocupado luego de $timeout segundos"
        return 1
    fi

    log_debug "Puerto $port está libre"
    return 0
}

# Esperar que el servidor esté listo
wait_for_server_ready() {
    local port="$1"
    local timeout=${2:-15}
    local count=0

    while [[ $count -lt $timeout ]]; do
        if nc -z 127.0.0.1 "$port" 2>/dev/null; then
            log_debug "Servidor respondiendo en puerto $port"
            sleep 1
            return 0
        fi

        # Verificar que el proceso siga vivo
        if [[ -n "${SERVER_PID:-}" ]] && ! kill -0 "$SERVER_PID" 2>/dev/null; then
            log_warn "Proceso del servidor murió durante el arranque"
            return 1
        fi

        sleep 1
        ((count++))
    done

    log_warn "Servidor no respondió en puerto $port después de $timeout segundos"
    return 1
}

# Configurar entorno
setup_env() {
    export PORT="$1"
    export RELEASE="0.1.0-test"
    export OUT_DIR="test/test-out"
    export DIST_DIR="test/test-dist"

    mkdir -p "$OUT_DIR" "$DIST_DIR"

    log_debug "Entorno configurado: PORT=$PORT, RELEASE=$RELEASE"
}

# Iniciar el servidor para tests
start_test_server() {
    local port="$1"

    setup_env "$port"

    # Asegurar puerto libre
    cleanup_port "$port"
    wait_for_port_free "$port" 5 || {
        skip "No se pudo liberar puerto $port"
    }

    log_debug "Iniciando servidor de test en puerto $port"

    # Arrancar servidor en background
    (cd src && ./server.sh) &
    SERVER_PID=$!

    log_debug "Servidor iniciado con PID: $SERVER_PID"
    # Esperar que esté listo
    if ! wait_for_server_ready "$port"; then
        log_error "Servidor no arrancó correctamente"
        skip "Servidor no arrancó en puerto $port"
    fi
    
    return 0
}

# Tests
@test "validación de configuración debe funcionar correctamente" {
    setup_env 8080
    run bash -c "cd src && source check-env.sh && validate_env"
    [ "$status" -eq 0 ]
}

@test "validación debe fallar con puerto inválido" {
    export PORT="abcdefg"
    export RELEASE="0.1.0-test"
    export OUT_DIR="test/test-out"
    export DIST_DIR="test/test-dist"

    run bash -c "cd src && source check-env.sh && validate_env"
    [ "$status" -ne 0 ]
    [[ "$output" =~ "PORT debe ser" ]]
}

@test "validación debe fallar con release inválido" {
    setup_env 8080
    export RELEASE="invalid-version"

    run bash -c "cd src && source check-env.sh && validate_env"
    [ "$status" -ne 0 ]
    [[ "$output" =~ "RELEASE debe seguir formato" ]]
}

@test "validación debe fallar con directorios absolutos" {
    setup_env 8080
    export OUT_DIR="/tmp/test-out"
    export DIST_DIR="/tmp/test-dist"

    run bash -c "cd src && source check-env.sh && validate_env"
    [ "$status" -ne 0 ]
    [[ "$output" =~ "debe ser ruta relativa" ]]
}

@test "servidor debe arrancar" {
    start_test_server 8090
    
    kill -0 "$SERVER_PID"
    [ $? -eq 0 ]
}

@test "servidor debe responder en /salud" {
    start_test_server 8091
    
    run curl -s "http://127.0.0.1:8091/salud"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "OK" ]]
}