# Infrastructure Design

## Overview

Zuralog runs on three managed platforms, each chosen for a specific role. The goal is to keep infrastructure simple, fully managed (no servers to maintain), and cost-effective at the current stage while being straightforward to scale as the user base grows.

## Platforms

### Supabase — Database and Authentication

Supabase provides two core services:

1. **PostgreSQL database** — the single data store for all application data. Supabase manages backups, connection pooling, and availability. Row-level security is enforced at the database level.
2. **Authentication** — handles user registration, login, password resets, and social sign-in (Google, Apple). The backend verifies Supabase-issued JWT tokens on every API request. The mobile app authenticates directly with Supabase, then uses the resulting token to talk to the backend.

### Railway — Backend Server and Background Workers

Railway hosts the Python backend and its supporting services:

1. **Web server** — the FastAPI application that serves all API requests from the mobile app and the marketing website. Runs database migrations automatically on every deployment.
2. **Celery worker** — processes background tasks like syncing data from external integrations, generating AI insights, computing health scores, and sending push notifications. Tasks are dispatched from the web server and executed asynchronously.
3. **Redis** — a managed Redis instance that serves as the message broker between the web server and the Celery worker. Also used for rate limiting and distributed locks.

All three run from the same codebase, deployed from the same Docker image with different start commands.

### Vercel — Marketing Website

The Next.js marketing site is deployed on Vercel. It is a static site with minimal server-side logic, used for the public-facing landing pages at zuralog.com.

## External Services

The application integrates with several third-party services:

| Service | Role |
|---------|------|
| **OpenRouter** | Routes AI requests to the appropriate language model for coaching and insight generation |
| **OpenAI** | Generates text embeddings for semantic search across health data and journal entries |
| **Pinecone** | Vector database that stores embeddings and enables similarity search |
| **Firebase (FCM)** | Delivers push notifications to iOS and Android devices |
| **RevenueCat** | Manages in-app subscriptions, billing, and entitlement checks |
| **Sentry** | Captures errors and crashes in both the backend and the mobile app |
| **PostHog** | Anonymous product analytics to understand how users interact with the app |

## Health Integration Partners

These are the external fitness and health platforms that Zuralog connects to for data syncing:

| Integration | Connection Method |
|-------------|------------------|
| **Apple Health** | Native HealthKit access on the device, data synced via the mobile app |
| **Google Health Connect** | Native Health Connect access on the device, data synced via the mobile app |
| **Strava** | OAuth + real-time webhooks |
| **Fitbit** | OAuth + real-time webhooks + periodic sync |
| **Oura** | OAuth + real-time webhooks |
| **Withings** | OAuth + real-time webhooks |
| **Polar** | OAuth + real-time webhooks |

Apple Health and Google Health Connect are device-level integrations — the mobile app reads data directly from the phone's health platform and sends it to the backend. All other integrations are cloud-to-cloud — the backend talks to their APIs directly.

## Environment Configuration

All secrets, API keys, and service URLs are stored as environment variables. Nothing sensitive is committed to the codebase. Each platform (Railway, Vercel, Supabase) has its own environment configuration. Local development uses a `.env` file that mirrors the production variables but points to local or staging services.
