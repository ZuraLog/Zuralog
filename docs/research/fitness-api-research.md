# Fitness & Workout Tracking App API Research

> **Date**: 2026-02-28
> **Purpose**: Determine which popular fitness/workout platforms have public OAuth 2.0 REST APIs that ZuraLog can integrate with.
> **Researcher**: AI Agent (Claude)

---

## Summary Table

| Platform | API Status | Auth Method | Self-Service Registration | ZuraLog Integration? |
|---|---|---|---|---|
| **Polar (AccessLink)** | Public OAuth 2.0 | OAuth 2.0 | Yes - any developer | **YES** |
| **Suunto (Cloud API)** | Partner OAuth 2.0 | OAuth 2.0 + Subscription Key | Apply & review (1-2 weeks) | **LIKELY** (requires approval) |
| **Peloton** | No Public API | Username/Password (unofficial) | N/A | **NO** (unofficial only) |
| **Nike Run Club / NTC** | No Public API | N/A | N/A | **NO** |
| **MapMyFitness / MapMyRun** | Public OAuth 2.0 | OAuth 2.0 | Yes - request a key online | **YES** |
| **COROS** | No Public API | N/A | N/A | **NO** |
| **TrainingPeaks** | Partner-Only API | OAuth 2.0 | Apply & review | **MAYBE** (partner approval required) |

---

## 1. Polar (Polar Flow / AccessLink API)

### API Status: **PUBLIC OAuth 2.0** — Best-in-class developer experience

| Field | Details |
|---|---|
| **Auth Method** | OAuth 2.0 (Authorization Code flow) |
| **Developer Portal** | https://admin.polaraccesslink.com |
| **API Docs** | https://www.polar.com/accesslink-api/ |
| **API Base URL** | `https://www.polaraccesslink.com/v3/` |
| **Token Endpoint** | `https://polarremote.com/v2/oauth2/token` |
| **Auth Endpoint** | `https://flow.polar.com/oauth2/authorization` |
| **Current Version** | AccessLink API v3 (last updated Aug 2025) |
| **GitHub** | https://github.com/polarofficial |

### Registration Process
1. Create a Polar Flow account at https://flow.polar.com
2. Go to https://admin.polaraccesslink.com and log in
3. Fill in application info and create a client
4. Receive OAuth2 `client_id` and `client_secret` immediately
5. **No approval wait** — fully self-service

### Key Data Types Available
- **Exercises**: Full workout data (FIT/TCX/GPX export), HR zones, samples, routes, Training Load Pro
- **Daily Activity**: Steps, calories, active time, zone data (28-day window)
- **Continuous Heart Rate**: Ongoing HR data with timestamps
- **Cardio Load**: Training load / TRIMP data, historical load by day/month
- **Sleep + Sleep Plus Stages**: Sleep data, sleep stages
- **Nightly Recharge**: Recovery metrics
- **SleepWise**: Alertness periods, circadian bedtime
- **Elixir Biosensing**: Body temperature, skin temperature, ECG, SpO2
- **Physical Info**: Weight, height, user biometrics
- **Webhooks**: Real-time push notifications for exercises, sleep, HR, activity

### Rate Limits
Dynamic scaling based on registered users:
- **15-minute limit**: `500 + (users x 20)` requests
- **24-hour limit**: `5000 + (users x 100)` requests
- Headers: `RateLimit-Usage`, `RateLimit-Limit`, `RateLimit-Reset`
- Exceeding returns `429 Too Many Requests`

### Pricing
- **Free** for all developers. No paid tiers mentioned.

### Popularity
- ~10M+ Polar Flow users globally
- Strong in Europe, popular among serious athletes and runners
- Compatible with Polar Vantage, Grit X, Ignite, Pacer series, Verity Sense HR monitor

### Verdict: **STRONG YES for ZuraLog**
Polar AccessLink is the gold standard for fitness device APIs. Fully self-service OAuth 2.0, rich data (exercise + continuous HR + sleep + recovery + biosensing), webhook support, free, active development (updated Aug 2025). Immediate integration candidate.

---

## 2. Suunto (Suunto Cloud API)

### API Status: **Partner OAuth 2.0** — Application required, review within 1-2 weeks

