# =============================================================================
# Zuralog Flutter — Makefile (delegation shim)
# =============================================================================
# All Flutter targets live in the root Makefile one level up.
# This shim lets you run `make run`, `make analyze`, etc. from inside the
# zuralog/ directory without having to cd to the project root first.
# =============================================================================

SHELL := /bin/bash

ROOT := $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))

.PHONY: run run-mock run-prod run-ios run-ios-prod run-device run-device-prod \
        analyze test build-apk build-appbundle build-prod build-prod-ios

run:
	"$(MAKE)" -C "$(ROOT)/.." run

run-mock:
	"$(MAKE)" -C "$(ROOT)/.." run-mock

run-prod:
	"$(MAKE)" -C "$(ROOT)/.." run-prod

run-ios:
	"$(MAKE)" -C "$(ROOT)/.." run-ios

run-ios-prod:
	"$(MAKE)" -C "$(ROOT)/.." run-ios-prod

run-device:
	"$(MAKE)" -C "$(ROOT)/.." run-device

run-device-prod:
	"$(MAKE)" -C "$(ROOT)/.." run-device-prod

analyze:
	"$(MAKE)" -C "$(ROOT)/.." analyze

test:
	"$(MAKE)" -C "$(ROOT)/.." test

build-apk:
	"$(MAKE)" -C "$(ROOT)/.." build-apk

build-appbundle:
	"$(MAKE)" -C "$(ROOT)/.." build-appbundle

build-prod:
	"$(MAKE)" -C "$(ROOT)/.." build-prod

build-prod-ios:
	"$(MAKE)" -C "$(ROOT)/.." build-prod-ios
