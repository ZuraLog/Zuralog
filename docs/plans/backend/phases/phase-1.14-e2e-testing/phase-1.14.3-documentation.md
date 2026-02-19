# Phase 1.14.3: Documentation Update

**Parent Goal:** Phase 1.14 End-to-End Testing & Exit Criteria
**Checklist:**
- [x] 1.14.1 Integration Tests
- [x] 1.14.2 E2E Flutter Test
- [x] 1.14.3 Documentation Update
- [ ] 1.14.4 Code Review
- [ ] 1.14.5 Performance Testing
- [ ] 1.14.6 Final Exit Criteria Checklist

---

## What
Review and update all technical documentation to reflect the *actual* implemented state of the MVP.

## Why
Docs often drift from code. Future developers (and AI agents) need accurate maps.

## How
Manual review + Auto-generation where possible (e.g., OpenAPI docs).

## Features
- **OpenAPI Schema:** Export `openapi.json` from FastAPI.
- **Environment Variables:** Ensure `.env.example` has all new keys (RevenueCat, Deep Links, etc).

## Files
- Update: `docs/plans/backend/backend-implementation.md`
- Create: `cloud-brain/openapi.json`

## Steps

1. **Export OpenAPI schema**
   - Run `python -m cloudbrain.scripts.export_openapi`
   - Save to `cloud-brain/openapi.json`

2. **Update Readme**
   - Add "How to run Integration Tests" section.
   - Add "Deep Link Testing" guide.

## Exit Criteria
- `openapi.json` exists.
- `README.md` is up to date.
