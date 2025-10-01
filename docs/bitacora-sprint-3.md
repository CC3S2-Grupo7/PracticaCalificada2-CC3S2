# Bitácora Sprint 3 - Pipeline "Build-Release-Run" con artefacto firmado

## Comandos Ejecutados y Resultados

### Diego - Implementacion del servidor


### Pedro - Implementacion de cache incremental

#### 1. Creacion del sistema de timestamps
```bash
mkdir -p .make
```
Modifaciones al Makefile:
- Nuevo directorio: `TIMESTAMP_DIR := .make`
- Stamps: `build.stamp`, `test.stamp`, `lint.stamp`, `tools.stamp`

#### Primera ejecucion de make build
```bash
time make build
```
**Salida:**
```
Verificando herramientas
Todas las herramientas están disponibles
Validando sintaxis con shellcheck
  Validando src/check-env.sh
  Validando src/logger.sh
  Validando src/server.sh
Validación de sintaxis completada
Ejecutando build
Generando información de build
Build completado

real    0m0.141s
user    0m0.091s
sys     0m0.038s
```
#### Segunda ejecucion de make build (cache incremental)
```bash
time make build
```
**Salida:**
```
make: Nothing to be done for 'build'.

real    0m0.016s
user    0m0.003s
sys     0m0.013s
```

### 2. Verificacion de reproducibilidad

#### Primer build
```bash
make clean
make pack
```
**Salida:**
```
Empaquetando release 0.1.0-beta de forma reproducible
Paquete creado: dist/pipeline-0.1.0-beta.tar.gz
Generando checksum SHA256
SHA256: a0507e48b442d8b2f3a617e8239f77ba4d53bbd7f05fa5ec2f8d53f8340448cf
Paquete: dist/pipeline-0.1.0-beta.tar.gz
Checksum: dist/pipeline-0.1.0-beta.sha256
SHA256: a0507e48b442d8b2f3a617e8239f77ba4d53bbd7f05fa5ec2f8d53f8340448cf
-rw-r--r--. 1 pv4r pv4r 11K Oct  1 10:34 dist/pipeline-0.1.0-beta.tar.gz
```

#### Segundo build (verificacion de reproducibilidad)
```bash
make clean 
make pack
```
**Salida:**
```
Empaquetando release 0.1.0-beta de forma reproducible
Paquete creado: dist/pipeline-0.1.0-beta.tar.gz
Generando checksum SHA256
SHA256: a0507e48b442d8b2f3a617e8239f77ba4d53bbd7f05fa5ec2f8d53f8340448cf
Paquete: dist/pipeline-0.1.0-beta.tar.gz
Checksum: dist/pipeline-0.1.0-beta.sha256
SHA256: a0507e48b442d8b2f3a617e8239f77ba4d53bbd7f05fa5ec2f8d53f8340448cf
-rw-r--r--. 1 pv4r pv4r 11K Oct  1 10:36 dist/pipeline-0.1.0-beta.tar.gz
```

### 3. Tests para el Makefile
```bash
PACK_SKIP_TEST=1 test/makefile.bats
```
**Salida:**
```
makefile.bats
 ✓ target build es idempotente
 ✓ caché se invalida correctamente al modificar archivos
 ✓ timestamps de caché se crean correctamente
 ✓ caché mejora significativamente el tiempo de ejecución
 ✓ limpieza no deja archivos huérfanos
 ✓ pipeline completo build-pack se ejecuta sin errores

6 tests, 0 failures
```

## Decisiones Técnicas Tomadas

### Pedro - Cache Incremental con Make
- **Decisión**: Implementar sistema de timestamps en `.make/` con archivos `.stamp` como centinelas
- **Razón**: Permitir a Make detectar cambios automáticamente y evitar realizar trabajo innecesario, aprovechando el sistema nativo de timestamps

### Pedro - Empaquetado Reproducible

- **Decisión**: Normalizar timestamps, orden y permisos en tarballs
- **Razón**: Garantizar que el mismo código siempre produce el mismo artefacto binario, que sea auditable

### Pedro - Agregar tests para Makefile

- **Decisión**: Crear tests específicos que validan idempotencia, reproducibilidad y limpieza
- **Razón**: Asegurar que el Makefile funcione como se espera
