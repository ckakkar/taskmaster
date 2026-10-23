.PHONY: build run check lint format app dmg measure clean help

export CLANG_MODULE_CACHE_PATH := $(CURDIR)/.build/module-cache
export SWIFTPM_MODULECACHE_OVERRIDE := $(CURDIR)/.build/module-cache

help:
	@echo "make run    Build and open Taskmaster.app"
	@echo "make check  Run behavior tests and compile the native app"
	@echo "make app    Build a release .app in build/"
	@echo "make dmg    Package a drag-and-drop disk image"
	@echo "make measure  CPU/memory matrix on an optimized build with debug workloads"
	@echo "make clean  Remove generated build products"

build:
	./scripts/swift.sh build

check:
	./scripts/swift.sh test
	.build/debug/Taskmaster --self-check

lint:
	xcrun swift-format lint --strict --recursive Sources Tests scripts/render-icon.swift Package.swift

format:
	xcrun swift-format format --in-place --recursive Sources Tests scripts/render-icon.swift Package.swift

app:
	./scripts/build-app.sh

run: app
	open build/Taskmaster.app

dmg: app
	./scripts/build-dmg.sh

# Optimized like a release, but keeps the debug-only workload switches; built apart from release output.
measure:
	swift build -c release -Xswiftc -DDEBUG --product Taskmaster --scratch-path .build/perf --disable-sandbox
	python3 scripts/measure-performance.py --binary .build/perf/release/Taskmaster

clean:
	rm -rf .build build
