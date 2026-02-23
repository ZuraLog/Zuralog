# Asset Strategy: Shared Brand Assets in a Multi-Platform Monorepo

## Overview

This monorepo hosts three distinct consumers of brand assets:

| Consumer | Location | Type |
|---|---|---|
| Mobile App (Flutter) | `zuralog/` | Flutter/Dart project |
| Website (Next.js) | `web/` | Node.js/React project |
| Backend (FastAPI) | `cloud-brain/` | Python project |

Each platform has different rules about how it can reference files. This document explains the chosen strategy, why it was selected, and how agents and developers should manage brand assets going forward.

---

## Chosen Strategy: Root-Level Source of Truth with Intentional Flutter Copy

### Source of Truth

All brand assets live in:

```
assets/
└── brand/
    ├── logo/       # SVG, PNG variants of the Zuralog logo
    ├── icons/      # Brand-specific icons (not UI icons)
    └── fonts/      # Custom brand typefaces
```

This folder is the **single source of truth** for all brand assets. No asset should be created or modified in any platform-specific folder directly — always update here first.

---

### Why a Dedicated Root Folder?

- **Next.js** (`web/`) and **FastAPI** (`cloud-brain/`) can reference files anywhere in the repo via relative paths or build-time copies. Placing assets at the root gives them a neutral, platform-agnostic home.
- **Clarity for agents and contributors**: A single location removes ambiguity about where the "real" version of a logo or font lives.
- **Avoids coupling**: The mobile app's asset folder (`zuralog/assets/`) is not forced to serve as a shared resource it was not designed for.

---

### The Flutter Exception (Why There Is a Copy)

Flutter's build toolchain **requires** all assets to:
1. Live inside the Flutter project directory (`zuralog/`)
2. Be explicitly declared in `zuralog/pubspec.yaml`

There is no mechanism to reference files outside the Flutter project at build or runtime. This is a hard constraint of the Dart/Flutter toolchain, not a design choice.

**As a result**, any brand asset that Flutter needs must be copied into:

```
zuralog/
└── assets/
    ├── fonts/
    ├── icons/
    └── images/
```

This duplication is **intentional and managed** — not accidental. The copy in `zuralog/assets/` is a derivative of the source in `assets/brand/`.

---

## Rules for Agents and Developers

### Adding or Updating a Brand Asset

1. **Add/modify the file in `assets/brand/`** — this is always the first step.
2. **If Flutter needs it**, copy the file into the appropriate subfolder under `zuralog/assets/` and declare it in `zuralog/pubspec.yaml` if it is not already listed.
3. **If Next.js needs it**, copy or reference it from `assets/brand/` into `web/public/` as part of the build configuration or a sync script.
4. **Never modify only the platform copy** — always update the root source first.

### Sync Script

A sync script should be maintained at:

```
scripts/sync-assets.sh
```

This script copies files from `assets/brand/` into each platform's expected location. Run it after any change to `assets/brand/`. If this script does not yet exist, create it when adding the first real asset.

---

## Directory Reference Summary

| Path | Purpose | Editable Directly? |
|---|---|---|
| `assets/brand/` | Source of truth for all brand assets | Yes — always edit here first |
| `assets/brand/logo/` | Logo variants (SVG, PNG, dark/light) | Yes |
| `assets/brand/icons/` | Brand icons | Yes |
| `assets/brand/fonts/` | Custom typefaces | Yes |
| `zuralog/assets/` | Flutter-consumed copy of brand assets | Only via sync from root |
| `web/public/` | Next.js static asset serving directory | Only via sync from root |

---

## Why Not Other Options?

| Option | Rejected Because |
|---|---|
| Flutter's `zuralog/assets/` as source of truth | Couples brand ownership to the mobile app; semantically wrong |
| Symlinks from `zuralog/assets/` to root | Flutter's build system does not follow symlinks reliably across platforms |
| No shared folder; each platform owns its own | No single source of truth; drift and inconsistency over time |
| Root `assets/brand/` with sync (chosen) | Minimal intentional duplication; explicit ownership; scalable |
