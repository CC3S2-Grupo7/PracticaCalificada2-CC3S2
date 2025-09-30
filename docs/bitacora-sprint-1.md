# Bitácora Sprint 1 - Pipeline "Build-Release-Run" con artefacto firmado

## Objetivo del Sprint
Establecer el codebase, implementar un servicio mínimo con un endpoint /salud y agregar un Makefile inicial con la estructura de los targets. Además, agregar una prueba Bats representativa.

## Comandos Ejecutados y Resultados


### Diego - Implementacion del servidor

#### 1. Inicio del servidor

```bash
./src/server.sh 
```
**Salida:**
```
Iniciando servidor en 127.0.0.1:8080
Esperando conexión
```


#### 2. Lectura del endpoint /salud

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

#### 3. Manejo de otros endpoints
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

### Pedro - Testing y configuración de release

#### 1. Configuración de variables de entorno
```bash
cp .env.example .env
cat .env.example
```
**Salida:**
```
# Copiar a .env y ajustar valores cuando sea necesario

# Puerto del servidor HTTP
PORT=8080

# Versión de release (formato semántico)
RELEASE=0.1.0-alpha

# Fecha de build (se genera automáticamente)
BUILD_DATE=auto

# Directorio de salida para artefactos intermedios
OUT_DIR=out

# Directorio de distribución
DIST_DIR=dist

# Nivel de logging (debug|info|warn|error)
LOG_LEVEL=info
```

#### 2. Validación de entorno
```bash
PORT=8080 RELEASE=0.1.0-alpha OUT_DIR=out DIST_DIR=dist ./src/check-env.sh
```

**Salida:**
```
2025-09-29 00:03:06 [INFO] === Validando configuración ===
2025-09-29 00:03:06 [WARN] Advertencias encontradas:
2025-09-29 00:03:06 [WARN]   - OUT_DIR apunta a un directorio inexistente: out
2025-09-29 00:03:06 [WARN]   - DIST_DIR apunta a un directorio inexistente: dist
2025-09-29 00:03:06 [SUCCESS] Configuración válida
2025-09-29 00:03:06 [INFO] Puerto: 8080, Release: 0.1.0-alpha, Directorios: out, dist
```

#### 3. Ejecución de pruebas Bats (ESTADO ROJO)
```bash
LOG_LEVEL=0 test/server.bats
```
**Salida:**
```
server.bats
 ✗ servidor debe arrancar
   (from function `start_server' in file test/server.bats, line 50,
    in test file test/server.bats, line 57)
     `start_server 8090' failed
   /home/pv4r/UNI/2025-2/CC3S2/pc2/test/server.bats: line 50: cd: OLDPWD not set
   2025-09-29 00:10:45 [ERROR] Servidor terminando
   /home/pv4r/UNI/2025-2/CC3S2/pc2/test/server.bats: line 21: 123647 Killed                  cd src && ./server.sh
 ✗ servidor debe responder en /salud
   (from function `start_server' in file test/server.bats, line 50,
    in test file test/server.bats, line 64)
     `start_server 8091' failed
   /home/pv4r/UNI/2025-2/CC3S2/pc2/test/server.bats: line 50: cd: OLDPWD not set
   2025-09-29 00:10:45 [ERROR] Servidor terminando
   /home/pv4r/UNI/2025-2/CC3S2/pc2/test/server.bats: line 21: 123670 Killed                  cd src && ./server.sh

2 tests, 2 failures
```

#### 4. Ejecución de pruebas Bats (ESTADO VERDE)
```bash
LOG_LEVEL=3 bats test/server.bats
```
**Salida:**
```
server.bats
 ✓ validacion debe funcionar
 ✓ servidor debe arrancar
 ✓ servidor debe responder en /salud

3 tests, 0 failures
```

#### 5. Verificacion del Makefile
```bash
make pack
```
**Salida:**
```
Verificando herramientas
Todas las herramientas están disponibles
Build completado
server.bats
 ✓ validacion debe funcionar
 ✓ servidor debe arrancar
 ✓ servidor debe responder en /salud

3 tests, 0 failures

Paquete creado: dist/pipeline-0.1.0-alpha.tar.gz
```



## Decisiones Técnicas Tomadas

### Diego - Estructura de Directorios
- **Decisión:** Separación de directorios en source (`src/`), tests (`tests/`), salidas (`out/`) y distribución (`dist/`)
- **Razón:** Organización estándar que facilita automatización y empaquetado

### Diego - Variables de Entorno
- **Decisión:** Usar `PORT`, `HOST`, `RELEASE` y `LOG_LEVEL` como variables de entorno
- **Razón:** Cumplimiento 12-Factor Factor III - configuración externa

### Diego - Dependencias de Targets
- **Decisión:** Cadena `tools → build → test` y `build → run`
- **Razón:** Garantizar verificación de dependencias antes de ejecución

### Pedro - Uso de SIGKILL en cleanup
- **Decisión:** Usar `pkill -9` para asegurar terminación de procesos
- **Razón:** Evitar procesos huérfanos que puedan interferir con pruebas

### Pedro - Metodologia RGR
- **Decisión:** Commits separados mostrando como los test fallan primero y luego pasan
- **Razón:** Demostrar TDD y asegurar calidad del código

### Pedro - Ajustes por ShellCheck
- **Decisión:** Añadir directivas para ignorar algunos warnings de ShellCheck
- **Razón:** Mantener código limpio y evitar falsos positivos en análisis estático

### Andrew - Implementación y validación del Runtime
## 1 Implementación y ejecución del target 'run'
Se modificó el `Makefile` para que `make run` ejecute el servidor.
###  1.1.Leer variables de entorno correctamente
Se modifico el Log_level de "info" a "2"
###  1.2 Verificar puerto disponible antes de arrancar
Ya estaba acoplado en server.sh
## 2 validaciones en runtime
### 2.1 Scripts para verificar dependencias
- **Decisión:** Que se maneje con validate_env
- **Razón:** para maneter un orden y escalabilidad
### 2.2 Manejar las señales (TERM, INT) para parada limpia
- **Decisión:** ajustar la funcion de limpieza (cleanup) y el capturador de señales(trap)
- **Razón:** arreglo de funcionamiento del manejo de señales
### 2.3 Estructurar el logging del servidor 
- **Decisión:** Utiliza log_info en server.sh para registrar cada petición, alineándose con logger.sh 
- **Razón:** peticion del servidor 
## 3 testing de integracion 
### 3.1 Pruebar básicas con curl al endpoint
- **Decisión:** peticion del servidor Implementar test de integración con curl para validar el endpoint /salud
- **Razón:**  corroborar que este en correcto funcionamiento todo lo que ya hemos realizado
### 3.2 Validacion códigos de respuesta HTTP
- **Decisión:** hacer assets de las respuestas http
- **Razón:**  para poder corroborar los request anteriores 
##  4. Limpieza y trap
- **Decisión:** corroborar el funcionamineto de la limpieza y el trap
- **Razón:**  tener un mejor control de la memoria asi como los recursos del sistema 
end