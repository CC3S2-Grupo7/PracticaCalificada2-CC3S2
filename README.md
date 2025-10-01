# Proyecto 7: Pipeline "Compilar-Lanzar-Ejecutar"

## Descripción
Pipeline Make que implementa una separación clara entre las etapas de build, release y run, produciendo artefactos reproducibles con versionado semántico.

## Estructura del Proyecto

```
PracticaCalificada2-CC3S2/
├── src/               # Scripts Bash del servidor
├── test/              # Casos de prueba Bats
├── docs/              # Documentación y bitácoras
├── out/               # Artefactos intermedios
├── dist/              # Paquetes finales
├── .env.example       # Plantilla de variables de entorno
├── Makefile           # Pipeline de automatización
```

## Configuración

### Variables de Entorno

| Variable     | Efecto                               | Validación                              | Valor por Defecto |
|--------------|--------------------------------------|-----------------------------------------|-------------------|
| `PORT`       | Puerto donde escucha el servidor     | `ss -ltnp \| grep $PORT`                | 8080              |
| `RELEASE`    | Versión del artefacto generado       | Aparece en nombre de paquete en 'dist/' | 0.1.0-alpha       |
| `BUILD_DATE` | Timestamp de la compilación          | En logs de inicio y headers HTTP        | Auto-generado     |
| `OUT_DIR`    | Directorio de artefactos intermedios | `ls $OUT_DIR/` muestra los artefactos   | out               |
| `DIST_DIR`   | Directorio de paquetes finales       | `ls $DIST_DIR/` muestra los paquetes    | dist              |
| `LOG_LEVEL`  | Verbosidad de logs                   | Filtra los logs por nivel de severidad  | info              |

### Instrucciones de uso

```bash
# Copiar valores de ejemplo 
cp .env.example .env

# Verificar dependencias
make tools

# Ejecutar el servidor (desarrollo)
make run
```

### Pipeline de Desarrollo

```bash
# 1. Validar código (lint + formato)
make lint format

# 2. Ejecutar tests
make test

# 3. Build completo
make build

# 4. Empaquetar release
make pack

# 5. Verificar reproducibilidad
make verify-repro
```

## Endpoints Disponibles

### `/salud` - Health Check
Retorna el estado de salud del servidor.

```bash
curl http://127.0.0.1:8080/salud
```

**Respuesta:**
```json
{
    "status": "OK",
    "timestamp": "2025-10-01T03:50:37Z",
    "uptime_seconds": 36,
}
```

## Principios de Diseño

- **12-Factor App**: Configuración desde entorno
- **Bash Robusto**: `set -euo pipefail`
- **Tests AAA/RGR**: Estructura clara de tests
- **Reproducibilidad**: Builds determinísticos
- **Trazabilidad**: Logging estructurado
- **Versionado Semántico**: Control de versiones claro
