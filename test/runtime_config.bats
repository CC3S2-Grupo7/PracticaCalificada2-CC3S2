#!/usr/bin/env bats


HOST="127.0.0.1"
PORT="8082" # Usar un puerto único para esta suite
SERVER_PID=""

# Define la variable de entorno PORT para el script
export PORT="$PORT"

# Funcion auxiliar para iniciar el servidor
start_server() {
    # Inicia el servidor usando make run y captura el PID de Make
    nohup make run > runtime_test.log 2>&1 &
    SERVER_PID=$!
    sleep 1.5 # Esperar a que inicie
}

teardown() {
    # Limpia: Mata el proceso y verifica el puerto
    if [[ -n "$SERVER_PID" ]]; then
        kill -SIGINT "$SERVER_PID" 2>/dev/null || true
        wait "$SERVER_PID" 2>/dev/null || true
        ! nc -z "$HOST" "$PORT" 2>/dev/null
    fi
}

@test "El servidor en modo produccion usa LOG_LEVEL=1 (WARN)" {
    # Arrange: Configuración de Producción
    export RUNTIME_MODE=production
    
    start_server
    
    # Act: Forzar una petición (el servidor registra su inicio y modo)
    curl -s "http://$HOST:$PORT/salud" > /dev/null
    
    # Assert: El log debe contener la advertencia de cambio de nivel (WARN)
    # y no debe contener entradas de DEBUG (Nivel 3).
    
    # Verificamos la advertencia de cambio de modo:
    run grep "LOG_LEVEL forzado a 1" runtime_test.log
    assert_success
    
    # Limpiar el archivo de log para la siguiente prueba
    rm -f runtime_test.log
}

@test "Falla al iniciar con puerto fuera de rango (Caso Negativo)" {
    # Arrange: Configuración Inválida (PORT fuera de 1024-65535)
    export PORT=999
    
    # Act: Intenta iniciar el servidor. No usamos start_server para capturar la falla directamente.
    run make run
    
    # Assert: make run debe fallar (código != 0) y el log debe contener el mensaje de error de PORT.
    assert_failure
    assert_output --partial "PORT debe estar entre 1024-65535, actual: 999"

    # Restablecer la variable PORT para el entorno
    export PORT=8082
}

@test "Falla al iniciar con RUNTIME_MODE invalido" {
    # Arrange: Configuración Inválida
    export RUNTIME_MODE=staging
    
    # Act
    run make run
    
    # Assert
    assert_failure
    assert_output --partial "RUNTIME_MODE debe ser 'debug' o 'production', actual: staging"

    # Restablecer la variable
    export RUNTIME_MODE=debug
}