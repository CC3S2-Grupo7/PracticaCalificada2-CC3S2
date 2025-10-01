# Contrato de Salidas - Artefactos del Pipeline

Este documento especifica todos los artefactos generados por el pipeline de build, su ubicación, contenido y el proceso de generación.

## Directorio `/out` - Artefactos Intermedios

El directorio `out/` contiene artefactos intermedios del proceso de build. Estos archivos son **efímeros** y se regeneran en cada build limpio.

### Estructura

```
out/
├── tools.verified          # Verificación de dependencias
├── build-info.txt          # Metadatos del build
├── *.lint                  # Marcadores de lint exitoso
├── *.format                # Marcadores de formato exitoso
├── *.built                 # Marcadores de validación sintáctica
└── *.executed              # Marcadores de tests ejecutados
```

---

### `out/tools.verified`

**Propósito:** Verificar que todas las herramientas requeridas están disponibles.

**Generación:**
```makefile
Target: tools
Comando: make tools
```

**Proceso:**
1. Itera sobre `REQUIRED_TOOLS` (bash, shellcheck, shfmt, bats, curl, find, nc, ss, jq)
2. Verifica existencia con `command -v`
3. Crea archivo marcador si todas las herramientas están disponibles

**Contenido:**
Archivo vacío que actúa como marcador de verificación exitosa.

**Dependencias:**
- Sistema con herramientas instaladas

### `out/*.lint`

**Propósito:** Marcadores de validación de estilo y sintaxis con shellcheck.

**Generación:**
```makefile
Target: lint
Comando: make lint
Patrón: $(OUT_DIR)/%.lint: $(SRC_DIR)/%.sh
```

**Proceso:**
1. Ejecuta `shellcheck -e SC1091` sobre cada script en `src/`
2. Si pasa la validación, crea archivo marcador

**Archivos generados:**
- `out/check-env.lint`
- `out/logger.lint`
- `out/server.lint`

### `out/*.format`

**Propósito:** Marcadores de formateo aplicado con shfmt.

**Generación:**
```makefile
Target: format
Comando: make format
Patrón: $(OUT_DIR)/%.format: $(SRC_DIR)/%.sh
```

**Proceso:**
1. Ejecuta `shfmt -w` sobre cada script en `src/`
2. `-w`: Escribe cambios directamente en el archivo
3. Crea archivo marcador después de formatear

**Archivos generados:**
- `out/check-env.format`
- `out/logger.format`
- `out/server.format`

### `out/*.built`

**Propósito:** Marcadores de validación sintáctica de Bash.

**Generación:**
```makefile
Target: build
Comando: make build
Patrón: $(OUT_DIR)/%.built: $(SRC_DIR)/%.sh
```

**Proceso:**
1. Ejecuta `bash -n` (modo no-ejecución) sobre cada script
2. Verifica sintaxis sin ejecutar el código
3. Crea archivo marcador si la sintaxis es válida

**Archivos generados:**
- `out/check-env.built`
- `out/logger.built`
- `out/server.built`

### `out/build-info.txt`

**Propósito:** Metadatos centralizados del build para trazabilidad.

**Generación:**
```makefile
Target: build
Comando: make build
Depende de: $(BUILD_TARGETS)
```

**Proceso:**
1. Recopila información del entorno de build
2. Registra versión, timestamp, hash de git
3. Cuenta scripts y tests procesados
4. Lista rutas de artefactos principales

**Contenido:**
```
Release: 0.2.0-beta
Timestamp: 1727695800
Git Hash: a1b2c3d
Scripts procesados: 4
Tests disponibles: 1
Artifacts:
	build_info: out/build-info.txt
	package: dist/pipeline-0.2.0-beta.tar.gz
```

**Variables utilizadas:**
- `RELEASE`: Versión semántica del release
- `TIMESTAMP`: Unix timestamp del build (`date +%s`)
- `GIT_HASH`: Hash corto del commit actual (`git rev-parse --short HEAD`)
- `SRC_SCRIPTS`: Lista de scripts en src/
- `TEST_BATS`: Lista de tests en test/

### `out/*.executed`

**Propósito:** Marcadores de ejecución exitosa de tests.

**Generación:**
```makefile
Target: test
Comando: make test
Patrón: $(OUT_DIR)/%.executed: $(TEST_DIR)/%.bats
```

**Proceso:**
1. Ejecuta `bats` sobre cada archivo `.bats` en `test/`
2. Si todos los tests pasan, crea archivo marcador
3. Falla si algún test no pasa

**Archivos generados:**
- `out/server.executed`

## Directorio `/dist` - Artefactos Finales

El directorio `dist/` contiene artefactos **finales** y **distribuibles** del pipeline. Estos son los únicos artefactos que deben publicarse o compartirse.

### Estructura

