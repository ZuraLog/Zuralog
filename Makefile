# =============================================================================
# Zuralog — Root Makefile
# =============================================================================
# Flutter Edge Agent development commands.
#
# NOTE (Windows): `make` requires GNU Make. Install via Scoop (recommended):
#   scoop install make
# Or see the "make not found" section in SETUP.md for alternatives.
#
# All flutter targets read GOOGLE_WEB_CLIENT_ID and POSTHOG_API_KEY from cloud-brain/.env
# automatically so you never have to pass them manually.
# =============================================================================

# Force Git Bash on Windows — prevents make from falling back to cmd.exe
SHELL := /bin/bash

# ---------------------------------------------------------------------------
# Load secrets from cloud-brain/.env (gitignored — never committed)
# Extracts variables without requiring `export` in the .env file.
# ---------------------------------------------------------------------------
GOOGLE_WEB_CLIENT_ID := $(shell grep -m1 '^GOOGLE_WEB_CLIENT_ID=' cloud-brain/.env | cut -d '=' -f2-)
SENTRY_DSN           := $(shell grep -m1 '^SENTRY_DSN=' cloud-brain/.env | cut -d '=' -f2-)
POSTHOG_API_KEY      := $(shell grep -m1 '^POSTHOG_API_KEY=' cloud-brain/.env | cut -d '=' -f2-)

.PHONY: run run-ios run-device analyze test build-apk build-appbundle build-prod build-prod-ios

## Run on Android emulator (default)
## Equivalent: flutter run --dart-define=GOOGLE_WEB_CLIENT_ID=... --dart-define=SENTRY_DSN=...
run:
	cd zuralog && flutter run \
		--dart-define=GOOGLE_WEB_CLIENT_ID=$(GOOGLE_WEB_CLIENT_ID) \
		--dart-define=SENTRY_DSN=$(SENTRY_DSN) \
		--dart-define=POSTHOG_API_KEY=$(POSTHOG_API_KEY) \
		--dart-define=APP_ENV=development

## Run on iOS Simulator
## Equivalent: flutter run --dart-define=BASE_URL=http://localhost:8001 ...
run-ios:
	cd zuralog && flutter run \
		--dart-define=BASE_URL=http://localhost:8001 \
		--dart-define=GOOGLE_WEB_CLIENT_ID=$(GOOGLE_WEB_CLIENT_ID) \
		--dart-define=SENTRY_DSN=$(SENTRY_DSN) \
		--dart-define=POSTHOG_API_KEY=$(POSTHOG_API_KEY) \
		--dart-define=APP_ENV=development

## Run on a physical device (update BASE_URL to your machine's LAN IP)
## Equivalent: flutter run --dart-define=BASE_URL=http://192.168.x.x:8001 ...
run-device:
	cd zuralog && flutter run \
		--dart-define=BASE_URL=http://192.168.1.100:8001 \
		--dart-define=GOOGLE_WEB_CLIENT_ID=$(GOOGLE_WEB_CLIENT_ID) \
		--dart-define=SENTRY_DSN=$(SENTRY_DSN) \
		--dart-define=POSTHOG_API_KEY=$(POSTHOG_API_KEY) \
		--dart-define=APP_ENV=development

## Run static analysis (zero warnings policy)
## Equivalent: flutter analyze
analyze:
	cd zuralog && flutter analyze

## Run Flutter tests
## Equivalent: flutter test
test:
	cd zuralog && flutter test

## Build a debug APK
## Equivalent: flutter build apk --debug --dart-define=...
build-apk:
	cd zuralog && flutter build apk --debug \
		--dart-define=GOOGLE_WEB_CLIENT_ID=$(GOOGLE_WEB_CLIENT_ID) \
		--dart-define=SENTRY_DSN=$(SENTRY_DSN) \
		--dart-define=POSTHOG_API_KEY=$(POSTHOG_API_KEY) \
		--dart-define=APP_ENV=development

## Build a release App Bundle for Play Store submission
## Equivalent: flutter build appbundle --release --dart-define=...
build-appbundle:
	cd zuralog && flutter build appbundle --release \
		--dart-define=GOOGLE_WEB_CLIENT_ID=$(GOOGLE_WEB_CLIENT_ID) \
		--dart-define=SENTRY_DSN=$(SENTRY_DSN) \
		--dart-define=POSTHOG_API_KEY=$(POSTHOG_API_KEY) \
		--dart-define=APP_ENV=production

## Production Android build — points to Railway backend (api.zuralog.com)
## Reads GOOGLE_WEB_CLIENT_ID and SENTRY_DSN from cloud-brain/.env
build-prod:
	cd zuralog && flutter build appbundle \
		--dart-define=BASE_URL=https://api.zuralog.com \
		--dart-define=GOOGLE_WEB_CLIENT_ID=$(GOOGLE_WEB_CLIENT_ID) \
		--dart-define=SENTRY_DSN=$(SENTRY_DSN) \
		--dart-define=POSTHOG_API_KEY=$(POSTHOG_API_KEY) \
		--dart-define=APP_ENV=production

## Production iOS build — points to Railway backend (api.zuralog.com)
## Reads GOOGLE_WEB_CLIENT_ID and SENTRY_DSN from cloud-brain/.env
build-prod-ios:
	cd zuralog && flutter build ipa \
		--dart-define=BASE_URL=https://api.zuralog.com \
		--dart-define=GOOGLE_WEB_CLIENT_ID=$(GOOGLE_WEB_CLIENT_ID) \
		--dart-define=SENTRY_DSN=$(SENTRY_DSN) \
		--dart-define=POSTHOG_API_KEY=$(POSTHOG_API_KEY) \
		--dart-define=APP_ENV=production