| Field | Details |
|---|---|
| **Auth Method** | OAuth 2.0 + Azure API Management Subscription Key |
| **Developer Portal** | https://suunto-api.developer.azure-api.net/ (Azure APIM) |
| **Application Portal** | https://www.suunto.com/welcomepartners |
| **Auth Endpoint** | `https://cloudapi-oauth.suunto.com/oauth/authorize` |
| **Token Endpoint** | `https://cloudapi-oauth.suunto.com/oauth/token` |
| **API Base URL** | `https://cloudapi.suunto.com/v2/` |

### Registration Process
1. Learn about the partner program at https://www.suunto.com/welcomepartners
2. Submit application via web form (company/service info required)
3. Accept API agreement
4. **Applications reviewed weekly** — up to 2-week wait
5. Once approved: subscribe to Developer API, configure OAuth in profile
6. Production access requires additional submission review

### Key Data Types Available
- **Workouts**: FIT file export (industry-standard)
- FIT files contain: duration, avg HR, distance, GPS tracks, altitude, temperature, power, R-R data
- Webhook support for new workout notifications

### Rate Limits
- **Developer tier**: Lower limits (specific numbers behind portal)
- **Production tier**: "Unlimited" (after approval)
- Two subscription tiers: `Starter` (dev) and `Unlimited` (production)

### Pricing
- **Free** — "We do not charge from the use of the API"
- Marketing/promotion collaboration offered (Suunto promotes partners on suunto.com)

### Restrictions
- **Not for personal use** — "We currently don't offer the API access for personal use"
- Must be a company/organization providing tools/apps/services to a public audience
- Reviewed for brand fit, customer interest, and innovation

### Popularity
- ~2-3M Suunto app users
- Strong outdoor sports niche (hiking, trail running, diving)
- Popular in Nordic countries, growing globally

### Verdict: **LIKELY YES for ZuraLog** (with caveats)
Suunto uses proper OAuth 2.0 and provides FIT file access. However, it's a **partner program** requiring application + review (1-2 weeks). ZuraLog would need to apply as a company building a public-facing app — which it is. The "no personal use" policy means individual hobby projects won't get access, but a legitimate product like ZuraLog should qualify. The data is primarily FIT files, which are rich but require parsing.

---

## 3. Peloton

### API Status: **NO PUBLIC API** — Internal/unofficial only

| Field | Details |
|---|---|
| **Auth Method** | Username/password session (unofficial) |
| **Developer Portal** | None |
| **API Base URL** | `https://api.onepeloton.com` (undocumented) |

