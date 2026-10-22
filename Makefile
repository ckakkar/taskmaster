.PHONY: build run check app dmg clean help

export CLANG_MODULE_CACHE_PATH := $(CURDIR)/.build/module-cache
export SWIFTPM_MODULECACHE_OVERRIDE := $(CURDIR)/.build/module-cache

help:
	@echo "make run    Build and open Taskmaster.app"
	@echo "make check  Run behavior tests and compile the native app"
	@echo "make app    Build a release .app in build/"
	@echo "make dmg    Package a drag-and-drop disk image"
	@echo "make clean  Remove generated build products"

build:
	./scripts/swift.sh build

check:
	./scripts/swift.sh test

app:
	./scripts/build-app.sh

run: app
	open build/Taskmaster.app

dmg: app
	./scripts/build-dmg.sh

clean:
	rm -rf .build build
