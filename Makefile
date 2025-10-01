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
TIMESTAMP_DIR := .make

# Flag para saltar tests cuando se ejecuta pack
PACK_SKIP_TEST ?= 0

# Variables de entorno
PORT ?= 8080
RELEASE ?= 0.1.0-beta
LOG_LEVEL ?= 2

# Exportar variables de entorno para que los scripts Bash puedan leerlas
export PORT RELEASE LOG_LEVEL OUT_DIR DIST_DIR

# Otras variables
BUILD_INFO := $(OUT_DIR)/build-info.txt
TIMESTAMP := $(shell date +%s)
GIT_HASH := $(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")
REQUIRED_TOOLS = bash shellcheck shfmt bats curl find nc ss jq
SRC_SCRIPTS := $(wildcard $(SRC_DIR)/*.sh)
TEST_BATS := $(wildcard $(TEST_DIR)/*.bats)

# Timestamps para caché incremental
BUILD_STAMP := $(TIMESTAMP_DIR)/build.stamp
TEST_STAMP := $(TIMESTAMP_DIR)/test.stamp
TEST_BATS := $(filter-out test/makefile.bats, $(wildcard test/*.bats))
LINT_STAMP := $(TIMESTAMP_DIR)/lint.stamp
FORMAT_STAMP := $(TIMESTAMP_DIR)/format.stamp
TOOLS_STAMP := $(TIMESTAMP_DIR)/tools.stamp

# Artefactos reproducibles
PACKAGE_NAME := pipeline-$(RELEASE)
PACKAGE_TAR := $(DIST_DIR)/$(PACKAGE_NAME).tar.gz
CHECKSUM_SHA256 := $(DIST_DIR)/$(PACKAGE_NAME).sha256
REPRO_ARTIFACTS := $(PACKAGE_TAR) $(CHECKSUM_SHA256)

# Targets principales
tools: $(TOOLS_STAMP) ## Verificar disponibilidad de dependencias

lint: $(LINT_STAMP) ## Revisar formato de Bash scripts

format: $(FORMAT_STAMP) ## Formatear Bash scripts

build: $(BUILD_STAMP) ## Prepara artefactos intermedios en out/

test: $(TEST_STAMP) ## Ejecutar suite de pruebas Bats

run: build ## Ejecutar el pipeline principal
	@echo "Lanzando servidor..."
	@$(SRC_DIR)/server.sh

pack: $(REPRO_ARTIFACTS) ## Generar paquete reproducible con metadata
	@echo "Paquete: $(PACKAGE_TAR)"
	@echo "Checksum: $(CHECKSUM_SHA256)"
	@echo "SHA256: $$(cat $(CHECKSUM_SHA256))"
	@ls -lh $(PACKAGE_TAR)

checksum: $(CHECKSUM_SHA256) ## Generar checksums del paquete

verify-repro: ## Verificar reproducibilidad del empaquetado
	@echo "Verificando reproducibilidad del build..."
	@$(MAKE) -s pack
	@cp $(PACKAGE_TAR) $(DIST_DIR)/pipeline-verify-1.tar.gz
	@cp $(CHECKSUM_SHA256) $(DIST_DIR)/pipeline-verify-1.sha256
	@sleep 2
	@$(MAKE) -s pack
	@cp $(PACKAGE_TAR) $(DIST_DIR)/pipeline-verify-2.tar.gz
	@cp $(CHECKSUM_SHA256) $(DIST_DIR)/pipeline-verify-2.sha256
	@if diff $(DIST_DIR)/pipeline-verify-1.sha256 $(DIST_DIR)/pipeline-verify-2.sha256 >/dev/null; then \
		echo "REPRODUCIBLE: Los builds generan checksums idénticos"; \
		echo "	SHA256: $$(cat $(CHECKSUM_SHA256))"; \
	else \
		echo "NO REPRODUCIBLE: Los checksums difieren"; \
		echo "	Build 1: $$(cat $(DIST_DIR)/pipeline-verify-1.sha256)"; \
		echo "	Build 2: $$(cat $(DIST_DIR)/pipeline-verify-2.sha256)"; \
		exit 1; \
	fi
	@rm -f $(DIST_DIR)/pipeline-verify-*.tar.gz $(DIST_DIR)/pipeline-verify-*.sha256

release: pack ## Crear release y actualizar CHANGELOG.md
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
	
clean: ## Limpiar directorios out/, dist/ y caché
	@echo "Limpiando artefactos y caché"
	@rm -rf $(OUT_DIR) $(DIST_DIR) $(TIMESTAMP_DIR)

help: ## Mostrar lista de targets
	@echo "Targets disponibles:"
	@grep -E '^[a-zA-Z0-9_\-]+:.*?##' $(MAKEFILE_LIST) | \
		awk 'BEGIN{FS=":.*?##"}{printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2}'

# Reglas con caché incremental

# Crear directorio de timestamps
$(TIMESTAMP_DIR):
	@mkdir -p $@

$(OUT_DIR):
	@mkdir -p $@

$(DIST_DIR):
	@mkdir -p $@

# Tools: verificar herramientas una sola vez
$(TOOLS_STAMP): | $(TIMESTAMP_DIR)
	@echo "Verificando herramientas"
	@for cmd in $(REQUIRED_TOOLS); do \
		command -v $$cmd > /dev/null 2>&1 || { echo "Comando no encontrado: $$cmd"; exit 1; }; \
	done
	@echo "Todas las herramientas están disponibles"
	@touch $@

# Lint: validar sintaxis con shellcheck
$(LINT_STAMP): $(SRC_SCRIPTS) $(TOOLS_STAMP) | $(TIMESTAMP_DIR)
	@echo "Validando sintaxis con shellcheck"
	@for script in $(SRC_SCRIPTS); do \
		echo "  Validando $$script"; \
		$(SHELLCHECK) -e SC1091 "$$script"; \
	done
	@echo "Validación de sintaxis completada"
	@touch $@

# Formatear scripts con shfmt

$(FORMAT_STAMP): $(SRC_SCRIPTS) | $(TIMESTAMP_DIR)
	@echo "Formateando scripts con shfmt"
	@for script in $(SRC_SCRIPTS); do \
		echo "  Formateando $$script"; \
		$(SHFMT) -w "$$script"; \
	done
	@echo "Formateo completado"
	@touch $@


# Build: validar y generar metadata
$(BUILD_STAMP): $(SRC_SCRIPTS) $(LINT_STAMP) | $(TIMESTAMP_DIR) $(OUT_DIR)
	@echo "Ejecutando build"
	@# Generar build-info.txt
	@echo "Generando información de build"
	@echo "release=$(RELEASE)" > $(BUILD_INFO)
	@echo "build_date=$$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> $(BUILD_INFO)
	@echo "git_commit=$(GIT_HASH)" >> $(BUILD_INFO)
	@# Generar release-info.txt
	@echo "release=$(RELEASE)" > $(OUT_DIR)/release-info.txt
	@echo "build_date=$$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> $(OUT_DIR)/release-info.txt
	@echo "git_commit=$(GIT_HASH)" >> $(OUT_DIR)/release-info.txt
	@echo "Build completado"
	@touch $@

# Test: ejecutar suite Bats
$(TEST_STAMP): $(BUILD_STAMP) $(TEST_BATS) | $(TIMESTAMP_DIR)
	@echo "Ejecutando suite de tests"
	@for test in $(TEST_BATS); do \
		echo "  Ejecutando $$test"; \
		bats "$$test"; \
	done
	@echo "Tests completados"
	@touch $@

# Pack: crear tarball reproducible
$(PACKAGE_TAR): $(TEST_STAMP) | $(DIST_DIR)
ifeq ($(PACK_SKIP_TEST),1)
	@echo "Saltando tests en pack"
endif
	@echo "Empaquetando release $(RELEASE) de forma reproducible"
	@tar --sort=name \
	     --owner=0 --group=0 --numeric-owner \
	     --mtime='@$(TIMESTAMP)' \
	     -czf $@ \
	     --exclude='$(OUT_DIR)' --exclude='$(DIST_DIR)' --exclude='$(TIMESTAMP_DIR)' \
	     --exclude='.git' --exclude='.gitignore' \
	     src/ test/ docs/ Makefile .env.example README.md
	@echo "Paquete creado: $@"

# Checksum: generar SHA256
$(CHECKSUM_SHA256): $(PACKAGE_TAR)
	@echo "Generando checksum SHA256"
	@sha256sum $< | awk '{print $$1}' > $@
	@echo "SHA256: $$(cat $@)"