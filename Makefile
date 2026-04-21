# =============================================================================
# Zuralog — Root Makefile
# =============================================================================
# Flutter Edge Agent development commands.
#
# NOTE (Windows): `make` requires GNU Make. Install via Scoop (recommended):
#   scoop install make
# Or see the "make not found" section in SETUP.md for alternatives.
#
# All flutter targets read credentials from cloud-brain/.env automatically
# so you never have to pass them manually.
#
# ---------------------------------------------------------------------------
# Development vs Production
# ---------------------------------------------------------------------------
# | Target            | Flutter mode | Backend              | Mock data?  |
# |-------------------|--------------|----------------------|-------------|
# | run               | --debug      | local (10.0.2.2)     | NO          |
# | run-mock          | --debug      | none required        | YES (forced)|
# | run-prod          | --release    | api.zuralog.com      | NO          |
# | run-ios           | --debug      | local (localhost)    | NO          |
# | run-ios-prod      | --release    | api.zuralog.com      | NO          |
# | run-device        | --debug      | local (DEVICE_IP)    | NO          |
# | run-device-prod   | --release    | api.zuralog.com      | NO          |
# | reinstall         | --debug      | local (10.0.2.2)     | NO          |
# | reinstall-prod    | --release    | api.zuralog.com      | NO          |
#
# Mock data: only active when USE_MOCK_DATA=true (run-mock target).
# All other targets — debug or release — use real repositories.
#
# reinstall / reinstall-prod: uninstall the existing APK, run flutter clean,
# then build and install fresh. Use these whenever make run / make run-prod
# launches stale code after making source changes in release mode.
# ---------------------------------------------------------------------------

# Force Git Bash on Windows — prevents make from falling back to cmd.exe
SHELL := /bin/bash

# ---------------------------------------------------------------------------
# Load secrets from cloud-brain/.env (gitignored — never committed)
# Extracts variables without requiring `export` in the .env file.
# ---------------------------------------------------------------------------
GOOGLE_WEB_CLIENT_ID := $(shell grep -m1 '^GOOGLE_WEB_CLIENT_ID=' cloud-brain/.env 2>/dev/null | cut -d '=' -f2-)
SENTRY_DSN           := $(shell grep -m1 '^SENTRY_DSN=' cloud-brain/.env 2>/dev/null | cut -d '=' -f2-)
POSTHOG_API_KEY      := $(shell grep -m1 '^POSTHOG_API_KEY=' cloud-brain/.env 2>/dev/null | cut -d '=' -f2-)
# Physical device LAN IP — set DEVICE_IP=192.168.x.x in cloud-brain/.env
DEVICE_IP            := $(shell grep -m1 '^DEVICE_IP=' cloud-brain/.env 2>/dev/null | cut -d '=' -f2-)

# ---------------------------------------------------------------------------
# Android app package ID and ADB path
# ADB is auto-located from the standard Android SDK location on Windows.
# Override ADB by setting ADB=/path/to/adb in your shell if needed.
# ---------------------------------------------------------------------------
APP_ID := com.zuralog.zuralog
ADB    := $(shell ls "$$LOCALAPPDATA/Android/Sdk/platform-tools/adb.exe" 2>/dev/null \
           || ls "$$HOME/AppData/Local/Android/Sdk/platform-tools/adb.exe" 2>/dev/null \
           || which adb 2>/dev/null \
           || echo "adb")

.PHONY: run run-mock run-prod run-ios run-ios-prod run-device run-device-prod \
        uninstall reinstall reinstall-prod \
        analyze test build-apk build-appbundle build-prod build-apk-prod build-prod-ios

# ---------------------------------------------------------------------------
# Android Emulator — DEBUG (local backend, real API data)
# ---------------------------------------------------------------------------
## Default dev target. Connects to local backend at http://10.0.2.2:8001.
## Uses real API repositories. Run `make run-mock` instead for mock data (no backend needed).
run:
	cd zuralog && flutter run --debug \
		--dart-define=GOOGLE_WEB_CLIENT_ID=$(GOOGLE_WEB_CLIENT_ID) \
		--dart-define=SENTRY_DSN=$(SENTRY_DSN) \
		--dart-define=POSTHOG_API_KEY=$(POSTHOG_API_KEY) \
		--dart-define=APP_ENV=development

