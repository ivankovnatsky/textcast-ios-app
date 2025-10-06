.PHONY: build install launch run relaunch help clean watch

# Configuration
SCHEME = Textcast
DEVICE_NAME = iPhone 17 Pro Max
DESTINATION = 'platform=iOS Simulator,name=$(DEVICE_NAME)'
BUNDLE_ID = com.cabotagealts.textcast

# Dynamically find simulator ID
SIMULATOR_ID = $(shell xcrun simctl list devices | grep "$(DEVICE_NAME)" | grep -v "unavailable" | head -1 | grep -o '[A-F0-9\-]\{36\}')
# Use xcodebuild to get the actual build path
APP_PATH = $(shell xcodebuild -project Textcast.xcodeproj -scheme $(SCHEME) -destination $(DESTINATION) -showBuildSettings 2>/dev/null | grep "^\s*BUILT_PRODUCTS_DIR" | sed 's/.*= //')/$(SCHEME).app

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
	@open -a Simulator
	@echo "✓ App is running"

relaunch: build install ## Rebuild, install, and relaunch the app
	@xcrun simctl terminate $(SIMULATOR_ID) $(BUNDLE_ID) 2>/dev/null || true
	@xcrun simctl launch $(SIMULATOR_ID) $(BUNDLE_ID)
	@echo "✓ App relaunched"

clean: ## Clean build artifacts
	@xcodebuild -project Textcast.xcodeproj -scheme $(SCHEME) clean
	@echo "✓ Build artifacts cleaned"

watch: ## Watch for file changes and auto-rebuild
	while true; do \
		watchman-make \
			--pattern \
				'Textcast/**/*.swift' \
			--target relaunch; \
		echo "watchman-make exited, restarting..."; \
		sleep 1; \
	done

# Default target
.DEFAULT_GOAL := help
