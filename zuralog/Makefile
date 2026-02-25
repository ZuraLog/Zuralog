# =============================================================================
# Zuralog Flutter — Makefile (delegation shim)
# =============================================================================
# All Flutter targets live in the root Makefile one level up.
# This shim lets you run `make run`, `make analyze`, etc. from inside the
# zuralog/ directory without having to cd to the project root first.
# =============================================================================

SHELL := /bin/bash

ROOT := $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))

.PHONY: run run-ios run-device analyze test build-apk build-appbundle

run:
	"$(MAKE)" -C "$(ROOT)/.." run

run-ios:
	"$(MAKE)" -C "$(ROOT)/.." run-ios

run-device:
	"$(MAKE)" -C "$(ROOT)/.." run-device

analyze:
	"$(MAKE)" -C "$(ROOT)/.." analyze

test:
	"$(MAKE)" -C "$(ROOT)/.." test

build-apk:
	"$(MAKE)" -C "$(ROOT)/.." build-apk

build-appbundle:
	"$(MAKE)" -C "$(ROOT)/.." build-appbundle
