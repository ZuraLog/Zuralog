# Zuralog — Product Overview

## What Zuralog Is

Zuralog is an AI-powered health assistant that brings all of a person's health and fitness data into one place. It connects to the apps and wearables people already use — Apple Health, Google Health Connect, Strava, Fitbit, Oura, and more — and combines that data with anything the user logs manually. Then it uses artificial intelligence to help people actually understand their health, not just collect numbers.

## The Problem It Solves

Most people who track their health use multiple apps and devices. Their sleep is in one app, their workouts in another, their weight somewhere else, and their nutrition in yet another. No single app sees the full picture, so no single app can give them meaningful insight. People end up with a lot of data and very little understanding.

Zuralog solves this by being the hub. It does not replace those apps — it connects to them and pulls everything together. Once it has the full picture, it can do things no single-source app can: find connections between sleep and workout performance, spot trends across weeks and months, and give personalized coaching grounded in real data.

## Who It Is For

Zuralog is for anyone who tracks their health and wants to get more out of the data they are already collecting. This ranges from casual users who just want to understand their sleep and activity patterns, to serious athletes who want data-driven insights across multiple metrics. The app is designed to be approachable for beginners and deep enough for power users.

## The Core Experience

The app is organized around five tabs, each serving a distinct purpose:

- **Today** — a daily dashboard showing what is happening right now
- **Data** — a deep dive into all health metrics and their history
- **Coach** — an AI chat that knows your data and gives personalized advice
- **Progress** — goals, streaks, achievements, and personal journaling
- **Trends** — AI-discovered correlations between different health metrics

Each tab is documented separately in its own file.

## How Data Flows

Every piece of health data — whether it comes from a connected app, a wearable device, or a manual log — flows through one universal pipeline into a single database. The data is deduplicated (so the same workout from two apps is not counted twice), aggregated into daily totals, and made available to every part of the app. No data is siloed. Every tab sees the same complete picture.

## The AI Layer

Zuralog uses AI in three ways:

1. **The Coach** — a conversational assistant that can answer health questions using the user's actual data
2. **Daily Insights** — automatically generated observations about the user's health patterns, delivered as cards on the Today tab
3. **Trend Discovery** — statistical analysis that finds connections between metrics the user would never notice on their own

The AI is always grounded in the user's real data. It does not give generic advice — it gives personalized observations based on what the numbers actually show.

## Business Model

Zuralog uses a freemium model. The core experience is free. A paid subscription unlocks advanced features like deeper AI coaching, richer trend analysis, and longer data history. Subscriptions are managed through the app stores via RevenueCat.

## Privacy

Users own their data. They can see everything the AI has stored about them, delete any of it at any time, and export all their data. The app does not sell user data. Analytics are anonymous and opt-in.

## Scale

Zuralog is designed from day one to serve a large user base. Every architectural decision — database schema, API design, background job processing, caching — is made with scale in mind. The system is built to handle many users with many connected integrations without degrading performance.
