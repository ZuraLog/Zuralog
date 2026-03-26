# Database Design

## Overview

Zuralog uses a PostgreSQL database hosted on Supabase. The database is the single source of truth for all user data, health metrics, AI-generated content, and application state.

The database follows a two-tier architecture for health data: a raw event store that captures every individual measurement, and a derived summary layer that pre-computes daily totals for fast reading. Every screen in the app reads from the summary layer, while the event store preserves the full history for reprocessing and detailed views.

## Health Data: The Two-Tier Model

### Tier 1 — Raw Events (health_events)

Every piece of health data that enters the system — from any source — lands here as an individual event. A Strava run, an Apple Health step count, a manually logged glass of water, a Fitbit sleep session: they all become rows in the same table.

Each event records what was measured, the numeric value, which app or device it came from, when it was recorded, and a flexible metadata field for source-specific details (like workout type or activity name).

This table is the source of truth. If every other table were deleted, the entire system could be rebuilt from the events alone.

Events are never physically deleted. When a user removes a log entry, it is soft-deleted (marked with a timestamp) so that daily totals can be recalculated correctly.

### Tier 2 — Daily Summaries (daily_summaries)

This table holds one row per user, per day, per metric type. It is a pre-computed cache derived entirely from the events table. Every screen in the app reads from this table for daily totals and historical charts.

The summaries are kept up to date by an aggregation service that runs automatically whenever new events arrive and on a recurring schedule as a safety net. The aggregation applies one of three rules depending on the metric: sum (for things like steps and calories), average (for things like heart rate), or latest (for things like weight).

### Smart Deduplication

When a user has multiple sources reporting the same metric (for example, both Fitbit and Apple Health reporting daily steps), the system uses source-priority rankings to decide which version counts. The ranking is per metric category — Strava is trusted most for exercise data, Oura for sleep, Withings for body measurements, and so on.

The deduplication logic also distinguishes between true duplicates (the same workout reported by two apps) and distinct activities (a morning gym session and an evening run on the same day). True duplicates are resolved by source priority. Distinct activities are both counted.

This dedup logic runs at aggregation time, not when data arrives. Events are always stored as-is. A flag on each event indicates whether it is the "primary" version or has been superseded by a higher-priority source. Screens filter by this flag so users never see duplicate data.

### Rich Detail Storage (event_details)

Some health data has rich payloads that do not belong in the events table — GPS tracks from runs, sleep stage breakdowns, heart rate time series, lap splits. These are stored in a separate detail table, linked back to the parent event. This keeps the main events table lean for aggregation queries while preserving the full detail for features that need it (like a map view of a run or a sleep stage chart).

## Non-Health Data

Beyond health metrics, the database stores:

- **Users and authentication** — managed by Supabase Auth, with user profiles and preferences stored in application tables
- **AI coaching** — conversation history, AI-generated memories about each user, and insight cards
- **Goals, streaks, and achievements** — user-defined targets and the system's tracking of progress against them
- **Journals** — personal reflections and guided entries
- **Integrations** — which apps and devices each user has connected, their OAuth tokens, and sync status
- **Subscriptions** — plan status and entitlements, synced from RevenueCat
- **Metric definitions** — the master list of all supported metric types with their units, valid ranges, and aggregation rules
- **Push notification state** — device tokens and notification preferences

## Row-Level Security

Every table that contains user data has row-level security enabled. This means the database itself enforces that a user can only read and write their own data, regardless of what the application code does. This is a defense-in-depth measure — even if the application has a bug, the database will not leak one user's data to another.

## Schema Management

Database schema changes are managed through versioned migration files. Migrations run automatically before every deployment, so the database schema is always in sync with the application code.
