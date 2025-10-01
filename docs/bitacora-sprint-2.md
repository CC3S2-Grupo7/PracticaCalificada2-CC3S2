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

#### 2. Ejecución de target release
```bash
RELEASE=0.2.0-beta make release
```
**Salida:**
```
❯ RELEASE=0.2.0-beta make release
Validando sintaxis de src/check-env.sh
Validando sintaxis de src/logger.sh
Validando sintaxis de src/server.sh
Generando información de build
Build completado

Ejecutando test Bats test/server.bats
server.bats
 ✓ validación de configuración debe funcionar correctamente
 ✓ validación debe fallar con puerto inválido
 ✓ validación debe fallar con release inválido
 ✓ validación debe fallar con directorios absolutos
 ✓ servidor debe arrancar sin errores inmediatos
 ✓ servidor responde en /salud con OK y código 200
 ✓ servidor responde 404 y mensaje Not Found en endpoints inexistentes

7 tests, 0 failures

Empaquetando release 0.2.0-beta de forma reproducible
Paquete creado: dist/pipeline-0.2.0-beta.tar.gz
Generando checksum SHA256
SHA256: ba7029c7ad3ead7f15ac3e548688f0a3bb2adbdeaedfaf125f7c4a975ca571bf
Paquete: dist/pipeline-0.2.0-beta.tar.gz
Checksum: dist/pipeline-0.2.0-beta.sha256
SHA256: ba7029c7ad3ead7f15ac3e548688f0a3bb2adbdeaedfaf125f7c4a975ca571bf
-rw-r--r--. 1 pv4r pv4r 15K Oct  1 06:01 dist/pipeline-0.2.0-beta.tar.gz
Generando release 0.2.0-beta
Generando changelog desde v0.1.0-beta...
CHANGELOG.md actualizado
[release 6a01495] Actualizar CHANGELOG.md para v0.2.0-beta
 1 file changed, 5 insertions(+)
Commit del changelog creado
Tag v0.2.0-beta creado
Subiendo a la rama release...
Enumerating objects: 22, done.
Counting objects: 100% (19/19), done.
Delta compression using up to 16 threads
Compressing objects: 100% (12/12), done.
Writing objects: 100% (12/12), 1.55 KiB | 1.55 MiB/s, done.
Total 12 (delta 8), reused 0 (delta 0), pack-reused 0 (from 0)
remote: Resolving deltas: 100% (8/8), completed with 5 local objects.
To github.com:CC3S2-Grupo7/PracticaCalificada2-CC3S2.git
   feea9b6..6a01495  release -> release
Enumerating objects: 1, done.
Counting objects: 100% (1/1), done.
Writing objects: 100% (1/1), 161 bytes | 161.00 KiB/s, done.
Total 1 (delta 0), reused 0 (delta 0), pack-reused 0 (from 0)
To github.com:CC3S2-Grupo7/PracticaCalificada2-CC3S2.git
 * [new tag]         v0.2.0-beta -> v0.2.0-beta
Release v0.2.0-beta completado y enviado al remoto
```


## Decisiones Técnicas Tomadas

### Pedro - Metadata de Release
- **Decisión**: Generar release-info.txt con un formato estructurado (release, build_date, git_commit)
- **Razón**: Trazabilidad completa de cada release, esto permite identificar qué configuración se usó en cada build

### Pedro - Automatización de Release con Git

- **Decisión**: Target release que valida estado de Git, crea tags y hace push automático
- **Razón**: Reducir errores humanos en el proceso de release

### Pedro - Automatización de CHANGELOG

- **Decisión**: Extraer commits desde último tag y formatearlos para su uso en CHANGELOG.md
- **Razón**: Mantener historial de cambios actualizado sin trabajo manual

### Pedro - Validaciones Pre-Release

- **Decisión**: Verificar que no haya cambios sin commitear y que el tag no exista antes de crear la release
- **Razón**: Prevenir releases inconsistentes o duplicados
