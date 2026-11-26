SHELL       := /bin/bash
.SHELLFLAGS := -o pipefail -c

APP_NAME    := Standup
BUNDLE_ID   := dev.standup.Standup
PROJECT     := $(APP_NAME).xcodeproj
BUILD_DIR   := build.noindex
INSTALL_DIR := /Applications
INSTALLED   := $(INSTALL_DIR)/$(APP_NAME).app

XCODEBUILD_BASE := xcodebuild -project $(PROJECT) -scheme $(APP_NAME) \
               -derivedDataPath $(BUILD_DIR) -destination 'platform=macOS,arch=arm64'
XCODEBUILD  := $(XCODEBUILD_BASE) -quiet
DEBUG_APP   := $(BUILD_DIR)/Build/Products/Debug/$(APP_NAME).app
RELEASE_APP := $(BUILD_DIR)/Build/Products/Release/$(APP_NAME).app
LSREGISTER  := /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

.PHONY: help project build test coverage run install uninstall quit clean

help:
	@echo "make project    Generate $(PROJECT) from project.yml"
	@echo "make build      Debug build"
	@echo "make test       Run unit tests"
	@echo "make coverage   Run tests and print StandupCore line coverage"
	@echo "make run        Debug build and launch it"
	@echo "make install    Release build, install to $(INSTALLED), launch"
	@echo "make uninstall  Remove $(INSTALLED) (PURGE=1 also deletes settings)"
	@echo "make clean      Remove build output and generated project"

project:
	@command -v xcodegen >/dev/null || { echo "XcodeGen not found: brew install xcodegen"; exit 1; }
	@xcodegen generate --quiet --use-cache

build: project
	$(XCODEBUILD) -configuration Debug build

# Not -quiet: show Swift Testing results, filtered to the useful lines.
test: project
	@$(XCODEBUILD_BASE) test 2>&1 | grep -E '^[✔✘]|error:|\*\* TEST'

coverage: project
	@rm -rf $(BUILD_DIR)/coverage.xcresult
	@$(XCODEBUILD) test -enableCodeCoverage YES -resultBundlePath $(BUILD_DIR)/coverage.xcresult >/dev/null 2>&1
	@xcrun xccov view --report --files-for-target StandupCore.framework $(BUILD_DIR)/coverage.xcresult \
		| sed -E 's#/[^ ]*/StandupCore/##' | tail -n +2

run: build quit
	open "$(DEBUG_APP)"

install: project
	$(XCODEBUILD) -configuration Release build
	@$(MAKE) --no-print-directory quit
	rm -rf "$(INSTALLED)"
	ditto "$(RELEASE_APP)" "$(INSTALLED)"
	@# Keep macOS's app registry pointing only at the installed copy (not the build products).
	@-$(LSREGISTER) -u "$(CURDIR)/$(RELEASE_APP)" "$(CURDIR)/$(DEBUG_APP)" 2>/dev/null
	@$(LSREGISTER) -f "$(INSTALLED)"
	open "$(INSTALLED)"
	@echo "Installed $(INSTALLED)"

uninstall: quit
	@if [ -x "$(INSTALLED)/Contents/MacOS/$(APP_NAME)" ]; then \
		"$(INSTALLED)/Contents/MacOS/$(APP_NAME)" --unregister-login-item; fi
	@-$(LSREGISTER) -u "$(INSTALLED)" 2>/dev/null
	@# So a later reinstall registers the login item again (LoginItemManager.attemptedKey).
	@-defaults delete $(BUNDLE_ID) loginItem.autoRegisterAttempted 2>/dev/null
	rm -rf "$(INSTALLED)"
ifeq ($(PURGE),1)
	-defaults delete $(BUNDLE_ID)
endif
	@echo "Uninstalled $(APP_NAME)"

# Quit any running copy (Debug or installed) and wait for it to exit.
quit:
	@pkill -x $(APP_NAME) 2>/dev/null || true
	@for i in $$(seq 1 25); do pgrep -x $(APP_NAME) >/dev/null || exit 0; sleep 0.2; done; \
		echo "$(APP_NAME) did not quit"; exit 1

clean:
	rm -rf $(BUILD_DIR) $(PROJECT)
