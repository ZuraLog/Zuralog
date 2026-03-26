# Repository Design

## Overview

Zuralog is a monorepo — all parts of the product live in one repository. This keeps everything in sync and makes it easy to coordinate changes that touch multiple parts of the system.

## Top-Level Structure

### `zuralog/`

The mobile application. Built with Flutter, targeting both iOS and Android from a single codebase. This is what users download from the App Store and Google Play.

Contains: all screens, widgets, state management, native health platform bridges (Apple HealthKit and Google Health Connect), networking layer, and local storage.

### `cloud-brain/`

The backend server. Built with Python and FastAPI, deployed to Railway. This is the Cloud Brain — the intelligence center of the system.

Contains: all API endpoints, database models and migrations, integration sync logic, AI orchestration (coaching, insights, trends), background task definitions, and the data processing pipeline.

### `website/`

The marketing website. Built with Next.js, deployed to Vercel. This is the public-facing site at zuralog.com.

Contains: landing pages, feature descriptions, pricing, legal pages (privacy policy, terms of service), and any public-facing content.

### `docs/`

All project documentation. This is where the files you are reading right now live.

Contains: product overview, tab documentation, database design, architecture, infrastructure, server design, and design specs for features being planned or built.

### `assets/`

Shared brand assets used across the project — logos, icons, and images that are referenced by the mobile app, website, or documentation.

### `.agent/`

Configuration and skills for AI development agents that assist with building the project. Not part of the product — this is tooling for the development process itself.

## How the Pieces Connect

The mobile app (`zuralog/`) talks to the backend (`cloud-brain/`) over a REST API. The backend talks to the database (Supabase Postgres), to external integration APIs (Strava, Fitbit, etc.), and to AI services (OpenRouter, OpenAI, Pinecone). The marketing website (`website/`) is standalone and does not communicate with the backend at runtime.

All three deployable components — the mobile app, the backend, and the website — are versioned together in this repository but deployed independently to their respective platforms.
