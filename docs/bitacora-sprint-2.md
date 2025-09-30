# Bitácora Sprint 2- : Release y Refinamiento

## Objetivo del Sprint

## Comandos Ejecutados y Resultados


### Diego -


### Pedre


### Andrew
1.1
el patrón ${VAR:-DEFAULT} es la forma estándar de Bash robusto para lectura dinámica y asignación de valor por defecto:
```
HOST="${HOST:-127.0.0.1}"
PORT="${PORT:-8080}"
```
La lectura dinámica es inútil si la configuración es incorrecta.El script check-env.sh es el responsable de las validaciones.
1.2
Se agrega la varible de entorno runtime_mode 
```
RUNTIME_MODE ?= debug 

export RUNTIME_MODE
```
Se implemento su funcion de validacion 
```
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
```
Por ultimo la integracion en el startup en validate_env:
```
    validate_runtime_mode || status=1
```
Ejecutando tendremos:
```
i5@DESKTOP-1T2U4F6:~/trabajopc2/PracticaCalificada2-CC3S2$ RUNTIME_MODE=staging make run
Verificando herramientas
Todas las herramientas están disponibles
Build completado
Lanzando servidor...
2025-09-30 20:25:45 [ERROR] Errores encontrados:
2025-09-30 20:25:45 [ERROR]   - RUNTIME_MODE debe ser 'debug' o 'production', actual: staging
2025-09-30 20:25:45 [ERROR] Servidor no iniciado: configuracion invalida
2025-09-30 20:25:45 [INFO] Apagando servidor...
2025-09-30 20:25:46 [SUCCESS] Servidor detenido correctamente
i5@DESKTOP-1T2U4F6:~/trabajopc2/PracticaCalificada2-CC3S2$ RUNTIME_MODE=debug make run
Verificando herramientas
Todas las herramientas están disponibles
Build completado
Lanzando servidor...
2025-09-30 20:25:55 [WARN] Advertencias encontradas:
2025-09-30 20:25:55 [WARN]   - DIST_DIR apunta a un directorio inexistente: dist
2025-09-30 20:25:55 [SUCCESS] Iniciando servidor en 127.0.0.1:8080
2025-09-30 20:25:55 [INFO] Esperando conexion en 127.0.0.1:8080
^C2025-09-30 20:26:47 [INFO] Apagando servidor...
2025-09-30 20:26:47 [SUCCESS] Servidor detenido correctamente
2025-09-30 20:26:47 [INFO] Apagando servidor...
2025-09-30 20:26:48 [SUCCESS] Servidor detenido correctamente
```
1.3
Agregamos el mode de runtime_mode = prodution 
```
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
        log_warn "Ejecutando en modo PRODUCCIÓN :)."
    else
        # En debug, usamos el nivel por defecto 
        log_info "Ejecutando en modo DEBUG. Logging detallado."
    fi
    
	# 3. Iniciar el servidor con la configuración ajustada
	log_success "Iniciando servidor en $HOST:$PORT (Modo: $RUNTIME_MODE)"

```
lo ejecutamos en make y obtenemos:
```
i5@DESKTOP-1T2U4F6:~/trabajopc2/PracticaCalificada2-CC3S2$ RUNTIME_MODE=debug make run
Verificando herramientas
Todas las herramientas están disponibles
Build completado
Lanzando servidor...
2025-09-30 20:36:07 [WARN] Advertencias encontradas:
2025-09-30 20:36:07 [WARN]   - DIST_DIR apunta a un directorio inexistente: dist
2025-09-30 20:36:07 [INFO] Ejecutando en modo DEBUG. Logging detallado.
2025-09-30 20:36:07 [SUCCESS] Iniciando servidor en 127.0.0.1:8080 (Modo: debug)
2025-09-30 20:36:07 [INFO] Esperando conexion en 127.0.0.1:8080
^C2025-09-30 20:36:23 [INFO] Apagando servidor...
2025-09-30 20:36:23 [SUCCESS] Servidor detenido correctamente
2025-09-30 20:36:23 [INFO] Apagando servidor...
2025-09-30 20:36:24 [SUCCESS] Servidor detenido correctamente

i5@DESKTOP-1T2U4F6:~/trabajopc2/PracticaCalificada2-CC3S2$ RUNTIME_MODE=production make run
Verificando herramientas
Todas las herramientas están disponibles
Build completado
Lanzando servidor...
2025-09-30 20:36:34 [WARN] Advertencias encontradas:
2025-09-30 20:36:34 [WARN]   - DIST_DIR apunta a un directorio inexistente: dist
2025-09-30 20:36:34 [WARN] Ejecutando en modo PRODUCCIÓN :) (WARN/ERROR).
```
2.
Creacuib del endpoint /metrics que devuelva informacion del sistema 
```
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
```
```
y agregamos en las peticiones la metrica(Por ahora para el metodo get)
"/metrics" | "/metrics/")
		if [[ "$method" == "GET" ]]; then
			metrics_endpoint
		else
			generate_response "405 Method Not Allowed" '{"error":"Method Not Allowed"}'
		fi
		;;	
```
Ahora verificamos su funcionamiento:
```
i5@DESKTOP-1T2U4F6:~/trabajopc2/PracticaCalificada2-CC3S2$ RUNTIME_MODE=debug make run
Verificando herramientas
Todas las herramientas están disponibles
Build completado
Lanzando servidor...
2025-09-30 20:53:18 [WARN] Advertencias encontradas:
2025-09-30 20:53:18 [WARN]   - DIST_DIR apunta a un directorio inexistente: dist
2025-09-30 20:53:18 [INFO] Ejecutando en modo DEBUG. Logging detallado.
2025-09-30 20:53:18 [SUCCESS] Iniciando servidor en 127.0.0.1:8080 (Modo: debug)
2025-09-30 20:53:18 [INFO] Esperando conexion en 127.0.0.1:8080
2025-09-30 20:53:36 [INFO] Request: GET /metrics
2025-09-30 20:53:36 [INFO] Esperando conexion en 127.0.0.1:8080
```

## Decisiones Técnicas Tomadas






### Andrew: 1. runtime parametrizable 
#### lectura dinamica de variables de entorno:
- **Decisión:** hacer que el servidor pueda adaptarse a diferentes entornos sin modificar el codigo
- **Razón:**  un mayor dinamismo entre el desarrollo y la produccion
#### Validación de configuración al startup
- **Decisión:** Crear la nueva variable runtime_mode y su respectiva validacion 
- **Razón:** Poder generar a continuacion el modo debug
#### Modo debug/producción
- **Decisión:** implementar un startup diferenciado entre debug y prodution
- **Razón:** Para poder comprender que a diferentes necesidades diferente informacion que se envia
### 2.Monitoreo básico
#### Endpoint /metrics simple
- **Decisión:** Implementar /metrics simple para que nos envie el uptime 
- **Razón:** poder implemntar a posteriori mas funciones para la metric
#### Logging de peticiones
- **Decisión:** 
- **Razón:**
#### Reporte de salud del servicio
- **Decisión:** 
- **Razón:**
### 3. Testing de runtime 
#### Casos Bats para diferentes configuraciones
- **Decisión:** 
- **Razón:**
#### Tests de timeout y recuperación
- **Decisión:** 
- **Razón:**
#### Validación de limpieza
- **Decisión:** 
- **Razón:**



