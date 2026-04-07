# Nutrition Feature Design

**Date:** 2026-04-07
**Status:** Draft — pending user review
**Author:** Fernando + Claude
**Type:** Information architecture change + new feature spec
**Scope:** Documentation only. No code changes in this pass.

---

## TL;DR (read this first)

We are adding a **Nutrition** feature to ZuraLog, inspired by what the Bevel app gets right. Nutrition will not get its own bottom-tab slot. Instead, it lives as a **large, prominent card on the Today tab**, and tapping that card opens a full Nutrition screen with everything inside it.

At the same time, we are **retiring the Progress and Trends bottom tabs from the navigation bar**. We are not deleting any code. The screens, widgets, providers, and data they use stay exactly where they are in the codebase. We are only changing where the user *finds* them:

- **Goals and Streaks** (from the old Progress tab) move into a section on the **Today** tab.
- **Achievements and the personal Journal** (from the old Progress tab) move under the **Profile** tab.
- **Trends** (charts, patterns, correlations) becomes a **sub-tab inside the Data tab**.

After this change, the bottom bar goes from five tabs to four:

**Before:** Today · Data · Coach · Progress · Trends
**After:** Today · Data · Coach · Profile

This document explains *why* we are doing this, *what* the Nutrition feature looks like screen by screen, and *how* it ties into the rest of the app — especially the AI Coach. It is intentionally long, but every section is written in plain language so anyone on the team can read it without a technical background.

---

## Table of Contents

