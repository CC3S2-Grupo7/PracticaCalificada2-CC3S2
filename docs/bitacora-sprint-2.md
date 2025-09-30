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
1.3

## Decisiones Técnicas Tomadas






### Andrew: 1. runtime parametrizable 
#### lectura dinamica de variables de entorno:
- **Decisión:** hacer que el servidor pueda adaptarse a diferentes entornos sin modificar el codigo
- **Razón:**  un mayor dinamismo entre el desarrollo y la produccion
#### Validación de configuración al startup
- **Decisión:** Crear la nueva variable runtime_mode y su respectiva validacion 
- **Razón:** Poder generar a continuacion el modo debug
#### Modo debug/producción
- **Decisión:** Separación de directorios en source (`src/`), tests (`tests/`), salidas (`out/`) y distribución (`dist/`)
- **Razón:** Organización estándar que facilita automatización y empaquetado

### 2.Monitoreo básico



