# OctaneOS top-level Makefile
# Convenience wrapper around scripts/build.sh
# All targets must be run inside WSL2.

.PHONY: setup build clean menuconfig linux-rebuild help

setup:
	./scripts/setup-build-env.sh

build:
	./scripts/build.sh

linux-rebuild:
	./scripts/build.sh linux-rebuild

linux-menuconfig:
	./scripts/build.sh linux-menuconfig

clean:
	./scripts/build.sh clean

help:
	@echo "OctaneOS build targets:"
	@echo "  make setup            - Install deps, init submodule, link configs"
	@echo "  make build            - Full build (first run takes several hours)"
	@echo "  make linux-rebuild    - Rebuild kernel only"
	@echo "  make linux-menuconfig - Open kernel config menu"
	@echo "  make clean            - Clean build output"
	@echo ""
	@echo "All targets require WSL2 (Ubuntu 22.04+). Do not run on Windows directly."
