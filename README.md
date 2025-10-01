# Proyecto 7: Pipeline "Compilar-Lanzar-Ejecutar"

## Descripción
Pipeline Make que implementa una separación clara entre las etapas de build, release y run, produciendo artefactos reproducibles con versionado semántico.

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

### Uso Básico

```bash
# Copiar valores de ejemplo 
cp .env.example .env
```

## Estructura del Proyecto

```
pc2/
├── src/               # Scripts Bash del servidor
├── test/              # Casos de prueba Bats
├── docs/              # Documentación y bitácoras
├── out/               # Artefactos intermedios
├── dist/              # Paquetes finales
├── .env.example       # Plantilla de variables de entorno
├── Makefile           # Pipeline de automatización
```
