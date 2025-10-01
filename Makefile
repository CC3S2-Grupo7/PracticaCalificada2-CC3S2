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
RELEASE ?= 0.2.0-beta
LOG_LEVEL ?= 2

# Exportar variables de entorno para que los scripts Bash puedan leerlas
export PORT RELEASE LOG_LEVEL OUT_DIR DIST_DIR

# Otra variables
BUILD_INFO := $(OUT_DIR)/build-info.txt
TIMESTAMP := $(shell date +%s)
REQUIRED_TOOLS = bash shellcheck shfmt bats curl find nc ss jq
SRC_SCRIPTS := $(wildcard $(SRC_DIR)/*.sh)
TEST_BATS := $(wildcard $(TEST_DIR)/*.bats)
LINT_TARGETS := $(SRC_SCRIPTS:$(SRC_DIR)/%.sh=$(OUT_DIR)/%.lint)
FORMAT_TARGETS := $(SRC_SCRIPTS:$(SRC_DIR)/%.sh=$(OUT_DIR)/%.format)
BUILD_TARGETS := $(SRC_SCRIPTS:$(SRC_DIR)/%.sh=$(OUT_DIR)/%.built)
TEST_TARGETS := $(TEST_BATS:$(TEST_DIR)/%.bats=$(OUT_DIR)/%.executed)

# Targets
tools: $(OUT_DIR)/tools.verified ## Verificar disponibilidad de dependencias

lint: $(LINT_TARGETS) ## Revisar formato de Bash scripts

format: $(FORMAT_TARGETS) ## Formatear Bash scripts

build: $(BUILD_TARGETS) $(BUILD_INFO) ## Prepara artefactos intermedios en out/

test: $(TEST_TARGETS) ## Ejecutar suite de pruebas Bats

run: build ## Ejecutar el pipeline principal
	@echo "Lanzando servidor..."
	@$(SRC_DIR)/server.sh

pack: $(DIST_DIR)/pipeline-$(RELEASE).tar.gz ## Generar paquete reproducible en dist/
	
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

$(OUT_DIR)/%.lint: $(SRC_DIR)/%.sh | $(OUT_DIR)/tools.verified
	@echo "Revisando $<"
	@$(SHELLCHECK) -e SC1091 "$<"
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
	@echo "Build completado"

$(OUT_DIR)/%.executed: $(TEST_DIR)/%.bats $(BUILD_INFO)
	@echo "Ejecutando test Bats $<"
	@bats "$<"
	@mkdir -p $(@D)
	@touch $@

$(DIST_DIR)/pipeline-$(RELEASE).tar.gz: $(BUILD_INFO) $(TEST_TARGETS)
	@echo "Empaquetando release $(RELEASE)"
	@mkdir -p $(@D)
	@tar -czf $@ \
		--exclude='$(OUT_DIR)' --exclude='$(DIST_DIR)' \
		src/ test/ docs/ Makefile .env.example
	@echo "Paquete creado: $@"
