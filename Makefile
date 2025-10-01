# Configuración inicial
SHELL := /bin/bash
SHELLCHECK := shellcheck
SHFMT := shfmt

MAKEFLAGS += --warn-undefined-variables --no-builtin-rules --no-print-directory

.DEFAULT_GOAL := help
.SHELLFLAGS := -eu -o pipefail -c
.DELETE_ON_ERROR:

export LC_ALL := C
export LANG := C
export TZ := UTC

.PHONY: build clean format help lint pack run test tools checksum verify-repro release

# Directorios
SRC_DIR := src
TEST_DIR := test
OUT_DIR := out
DIST_DIR := dist

# Variables de entorno
PORT ?= 8080
RELEASE ?= 0.2.0-beta
LOG_LEVEL ?= 2
RUNTIME_MODE ?= debug

# Exportar variables de entorno para que los scripts Bash puedan leerlas
export PORT RELEASE LOG_LEVEL OUT_DIR DIST_DIR RUNTIME_MODE

# Otras variables
BUILD_INFO := $(OUT_DIR)/build-info.txt
TIMESTAMP := $(shell date +%s)
GIT_HASH := $(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")
# definicion de archivos 
REQUIRED_TOOLS = bash shellcheck shfmt bats curl find nc ss jq
SRC_SCRIPTS := $(wildcard $(SRC_DIR)/*.sh)
TEST_SCRIPTS := $(wildcard $(TEST_DIR)/*.bats)

# Artefactos reproducibles
PACKAGE_NAME := pipeline-$(RELEASE)
PACKAGE_TAR := $(DIST_DIR)/$(PACKAGE_NAME).tar.gz
CHECKSUM_SHA256 := $(DIST_DIR)/$(PACKAGE_NAME).sha256
REPRO_ARTIFACTS := $(PACKAGE_TAR) $(CHECKSUM_SHA256)

# Targets
tools: ## Verificar disponibilidad de dependencias
	@echo "Verificando herramientas..."
	@for cmd in $(REQUIRED_TOOLS); do \
		command -v $$cmd > /dev/null 2>&1 || { echo "Error: Comando no encontrado: '$$cmd'"; exit 1; }; \
	done
	@echo "Todas las herramientas están disponibles."

lint: tools ## Revisar la sintaxis de los scripts
	@echo "Revisando scripts con shellcheck..."
	
format: tools ## Formatear los scripts
	@echo "Formateando scripts con shfmt..."
	@$(SHFMT) -w $(SRC_SCRIPTS)

build: ## Validar la sintaxis de los scripts
	@echo "Validando sintaxis de los scripts..."
	@for script in $(SRC_SCRIPTS); do \
		bash -n "$$script"; \
	done
	@echo "Build completado."

test: build lint format ## Ejecutar la suite de pruebas de Bats
	@echo "Ejecutando pruebas de integración..."
	@bats $(TEST_DIR)/server.bats

run: build ## Ejecutar el servidor principal
	@echo "Lanzando servidor en modo: $(RUNTIME_MODE)..."
	@$(SRC_DIR)/server.sh

pack: test ## Generar paquete reproducible con metadata
	@echo "Empaquetando release $(RELEASE)..."
	@mkdir -p $(DIST_DIR)
	@tar --sort=name \
	     --owner=0 --group=0 --numeric-owner \
	     --mtime='@$(TIMESTAMP)' \
	     -czf $(PACKAGE_TAR) \
	     --exclude='$(OUT_DIR)' --exclude='$(DIST_DIR)' \
	     src/ test/ docs/ Makefile .env.example
	@echo "Paquete creado: $(PACKAGE_TAR)"

checksum: pack ## Generar checksums del paquete
	@echo "Generando checksum SHA256..."
	@sha256sum $(PACKAGE_TAR) | awk '{print $$1}' > $(CHECKSUM_SHA256)
	@echo "SHA256: $$(cat $(CHECKSUM_SHA256))"

release: checksum ## Crear un tag de release y actualizar CHANGELOG.md
	@echo "Generando release $(RELEASE)"
	@# Validar que no haya cambios sin commitear
	@if ! git diff --quiet || ! git diff --cached --quiet; then \
		echo "Error: Hay cambios sin commitear, haz commit o stash antes de crear la nueva release."; \
		exit 1; \
	fi
	@# Abortar si el tag ya existe
	@if git rev-parse "v$(RELEASE)" >/dev/null 2>&1; then \
		echo "Error: El tag v$(RELEASE) ya existe, utiliza una nueva versión."; \
		exit 1; \
	fi
	@# Asegurar que exista CHANGELOG.md con encabezado
	@if [ ! -f CHANGELOG.md ]; then \
		echo "# Changelog" > CHANGELOG.md; \
		echo "" >> CHANGELOG.md; \
	fi
	@# Generar changelog temporal para la nueva versión
	@tmpfile=$$(mktemp); \
	echo "## [$(RELEASE)] - $$(date +%Y-%m-%d)" > $$tmpfile; \
	if git describe --tags --abbrev=0 >/dev/null 2>&1; then \
		last_tag=$$(git describe --tags --abbrev=0); \
		echo "Generando changelog desde $$last_tag..."; \
		git log --oneline $$last_tag..HEAD | sed 's/^/- /' >> $$tmpfile; \
	else \
		echo "No hay tags previos, incluyendo todos los commits"; \
		git log --oneline --reverse | sed 's/^/- /' >> $$tmpfile; \
	fi; \
	echo "" >> $$tmpfile; \
	cat CHANGELOG.md >> $$tmpfile; \
	mv $$tmpfile CHANGELOG.md
	@echo "CHANGELOG.md actualizado"
	@# Commit del changelog
	@git add CHANGELOG.md
	@git commit -m "Actualizar CHANGELOG.md para v$(RELEASE)"
	@echo "Commit del changelog creado"
	@# Crear el tag
	@git tag -a "v$(RELEASE)" -m "Release $(RELEASE)"
	@echo "Tag v$(RELEASE) creado"
	@# Push del commit y del tag
	@current_branch=$$(git symbolic-ref --short HEAD); \
	echo "Subiendo a la rama $$current_branch..."; \
	git push origin $$current_branch && \
	git push origin "v$(RELEASE)"
	@echo "Release v$(RELEASE) completado y enviado al remoto"

clean: ## Limpiar directorios out/ y dist/
	@echo "Limpiando artefactos..."
	@rm -rf $(OUT_DIR) $(DIST_DIR)

help: ## Mostrar esta lista de ayuda
	@echo "Targets disponibles:"
	@grep -E '^[a-zA-Z0-9_\-]+:.*?##' $(MAKEFILE_LIST) | \
		awk 'BEGIN{FS=":.*?##"}{printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2}'

# Reglas patrón
$(OUT_DIR)/tools.verified:
	@echo "Verificando herramientas"
	@for cmd in $(REQUIRED_TOOLS); do \
		command -v $$cmd > /dev/null 2>&1 || { echo "Comando no encontrado: $$cmd"; exit 1; }; \
	done
	@mkdir -p $(@D)
	@touch $@

$(OUT_DIR)/%.lint: $(SRC_DIR)/%.sh | $(OUT_DIR)/tools.verified
	@echo "Revisando $<"
	@$(SHELLCHECK) -e SC1091 "$<"
	@mkdir -p $(@D)
	@touch $@

$(OUT_DIR)/%.format: $(SRC_DIR)/%.sh | $(OUT_DIR)/tools.verified
	@echo "Formateando $<"
	@$(SHFMT) -w "$<"
	@mkdir -p $(@D)
	@touch $@

$(OUT_DIR)/%.built: $(SRC_DIR)/%.sh
	@echo "Validando sintaxis de $<"
	@$(SHELL) -n "$<"
	@mkdir -p $(@D)
	@touch $@

$(BUILD_INFO): $(BUILD_TARGETS)
	@echo "Generando información de build"
	@mkdir -p $(@D)
	@echo "Release: $(RELEASE)" > $@
	@echo "Timestamp: $(TIMESTAMP)" >> $@
	@echo "Git Hash: $(GIT_HASH)" >> $@
	@echo "Scripts procesados: $(words $(SRC_SCRIPTS))" >> $@
	@echo "Tests disponibles: $(words $(TEST_BATS))" >> $@
	@echo "Artifacts:" >> $@
	@echo "	build_info: $(BUILD_INFO)" >> $@
	@echo "	package: $(PACKAGE_TAR)" >> $@
	@echo "Build completado"

$(OUT_DIR)/%.executed: $(TEST_DIR)/%.bats $(BUILD_INFO)
	@echo "Ejecutando test Bats $<"
	@bats "$<"
	@mkdir -p $(@D)
	@touch $@

$(PACKAGE_TAR): $(BUILD_INFO) $(TEST_TARGETS)
	@echo "Empaquetando release $(RELEASE) de forma reproducible"
	@mkdir -p $(@D)
	@# Crear archivo de metadata
	@echo "release: $(RELEASE)" > $(OUT_DIR)/release-info.txt
	@echo "build_date: $$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> $(OUT_DIR)/release-info.txt
	@echo "git_commit: $(GIT_HASH)" >> $(OUT_DIR)/release-info.txt
	@# Crear tarball reproducible
	@tar --sort=name \
	     --owner=0 --group=0 --numeric-owner \
	     --mtime='@$(TIMESTAMP)' \
	     -czf $@ \
	     --exclude='$(OUT_DIR)' --exclude='$(DIST_DIR)' \
	     src/ test/ docs/ Makefile .env.example
	@echo "Paquete creado: $@"

$(CHECKSUM_SHA256): $(PACKAGE_TAR)
	@echo "Generando checksum SHA256"
	@sha256sum $< | awk '{print $$1}' > $@
	@echo "SHA256: $$(cat $@)"