.PHONY: build install launch run relaunch help clean

# Configuration
SCHEME = Textcast
DEVICE_NAME = iPhone 17 Pro Max
DESTINATION = 'platform=iOS Simulator,name=$(DEVICE_NAME)'
BUNDLE_ID = com.cabotagealts.textcast

# Dynamically find simulator ID and app path
SIMULATOR_ID = $(shell xcrun simctl list devices | grep "$(DEVICE_NAME)" | grep -v "unavailable" | head -1 | grep -o '[A-F0-9\-]\{36\}')
APP_PATH = $(shell find $(HOME)/Library/Developer/Xcode/DerivedData -name "Textcast.app" -path "*/Debug-iphonesimulator/*" 2>/dev/null | head -1)

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Available targets:'
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

build: ## Build the app (shows last 10 lines)
	@xcodebuild -project Textcast.xcodeproj \
		-scheme $(SCHEME) \
		-destination $(DESTINATION) \
		-configuration Debug \
		build 2>&1 | tail -10

install: ## Install the app to simulator
	@xcrun simctl install $(SIMULATOR_ID) $(APP_PATH)

launch: ## Launch the app on simulator
	@xcrun simctl launch $(SIMULATOR_ID) $(BUNDLE_ID)

run: build install launch ## Build, install, and launch the app
	@echo "✓ App is running"

relaunch: build install ## Rebuild, install, and relaunch the app
	@xcrun simctl terminate $(SIMULATOR_ID) $(BUNDLE_ID) 2>/dev/null || true
	@xcrun simctl launch $(SIMULATOR_ID) $(BUNDLE_ID)
	@echo "✓ App relaunched"

clean: ## Clean build artifacts
	@xcodebuild -project Textcast.xcodeproj -scheme $(SCHEME) clean
	@echo "✓ Build artifacts cleaned"

# Default target
.DEFAULT_GOAL := help
