# Server Design

## Overview

The Zuralog backend — called **Cloud Brain** — is a Python server built with FastAPI. It runs on Railway and handles everything that happens behind the scenes: serving API requests, syncing data from external services, running AI pipelines, and processing background tasks.

## How It Runs

The server runs as three processes from the same codebase:

1. **The web process** — a FastAPI application that handles all HTTP requests from the mobile app. This is the front door. Every API call (fetching today's summary, sending a message to the coach, logging a workout) comes through here.

2. **The worker process** — a Celery worker that handles background tasks. Anything that does not need to happen while the user waits — syncing Strava data, generating AI insights, sending push notifications, recomputing daily summaries — runs here. Tasks are placed in a queue by the web process and picked up by the worker asynchronously.

3. **The scheduler** — Celery Beat, a timer that kicks off recurring tasks on a schedule. For example: fan out daily insight generation every hour (checking which users are at 6 AM in their local timezone), run periodic integration syncs, recompute stale data summaries.

All three processes connect to the same PostgreSQL database and the same Redis instance. Redis serves as the message queue between the web process and the workers.

## API Design

The API follows REST conventions and is versioned under `/api/v1/`. All endpoints require authentication (a valid JWT token from Supabase) except for webhook receivers and public health checks.

The API is organized by domain:

- **Ingest** — receives health data from the mobile app and from integration adapters
- **Today** — serves the daily dashboard summary and timeline
- **Analytics** — serves charts, metric history, and health scores for the Data tab
- **Coach** — handles AI chat conversations
- **Insights** — serves pre-generated AI insight cards
- **Trends** — serves correlation data and pattern details
- **Progress** — serves goals, streaks, and achievements
- **Integrations** — manages OAuth connections and sync status
- **Settings** — user preferences and profile management
- **Webhooks** — receives real-time pushes from Strava, Fitbit, Oura, Withings, Polar, and RevenueCat

Every endpoint has rate limiting to prevent abuse. Limits are tuned per-endpoint based on expected usage patterns.

## Background Task System

The Celery worker handles several categories of tasks:

- **Integration syncing** — fetching new data from connected apps when a webhook arrives or on a periodic schedule
- **Data aggregation** — recomputing daily summaries after new events arrive, with smart deduplication
- **AI insight generation** — running the full insight pipeline (data gathering → signal detection → prioritization → LLM card writing) once per day per user
- **Notification delivery** — sending morning briefings, smart reminders, and activity alerts via Firebase Cloud Messaging
- **Health score computation** — recalculating the composite health score when underlying metrics change
- **Backfill processing** — importing historical data when a user connects a new integration, throttled to avoid overwhelming the system

Tasks that can fail are retried automatically with exponential backoff. Critical tasks have dead-letter handling so failures are visible and can be investigated.

## Error Handling and Monitoring

The server reports all errors and unhandled exceptions to Sentry, with enough context to debug without needing to reproduce the issue. API responses follow consistent error formats so the mobile app can display helpful messages.

Every deployment runs database migrations automatically before the new version starts serving traffic. If a migration fails, the deployment is rolled back.

## Security

- All API endpoints require authentication except webhooks (which use signature verification) and public routes
- Rate limiting on every endpoint prevents abuse
- Row-level security at the database ensures users can only access their own data
- All external API keys and secrets are stored as environment variables, never in the codebase
- Webhook payloads from external services are verified using the provider's signature mechanism before being processed
- Input validation on every endpoint rejects malformed or out-of-range data
