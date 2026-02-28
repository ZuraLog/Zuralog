# Planned Direct Integrations

**Status:** 🔜 Planned / 📋 Future  
**Source:** [`.opencode/plans/2026-02-28-direct-integrations-top10-research.md`](../../.opencode/plans/2026-02-28-direct-integrations-top10-research.md)

All planned integrations follow the same implementation pattern as Strava and Fitbit. See [README.md](./README.md) for the step-by-step pattern.

---

## Priority 1 (MVP) — Tier 1 APIs

### Oura Ring

**Status:** 🔜 Planned (shown as "Coming Soon" in mobile app was not yet labeled in UI)  
**Priority:** P1  
**API:** Oura API v2, OAuth 2.0 (Authorization Code + Implicit)  
**Developer Portal:** https://cloud.ouraring.com/oauth/applications

| Property | Value |
|----------|-------|
| Auth URL | `https://cloud.ouraring.com/oauth/authorize` |
| Token URL | `https://api.ouraring.com/oauth/token` |
| Rate Limit | ~5,000 requests / 5-minute window |
| Webhooks | No (V2 doesn't document webhooks) |
| Read/Write | Read-only |
| Users | ~1M+ active |
| Dev Limit | **10-user limit** by default. Must submit for review to serve more users (standard app review, not a partner agreement). |

**Data Types (8 scopes):**
- `daily` — Sleep summaries, activity summaries, readiness scores
- `heartrate` — Time-series heart rate (Gen 3+)
- `spo2` — Daily SpO2 average during sleep
- `workout` — Auto-detected + user-entered workouts
- `personal` — Gender, age, height, weight
- `tag` — User-entered tags
- `session` — Guided/unguided sessions (meditation, breathing)

**Why integrate:** Gold standard for sleep + recovery. Oura Ring is the most popular dedicated sleep wearable. Unique data not available elsewhere.

**Action:** Submit for app review early in development cycle so the 10-user limit is lifted before launch.

---

### WHOOP

**Status:** 🔜 Planned (shown as "Coming Soon" in mobile app)  
**Priority:** P1  
**API:** WHOOP Developer API v1, OAuth 2.0 (Authorization Code)  
**Developer Portal:** https://developer.whoop.com

| Property | Value |
|----------|-------|
| Auth URL | `https://api.prod.whoop.com/oauth/oauth2/auth` |
| Token URL | `https://api.prod.whoop.com/oauth/oauth2/token` |
| Rate Limit | 100 req/min, 10,000 req/day (increases available on request) |
| Webhooks | Yes (v2, real-time data notifications) |
| Read/Write | Read-only |
| Users | ~500K+ active members |
| App Approval | Required before public launch (standard review, not partner gate) |

**Data Types:**
- **Cycle** — Physiological cycle data (strain score, kilojoules, avg/max HR)
- **Recovery** — Recovery score, HRV, resting HR, SpO2
- **Sleep** — Performance, stages, respiratory rate
- **Workout** — Sport type, strain score
- **User** — Basic profile

**Why integrate:** Premium recovery/strain tracking. WHOOP users are engaged, data-driven athletes.

**Action:** Follow WHOOP's approval docs carefully. Provide a clear use case in the application.

---

### Withings

**Status:** 🔜 Planned  
**Priority:** P1  
**API:** Withings API, OAuth 2.0 (Authorization Code)  
**Developer Portal:** https://developer.withings.com

| Property | Value |
|----------|-------|
| Rate Limit | Documented in API tiers |
| Webhooks | Yes (real-time notifications) |
| Read/Write | Both (limited write for goals/targets) |
| Pricing | Free "Public API" tier |
| HIPAA/HDS | Compliant |

**Data Types:**
- **Scales:** Weight, fat mass, muscle mass, bone mass, water mass, visceral fat, BMR, heart rate, pulse wave velocity, vascular age, segmental body composition
- **Sleep:** Sleep score, efficiency, stages, HR, HRV, respiratory rate, snoring, apnea index
- **Blood Pressure:** Systolic/diastolic, heart rate, ECG
- **Activity:** Steps, distance, calories, VO2 max, SpO2, continuous HR
- **Temperature:** Body temp, skin temp

**Why integrate:** Best device ecosystem API. Single integration covers smart scales + sleep mats + BP monitors + thermometers. Used by Strava, Weight Watchers, Lifesum.

---

## Priority 2 — Tier 1 APIs

### Polar

**Status:** 📋 Future  
**Priority:** P2  
**API:** Polar AccessLink API, OAuth 2.0  
**Developer Portal:** https://admin.polaraccesslink.com

| Property | Value |
|----------|-------|
| Webhooks | Yes |
| Read/Write | Read-only |
| Users | 10M+ registered |

**Data Types:** Exercises (all sport types), HR zones, sleep, recovery (Nightly Recharge), physical info (weight, height, VO2 max)

**Why integrate:** Legacy brand in heart rate monitoring. Popular among runners, cyclists, and triathlon athletes.

---

### MapMyFitness / MapMyRun (Under Armour)

**Status:** 📋 Future  
**Priority:** P2  
**API:** Under Armour / MapMyFitness API, OAuth 2.0  
**Developer Portal:** https://developer.mapmyfitness.com

| Property | Value |
|----------|-------|
| Rate Limit | 25,000 requests/day |
| Webhooks | Yes |
| Read/Write | Both (create routes, log activities) |
| Users | 40M+ registered |

**Data Types:** 700+ activity types, routes with GPS, heart rate zones, device data, user stats

**Why integrate:** One of the largest fitness communities. Covers a massive variety of activity types.

---

## Priority 2 — Tier 2 APIs (Require Business Application)

### Garmin

**Status:** 📋 Future (shown as "Coming Soon" in mobile app)  
**Priority:** P2 — Apply when Zuralog has measurable user base  
**API:** Garmin Health API, OAuth 2.0  
**Developer Portal:** https://developer.garmin.com/gc-developer-program/overview/  
**Access Request:** https://www.garmin.com/en-US/forms/GarminConnectDeveloperAccess/

| Property | Value |
|----------|-------|
| Access Process | Submit business application → 2 business day review → integration call |
| Pricing | Free for approved developers |
| Users | 20M+ active |
| Blocker | Requires business justification. Apply with traction. |

**Data Types (if approved):**
- Health API: HR, sleep, steps, stress, Body Battery, all-day summaries
- Activity API: Full data for 30+ activity types
- Women's Health API: Menstrual cycle, pregnancy tracking
- Training API: Push structured workouts to devices

---

### Lose It!

**Status:** 📋 Future  
**Priority:** P2 — Apply alongside Garmin  
**API:** Lose It! API (Beta), OAuth 2.0  
**Developer Portal:** https://loseit.com/api

| Property | Value |
|----------|-------|
| Access | Partner application via SurveyMonkey form |
| Webhooks | Yes |
| Read/Write | Read-only |
| Users | 40M+ |
| Blocker | Requires business presence |

**Why integrate:** Fills the critical nutrition gap. Only Fitbit offers basic food logging in Tier 1. Lose It! provides detailed macro/micronutrient tracking.

---

## Priority 3 — Future

### Suunto

**Status:** 📋 Future  
**Priority:** P3 — Apply when outdoor sports demand emerges  
**API:** Suunto API, OAuth 2.0 + API Key  
**Access:** 1–2 week review process

**Data Types:** FIT file export, workout data, GPS routes, heart rate  
**Users:** 2–5M (outdoor/adventure athletes, divers)
