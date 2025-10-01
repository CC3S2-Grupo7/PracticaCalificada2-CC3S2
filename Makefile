# Configuración inicial
SHELL := /bin/bash
SHELLCHECK := shellcheck
SHFMT := shfmtsudo apt install shfmt 

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
RELEASE ?= 0.2.0-beta
LOG_LEVEL ?= 2

# Exportar variables de entorno para que los scripts Bash puedan leerlas
export PORT RELEASE LOG_LEVEL OUT_DIR DIST_DIR

REQUIRED_TOOLS = bash shellcheck shfmt bats curl find nc ss jq

# Targets
tools: $(OUT_DIR)/tools.verified ## Verificar disponibilidad de dependencias

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
	@bats $(TEST_DIR)/run_integration.bats

run: build ## Ejecutar el pipeline principal
	@echo "Lanzando servidor..."
	@$(SRC_DIR)/server.sh

pack: build test ## Generar paquete reproducible en dist/
	@mkdir -p $(DIST_DIR)
	@tar -czf $(DIST_DIR)/pipeline-$(RELEASE).tar.gz \
		--exclude='$(OUT_DIR)' --exclude='$(DIST_DIR)' \
		src/ test/ docs/ Makefile .env.example
	@echo "Paquete creado: $(DIST_DIR)/pipeline-$(RELEASE).tar.gz"
	
clean: ## Limpiar directorios out/ y dist/
	@echo "Limpiando artefactos"
	@rm -rf $(OUT_DIR) $(DIST_DIR)

help: ## Mostrar lista de targets
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