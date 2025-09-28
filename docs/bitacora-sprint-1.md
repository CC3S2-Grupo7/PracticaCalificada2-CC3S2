# Bitácora Sprint 1 - Pipeline "Build-Release-Run" con artefacto firmado

## Objetivo del Sprint
Establecer el codebase, implementar un servicio mínimo con un endpoint /salud y agregar un Makefile inicial con la estructura de los targets. Además, agregar una prueba Bats representativa.

## Comandos Ejecutados y Resultados

### 1. Inicio del servidor
```bash
./src/server.sh 
```
**Salida:**
```
Iniciando servidor en 127.0.0.1:8080
Esperando conexión
```

### 2. Lectura del endpoint /salud
```bash
curl http://127.0.0.1:8080/salud
```
**Salida:**
```
{
    "status": "OK",
    "timestamp": "2025-09-27T23:42:22Z",
    "uptime_seconds": 29 
}
```

### 3. Manejo de otros endpoints
```bash
curl http://127.0.0.1:8080/otro
```
**Salida:**
```
{
    "error": "Not Found"
    "message": "Endpoint /otro no encontrado"
    "timestamp": "2025-09-27T23:44:00Z"
}
```

## Decisiones Técnicas Tomadas

### Estructura de Directorios
- **Decisión:** Separación de directorios en source (`src/`), tests (`tests/`), salidas (`out/`) y distribución (`dist/`)
- **Razón:** Organización estándar que facilita automatización y empaquetado

### Variables de Entorno
- **Decisión:** Usar `PORT`, `HOST`, `RELEASE` y `LOG_LEVEL` como variables de entorno
- **Razón:** Cumplimiento 12-Factor Factor III - configuración externa

### Dependencias de Targets
- **Decisión:** Cadena `tools → build → test` y `build → run`
- **Razón:** Garantizar verificación de dependencias antes de ejecución