# ---------------------------------------------------------------------------
# Android Emulator — DEBUG, mock data only (no backend required)
# ---------------------------------------------------------------------------
## Runs in debug mode with mock data. No backend or Docker needed.
## Useful for UI work or when you don't have API credentials yet.
run-mock:
	cd zuralog && flutter run --debug \
		--dart-define=GOOGLE_WEB_CLIENT_ID=$(GOOGLE_WEB_CLIENT_ID) \
		--dart-define=SENTRY_DSN=$(SENTRY_DSN) \
		--dart-define=POSTHOG_API_KEY=$(POSTHOG_API_KEY) \
		--dart-define=APP_ENV=development \
		--dart-define=USE_MOCK_DATA=true

# ---------------------------------------------------------------------------
# Android Emulator — RELEASE (production backend, real data, no mocks)
# ---------------------------------------------------------------------------
## Release build against api.zuralog.com. kDebugMode=false → real repositories.
## Use this to verify production behaviour before submitting to the Play Store.
run-prod:
	cd zuralog && flutter run --release \
		--dart-define=BASE_URL=https://api.zuralog.com \
		--dart-define=GOOGLE_WEB_CLIENT_ID=$(GOOGLE_WEB_CLIENT_ID) \
		--dart-define=SENTRY_DSN=$(SENTRY_DSN) \
		--dart-define=POSTHOG_API_KEY=$(POSTHOG_API_KEY) \
		--dart-define=APP_ENV=production

# ---------------------------------------------------------------------------
# iOS Simulator — DEBUG (local backend, mock data active via kDebugMode)
# ---------------------------------------------------------------------------
## iOS equivalent of `make run`. Uses localhost (not 10.0.2.2) for the backend.
run-ios:
	cd zuralog && flutter run --debug \
		--dart-define=BASE_URL=http://localhost:8001 \
		--dart-define=GOOGLE_WEB_CLIENT_ID=$(GOOGLE_WEB_CLIENT_ID) \
		--dart-define=SENTRY_DSN=$(SENTRY_DSN) \
		--dart-define=POSTHOG_API_KEY=$(POSTHOG_API_KEY) \
		--dart-define=APP_ENV=development

# ---------------------------------------------------------------------------
# iOS Simulator — RELEASE (production backend, real data, no mocks)
# ---------------------------------------------------------------------------
run-ios-prod:
	cd zuralog && flutter run --release \
		--dart-define=BASE_URL=https://api.zuralog.com \
		--dart-define=GOOGLE_WEB_CLIENT_ID=$(GOOGLE_WEB_CLIENT_ID) \
		--dart-define=SENTRY_DSN=$(SENTRY_DSN) \
		--dart-define=POSTHOG_API_KEY=$(POSTHOG_API_KEY) \
		--dart-define=APP_ENV=production

# ---------------------------------------------------------------------------
# Physical Device — DEBUG (local backend at DEVICE_IP, mock data active)
# ---------------------------------------------------------------------------
## Set DEVICE_IP=192.168.x.x in cloud-brain/.env — your machine's LAN address.
## Run `make run-device` from the project root with the device connected via USB.
run-device:
	@if [ -z "$(DEVICE_IP)" ]; then \
		echo "Error: DEVICE_IP is not set. Add DEVICE_IP=192.168.x.x to cloud-brain/.env"; \
		exit 1; \
	fi
	cd zuralog && flutter run --debug \
		--dart-define=BASE_URL=http://$(DEVICE_IP):8001 \
		--dart-define=GOOGLE_WEB_CLIENT_ID=$(GOOGLE_WEB_CLIENT_ID) \
		--dart-define=SENTRY_DSN=$(SENTRY_DSN) \
		--dart-define=POSTHOG_API_KEY=$(POSTHOG_API_KEY) \
		--dart-define=APP_ENV=development

# ---------------------------------------------------------------------------
# Physical Device — RELEASE (production backend, real data, no mocks)
# ---------------------------------------------------------------------------
run-device-prod:
	cd zuralog && flutter run --release \
		--dart-define=BASE_URL=https://api.zuralog.com \
		--dart-define=GOOGLE_WEB_CLIENT_ID=$(GOOGLE_WEB_CLIENT_ID) \
		--dart-define=SENTRY_DSN=$(SENTRY_DSN) \
		--dart-define=POSTHOG_API_KEY=$(POSTHOG_API_KEY) \
		--dart-define=APP_ENV=production

