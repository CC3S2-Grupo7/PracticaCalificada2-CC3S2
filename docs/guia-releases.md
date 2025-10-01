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

### 1. Cambiar a una rama `release` temporal
```bash
# Crear y cambiar a una rama temporal
git switch -c release
```

### 2. Crear la release
```bash
# Escoger la versión y ejecutar
RELEASE=<versión> make release
```

### 3. Verificar los archivos generados
```bash
# Verificar los archivos en out
ls out/

# Verificar los archivos en dist
ls dist/
```