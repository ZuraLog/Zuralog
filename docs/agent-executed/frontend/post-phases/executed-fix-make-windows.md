# Executed: Fix `make` on Windows

**Branch:** `fix/setup-make-path-instruction` (merged to `main`)
**Date:** 2026-02-24
**Preceded by:** `feat/social-oauth-signin` (native Google + Apple Sign-In)

---

## Summary

Resolved `bash: make: command not found` on Windows (Git Bash / AntiGravity) and
`make: *** No rule to make target 'run'. Stop.` when running `make run` from
inside the `zuralog/` subdirectory.

Three commits on this branch:

1. `docs: fix make PATH instruction for GnuWin32 on Windows` — corrected the
   incomplete instruction in SETUP.md that said "close and reopen Git Bash"
   (insufficient — the entire app process must restart).
2. `fix: reliable make on Windows via Scoop + SHELL directive` — installed
   `make` 4.4.1 via Scoop, added `SHELL := /bin/bash` to root Makefile,
   rewrote SETUP.md `make not found` section.
3. `fix: add zuralog/Makefile delegation shim` — created `zuralog/Makefile`
   so `make run` (and all other targets) work from inside the `zuralog/`
   subdirectory.

---

## Root Cause Analysis

Two distinct bugs, not one:

### Bug 1 — Stale process environment

`make.exe` was physically present at `C:\Program Files (x86)\GnuWin32\bin\make.exe`
and the system PATH registry entry was correctly set. But AntiGravity (and every
terminal tab within it) had been launched **before** the PATH was updated. Windows
PATH changes to the registry take effect for newly spawned processes only — all
existing processes retain the environment they inherited at startup.

Closing a terminal tab and opening a new one does **not** help; the new tab is a
child process of AntiGravity, which still holds the old environment. The entire
editor/IDE must be fully closed and reopened from the Start Menu.

### Bug 2 — GnuWin32 `make` 3.81 is ancient and unreliable

`winget install GnuWin32.Make` installs a 32-bit i386 binary from 2006. It has
known issues with multi-line backslash (`\`) continuation syntax in Makefile
recipes on Windows, and is not the version this project's Makefile was developed
against.

### Bug 3 — `make run` not found from `zuralog/`

The `run`, `analyze`, `test`, and build targets all live in the **root**
`Makefile`. The `zuralog/` subdirectory had no `Makefile`. Running `make run`
from inside `zuralog/` silently failed with `No rule to make target 'run'`
because make only looks in the current directory.

---

## What Was Actually Built

### `scoop install make` (environment fix)

Installed GNU Make 4.4.1 via Scoop. Scoop's shim directory
(`C:\Users\hyoar\scoop\shims`) was already present in the user PATH, so the
`make` shim is available in every new Git Bash terminal without any additional
PATH editing. No manual registry changes required.

### `Makefile` — `SHELL := /bin/bash`

Added to the root `Makefile` immediately after the header comment block:

```makefile
# Force Git Bash on Windows — prevents make from falling back to cmd.exe
SHELL := /bin/bash
```

Without this, GNU Make on Windows may fall back to `cmd.exe` as the shell,
which would break the `grep | cut` pipeline used to read `GOOGLE_WEB_CLIENT_ID`
from `cloud-brain/.env`.

### `zuralog/Makefile` — delegation shim

Created a new `Makefile` inside `zuralog/` that delegates every target to the
root Makefile via `$(MAKE) -C`:

```makefile
ROOT := $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))

run:
	$(MAKE) -C $(ROOT)/.. run
```

All seven targets are delegated: `run`, `run-ios`, `run-device`, `analyze`,
`test`, `build-apk`, `build-appbundle`. The root Makefile handles secret
injection (`GOOGLE_WEB_CLIENT_ID` from `cloud-brain/.env`) — no logic is
duplicated in the shim.

This makes the project consistent: `cloud-brain/Makefile` has always worked
from within `cloud-brain/`; now `zuralog/Makefile` works from within `zuralog/`.

### `SETUP.md` — rewritten `make not found` section

- Prerequisites table: updated to `make 4.4+`, references `scoop install make`
- `make not found` section completely rewritten:
  - **Scoop** is the primary recommended method (one command, no PATH fuss)
  - **GnuWin32** documented as alternative with all three required steps
    explicitly spelled out (install → add PATH → restart entire app)
  - Explains *why* PATH changes require a full IDE restart, not just a new tab
  - Notes GnuWin32 3.81 caveat and recommends Scoop if issues persist

---

## Deviations from Original Plan

1. **Task 1 (verify terminal restart) was absorbed into investigation** — rather
   than asking the user to manually restart AntiGravity to test the GnuWin32
   theory, Scoop was installed directly (Task 2) since Scoop shims were already
   confirmed in PATH. This resolved the issue without requiring any user action
   beyond opening a new terminal.

2. **`docs/plans/` entry created** — the plan was written to
   `docs/plans/2026-02-23-fix-make-windows.md` per the writing-plans skill, then
   the user moved it to `.Claude/2026-02-23-fix-make-windows.md`. The
   `docs/plans/` copy was left in place (it is tracked but harmless).

---

## Verification

```
make --version          → GNU Make 4.4.1  ✅
make --just-print run   → delegates correctly to root Makefile  ✅
  (from zuralog/)         reads GOOGLE_WEB_CLIENT_ID from cloud-brain/.env  ✅
```

---

## Next Steps

- `make run` will launch `flutter run` with `GOOGLE_WEB_CLIENT_ID` injected.
  Ensure an Android emulator is running before invoking it.
- `make dev` (from `cloud-brain/`) starts the FastAPI backend — run this first.
- No further `make`-related setup is required on this machine.
