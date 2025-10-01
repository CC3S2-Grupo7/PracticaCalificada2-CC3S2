# Bitácora Sprint 2 - Pipeline "Build-Release-Run" con artefacto firmado

## Comandos Ejecutados y Resultados

### Diego - Implementacion del servidor


### Pedro - Testing y configuración de release

#### 1. Ejecucion de tests completos
```bash
make test
```
**Salida:**
```
Verificando herramientas
Todas las herramientas están disponibles
Build completado
server.bats
 ✓ validación de configuración debe funcionar correctamente
 ✓ validación debe fallar con puerto inválido
 ✓ validación debe fallar con release inválido
 ✓ validación debe fallar con directorios absolutos
 ✓ servidor debe arrancar sin errores inmediatos
 ✓ servidor responde en /salud con OK y código 200
 ✓ servidor responde 404 y mensaje Not Found en endpoints inexistentes

7 tests, 0 failures
```


## Decisiones Técnicas Tomadas