### What Exists
- Peloton has an **internal REST API** at `api.onepeloton.com` used by their own apps
- **No official developer program**, no OAuth 2.0, no documentation
- Community has reverse-engineered endpoints (login, workouts, ride data)
- Popular open-source tool: [peloton-to-garmin](https://github.com/philosowaffle/peloton-to-garmin) (359 stars, 547 forks) uses credential-based login to scrape workout data
- The unofficial API uses session cookies from username/password authentication

### Key Data Available (Unofficial)
- Workouts (cycling, tread, rower, strength, meditation)
- Ride/class metadata
- Heart rate, cadence, power, resistance
- Output metrics and leaderboard data

### Risks
- **ToS violations**: Using unofficial API may violate Peloton's Terms of Service
- **No stability guarantees**: Endpoints can change/break without notice
- **Credential handling**: Requires storing user's Peloton username/password — major security concern

### Popularity
- ~7M+ members (as of 2024)
- Massive connected fitness brand in US/Canada/UK
- 4.9 stars on iOS App Store

### Verdict: **NO for ZuraLog**
No public API, no OAuth, no developer program. The only path is credential-scraping via unofficial endpoints, which is fragile, insecure, and likely ToS-violating. Not suitable for a production app. **Alternative**: Users can export Peloton data to Strava/Garmin first, and ZuraLog can ingest from those platforms.

---

## 4. Nike Run Club / Nike Training Club

### API Status: **NO PUBLIC API** — Deprecated/shut down

| Field | Details |
|---|---|
| **Auth Method** | N/A |
| **Developer Portal** | `developer.nike.com` — does not exist / unreachable |

### History
- Nike previously had a **Nike+ API** (circa 2012-2018) that exposed running and fitness data
- The API was **officially deprecated and shut down** around 2018-2019
- `developer.nike.com` no longer resolves
- Nike moved to a closed ecosystem model focused on their own apps

### What Exists Now
- Nike Run Club and Nike Training Club are closed platforms
- No OAuth, no API keys, no developer access of any kind
- Data export limited to manual download from Nike's app/website (if available)
- Some community tools attempted scraping but Nike actively blocks them

### Popularity
- ~100M+ NRC downloads on Google Play
- One of the most popular free running apps globally
- 4.8 stars on iOS App Store

### Verdict: **NO for ZuraLog**
Nike has fully closed their developer ecosystem. No API, no partner program, no data access. This is a dead end. **Alternative**: Users who use Nike watches (rare — Nike mostly licenses from Apple Watch) would have data in Apple Health/Google Health Connect, which ZuraLog already integrates with.

---

## 5. Under Armour / MapMyFitness / MapMyRun

### API Status: **PUBLIC OAuth 2.0** — Self-service key registration

| Field | Details |
|---|---|
| **Auth Method** | OAuth 2.0 (Authorization Code + Client Credentials) |
| **Developer Portal** | https://developer.mapmyfitness.com |
| **API Docs** | https://developer.mapmyfitness.com/docs |
| **Request Key** | https://developer.mapmyfitness.com/requestkey |
| **Auth Endpoint** | `https://www.mapmyfitness.com/oauth2/authorize/` |
| **Token Endpoint** | `https://api.mapmyfitness.com/v7.1/oauth2/access_token/` |
| **Current Version** | API v7.1 |
| **Owner** | Outside Inc. (formerly Under Armour Connected Fitness) |

### Registration Process
1. Go to https://developer.mapmyfitness.com/requestkey
2. Fill in application details
3. Receive `client_id` and `client_secret`
4. **Self-service** — no approval wait for Personal Use tier

### Key Data Types Available
- **Workouts**: 700+ activity types, full workout logging and retrieval
- **Routes**: GPS route data, route creation and search
- **Devices**: Data from 400+ activity tracking devices
- **Heart Rate Zones**: HR zone data and calculations
- **User Profiles**: Basic user info
- **Webhooks**: Event notifications for data changes
- **24/7 Tracking**: Steps, sleep, distance, weight

### Rate Limits
- **Personal Use (Free)**: 25 requests/second, 25,000 requests/day, up to 10 users
- **Enterprise**: Higher limits — contact `partner-support@mapmyfitness.com`
- Token expiration: ~60 days (refresh token available)

### Pricing
- **Free** for Personal Use tier (25 req/sec, 25K req/day)
- **Enterprise/Paid**: Contact for pricing (for scale)
- Billing via Stripe portal available

### Important Notes
- **Every API request requires `Api-Key` header** (set to client_id) in addition to OAuth Bearer token
- MapMyFitness, MapMyRun, MapMyRide, MapMyWalk all share the same API platform
- Now owned by **Outside Inc.** (post-Under Armour divestiture)
- `developer.underarmour.com` no longer exists — redirected to MapMyFitness

### Popularity
- ~40M+ registered users across MapMy* apps
- Popular in US, strong casual fitness market
- 4.6 stars on iOS App Store

### Verdict: **YES for ZuraLog**
Solid public OAuth 2.0 API with self-service registration. Rich data (workouts, routes, devices, HR zones), generous free tier (25K requests/day), active developer portal with full docs. The MapMy* family covers a large user base. Good integration candidate, especially for running and general fitness tracking.

---

## 6. COROS

### API Status: **NO PUBLIC API** — Completely closed ecosystem

| Field | Details |
|---|---|
| **Auth Method** | N/A |
| **Developer Portal** | None (coros.com/developers, coros.com/openplatform, open.coros.com all return 404) |

### What Exists
- COROS has **no public API, no developer program, no partner portal**
- All tested URLs (developer pages, open platform pages) return 404 errors
- COROS syncs data to their own COROS Training Hub app only
- Third-party access is only through Strava sync (COROS → Strava → your app)
- No known unofficial API documentation in the community

### Data Export Options
- Manual FIT file export from COROS app
- Automatic sync to Strava, TrainingPeaks, Relive, Komoot (pre-built integrations)
- No direct API access for third parties

### Popularity
- ~1-2M users (rapidly growing)
- Very popular among ultrarunners and endurance athletes
- COROS PACE, VERTIX, APEX series watches
- 4.7 stars on iOS App Store

### Verdict: **NO for ZuraLog**
COROS is a completely closed platform with zero API access. Growing fast among athletes, but data access is only possible through their pre-built integrations to Strava/TrainingPeaks. **Alternative**: ZuraLog can capture COROS data indirectly via Strava integration (most COROS users sync to Strava anyway).

---

## 7. TrainingPeaks

### API Status: **Partner-Only API** — OAuth 2.0 but requires business approval

| Field | Details |
|---|---|
| **Auth Method** | OAuth 2.0 (reported from partner documentation) |
| **Developer Portal** | Not publicly accessible |
| **Partner Application** | Was at trainingpeaks.com/partnerships or similar (currently returning 404) |

### What's Known
- TrainingPeaks has an **API for approved partners** using OAuth 2.0
- Used by Suunto, Garmin, Wahoo, Zwift, and other established fitness platforms
- API provides access to: workouts, metrics, training plans, athlete data
- **Not self-service** — requires business partnership application and review
- Documentation and API endpoints are only shared after approval

### Key Data Types (from partner integrations)
- Planned vs. completed workouts
- TSS (Training Stress Score), IF (Intensity Factor), NP (Normalized Power)
- FTP (Functional Threshold Power)
- Heart rate, power, pace data
- Training calendar and plans
- Performance Management Chart (PMC) data

### Rate Limits
- Not publicly documented (shared with approved partners)

### Pricing
- Not publicly documented (likely free for approved partners)

### Restrictions
- Partner program focused on **established fitness businesses**
- No evidence of self-service developer registration
- Partnership pages returning 404 suggest possible program restructuring

### Popularity
- ~1-2M users (coaches + athletes)
- Dominant in triathlon, cycling, and endurance coaching
- 4.4 stars on iOS App Store

### Verdict: **MAYBE for ZuraLog** (low confidence)
TrainingPeaks has OAuth 2.0 capabilities but access is strictly partner-gated. The partnership application pages returning 404 is concerning — could indicate program changes. ZuraLog would need to apply as a business partner, which may involve proving market traction. Not a quick integration. **Alternative**: Like COROS, TrainingPeaks data often flows through Strava, making the Strava integration the more practical path.

---

## Integration Priority Matrix for ZuraLog

### Tier 1: Integrate Now (Public OAuth 2.0, Self-Service)
| Platform | Effort | Data Richness | User Base |
|---|---|---|---|
| **Polar AccessLink** | Low | Excellent (HR, sleep, recovery, biosensing, exercises) | ~10M |
| **MapMyFitness** | Low | Good (workouts, routes, devices, HR zones) | ~40M |

### Tier 2: Apply for Access (Partner Program, OAuth 2.0)
| Platform | Effort | Data Richness | User Base |
|---|---|---|---|
| **Suunto** | Medium (1-2 week approval) | Good (FIT files, workouts) | ~3M |
| **TrainingPeaks** | High (business review) | Excellent (TSS, power, training plans) | ~2M |

### Tier 3: Not Feasible (No Public API)
| Platform | Why Not | Workaround |
|---|---|---|
| **Peloton** | No API, only credential scraping | Users sync Peloton → Strava → ZuraLog |
| **Nike Run Club** | API shut down 2018-2019 | Users' data in Apple Health / Google Health Connect |
| **COROS** | Completely closed | Users sync COROS → Strava → ZuraLog |

### Recommended Integration Order
1. **Strava** (already planned — covers Peloton, COROS, and many other overflow users)
2. **Polar AccessLink** — richest data, easiest integration, free
3. **MapMyFitness** — large user base, easy integration, free tier
4. **Suunto** — apply for partnership, good outdoor sports coverage
5. **TrainingPeaks** — pursue after product has traction (endurance niche)

---

## Key Takeaways

1. **The fitness API landscape is fragmented** — only 2 of 7 major platforms offer true self-service public APIs (Polar, MapMyFitness).
2. **Strava remains the universal bridge** — most closed platforms (Peloton, COROS, Nike) sync TO Strava, making it the single most important integration for ZuraLog.
3. **Polar is the surprise winner** — best developer experience, richest data (biosensing, sleep, recovery), fully free, active development.
4. **MapMyFitness (ex-Under Armour)** is an underrated option — 40M users, public OAuth 2.0, generous free tier.
5. **Partner programs (Suunto, TrainingPeaks)** are worth pursuing once ZuraLog has a launched product to demonstrate.
6. **Nike and COROS are dead ends** for direct API integration.