1. [Why we are doing this](#1-why-we-are-doing-this)
2. [What Bevel gets right](#2-what-bevel-gets-right-research-summary)
3. [Information architecture: before and after](#3-information-architecture-before-and-after)
4. [Where Progress and Trends go](#4-where-progress-and-trends-go)
5. [The Nutrition feature, screen by screen](#5-the-nutrition-feature-screen-by-screen)
6. [How users log a meal](#6-how-users-log-a-meal)
7. [The Nutrition Score, in plain words](#7-the-nutrition-score-in-plain-words)
8. [Glucose monitor integration (optional)](#8-glucose-monitor-integration-optional)
9. [How Nutrition feeds the AI Coach](#9-how-nutrition-feeds-the-ai-coach)
10. [What we store (data model in plain language)](#10-what-we-store-data-model-in-plain-language)
11. [Privacy and safety](#11-privacy-and-safety)
12. [What is in scope vs. out of scope](#12-what-is-in-scope-vs-out-of-scope)
13. [Open questions](#13-open-questions)
14. [Sources](#14-sources)

---

## 1. Why we are doing this

ZuraLog's promise is to be a single Action Layer over a person's health — pulling data from many places, finding what matters, and helping the user act on it. Until now we have covered movement, sleep, heart, mood, and goals. We have not covered food. Food is the single largest daily lever a person has over how they feel, sleep, and perform, and our app is incomplete without it.

We looked closely at **Bevel**, an "all-in-one" health app that recently launched a nutrition feature. Bevel does nutrition in a way we admire: it is fast to log, it scores meals based on quality (not just calories), it ties food to how the body actually responds, and it talks to a coach. We are not cloning Bevel. We are taking the parts that fit ZuraLog's philosophy — simple, action-oriented, AI-led — and leaving the rest.

We are also using this as the moment to **simplify the bottom navigation**. Five tabs is one too many. Two of those tabs (Progress and Trends) were not pulling their weight as standalone destinations: users were not opening them, and the content inside them naturally belongs *next to* other things the user was already looking at. Folding them in makes the app feel less crowded and gives Nutrition the room it needs without adding a sixth tab.

---

## 2. What Bevel gets right (research summary)

Based on Bevel's public materials (linked at the bottom of this doc), here is what their nutrition feature actually does:

**Multiple ways to log a meal.** Bevel lets you log food by barcode scan, by photo (image recognition), by describing the meal in plain text, by picking from a recipe, or by searching a database of more than six million foods. The point is: no matter where the user is or what they just ate, there is a fast path.

**A daily Nutrition Score, but redesigned.** Bevel's score is *not* "did you hit your macros." It rewards the things that good nutrition research actually agrees on — vegetables, fruit, whole grains, nuts, healthy oils, omega-3s — and penalizes the things research agrees are harmful — processed meat, excess added sugar, excess sodium, and alcohol. The score is presented as a number out of 100 with a clear breakdown.

**A separate calorie and macro view.** For users who *do* want macro detail, Bevel still shows total calories, fat, carbs, and protein against a daily target. But this is a secondary view, not the headline.

**Real-time glucose tie-in (optional).** If the user wears a Dexcom or Libre continuous glucose monitor, Bevel pulls the data and shows how each meal actually affected their blood sugar. The meal score is then adjusted by the *individual's* response, not a generic average. This is the most differentiated thing they do.

**Pattern recognition.** Bevel watches across days and finds patterns — for example, "you tend to snack late at night, and on those days your morning run is slower." It surfaces these as small insights inside the app.

**Connection to the rest of the app.** Nutrition is not a silo. Bevel ties food to sleep quality, to workout recovery, and to a daily energy/recovery score. The whole thing reads as one story about the person's body, not five separate trackers.

**What Bevel does *not* do well.** Reviews note that Bevel is intentionally lighter than dedicated nutrition apps like MyFitnessPal or Cronometer. If a user wants strict macro precision down to the gram for every micronutrient, Bevel is not the right tool. We are fine with that trade-off — ZuraLog is also an Action Layer, not a food diary, and we want to keep nutrition feeling fast and motivating, not like data entry.

---

## 3. Information architecture: before and after

The single biggest visible change is the bottom navigation bar.

### Before (today)

```
┌──────────────────────────────────────────────────┐
│                                                  │
│                  (screen content)                │
│                                                  │
├──────────────────────────────────────────────────┤
│  Today    Data    Coach   Progress    Trends     │
└──────────────────────────────────────────────────┘
```

Five tabs. Progress and Trends are full destinations.

### After (this design)

```
┌──────────────────────────────────────────────────┐
│                                                  │
│                  (screen content)                │
│                                                  │
├──────────────────────────────────────────────────┤
│       Today      Data      Coach      Profile    │
└──────────────────────────────────────────────────┘
```

Four tabs. Cleaner, easier to thumb between, and every tab has a clear job.

#### What each tab is for, after the change

| Tab | What it answers | What lives inside |
|-----|-----------------|-------------------|
| **Today** | "What's going on with me right now?" | Daily snapshot, **Nutrition card (NEW)**, Goals & Streaks (relocated from Progress), quick log buttons, today's coach nudge |
| **Data** | "What does my body actually look like over time?" | Raw metrics, integrations, **Trends sub-tab (relocated)** with charts and patterns |
| **Coach** | "Help me make sense of all this and tell me what to do." | AI conversation, recommendations, weekly review |
| **Profile** | "Who am I in this app?" | Account, subscription, integrations, settings, **Achievements (relocated)**, **Journal (relocated)** |

### Visual: the new Today tab with the Nutrition card

Below is a wireframe of how the Today tab looks once the Nutrition card is added. It is intentionally simple — boxes and labels — to focus on layout, not visual polish.

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 360 720" width="360" height="720" role="img" aria-label="Today tab wireframe">
  <rect x="0" y="0" width="360" height="720" fill="#f7f7f5" stroke="#222" stroke-width="2"/>
  <!-- status bar -->
  <rect x="0" y="0" width="360" height="32" fill="#eaeae5"/>
  <text x="16" y="22" font-family="sans-serif" font-size="12" fill="#222">9:41</text>
  <!-- header -->
  <text x="20" y="64" font-family="sans-serif" font-size="22" font-weight="700" fill="#222">Good morning, Fer</text>
  <text x="20" y="84" font-family="sans-serif" font-size="12" fill="#666">Tuesday, April 7</text>
  <!-- snapshot tiles row -->
  <rect x="20" y="100" width="100" height="80" rx="12" fill="#fff" stroke="#ddd"/>
  <text x="32" y="124" font-family="sans-serif" font-size="11" fill="#666">Sleep</text>
  <text x="32" y="156" font-family="sans-serif" font-size="20" font-weight="700" fill="#222">7h 12m</text>
  <rect x="130" y="100" width="100" height="80" rx="12" fill="#fff" stroke="#ddd"/>
  <text x="142" y="124" font-family="sans-serif" font-size="11" fill="#666">Steps</text>
  <text x="142" y="156" font-family="sans-serif" font-size="20" font-weight="700" fill="#222">4,210</text>
  <rect x="240" y="100" width="100" height="80" rx="12" fill="#fff" stroke="#ddd"/>
  <text x="252" y="124" font-family="sans-serif" font-size="11" fill="#666">Mood</text>
  <text x="252" y="156" font-family="sans-serif" font-size="20" font-weight="700" fill="#222">Good</text>
  <!-- nutrition card (NEW, hero) -->
  <rect x="20" y="200" width="320" height="180" rx="16" fill="#1a3a2e" stroke="#1a3a2e"/>
  <text x="36" y="226" font-family="sans-serif" font-size="11" fill="#9ed5b8">NUTRITION</text>
  <text x="36" y="258" font-family="sans-serif" font-size="28" font-weight="700" fill="#fff">82</text>
  <text x="78" y="258" font-family="sans-serif" font-size="14" fill="#9ed5b8">/ 100 today</text>
  <text x="36" y="284" font-family="sans-serif" font-size="12" fill="#cfe9da">Strong start. 2 meals logged.</text>
  <!-- mini meal chips -->
  <rect x="36" y="300" width="56" height="56" rx="10" fill="#2a5a47"/>
  <text x="46" y="334" font-family="sans-serif" font-size="10" fill="#cfe9da">Breakfast</text>
  <rect x="100" y="300" width="56" height="56" rx="10" fill="#2a5a47"/>
  <text x="116" y="334" font-family="sans-serif" font-size="10" fill="#cfe9da">Lunch</text>
  <rect x="164" y="300" width="56" height="56" rx="10" fill="#2a5a47" stroke="#9ed5b8" stroke-dasharray="3 3"/>
  <text x="184" y="334" font-family="sans-serif" font-size="18" fill="#9ed5b8">+</text>
  <!-- "Log a meal" button -->
  <rect x="232" y="312" width="92" height="32" rx="16" fill="#9ed5b8"/>
  <text x="246" y="332" font-family="sans-serif" font-size="12" font-weight="700" fill="#1a3a2e">Log meal</text>
  <!-- goals & streaks (relocated) -->
  <text x="20" y="412" font-family="sans-serif" font-size="14" font-weight="700" fill="#222">Goals &amp; Streaks</text>
  <rect x="20" y="424" width="320" height="70" rx="12" fill="#fff" stroke="#ddd"/>
  <text x="36" y="448" font-family="sans-serif" font-size="12" fill="#222">Run 3x this week</text>
  <text x="36" y="468" font-family="sans-serif" font-size="11" fill="#666">2 / 3 done</text>
  <rect x="36" y="476" width="200" height="6" rx="3" fill="#eee"/>
  <rect x="36" y="476" width="133" height="6" rx="3" fill="#1a3a2e"/>
  <text x="280" y="468" font-family="sans-serif" font-size="11" fill="#1a3a2e">🔥 12d</text>
  <!-- coach nudge -->
  <rect x="20" y="510" width="320" height="64" rx="12" fill="#fff" stroke="#ddd"/>
  <text x="36" y="534" font-family="sans-serif" font-size="11" fill="#666">COACH</text>
  <text x="36" y="554" font-family="sans-serif" font-size="12" fill="#222">Try a lighter dinner — your sleep was rough last night.</text>
  <!-- bottom nav -->
  <rect x="0" y="660" width="360" height="60" fill="#fff" stroke="#ddd"/>
  <text x="34" y="694" font-family="sans-serif" font-size="11" font-weight="700" fill="#1a3a2e">Today</text>
  <text x="120" y="694" font-family="sans-serif" font-size="11" fill="#666">Data</text>
  <text x="200" y="694" font-family="sans-serif" font-size="11" fill="#666">Coach</text>
  <text x="280" y="694" font-family="sans-serif" font-size="11" fill="#666">Profile</text>
</svg>
```

The Nutrition card is the visual centerpiece of Today. It is large, dark, and uses the brand accent so it reads as the most important thing on the screen — which it should be, because food is the most controllable lever the user has each day.

---

## 4. Where Progress and Trends go

To be very clear: **we are not deleting anything**. Every Dart file under `zuralog/lib/features/progress/` and `zuralog/lib/features/trends/` stays exactly where it is. Every provider, widget, repository, and test continues to work. What changes is the *navigation* — the bottom bar no longer points at them as standalone destinations, and their content is mounted inside other tabs instead.

### Goals and Streaks → Today tab

Goals and streaks are inherently a "right now" question — *am I on track today, this week?* They belong on Today. We add a **Goals & Streaks** section beneath the Nutrition card, showing the user's active goals with their progress bars and current streak counts. Tapping a goal opens the same goal-detail screen that the old Progress tab used.

### Achievements and Journal → Profile tab

Achievements and the personal Journal are reflective, not daily. The user looks at them when they are thinking about *who they are* and *how far they have come*, which is exactly the mental model of a profile screen. Under Profile, we add two new sections:

- **Achievements** — the same medal/milestone list from the old Progress tab.
- **Journal** — the same private journal entries, including the AI-coach guided reflections.

### Trends → sub-tab inside Data

The Data tab already shows raw metrics. Trends is the *interpretation* of those metrics — charts, patterns, correlations. Putting Trends as a sub-tab at the top of the Data tab means a user looking at "my heart rate" can flip one tap over to "my heart rate over six months" without leaving the screen.

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 360 200" width="360" height="200" role="img" aria-label="Data tab top sub-tabs wireframe">
  <rect x="0" y="0" width="360" height="200" fill="#f7f7f5" stroke="#222" stroke-width="2"/>
  <text x="20" y="36" font-family="sans-serif" font-size="22" font-weight="700" fill="#222">Data</text>
  <!-- sub tabs -->
  <rect x="20" y="56" width="80" height="32" rx="16" fill="#1a3a2e"/>
  <text x="42" y="76" font-family="sans-serif" font-size="12" font-weight="700" fill="#fff">Metrics</text>
  <rect x="108" y="56" width="80" height="32" rx="16" fill="#fff" stroke="#ddd"/>
  <text x="132" y="76" font-family="sans-serif" font-size="12" fill="#222">Trends</text>
  <rect x="196" y="56" width="100" height="32" rx="16" fill="#fff" stroke="#ddd"/>
  <text x="216" y="76" font-family="sans-serif" font-size="12" fill="#222">Integrations</text>
  <text x="20" y="120" font-family="sans-serif" font-size="11" fill="#666">Trends is now a sub-tab here, not a bottom-nav destination.</text>
</svg>
```

### Implementation note (for the eventual code change, not this doc)

When we eventually wire this up, the bottom-nav widget gets four entries instead of five. The Today screen builder mounts the existing `GoalsListWidget` and the existing `StreaksWidget` from `features/progress/`. The Profile screen builder mounts `AchievementsListWidget` and `JournalListWidget`. The Data screen builder gets a top-of-screen tab bar with `MetricsView`, `TrendsView` (the existing trends screen content), and `IntegrationsView`. Nothing in `features/progress/` or `features/trends/` needs to be moved on disk or rewritten. This is a navigation/composition change only.

---

## 5. The Nutrition feature, screen by screen

The Nutrition feature is one tab-card on Today plus a small set of full screens reachable from it. There are five screens total:

1. **Nutrition home** — the daily view (today's score, today's meals, today's macros)
2. **Log meal** — the picker that chooses *how* you want to log
3. **Meal detail** — what you see after logging or when you tap an existing meal
4. **History** — past days, scrollable
5. **Insights** — patterns the system has noticed across time

We will walk through each one.

### 5.1 Nutrition home

The Nutrition home screen is what opens when the user taps the big Nutrition card on Today. It has three jobs: show today's score, show what you ate today, and make it dead easy to log the next thing.

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 360 720" width="360" height="720" role="img" aria-label="Nutrition home screen wireframe">
  <rect x="0" y="0" width="360" height="720" fill="#f7f7f5" stroke="#222" stroke-width="2"/>
  <!-- header -->
  <text x="20" y="48" font-family="sans-serif" font-size="22" font-weight="700" fill="#222">Nutrition</text>
  <text x="300" y="48" font-family="sans-serif" font-size="20" fill="#666">⋯</text>
  <text x="20" y="68" font-family="sans-serif" font-size="12" fill="#666">Tuesday, April 7</text>
  <!-- score ring -->
  <circle cx="180" cy="170" r="70" fill="none" stroke="#eee" stroke-width="14"/>
  <circle cx="180" cy="170" r="70" fill="none" stroke="#1a3a2e" stroke-width="14" stroke-dasharray="361" stroke-dashoffset="79" transform="rotate(-90 180 170)"/>
  <text x="180" y="172" font-family="sans-serif" font-size="36" font-weight="700" fill="#222" text-anchor="middle">82</text>
  <text x="180" y="194" font-family="sans-serif" font-size="11" fill="#666" text-anchor="middle">/ 100 today</text>
  <text x="180" y="266" font-family="sans-serif" font-size="12" fill="#1a3a2e" text-anchor="middle">Strong start — keep it up</text>
  <!-- macros row -->
  <rect x="20" y="290" width="100" height="56" rx="10" fill="#fff" stroke="#ddd"/>
  <text x="32" y="310" font-family="sans-serif" font-size="10" fill="#666">Protein</text>
  <text x="32" y="332" font-family="sans-serif" font-size="14" font-weight="700" fill="#222">62g / 110g</text>
  <rect x="130" y="290" width="100" height="56" rx="10" fill="#fff" stroke="#ddd"/>
  <text x="142" y="310" font-family="sans-serif" font-size="10" fill="#666">Carbs</text>
  <text x="142" y="332" font-family="sans-serif" font-size="14" font-weight="700" fill="#222">180g / 240g</text>
  <rect x="240" y="290" width="100" height="56" rx="10" fill="#fff" stroke="#ddd"/>
  <text x="252" y="310" font-family="sans-serif" font-size="10" fill="#666">Fat</text>
  <text x="252" y="332" font-family="sans-serif" font-size="14" font-weight="700" fill="#222">48g / 70g</text>
  <!-- today's meals -->
  <text x="20" y="378" font-family="sans-serif" font-size="14" font-weight="700" fill="#222">Today's meals</text>
  <rect x="20" y="390" width="320" height="64" rx="12" fill="#fff" stroke="#ddd"/>
  <rect x="32" y="402" width="40" height="40" rx="8" fill="#cfe9da"/>
  <text x="84" y="418" font-family="sans-serif" font-size="13" font-weight="700" fill="#222">Greek yogurt + berries</text>
  <text x="84" y="436" font-family="sans-serif" font-size="11" fill="#666">Breakfast · 320 kcal · score 88</text>
  <rect x="20" y="462" width="320" height="64" rx="12" fill="#fff" stroke="#ddd"/>
  <rect x="32" y="474" width="40" height="40" rx="8" fill="#cfe9da"/>
  <text x="84" y="490" font-family="sans-serif" font-size="13" font-weight="700" fill="#222">Salmon poke bowl</text>
  <text x="84" y="508" font-family="sans-serif" font-size="11" fill="#666">Lunch · 540 kcal · score 91</text>
  <!-- log meal CTA -->
  <rect x="20" y="546" width="320" height="52" rx="26" fill="#1a3a2e"/>
  <text x="180" y="578" font-family="sans-serif" font-size="14" font-weight="700" fill="#fff" text-anchor="middle">+ Log a meal</text>
  <!-- secondary links -->
  <text x="60" y="624" font-family="sans-serif" font-size="12" fill="#1a3a2e">History</text>
  <text x="180" y="624" font-family="sans-serif" font-size="12" fill="#1a3a2e" text-anchor="middle">Insights</text>
  <text x="300" y="624" font-family="sans-serif" font-size="12" fill="#1a3a2e" text-anchor="end">Goals</text>
</svg>
```

Note the order of importance on this screen:

1. **The score ring is the biggest thing.** That is the headline answer to "how am I doing today?"
2. **Macros are secondary.** They are there for users who care, but they are smaller and don't dominate.
3. **Meals you already logged** are listed in a friendly, scannable way with their own per-meal score.
4. **The "Log a meal" button is huge and unmissable.** Logging is the action we want most often.

### 5.2 Log meal — the picker

When the user taps "Log a meal," they get a sheet that asks *how* they want to log it. This is the screen where speed matters most.

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 360 560" width="360" height="560" role="img" aria-label="Log meal picker sheet wireframe">
  <rect x="0" y="0" width="360" height="560" fill="#f7f7f5" stroke="#222" stroke-width="2"/>
  <rect x="160" y="14" width="40" height="4" rx="2" fill="#ccc"/>
  <text x="20" y="56" font-family="sans-serif" font-size="20" font-weight="700" fill="#222">Log a meal</text>
  <text x="20" y="76" font-family="sans-serif" font-size="12" fill="#666">Pick the fastest way for what you're eating.</text>
  <!-- option: search -->
  <rect x="20" y="100" width="320" height="72" rx="14" fill="#fff" stroke="#ddd"/>
  <rect x="36" y="116" width="40" height="40" rx="10" fill="#cfe9da"/>
  <text x="56" y="142" font-family="sans-serif" font-size="18" fill="#1a3a2e" text-anchor="middle">🔍</text>
  <text x="92" y="132" font-family="sans-serif" font-size="14" font-weight="700" fill="#222">Search foods</text>
  <text x="92" y="152" font-family="sans-serif" font-size="11" fill="#666">Type a name and pick from the database.</text>
  <!-- option: photo -->
  <rect x="20" y="184" width="320" height="72" rx="14" fill="#fff" stroke="#ddd"/>
  <rect x="36" y="200" width="40" height="40" rx="10" fill="#cfe9da"/>
  <text x="56" y="226" font-family="sans-serif" font-size="18" fill="#1a3a2e" text-anchor="middle">📷</text>
  <text x="92" y="216" font-family="sans-serif" font-size="14" font-weight="700" fill="#222">Take a photo</text>
  <text x="92" y="236" font-family="sans-serif" font-size="11" fill="#666">Snap your plate. We'll guess what's on it.</text>
  <!-- option: describe -->
  <rect x="20" y="268" width="320" height="72" rx="14" fill="#fff" stroke="#ddd"/>
  <rect x="36" y="284" width="40" height="40" rx="10" fill="#cfe9da"/>
  <text x="56" y="310" font-family="sans-serif" font-size="18" fill="#1a3a2e" text-anchor="middle">💬</text>
  <text x="92" y="300" font-family="sans-serif" font-size="14" font-weight="700" fill="#222">Describe it</text>
  <text x="92" y="320" font-family="sans-serif" font-size="11" fill="#666">"Two eggs, toast, and a banana." We figure it out.</text>
  <!-- option: barcode -->
  <rect x="20" y="352" width="320" height="72" rx="14" fill="#fff" stroke="#ddd"/>
  <rect x="36" y="368" width="40" height="40" rx="10" fill="#cfe9da"/>
  <text x="56" y="394" font-family="sans-serif" font-size="18" fill="#1a3a2e" text-anchor="middle">▦</text>
  <text x="92" y="384" font-family="sans-serif" font-size="14" font-weight="700" fill="#222">Scan a barcode</text>
  <text x="92" y="404" font-family="sans-serif" font-size="11" fill="#666">Point at the package.</text>
  <!-- recents row -->
  <text x="20" y="456" font-family="sans-serif" font-size="12" font-weight="700" fill="#666">RECENT</text>
  <rect x="20" y="468" width="100" height="36" rx="18" fill="#fff" stroke="#ddd"/>
  <text x="70" y="490" font-family="sans-serif" font-size="11" fill="#222" text-anchor="middle">Greek yogurt</text>
  <rect x="128" y="468" width="100" height="36" rx="18" fill="#fff" stroke="#ddd"/>
  <text x="178" y="490" font-family="sans-serif" font-size="11" fill="#222" text-anchor="middle">Poke bowl</text>
  <rect x="236" y="468" width="100" height="36" rx="18" fill="#fff" stroke="#ddd"/>
  <text x="286" y="490" font-family="sans-serif" font-size="11" fill="#222" text-anchor="middle">Coffee + oat milk</text>
</svg>
```

Below the four logging methods, we always show the user's most-recent foods as one-tap chips. In real usage, the recents row is the most-tapped element on this whole screen, because people eat the same things over and over.

### 5.3 Meal detail

After logging (no matter which method), the user lands on the meal detail screen. This is also what they see when they tap a meal from any list.

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 360 720" width="360" height="720" role="img" aria-label="Meal detail screen wireframe">
  <rect x="0" y="0" width="360" height="720" fill="#f7f7f5" stroke="#222" stroke-width="2"/>
  <!-- photo / hero -->
  <rect x="0" y="0" width="360" height="200" fill="#cfe9da"/>
  <text x="180" y="110" font-family="sans-serif" font-size="13" fill="#1a3a2e" text-anchor="middle">[ meal photo ]</text>
  <text x="20" y="32" font-family="sans-serif" font-size="20" fill="#fff">←</text>
  <!-- title -->
  <text x="20" y="232" font-family="sans-serif" font-size="20" font-weight="700" fill="#222">Salmon poke bowl</text>
  <text x="20" y="252" font-family="sans-serif" font-size="12" fill="#666">Lunch · 12:40 pm</text>
  <!-- score chip -->
  <rect x="20" y="270" width="100" height="40" rx="20" fill="#1a3a2e"/>
  <text x="70" y="295" font-family="sans-serif" font-size="14" font-weight="700" fill="#fff" text-anchor="middle">Score 91</text>
  <!-- macros line -->
  <text x="20" y="338" font-family="sans-serif" font-size="12" fill="#666">540 kcal · 34g protein · 58g carbs · 18g fat</text>
  <!-- breakdown bullets -->
  <text x="20" y="368" font-family="sans-serif" font-size="13" font-weight="700" fill="#222">Why this scored 91</text>
  <circle cx="28" cy="392" r="3" fill="#1a3a2e"/>
  <text x="40" y="396" font-family="sans-serif" font-size="12" fill="#222">+ Omega-3 rich (salmon)</text>
  <circle cx="28" cy="414" r="3" fill="#1a3a2e"/>
  <text x="40" y="418" font-family="sans-serif" font-size="12" fill="#222">+ Lots of vegetables</text>
  <circle cx="28" cy="436" r="3" fill="#1a3a2e"/>
  <text x="40" y="440" font-family="sans-serif" font-size="12" fill="#222">+ Whole grain rice</text>
  <circle cx="28" cy="458" r="3" fill="#c44"/>
  <text x="40" y="462" font-family="sans-serif" font-size="12" fill="#222">– Soy sauce pushed sodium high</text>
  <!-- coach note -->
  <rect x="20" y="486" width="320" height="80" rx="12" fill="#fff" stroke="#ddd"/>
  <text x="36" y="510" font-family="sans-serif" font-size="11" fill="#666">COACH</text>
  <text x="36" y="530" font-family="sans-serif" font-size="12" fill="#222">Strong protein hit. If you're training tonight,</text>
  <text x="36" y="548" font-family="sans-serif" font-size="12" fill="#222">this'll help recovery.</text>
  <!-- edit / delete -->
  <rect x="20" y="592" width="150" height="44" rx="22" fill="#fff" stroke="#1a3a2e"/>
  <text x="95" y="618" font-family="sans-serif" font-size="13" font-weight="700" fill="#1a3a2e" text-anchor="middle">Edit</text>
  <rect x="190" y="592" width="150" height="44" rx="22" fill="#fff" stroke="#c44"/>
  <text x="265" y="618" font-family="sans-serif" font-size="13" font-weight="700" fill="#c44" text-anchor="middle">Delete</text>
</svg>
```

The meal detail screen is where Nutrition stops being a tracker and starts being an Action Layer. The "Why this scored 91" list is the key: instead of just a number, the user sees the *reasons* in plain words. Bevel does this well, and we are doing it the same way.

### 5.4 History

The History screen is a scroll of past days, each one collapsed into a row showing that day's score and meal count. Tapping a row expands it.

The simplest version is a vertical list. We don't need fancy graphs here — Insights is where the analysis lives.

### 5.5 Insights

Insights is a feed of patterns the system has noticed across the user's data. Each insight is a card with a one-line headline, a short explanation in plain English, and (when relevant) a small chart.

Examples of insights we want to surface (based on what Bevel does and what fits ZuraLog):

- "On days you eat after 9 pm, your sleep score drops by an average of 11 points."
- "You hit your protein target on workout days but miss it 60% of rest days."
- "Your nutrition score has gone up 14 points in the last 4 weeks. Nice."
- "Vegetables show up in only 3 of your 7 dinners this week."

These are not generic tips. They are tied to *this* user's data. That is what makes them feel like a coach and not a magazine.

---

## 6. How users log a meal

This section is the longest because logging is where users will spend the most time. If logging is slow or annoying, the entire feature dies. KISS rule applies hardest here.

### 6.1 Search foods

The user types a name. As they type, we show matching foods from a food database. They tap one, pick a portion size, tap "Log."

What we need behind the scenes (documented here, not built):

- A food database. We do not need to build our own. We will use one of the existing ones — USDA FoodData Central is free and covers basics; Open Food Facts is good for branded products; commercial APIs like Nutritionix or Edamam cover both with better search ergonomics. We will pick one (or layer two) when we get to implementation.
- A "portion" model — grams, common units (a cup, a slice, a piece), or "serving as listed."
- A recents/favorites list scoped to the user.

KISS for v1: pick one paid food database with good search, don't build our own, don't over-engineer the portion picker. A grams field and a "common portion" dropdown is enough.

### 6.2 Take a photo

The user opens the camera, snaps the plate, and we send the image to a vision model that returns a best-guess list of foods with rough portion estimates. The user reviews and confirms before the meal is saved.

This is the highest-magic, highest-risk path. If our guess is wrong, the user has to fix it, and that is slower than just searching. So our rule is: **never log a photo meal silently.** Always show the guesses, let the user edit them, and only save when they tap confirm.

KISS for v1: one vision call, return a list, render it as editable rows. No automatic logging. No fancy plate segmentation.

### 6.3 Describe it

The user types or speaks a sentence like *"two scrambled eggs, a slice of sourdough toast with butter, and a coffee with oat milk."* We send that text to the AI, get back a structured list of foods + portions, and let the user confirm.

This is the path power users will love. It is also the most natural way to log a complicated mixed meal.

KISS for v1: same flow as the photo path — show the parsed result, let the user edit, save on confirm. No complicated NLP pipelines.

### 6.4 Barcode

The user points the camera at a packaged-food barcode. We look it up in the food database. If we find it, we pre-fill the meal with that food and the package's serving size. The user picks how many servings.

KISS for v1: use the same food database as search. If it has barcodes, we get this almost free.

### 6.5 Recents and favorites

People eat the same things over and over. The single biggest speedup we can give a daily user is one-tap re-logging. Recents shows the last 10 things they logged, ordered by frequency-weighted recency. Favorites is a manually-pinned list.

This is not a separate logging *method* — it appears at the bottom of the picker sheet (see screen 5.2 above) and as a row on the Nutrition home below the score.

### 6.6 What we are explicitly *not* shipping in v1

To stay KISS:

- **Recipes** — Bevel has a recipe builder. We do not need it on day one. A user who eats homemade chicken-and-veggie soup can describe it once and favorite it.
- **Restaurant menus** — nice to have, but the database covers most chains via search.
- **Meal plans** — out of scope. The Coach can suggest meals in chat; we are not building a meal-planning UI.
- **Water tracking** — handled separately by hydration in the existing health tab.
- **Micronutrient deep-dive** — we show the basics. A user who needs nine micronutrients tracked to the milligram should use a specialized app.

---

## 7. The Nutrition Score, in plain words

The Nutrition Score is the headline number on every screen. It needs to be simple to understand and trustworthy. Here is the rule we use, in plain language:

> A meal's score goes **up** when it contains things that nutrition research broadly agrees are good for the body, and **down** when it contains things research broadly agrees are harmful in excess.

That's it. No magic formula visible to the user. But under the hood, we are scoring on a few clear dimensions:

**Things that add points:**

- Vegetables (especially leafy greens, cruciferous, colorful)
- Whole fruits
- Whole grains (oats, brown rice, quinoa, whole-wheat bread)
- Legumes and beans
- Nuts and seeds
- Healthy oils (olive, avocado)
- Lean protein (fish, poultry, tofu, eggs)
- Fatty fish specifically (omega-3 boost — salmon, sardines, mackerel)
- Fermented foods (yogurt, kefir, sauerkraut, kimchi)

**Things that subtract points:**

- Added sugar above a daily threshold
- Sodium above a daily threshold
- Refined carbs (white bread, white rice, pastries)
- Processed and cured meats
- Ultra-processed snack foods
- Alcohol (any amount subtracts a small number of points)
- Trans fats and most fried foods

The **daily score** is the average of meal scores, weighted by calories, capped at 100. So a user who eats a 95-score salad and a 60-score burger lands somewhere around 75 for the day (depending on portion sizes), not 77.5. This nudges users to make every meal count instead of "balancing out" a bad meal with a good one.

**What we are deliberately not doing:**

- We are not scoring on calorie targets. A user who eats 1,200 high-quality calories does not get punished for "under-eating," and a user who eats 3,000 high-quality calories does not get punished for "over-eating." Calories are visible as a separate number for users who care, but they do not enter the score.
- We are not scoring on macros. Macro balance is a separate (secondary) view, not a score input.
- We are not scoring on diet ideology. We do not assume keto is good or bad, vegan is good or bad, paleo is good or bad. The score is built from food-quality evidence, not diet labels.

This matches Bevel's philosophy and we believe it is the right one.

### Visual: how the score is communicated

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 360 200" width="360" height="200" role="img" aria-label="Score with breakdown wireframe">
  <rect x="0" y="0" width="360" height="200" fill="#f7f7f5" stroke="#222" stroke-width="2"/>
  <circle cx="80" cy="100" r="56" fill="none" stroke="#eee" stroke-width="12"/>
  <circle cx="80" cy="100" r="56" fill="none" stroke="#1a3a2e" stroke-width="12" stroke-dasharray="352" stroke-dashoffset="63" transform="rotate(-90 80 100)"/>
  <text x="80" y="106" font-family="sans-serif" font-size="28" font-weight="700" fill="#222" text-anchor="middle">82</text>
  <text x="160" y="60" font-family="sans-serif" font-size="11" fill="#1a3a2e">+ Vegetables</text>
  <text x="160" y="80" font-family="sans-serif" font-size="11" fill="#1a3a2e">+ Whole grains</text>
  <text x="160" y="100" font-family="sans-serif" font-size="11" fill="#1a3a2e">+ Omega-3</text>
  <text x="160" y="120" font-family="sans-serif" font-size="11" fill="#c44">– Sodium high</text>
  <text x="160" y="140" font-family="sans-serif" font-size="11" fill="#c44">– Added sugar at lunch</text>
</svg>
```

---

## 8. Glucose monitor integration (optional)

Users who wear a Dexcom or Libre continuous glucose monitor can connect it to ZuraLog. When they do, two things happen:

**1. The app shows a glucose curve under each meal.** Open any meal in the meal detail view, and below the macros there is a small graph of how the user's blood sugar moved in the two hours after they ate it. A high spike is highlighted in orange; a smooth, gentle curve is highlighted in green.

**2. The Nutrition Score gets a personal adjustment.** Two users can eat the exact same oatmeal and have very different glucose responses to it. For users with a connected monitor, we adjust the score of each meal *for that user* based on how their body actually responded. A meal that scores 82 generically might score 74 for someone whose glucose spiked badly on it, and 88 for someone whose glucose stayed flat.

This is the most differentiated thing Bevel does, and we believe it is worth copying because it is the cleanest example of the Action Layer philosophy: *the same food is not the same food for every body.*

**For v1, the integration is optional and read-only.** We do not write data back to Dexcom or Libre. We do not require a monitor. Users without one get the generic score and no glucose curve. Users with one get the personal score and the curve.

The actual integration plumbing (which CGM APIs, OAuth flow, refresh cadence) is out of scope for this doc and will be handled in the integration spec when we get to implementation.

---

## 9. How Nutrition feeds the AI Coach

Nutrition is not a silo. The whole point of ZuraLog is the Action Layer, and the Coach is what makes that layer actionable. So every meal the user logs becomes a signal the Coach can use.

Concretely, the Coach gains access to the following nutrition signals (alongside the sleep, movement, mood, and heart-rate signals it already has):

- **Today's nutrition score and recent trend** (last 7 / 30 days)
- **Macro and calorie totals for today**
- **Each meal logged today** with its score and time of day
- **Patterns** flagged by the insights pipeline (late-night snacking, low-veg dinners, big sodium days, etc.)
- **Glucose response data** for users with a connected monitor

The Coach uses these in three ways:

**Reactive answers.** When the user opens chat and asks *"why am I tired today?"* the Coach can now look at last night's dinner and notice it was a 600-calorie pasta plate eaten at 10 pm. The answer becomes specific instead of generic.

**Proactive nudges.** The Coach already shows a small nudge card on the Today tab. With nutrition data, those nudges get sharper: *"You hit your protein early today — nice. If you're lifting tonight, top it up after."* or *"Your sleep was rough last night and you had a late dinner. Try eating earlier today and see what happens."*

**Weekly review.** The existing weekly review screen now includes a nutrition section: top-scoring meals, lowest-scoring meals, the strongest pattern of the week, and one suggested experiment for next week.

What we are *not* doing: we are not having the Coach tell the user what to eat for every meal. That is a meal-planning app, and it is not what we are building. The Coach observes, explains, and nudges. The user decides what to eat.

---

## 10. What we store (data model in plain language)

We are documenting *what* we store, not *how*. The actual database design is the `db` subagent's job at implementation time. This section is just a plain-language inventory.

For every user, we store:

**Foods they have logged.** Each entry has: which user, what food it was, how much (a portion + a unit + grams), what meal type (breakfast / lunch / dinner / snack), the time it was eaten, the calculated calories and macros, the calculated nutrition score, and an optional photo. A meal is a group of one or more food entries logged together.

**Their food database hits.** We cache the food data we fetched from the external food database so we don't pay for the same lookup twice and so the app works offline for repeat foods.

**Their preferences.** Daily calorie target (optional — many users will leave it blank), macro targets (optional), dietary patterns the user has self-declared (vegetarian, gluten-free, dairy-free, etc. — used to filter recommendations), and which logging methods they prefer (so we can put the right one on top of the picker for them).

**Their glucose data.** If they have connected a monitor: a stream of glucose readings tied to timestamps, plus a derived "spike score" per meal.

**Their insights.** The patterns the system has noticed, with the data points that triggered each one. Old insights expire after a set window so the feed stays fresh.

**A few derived rollups for fast reads.** Daily score per user per day. Weekly average score. These are computed at write time, not at read time, so the home screen is fast even for users with two years of meals.

We are designing this for one million users from day one, so the schema needs to scale: meal entries are append-mostly, the rollup tables are the hot read path, and the food database cache is shared across users.

---

## 11. Privacy and safety

Food data is sensitive in ways some teams underestimate. People with eating disorders, body image issues, or restrictive diets can be harmed by careless nutrition UX. We take this seriously.

**What we will not do:**

- We will not show calorie totals as a "deficit" or "surplus" framing. No "you have 412 calories left today" because that framing reinforces restriction.
- We will not tell users their score is "bad." A low score gets neutral language ("there's room for more vegetables"), never shame.
- We will not push notifications about unlogged meals. If the user forgets to log dinner, that is fine. We do not nag them.
- We will not show before/after weight in the Nutrition feature. Weight lives in the Data tab. We deliberately keep it separate.
- We will not sell or share food data with third parties. Period.
- We will not let the AI Coach recommend a calorie deficit unprompted. If the user asks specifically, the Coach can discuss it with general guidance and a suggestion to talk to a registered dietitian for anything serious.

**What we will do:**

- An optional "gentle mode" in settings hides the score number entirely, replacing it with qualitative labels ("balanced day," "room to improve"). Recommended for users who self-identify as having a difficult history with food tracking.
- A clear, one-tap path to delete any logged meal — and a clear path to delete *all* nutrition data — under Profile → Privacy.
- Photo uploads are processed by the vision model and then *the photo is the user's, not ours*. We store it alongside the meal so the user can see their own history, but we do not use it for training and we delete it when the meal is deleted.
- A surgeon-general-style note in the empty state of Insights: "These are observations, not medical advice. If anything in here worries you, talk to a doctor."

---

## 12. What is in scope vs. out of scope

### In scope for the first version

- The Nutrition card on Today
- The Nutrition home screen with score, macros, today's meals
- The four logging methods: search, photo, describe, barcode
- The recents/favorites picker
- Meal detail with the "why this scored X" breakdown
- History (simple scroll)
- Insights (basic patterns)
- Coach access to nutrition signals
- The IA relocation: Goals/Streaks → Today, Achievements/Journal → Profile, Trends → Data sub-tab
- The bottom-nav reduction from 5 tabs to 4
- Privacy settings: gentle mode, delete-all-nutrition-data

### Out of scope for the first version (intentionally)

- A recipe builder
- Meal plans / "what should I eat tomorrow"
- A social / shared-meals feature
- Restaurant menu lookups beyond what the food database covers
- Micronutrient deep-dive (we show the basics, not all 30+ micros)
- Glucose monitor integration is in scope as *optional* — we are documenting it but it can ship in a fast-follow if it slows the main launch
- Migrating any code under `features/progress/` or `features/trends/` on disk (the relocation is navigation-only)
- Deleting any existing screens, providers, repositories, or tests

---

## 13. Open questions

These are the things we have not decided yet. They do not block this design, but they need answers before implementation.

1. **Food database vendor.** USDA + Open Food Facts (free, less polished), Nutritionix (commercial, polished, has restaurants), Edamam (commercial, polished, strong search), or a hybrid? Cost matters at one million users.
2. **Vision model for photo logging.** Use the same model the Coach already uses, or a specialized food-vision model? Accuracy of portion estimates is the main risk.
3. **Score formula tuning.** The general philosophy is decided. The exact point values per food category are not. We will need a small evidence-review pass with a real nutrition reference (Harvard Healthy Eating Plate, EAT-Lancet, etc.) before we lock numbers.
4. **Glucose: ship in v1 or fast-follow?** If the integration spec for Dexcom/Libre is heavy, we ship without it and add it in v1.1.
5. **Onboarding flow.** Do we ask new users to set calorie/macro targets when they first open the Nutrition screen, or do we leave targets off by default and let users opt in? The privacy section above leans toward off by default.
6. **Where does the "Nutrition card" appear if the user has never logged a meal?** It needs an empty state that invites them in without feeling like a chore.

---

## 14. Sources

Bevel research used for this document (all public):

- [Bevel — The Everything Health App (homepage)](https://www.bevel.health/)
- [Bevel: All-In-One Health App — App Store listing](https://apps.apple.com/us/app/bevel-all-in-one-health-app/id6456176249)
- [Bevel Launches AI-Powered Nutrition Tracking with Blood Glucose Integration — Fitt Insider](https://insider.fitt.co/press-release/bevel-launches-ai-powered-nutrition-app/)
- [Bevel Introduces AI-Powered Nutrition Tracking — The AI Insider](https://theaiinsider.tech/2025/02/07/bevel-introduces-ai-powered-nutrition-tracking-to-enhance-personalized-health-insights/)
- [Bevel App Review 2026 — Autonomous](https://www.autonomous.ai/ourblog/bevel-app-review)
- [Bevel launches AI nutrition coach powered by your glucose monitor — Wellworthy](https://wellworthy.com/bevel-launches-ai-nutrition-coach-powered-by-your-glucose-monitor/)

We are taking inspiration, not copying. Anything in this document that resembles Bevel does so because we believe it is the right design for ZuraLog's users; the rest of the app remains entirely our own.