# ---------------------------------------------------------------------------
# Uninstall / clean reinstall helpers
# ---------------------------------------------------------------------------
## Uninstall the app from the connected Android emulator or device.
## Useful when you need a guaranteed clean state (e.g. after code changes
## that the incremental build won't pick up in release mode).
uninstall:
	@echo "Uninstalling $(APP_ID)..."
	@"$(ADB)" uninstall $(APP_ID) 2>&1 || echo "App not installed — nothing to uninstall."

## Uninstall, flutter clean, then run debug build on the Android emulator.
## Use this when make run produces stale behaviour after code changes.
reinstall: uninstall
	cd zuralog && flutter clean
	cd zuralog && flutter run --debug \
		--dart-define=GOOGLE_WEB_CLIENT_ID=$(GOOGLE_WEB_CLIENT_ID) \
		--dart-define=SENTRY_DSN=$(SENTRY_DSN) \
		--dart-define=POSTHOG_API_KEY=$(POSTHOG_API_KEY) \
		--dart-define=APP_ENV=development

## Uninstall, flutter clean, then run release build against production backend.
## Use this when make run-prod produces stale behaviour after code changes.
reinstall-prod: uninstall
	cd zuralog && flutter clean
	cd zuralog && flutter run --release \
		--dart-define=BASE_URL=https://api.zuralog.com \
		--dart-define=GOOGLE_WEB_CLIENT_ID=$(GOOGLE_WEB_CLIENT_ID) \
		--dart-define=SENTRY_DSN=$(SENTRY_DSN) \
		--dart-define=POSTHOG_API_KEY=$(POSTHOG_API_KEY) \
		--dart-define=APP_ENV=production

# ---------------------------------------------------------------------------
# Static analysis + tests
# ---------------------------------------------------------------------------
## Run static analysis (zero warnings policy)
analyze:
	cd zuralog && flutter analyze

## Run Flutter tests
test:
	cd zuralog && flutter test

# ---------------------------------------------------------------------------
# Build artifacts
# ---------------------------------------------------------------------------
## Build a debug APK (local credentials, dev env)
build-apk:
	cd zuralog && flutter build apk --debug \
		--dart-define=GOOGLE_WEB_CLIENT_ID=$(GOOGLE_WEB_CLIENT_ID) \
		--dart-define=SENTRY_DSN=$(SENTRY_DSN) \
		--dart-define=POSTHOG_API_KEY=$(POSTHOG_API_KEY) \
		--dart-define=APP_ENV=development

## Build a release App Bundle for Play Store submission (production backend)
## flutter clean runs first to prevent Windows file-lock errors in the lint cache.
build-appbundle:
	cd zuralog && flutter clean
	cd zuralog && flutter build appbundle --release \
		--dart-define=BASE_URL=https://api.zuralog.com \
		--dart-define=GOOGLE_WEB_CLIENT_ID=$(GOOGLE_WEB_CLIENT_ID) \
		--dart-define=SENTRY_DSN=$(SENTRY_DSN) \
		--dart-define=POSTHOG_API_KEY=$(POSTHOG_API_KEY) \
		--dart-define=APP_ENV=production

## Alias for build-appbundle (backwards compatibility)
build-prod: build-appbundle

## Build a release APK for sideloading directly onto a device (production backend).
## Output: zuralog/build/app/outputs/flutter-apk/app-release.apk
## Install via: adb install zuralog/build/app/outputs/flutter-apk/app-release.apk
## Or send the file to your phone and tap to install (enable "Install from unknown sources" first).
build-apk-prod:
	cd zuralog && flutter clean
	cd zuralog && flutter build apk --release \
		--dart-define=BASE_URL=https://api.zuralog.com \
		--dart-define=GOOGLE_WEB_CLIENT_ID=$(GOOGLE_WEB_CLIENT_ID) \
		--dart-define=SENTRY_DSN=$(SENTRY_DSN) \
		--dart-define=POSTHOG_API_KEY=$(POSTHOG_API_KEY) \
		--dart-define=APP_ENV=production

## Build a release IPA for App Store submission (production backend)
build-prod-ios:
	cd zuralog && flutter build ipa \
		--dart-define=BASE_URL=https://api.zuralog.com \
		--dart-define=GOOGLE_WEB_CLIENT_ID=$(GOOGLE_WEB_CLIENT_ID) \
		--dart-define=SENTRY_DSN=$(SENTRY_DSN) \
		--dart-define=POSTHOG_API_KEY=$(POSTHOG_API_KEY) \
		--dart-define=APP_ENV=production
