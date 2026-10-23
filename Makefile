# Common tasks for Taskmaster; run `make` for the list. `make check` and `make lint` mirror CI.
.DEFAULT_GOAL := help
.PHONY: help build run check lint format app install dmg icons measure clean

APP_DIR ?= /Applications

export CLANG_MODULE_CACHE_PATH := $(CURDIR)/.build/module-cache
export SWIFTPM_MODULECACHE_OVERRIDE := $(CURDIR)/.build/module-cache

help: ## Show this list
	@awk 'BEGIN {FS = ":.*## "} /^[a-z0-9-]+:.*## / {printf "  \033[1m%-10s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

build: ## Compile everything (debug)
	./scripts/swift.sh build

run: ## Build Taskmaster.app and open it (quits a running Taskmaster first)
	@pkill -x Taskmaster 2>/dev/null || true
	scripts/build-app.sh
	open build/Taskmaster.app

check: ## Behavior tests, native compilation and the character resource self-check
	./scripts/swift.sh test
	.build/debug/Taskmaster --self-check

lint: ## swift-format, strict
	xcrun swift-format lint --strict --recursive Sources Tests scripts/render-icon.swift scripts/dmg-background.swift Package.swift

format: ## Format the code
	xcrun swift-format format --in-place --recursive Sources Tests scripts/render-icon.swift scripts/dmg-background.swift Package.swift

app: ## Build Taskmaster.app in build/
	scripts/build-app.sh

install: ## Build Taskmaster.app and install it in /Applications
	@if pgrep -f "$(APP_DIR)/Taskmaster.app/Contents/MacOS/" >/dev/null; then echo "Quit Taskmaster first (paw › Quit Taskmaster), then run make install again."; exit 1; fi
	scripts/build-app.sh
	rm -rf "$(APP_DIR)/Taskmaster.app"
	cp -R build/Taskmaster.app "$(APP_DIR)/"
	@echo "Installed $(APP_DIR)/Taskmaster.app."

dmg: ## Universal Taskmaster.app and Taskmaster.dmg (with its designed window) in build/
	scripts/build-app.sh --universal
	scripts/make-dmg.sh build/Taskmaster.app build/Taskmaster.dmg

icons: ## Re-render the app icon (scripts/render-icon.swift)
	scripts/make-icons.sh

# Optimized like a release, but keeps the debug-only workload switches; built apart from release output.
measure: ## CPU/memory matrix on an optimized build with the debug workloads
	swift build -c release -Xswiftc -DDEBUG --product Taskmaster --scratch-path .build/perf --disable-sandbox
	python3 scripts/measure-performance.py --binary .build/perf/release/Taskmaster

clean: ## Remove build output
	rm -rf .build build