```
dist/
├── pipeline-{VERSION}.tar.gz      # Paquete comprimido reproducible
├── pipeline-{VERSION}.sha256      # Checksum SHA256 del paquete
└── pipeline-verify-*.tar.gz       # Artefactos temporales de verificación
```

### `dist/pipeline-{VERSION}.tar.gz`

**Propósito:** Paquete distribuible reproducible del proyecto completo.

**Generación:**
```makefile
Target: pack
Comando: make pack
Variable: PACKAGE_TAR
```

**Proceso:**
1. Crea archivo tar con flags de reproducibilidad:
   - `--sort=name`: Ordenamiento alfabético determinístico
   - `--owner=0 --group=0`: Usuario/grupo normalizados
   - `--numeric-owner`: IDs numéricos en lugar de nombres
   - `--mtime='@$(TIMESTAMP)'`: Timestamp fijo del build
2. Incluye directorios: `src/`, `test/`, `docs/`, `Makefile`, `.env.example`
3. Excluye directorios temporales: `out/`, `dist/`
4. Comprime con gzip

**Contenido:**
```
pipeline-0.2.0-beta.tar.gz
├── src/
│   ├── config.sh
│   ├── logger.sh
│   ├── metrics.sh
│   └── server.sh
├── test/
│   ├── server.bats
│   └── test_helper.bash
├── docs/
│   └── ...
├── Makefile
└── .env.example
```

### `dist/pipeline-{VERSION}.sha256`

**Propósito:** Checksum SHA256 para verificación de integridad del paquete.

**Generación:**
```makefile
Target: checksum
Comando: make checksum
Variable: CHECKSUM_SHA256
```

**Proceso:**
1. Calcula SHA256 del archivo `.tar.gz`
2. Extrae solo el hash (sin nombre de archivo)
3. Guarda en archivo `.sha256`

**Contenido:**
Una única línea con el hash hexadecimal de 64 caracteres.

### Artefactos Temporales de Verificación

**Propósito:** Archivos temporales generados durante `make verify-repro`.

**Archivos:**
- `dist/pipeline-verify-1.tar.gz`
- `dist/pipeline-verify-1.sha256`
- `dist/pipeline-verify-2.tar.gz`
- `dist/pipeline-verify-2.sha256`

**Generación:**
```makefile
Target: verify-repro
Comando: make verify-repro
```

**Proceso:**
1. Genera primer paquete y guarda como `*-verify-1.*`
2. Espera 2 segundos
3. Genera segundo paquete y guarda como `*-verify-2.*`
4. Compara checksums de ambos builds
5. Elimina archivos temporales al finalizar

**Ciclo de vida:**
- Creados: Durante `make verify-repro`
- Eliminados: Al finalizar `make verify-repro` (exitoso o no)

**No deben persistir** después de la ejecución del comando.

## Verificación de Integridad

### Checksum SHA256

Todos los paquetes finales incluyen su checksum SHA256 para verificación.

**Generar checksum:**
```bash
make checksum
```

### Reproducibilidad

El pipeline garantiza que builds repetidos producen artefactos idénticos.

**Verificar reproducibilidad:**
```bash
make verify-repro
```

**Salida esperada:**
```
Verificando reproducibilidad del build...
REPRODUCIBLE: Los builds generan checksums idénticos
	SHA256: a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1v2w3x4y5z6a7b8c9d0e1f2
```

## Pipeline Completo

```bash
# Fase 1: Verificación
make tools              # → out/tools.verified

# Fase 2: Validación
make lint               # → out/*.lint
make format             # → out/*.format

# Fase 3: Build
make build              # → out/*.built
                        # → out/build-info.txt

# Fase 4: Testing
make test               # → out/*.executed

# Fase 5: Empaquetado
make pack               # → dist/pipeline-VERSION.tar.gz
                        # → dist/pipeline-VERSION.sha256

# Fase 6: Verificación
make verify-repro       # Valida reproducibilidad
```

## Dependencias por Target

| Target | Genera | Depende de |
|--------|--------|------------|
| `tools` | `out/tools.verified` | Sistema con herramientas |
| `lint` | `out/*.lint` | `out/tools.verified`, `src/*.sh` |
| `format` | `out/*.format` | `out/tools.verified`, `src/*.sh` |
| `build` | `out/*.built`, `out/build-info.txt` | `src/*.sh` |
| `test` | `out/*.executed` | `out/build-info.txt`, `test/*.bats` |
| `pack` | `dist/pipeline-*.tar.gz` | `out/build-info.txt`, `out/*.executed` |
| `checksum` | `dist/pipeline-*.sha256` | `dist/pipeline-*.tar.gz` |

## Limpieza de Artefactos

```bash
make clean
```

**Efecto:**
- Elimina `out/` completamente
- Elimina `dist/` completamente
- Limpia archivos temporales en `/tmp/server_metrics_*`
