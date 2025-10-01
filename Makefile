# Configuración inicial
SHELL := /bin/bash
SHELLCHECK := shellcheck
SHFMT := shfmt

MAKEFLAGS += --warn-undefined-variables --no-builtin-rules

.DEFAULT_GOAL := help
.SHELLFLAGS := -eu -o pipefail -c
.DELETE_ON_ERROR:

export LC_ALL := C
export LANG := C
export TZ := UTC

.PHONY: build clean format help lint pack run test tools

# Directorios
SRC_DIR := src
TEST_DIR := test
OUT_DIR := out
DIST_DIR := dist

# Variables de entorno
PORT ?= 8080
RELEASE ?= 0.1.0-alpha
LOG_LEVEL ?= info

# Targets
tools: ## Verificar disponibilidad de dependencias
	@echo "Verificando herramientas"
	@command -v bash > /dev/null 2>&1 || { echo "Comando no encontrado: bash"; exit 1; }
	@command -v shellcheck > /dev/null 2>&1 || { echo "Comando no encontrado: shellcheck"; exit 1; }
	@command -v shfmt > /dev/null 2>&1 || { echo "Comando no encontrado: shfmt"; exit 1; }
	@command -v bats > /dev/null 2>&1 || { echo "Comando no encontrado: bats"; exit 1; }
	@command -v curl > /dev/null 2>&1 || { echo "Comando no encontrado: curl"; exit 1; }
	@command -v find > /dev/null 2>&1 || { echo "Comando no encontrado: find"; exit 1; }
	@command -v nc > /dev/null 2>&1 || { echo "Comando no encontrado: nc"; exit 1; }
	@command -v ss > /dev/null 2>&1 || { echo "Comando no encontrado: ss"; exit 1; }
	@command -v jq > /dev/null 2>&1 || { echo "Comando no encontrado: jq"; exit 1; }
	@echo "Todas las herramientas están disponibles"

lint: ## Revisar formato de Bash scripts
	@find $(SRC_DIR) -name "*.sh" -type f | while read -r file; do \
		echo "Revisando $$file"; \
		$(SHELLCHECK) -e SC1091 "$$file" || exit 1; \
	done

format: ## Formatear Bash scripts
	@find $(SRC_DIR) -name "*.sh" -type f | while read -r file; do \
		echo "Formateando $$file"; \
		$(SHFMT) -w "$$file" || exit 1; \
	done

build: tools ## Prepara artefactos intermedios en out/
	@mkdir -p $(OUT_DIR)
	@$(SHELL) -n $(SRC_DIR)/server.sh
	@$(SHELL) -n $(SRC_DIR)/check-env.sh
	@$(SHELL) -n $(SRC_DIR)/logger.sh
	@echo "Build completado"

test: build ## Ejecutar suite de pruebas Bats
	@bats $(TEST_DIR)/server.bats

run: build ## Ejecutar el pipeline principal

pack: build test ## Generar paquete reproducible con metadata
	@mkdir -p $(DIST_DIR)
	@# Crear archivo de metadata
	@echo "release: $(RELEASE)" > $(OUT_DIR)/release-info.txt
	@echo "build_date: $$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> $(OUT_DIR)/release-info.txt
	@echo "git_commit: $$(git rev-parse --short HEAD 2>/dev/null || echo 'unknown')" >> $(OUT_DIR)/release-info.txt
	@# Crear tarball
	@tar -czf $(DIST_DIR)/pipeline-$(RELEASE).tar.gz \
		--exclude='$(OUT_DIR)' --exclude='$(DIST_DIR)' \
		src/ test/ docs/ Makefile .env.example
	@# Generar checksum
	@cd $(DIST_DIR) && sha256sum pipeline-$(RELEASE).tar.gz > pipeline-$(RELEASE).tar.gz.sha256
	@echo "✓ Paquete: $(DIST_DIR)/pipeline-$(RELEASE).tar.gz"
	@echo "✓ Checksum: $(DIST_DIR)/pipeline-$(RELEASE).tar.gz.sha256"
	@ls -lh $(DIST_DIR)/pipeline-$(RELEASE).tar.gz
	
clean: ## Limpiar directorios out/ y dist/
	@echo "Limpiando artefactos"
	@rm -rf $(OUT_DIR) $(DIST_DIR)

help: ## Mostrar lista de targets
	@echo "Targets disponibles:"
	@grep -E '^[a-zA-Z0-9_\-]+:.*?##' $(MAKEFILE_LIST) | \
		awk 'BEGIN{FS=":.*?##"}{printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2}'
