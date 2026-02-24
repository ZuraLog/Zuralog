# =============================================================================
# Zuralog Flutter — Makefile
# =============================================================================
# Flutter targets for running inside the zuralog/ directory.
# Secrets are loaded from ../cloud-brain/.env automatically.
# =============================================================================

SHELL := /bin/bash

# Load GOOGLE_WEB_CLIENT_ID from the cloud-brain .env one level up
GOOGLE_WEB_CLIENT_ID := $(shell grep -m1 '^GOOGLE_WEB_CLIENT_ID=' ../cloud-brain/.env | cut -d '=' -f2-)

.PHONY: run run-ios run-device analyze test build-apk build-appbundle

## Run on Android emulator (default)
run:
	flutter run \
		--dart-define=GOOGLE_WEB_CLIENT_ID=$(GOOGLE_WEB_CLIENT_ID)

## Run on iOS Simulator
run-ios:
	flutter run \
		--dart-define=BASE_URL=http://localhost:8001 \
		--dart-define=GOOGLE_WEB_CLIENT_ID=$(GOOGLE_WEB_CLIENT_ID)

## Run on a physical device (update BASE_URL to your machine's LAN IP)
run-device:
	flutter run \
		--dart-define=BASE_URL=http://192.168.1.100:8001 \
		--dart-define=GOOGLE_WEB_CLIENT_ID=$(GOOGLE_WEB_CLIENT_ID)

## Run static analysis (zero warnings policy)
analyze:
	flutter analyze

## Run Flutter tests
test:
	flutter test

## Build a debug APK
build-apk:
	flutter build apk --debug \
		--dart-define=GOOGLE_WEB_CLIENT_ID=$(GOOGLE_WEB_CLIENT_ID)

## Build a release App Bundle for Play Store submission
build-appbundle:
	flutter build appbundle --release \
		--dart-define=GOOGLE_WEB_CLIENT_ID=$(GOOGLE_WEB_CLIENT_ID)
