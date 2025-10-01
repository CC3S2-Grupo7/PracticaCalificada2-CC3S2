# Guía de Releases

## Convención de Versionado Semántico

- **X.Y.Z**: Versión semántica
  - X (major): Cambios incompatibles con versiones anteriores
  - Y (minor): Nueva funcionalidad
  - Z (patch): Correcciones de bugs o problemas menores

### Sufijos
- `-alpha`: Desarrollo temprano
- `-beta`: Funcionalidades completas, en testing
- `-rc`: Release candidate

## Proceso de Release

### 1. Preparar release
```bash
# Verificar que todo esté commiteado
git status

# Ejecutar tests
make test
```

### 2. Crear release
```bash
# Generar changelog y tag
make release RELEASE=0.1.0-beta

# Verificar tag
git tag -l
```

### 3. Empaquetar
```bash
# Crear el artefacto reproducible
make pack RELEASE=0.1.0-beta

# Verificar el checksum
cat dist/pipeline-0.1.0-beta.tar.gz.sha256
```