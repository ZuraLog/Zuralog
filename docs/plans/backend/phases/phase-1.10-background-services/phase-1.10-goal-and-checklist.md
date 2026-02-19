# Phase 1.10: Background Services & Sync Engine

**Goal:** Implement background data sync and push-to-write flow to ensure data consistency without user intervention.

## Checklist
- [ ] **1.10.1** Cloud-to-Device Write Flow
- [ ] **1.10.2** Background Sync Scheduler
- [ ] **1.10.3** Edge Agent Background Handler
- [ ] **1.10.4** Data Normalization
- [ ] **1.10.5** Source-of-Truth Hierarchy
- [ ] **1.10.6** Sync Status Tracking
- [ ] **1.10.7** Harness: Background Sync Test

## Dependencies
- Phase 1.4, 1.5, 1.9

## Exit Criteria
- Cloud-to-device write flow implemented.
- Celery sync scheduler created.
- Edge Agent background handler processes FCM.
- Data normalizer for cross-source data.
- Source-of-truth deduplication.
- Sync status tracking in database.
- Harness can trigger sync.
