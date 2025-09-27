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
TST_DIR := tests
OUT_DIR := out
DST_DIR := dist

# Variables de entorno
PORT ?= 8080
RELEASE ?= 0.1.0-alpha
LOG_LEVEL ?= info

# Targets
tools: ## Verificar disponibilidad de dependencias
	@echo "Verificando herramientas"
	@command -v bash > /dev/null 2>&1 || { echo "Comando no encontrado: bash"; exit 1; }
	@command -v bats > /dev/null 2>&1 || { echo "Comando no encontrado: bats"; exit 1; }
	@command -v curl > /dev/null 2>&1 || { echo "Comando no encontrado: curl"; exit 1; }
	@command -v find > /dev/null 2>&1 || { echo "Comando no encontrado: find"; exit 1; }
	@command -v nc > /dev/null 2>&1 || { echo "Comando no encontrado: nc"; exit 1; }
	@command -v ss > /dev/null 2>&1 || { echo "Comando no encontrado: ss"; exit 1; }

lint: ## Revisar formato de Bash scripts
	@find $(SRC_DIR) -name "*.sh" -type f | while read -r file; do \
		echo "Revisando $$file"; \
		$(SHELLCHECK) "$$file" || exit 1; \
		$(SHFMT) -d "$$file" || exit 1; \
	done

format: ## Formatear Bash scripts
	@find $(SRC_DIR) -name "*.sh" -type f | while read -r file; do \
		echo "Formateando $$file"; \
		$(SHFMT) -w "$$file" || exit 1; \
	done

build: tools ## Prepara artefactos intermedios en out/
	

test: build ## Ejecutar suite de pruebas Bats
	

run: build ## Ejecutar el pipeline principal
	

pack: build test ## Generar paquete reproducible en dist/
	

clean: ## Limpiar directorios out/ y dist/
	@echo "Limpiando artefactos"
	@rm -rf $(OUT_DIR) $(DST_DIR)

help: ## Mostrar lista de targets
	@echo "Targets disponibles:"
	@grep -E '^[a-zA-Z0-9_\-]+:.*?##' $(MAKEFILE_LIST) | \
		awk 'BEGIN{FS=":.*?##"}{printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2}'
