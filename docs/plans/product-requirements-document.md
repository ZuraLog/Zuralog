# Product Requirements Document (PRD): Life Logger

**Version:** 1.0
**Status:** Draft
**Date:** February 18, 2026
**Author:** AI Solutions Architect

---

## 1. Executive Summary

**Life Logger** is a "Super-App" AI Agent designed to solve the fragmentation of the health and fitness market. Currently, users are forced to act as manual data clerks, logging nutrition in one app, workouts in another, and sleep in a third, with no central intelligence to synthesize this data.

**Life Logger** acts as a unified "Action Layer" and "Analyst Layer." It allows users to capture data via low-friction inputs (Voice/Photo) and pushes that data into their existing ecosystem (Apple Health, Strava, Notion). Simultaneously, it reads from these sources to provide holistic correlations that single-vertical apps cannot offer.

## 2. Problem Statement

1. **Friction:** Logging data (especially food and finances) is tedious and leads to user churn.
2. **Fragmentation:** Data is siloed. Oura knows the user slept poorly, but Strava doesn't know *why* their run pace suffered.
3. **Passive Data:** Existing hubs (Apple Health/Google Health Connect) are passive data lakes. They store data but do not actively manage the user's life or provide cross-domain insights.

## 3. Target Audience

* **The Optimizer (Biohacker):** Wears Oura/Whoop, tracks macros, wants deep correlation analysis (e.g., "Does magnesium affecting my REM sleep?").
* **The Busy Professional:** Wants to track health but has zero patience for manual entry. Needs "fire and forget" logging.
* **The Quantitative lifestyler:** Tracks not just health, but time (Toggl) and money (YNAB) to optimize their entire existence.

## 4. Business Model

**Strategy:** B2C Subscription (SaaS).
**Justification:** The product relies on heavy LLM inference (Image recognition for food, complex synthesis for insights) and continuous API maintenance. A one-time purchase is not sustainable.

* **Free Tier (The "Viewer"):**
* Read-only access to Apple/Google Health.
* Basic chat interface.
* No "Write" automation (cannot log food/workouts).


* **Pro Tier ($19.99/mo - "The Chief of Staff"):**
* Unlimited Multi-modal logging (Food photos, Voice notes).
* Full "Write" automation to external apps (Strava, Notion, etc.).
* Advanced Correlation Engine ("Your spending at bars correlates with 20% lower sleep scores").



## 5. Technical Architecture: "The Hybrid Hub"

To bypass the limitations of cloud-only or device-only apps, Life Logger utilizes a **Hybrid Architecture**.

### 5.1 The Components

1. **The Cloud Brain (Central Intelligence):**
* **Role:** Runs the LLM Agent, processes voice/images, and hosts MCP (Model Context Protocol) clients for cloud-native APIs (Strava, Notion, YNAB).
* **Tech Stack:** Python/FastAPI, Vector Database (Pinecone) for long-term context.


2. **The Edge Agent (Mobile App):**
* **Role:** Acts as a **Local MCP Server**. It lives on the user's device to access protected OS-level data stores (HealthKit, Health Connect) that the cloud cannot touch.
* **Tech Stack:** Swift (iOS) / Kotlin (Android).



### 5.2 Data Flow (The "Action" Layer)

* **Scenario A: Cloud-to-Cloud (e.g., Strava, Notion)**
* *User:* "I'm running a 5k."
* *Path:* Cloud Brain  Strava API.


* **Scenario B: Cloud-to-Device (e.g., Weight, Nutrition)**
* *User:* "I ate a banana."
* *Path:* Cloud Brain parses "Banana (105 cal)"  Sends JSON Push Payload to Edge Agent  Edge Agent writes to Apple HealthKit.



## 6. Top 10 Priority Integrations (The "Must-Haves")

