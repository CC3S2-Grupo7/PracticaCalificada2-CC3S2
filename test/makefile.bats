#!/usr/bin/env bats
# Tests del Makefile y caché incremental

@test "target build es idempotente" {
    # Arrange: primera ejecución completa
    make clean >/dev/null 2>&1
    make build >/dev/null 2>&1
    [ -f .make/build.stamp ]
    
    # Act: capturar el timestamp del stamp antes y después
    stamp_before=$(stat -c %Y .make/build.stamp 2>/dev/null || stat -f %m .make/build.stamp 2>/dev/null)
    sleep 1
    make build >/dev/null 2>&1
    stamp_after=$(stat -c %Y .make/build.stamp 2>/dev/null || stat -f %m .make/build.stamp 2>/dev/null)
    
    # Assert: timestamp no debe cambiar (porque no se reconstruyó)
    [ "$stamp_before" = "$stamp_after" ]
}

@test "caché se invalida correctamente al modificar archivos" {
    # Arrange: build inicial
    make clean >/dev/null 2>&1
    make build >/dev/null 2>&1
    
    # Capturar timestamp original
    stamp_before=$(stat -c %Y .make/build.stamp 2>/dev/null || stat -f %m .make/build.stamp 2>/dev/null)
    
    # Act: modificar un archivo fuente
    sleep 2
    touch src/server.sh
    make build >/dev/null 2>&1
    
    # Capturar nuevo timestamp
    stamp_after=$(stat -c %Y .make/build.stamp 2>/dev/null || stat -f %m .make/build.stamp 2>/dev/null)
    
    # Assert: timestamp debe cambiar (porque se reconstruyó)
    [ "$stamp_before" != "$stamp_after" ]
}

@test "timestamps de caché se crean correctamente" {
    # Arrange: limpiar estado
    make clean >/dev/null 2>&1
    
    # Verificar que no existen
    [ ! -f .make/tools.stamp ]
    [ ! -f .make/build.stamp ]
    
    # Act: ejecutar tools y build
    make tools >/dev/null 2>&1
    make build >/dev/null 2>&1
    
    # Assert: timestamps deben existir
    [ -f .make/tools.stamp ]
    [ -f .make/lint.stamp ]
    [ -f .make/build.stamp ]
}

@test "caché mejora significativamente el tiempo de ejecución" {
    # Arrange: limpiar y ejecutar build inicial
    make clean >/dev/null 2>&1
    
    # Primera ejecución (sin caché) - capturar tiempo
    start1=$(date +%s%N 2>/dev/null || date +%s)
    make build >/dev/null 2>&1
    end1=$(date +%s%N 2>/dev/null || date +%s)
    time1=$((end1 - start1))
    
    # Segunda ejecución (con caché) - capturar tiempo
    start2=$(date +%s%N 2>/dev/null || date +%s)
    make build >/dev/null 2>&1
    end2=$(date +%s%N 2>/dev/null || date +%s)
    time2=$((end2 - start2))
    
    # Assert: segunda ejecución debe ser más rápida o casi instantánea
    [ $time2 -le $time1 ]
}

@test "limpieza no deja archivos huérfanos" {
    # Arrange: crear artefactos
    make clean >/dev/null 2>&1
    make build >/dev/null 2>&1
    make pack >/dev/null 2>&1
    
    # Verificar que existen
    [ -d out ]
    [ -d dist ]
    [ -d .make ]
    
    # Act: limpiar
    make clean >/dev/null 2>&1
    
    # Assert: directorios deben estar vacíos o no deben existir
    [ ! -d out ] || [ -z "$(ls -A out 2>/dev/null)" ]
    [ ! -d dist ] || [ -z "$(ls -A dist 2>/dev/null)" ]
    [ ! -d .make ] || [ -z "$(ls -A .make 2>/dev/null)" ]
}

@test "pipeline completo build-pack se ejecuta sin errores" {
    # Arrange: limpiar estado
    make clean >/dev/null 2>&1
    
    # Act: ejecutar pipeline
    run make tools
    [ "$status" -eq 0 ]
    
    run make build
    [ "$status" -eq 0 ]
    
    run make pack
    [ "$status" -eq 0 ]
    
    # Assert: todos los artefactos deben existir
    [ -f .make/tools.stamp ]
    [ -f .make/build.stamp ]
    [ -f out/build-info.txt ]
    [ -f dist/pipeline-*.tar.gz ]
    [ -f dist/pipeline-*.sha256 ]
}