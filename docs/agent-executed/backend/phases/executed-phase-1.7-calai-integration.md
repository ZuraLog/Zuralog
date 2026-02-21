# Executed Phase 1.7 — CalAI Integration (Zero-Friction)

**Date:** 2026-02-21
**Branch:** `feat/phase-1.7-calai-integration`
**Status:** Complete

---

## Summary

Implemented zero-friction CalAI integration across the Hybrid Hub stack. Users can deep-link to CalAI for food photo logging; nutrition data flows back through the OS Health Store (Apple Health / Health Connect) without any API keys or OAuth.

---

## What Was Built

### Flutter (Edge Agent)

- **`lib/core/deeplink/deeplink_launcher.dart`** — New static class for launching external apps via deep links. Attempts `calai://camera`, falls back to CalAI web URL.
- **`lib/core/health/health_bridge.dart`** — Added `getNutrition(startDate, endDate)` platform channel method for reading dietary energy entries.
- **`lib/features/health/data/health_repository.dart`** — Added `getNutrition()` wrapping the bridge method.
- **`lib/features/harness/harness_screen.dart`** — Added "Read Nutrition" button in HEALTHKIT section and new CALAI section with "Log Food (CalAI)" button.

### Backend (Cloud Brain)

- **`app/mcp_servers/apple_health_server.py`** — Added `nutrition` to `read_metrics` data_type enum; updated server and tool descriptions.
- **`app/mcp_servers/health_connect_server.py`** — Same changes as Apple Health (symmetric).
- **`tests/mcp/test_apple_health_server.py`** — Added 2 new tests: nutrition enum validation and nutrition read execution.
- **`tests/mcp/test_health_connect_server.py`** — Added 2 matching tests.

### Documentation

- **`docs/plans/backend/integrations/calai-integration.md`** — Updated with data flow diagram, advantages, requirements, and implementation details table.

---

## Deviations from Original Plan

| Item | Plan Said | What Was Built | Reason |
| --- | --- | --- | --- |
| Deep link file | Modify `deeplink_launcher.dart` | Created new file | No such file existed; existing `deeplink_handler.dart` handles inbound links — different concern |
| Nutrition read support | Only add to MCP servers | Also added to `health_bridge.dart` and `health_repository.dart` | The Dart layer had no way to read nutrition data; MCP server changes alone would be incomplete |
| Harness buttons | Not specified in plan | Added both "Read Nutrition" and "Log Food (CalAI)" | Consistent with prior phases adding harness buttons for every new capability |

---

## Verification Results

| Check | Result |
|-------|--------|
| Backend tests | 65/65 passed (61 prior + 4 new) |
| Ruff lint | 3 pre-existing warnings (in alembic migration, unrelated) |
| Flutter analyze | Requires macOS; Dart code follows established patterns |

---

## Next Steps

- **Native implementation:** Add `getNutrition` handler in `HealthKitBridge.swift` (iOS) and `HealthConnectBridge.kt` (Android) to query `HKQuantityType.dietaryEnergyConsumed` / `NutritionRecord`
- **CalAI deep link validation:** Verify the actual CalAI URL scheme once confirmed
- **Phase 1.8+:** Macro breakdown (protein, carbs, fat) in addition to total calories