| Priority | App / Service | Integration Type | Difficulty | Strategy |
| --- | --- | --- | --- | --- |
| **1** | **Apple Health** | **Native Edge** | High | **The Backend.** Used as the master database for weight, nutrition, and sleep. We write *to* it; other apps read *from* it. |
| **2** | **Google Health Connect** | **Native Edge** | High | The Android equivalent of Priority #1. Mandatory for Android market. |
| **3** | **Strava** | **Cloud API** | Low | Full Read/Write. We can post activities and read detailed split data. |
| **4** | **Notion** | **Cloud API** | Low | The "Life OS" database. Used for journaling, task management, and monthly reviews. |
| **5** | **Oura Ring** | **Cloud API** | Med | **Read-Heavy.** We pull Sleep/Readiness scores to context-tag other activities. |
| **6** | **Whoop** | **Cloud API** | Med | **Read-Heavy.** Similar to Oura. Critical for the "Athlete" demographic. |
| **7** | **MyFitnessPal** | **Bypass** | **Extreme** | **Do Not Integrate.** Instead, Life Logger *replaces* the input mechanism. We write nutrition to Apple Health; MFP reads it from there. |
| **8** | **Cronometer** | **Cloud API** | Low | A developer-friendly alternative to MFP. If users want a dedicated food database, we sync with this. |
| **9** | **Todoist / TickTick** | **Cloud API** | Low | Productivity logging. "Hey Agent, remind me to buy milk"  Adds to Todoist Inbox. |
| **10** | **YNAB (You Need A Budget)** | **Cloud API** | Med | Financial logging. "I spent $50 on dinner"  Agent logs transaction. |

## 7. Functional Requirements

### 7.1 The "Magical Loop" (Automation)

* **Deep Linking:** The Edge Agent must maintain a library of URI schemes (e.g., `strava://record`, `myfitnesspal://food/search`) to launch specific screens in other apps when the AI cannot perform the action via API.
* **Background Listening:** The Edge Agent must utilize `HKObserverQuery` (iOS) and WorkManager (Android) to detect when *other* apps write data, triggering the AI to ask for subjective context (e.g., "I see you finished a workout in Nike Run Club. How was your energy capability?").

### 7.2 Data Synthesis (The Analyst)

* **Normalization:** All data must be converted to **Open mHealth** standards before ingestion. (e.g., converting "Joules" from Apple and "Calories" from Fitbit into a single standard).
* **Deduplication:** The system must implement a "Source of Truth" hierarchy. If Apple Watch and Oura both report sleep, Oura takes precedence.

## 8. Challenges & Limitations

### 8.1 Challenges (Hard, but Solvable)

* **Data Hallucinations:** The LLM might invent correlations (e.g., "Your run pace improved because you ate a bagel 3 weeks ago").
* *Mitigation:* Use deterministic statistical analysis (Pearson correlation) for insights, using the LLM only to *narrate* the findings, not calculate them.


* **Latency:** waiting for a mobile app to wake up in the background to write data can take 5-10 seconds.
* *Mitigation:* Optimistic UI updates in the chat window ("Queued for logging...") so the user feels instant responsiveness.



### 8.2 Limitations (Currently Impossible)

* **UI Automation in Walled Gardens:** We cannot force a "Start" button press in apps like Nike Run Club or Strong. We can only launch the app to the correct screen. The user *must* tap the final button.
* **Closed Ecosystem Write Access:** We cannot write a "Sleep Session" into the Oura app or Whoop app. Those databases are read-only to third parties. We can only read from them and write to Apple Health.

## 9. Roadmap

### Phase 1: The "Lazy Logger" (MVP)

* **Core:** Chat Interface (Text/Voice).
* **Integrations:** Apple Health (Read/Write), Strava (Read/Write), Notion (Read/Write).
* **Feature:** Photo-to-Macros logging (bypassing MyFitnessPal).

### Phase 2: The "Connected Self"

* **Integrations:** Oura, Whoop, Google Health Connect.
* **Feature:** "The Morning Briefing" – AI synthesizes sleep data + calendar + weather to recommend the day's optimal workout intensity.

### Phase 3: The "Life Operating System"

* **Integrations:** Finance (YNAB) and Productivity (Todoist).
* **Feature:** Real-time bi-directional triggers (e.g., "If Oura Recovery < 30%, automatically reschedule deep work blocks in Todoist to shallow work").