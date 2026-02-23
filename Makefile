# =============================================================================
# Zuralog — Root Makefile
# =============================================================================
# Flutter Edge Agent development commands.
#
# NOTE (Windows): `make` requires GNU Make. Install via:
#   - Git Bash (included with Git for Windows) — recommended
#   - https://gnuwin32.sourceforge.net/packages/make.htm
#
# All flutter targets read GOOGLE_WEB_CLIENT_ID from cloud-brain/.env
# automatically so you never have to pass it manually.
# =============================================================================

# ---------------------------------------------------------------------------
# Load secrets from cloud-brain/.env (gitignored — never committed)
# Extracts GOOGLE_WEB_CLIENT_ID without requiring `export` in the .env file.
# ---------------------------------------------------------------------------
GOOGLE_WEB_CLIENT_ID := $(shell grep -m1 '^GOOGLE_WEB_CLIENT_ID=' cloud-brain/.env | cut -d '=' -f2-)

.PHONY: run run-ios run-device analyze test build-apk build-appbundle

## Run on Android emulator (default)
## Equivalent: flutter run --dart-define=GOOGLE_WEB_CLIENT_ID=...
run:
	cd zuralog && flutter run \
		--dart-define=GOOGLE_WEB_CLIENT_ID=$(GOOGLE_WEB_CLIENT_ID)

## Run on iOS Simulator
## Equivalent: flutter run --dart-define=BASE_URL=http://localhost:8001 --dart-define=GOOGLE_WEB_CLIENT_ID=...
run-ios:
	cd zuralog && flutter run \
		--dart-define=BASE_URL=http://localhost:8001 \
		--dart-define=GOOGLE_WEB_CLIENT_ID=$(GOOGLE_WEB_CLIENT_ID)

## Run on a physical device (update BASE_URL to your machine's LAN IP)
## Equivalent: flutter run --dart-define=BASE_URL=http://192.168.x.x:8001 --dart-define=GOOGLE_WEB_CLIENT_ID=...
run-device:
	cd zuralog && flutter run \
		--dart-define=BASE_URL=http://192.168.1.100:8001 \
		--dart-define=GOOGLE_WEB_CLIENT_ID=$(GOOGLE_WEB_CLIENT_ID)

## Run static analysis (zero warnings policy)
## Equivalent: flutter analyze
analyze:
	cd zuralog && flutter analyze

## Run Flutter tests
## Equivalent: flutter test
test:
	cd zuralog && flutter test

## Build a debug APK
## Equivalent: flutter build apk --debug --dart-define=GOOGLE_WEB_CLIENT_ID=...
build-apk:
	cd zuralog && flutter build apk --debug \
		--dart-define=GOOGLE_WEB_CLIENT_ID=$(GOOGLE_WEB_CLIENT_ID)

## Build a release App Bundle for Play Store submission
## Equivalent: flutter build appbundle --release --dart-define=GOOGLE_WEB_CLIENT_ID=...
build-appbundle:
	cd zuralog && flutter build appbundle --release \
		--dart-define=GOOGLE_WEB_CLIENT_ID=$(GOOGLE_WEB_CLIENT_ID)
