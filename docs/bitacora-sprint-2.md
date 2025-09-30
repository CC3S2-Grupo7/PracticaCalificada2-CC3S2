# Bitácora Sprint 2- : Release y Refinamiento

## Objetivo del Sprint

## Comandos Ejecutados y Resultados


### Diego -


### Pedre


### Andrew
el patrón ${VAR:-DEFAULT} es la forma estándar de Bash robusto para lectura dinámica y asignación de valor por defecto:
```
HOST="${HOST:-127.0.0.1}"
PORT="${PORT:-8080}"
```


## Decisiones Técnicas Tomadas






### Andrew: 1. runtime parametrizable 
#### lectura dinamica de variables de entorno:
- **Decisión:** hacer que el servidor pueda adaptarse a diferentes entornos sin modificar el codigo
- **Razón:**  un mayor dinamismo entre el desarrollo y la produccion
#### Validación de configuración al startup
- **Decisión:** 
- **Razón:** 
#### Modo debug/producción
- **Decisión:** Separación de directorios en source (`src/`), tests (`tests/`), salidas (`out/`) y distribución (`dist/`)
- **Razón:** Organización estándar que facilita automatización y empaquetado

### 2.Monitoreo básico



