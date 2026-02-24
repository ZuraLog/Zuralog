# Phase 3.2: Waitlist Landing Page — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a production-ready, Awwwards-caliber single-page waitlist landing page with: an immersive 3D hero (ecosystem icons converging into a floating phone with animated Zuralog UI components), GSAP scroll-triggered feature showcases, an interactive 3-question quiz, email signup with referral system + public top-10 leaderboard, Resend transactional emails, and full Supabase backend. The page must feel like a premium startup launch — not a generic template.

**Architecture:** Single-page scroll experience built on the Phase 3.1 foundation. Backend logic uses Next.js API Routes (Route Handlers) talking to Supabase and Resend. Rate limiting via Upstash Redis. All 3D content lazy-loaded via `next/dynamic` with SSR disabled.

**Tech Stack:** Everything from Phase 3.1 plus: Resend + React Email (emails), Zod + React Hook Form (forms), Upstash Redis (rate limiting), nanoid (referral codes).

**Companion Document:** `docs/plans/web/web-view-design.md` — the full visual design specification. Every section below references it.

---

## Dependencies

- Phase 3.1 complete (all 9 sub-tasks)
- Supabase project accessible
- Resend account created (free tier: 100 emails/day, 3,000/month)
- Upstash Redis instance created (free tier: 10,000 requests/day)

---

## Phase 3.2 Sub-Phase Checklist

- [ ] **3.2.1** Database Schema (Supabase Migration)
- [ ] **3.2.2** Waitlist API Routes
- [ ] **3.2.3** Resend Email Integration
- [ ] **3.2.4** Navbar Component
- [ ] **3.2.5** Hero Section + 3D Scene
- [ ] **3.2.6** Problem Statement Section
- [ ] **3.2.7** Features Showcase Section
- [ ] **3.2.8** How It Works Section
- [ ] **3.2.9** Interactive Quiz Component
- [ ] **3.2.10** Waitlist Signup Form
- [ ] **3.2.11** Referral System & Leaderboard
- [ ] **3.2.12** Footer Component
- [ ] **3.2.13** Responsive Design & Mobile Optimization
- [ ] **3.2.14** Performance Optimization
- [ ] **3.2.15** Custom Cursor + Immersive Polish
- [ ] **3.2.16** SEO, Open Graph & Launch Readiness
- [ ] **3.2.17** E2E Testing & Final QA

---

## Page Architecture (Single Scroll)

```
[Navbar — sticky, frosted glass, z-50]
  ├── Logo + Wordmark
  ├── Nav links: Features · How It Works · Join (smooth scroll anchors)
  └── "Join Waitlist" CTA pill button

[Section 1: Hero — 100vh]
  ├── 3D Scene: App icons orbiting → converging into floating iPhone
  │   with animated Zuralog UI components assembling on screen
  ├── Headline: "[Placeholder Tagline]"
  ├── Sub-headline: "The AI that connects your fitness apps and actually thinks."
  └── CTA: "Join the Waitlist" → smooth scrolls to Section 5

[Section 2: Problem Statement — "Your apps don't talk to each other."]
  ├── GSAP scroll-triggered reveal
  ├── Visual: scattered icons → animated into order
  └── 3 pain point cards with staggered entrance

[Section 3: Features Showcase — "What Zuralog Does"]
  ├── 4 alternating text/visual blocks
  │   ├── Cross-App AI Reasoning
  │   ├── Autonomous Actions
  │   ├── Zero-Friction Logging
  │   └── One Dashboard
  └── Each with scroll-triggered animation

[Section 4: How It Works — "3 Steps"]
  ├── Connect → Learn → Act
  └── Sequential reveal with connecting animated lines

[Section 5: Quiz + Waitlist Form]
  ├── 3-question interactive quiz (Framer AnimatePresence)
  ├── Email input + CTA
  └── Post-submit: referral code + position + share buttons

[Section 6: Social Proof & Leaderboard]
  ├── Live waitlist counter
  ├── Top-10 referral leaderboard (anonymous/named toggle)
  └── Personal rank card (if signed up)

[Section 7: Footer]
  ├── Logo, tagline, legal links, social icons
  └── © 2026 Zuralog
```

---

## Task 3.2.1: Database Schema (Supabase Migration)

**What:** Create the `waitlist_users` table, indexes, RLS policies, and a `referral_leaderboard` view in the existing Supabase project.

**Why:** All waitlist data (signups, quiz answers, referrals, positions) needs a persistent, queryable store. Using the same Supabase project as the mobile app means users can be migrated seamlessly at launch.

**Files:**
- Create: Supabase migration (via dashboard SQL editor or CLI)
- Modify: `web/src/types/database.ts` (typed schema)

**Schema:**

```sql
-- Waitlist users table
CREATE TABLE public.waitlist_users (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  email TEXT UNIQUE NOT NULL,
  referral_code TEXT UNIQUE NOT NULL,
  referred_by TEXT REFERENCES public.waitlist_users(referral_code),
  display_name TEXT, -- optional, for public leaderboard
  show_name BOOLEAN DEFAULT false, -- opt-in for public name
  queue_position INTEGER,
  
  -- Quiz answers
  quiz_apps_used TEXT[] DEFAULT '{}', -- e.g. ['strava', 'oura', 'calai']
  quiz_frustration TEXT, -- e.g. 'too_many_apps'
  quiz_goal TEXT, -- e.g. 'weight_loss'
  
  -- Tier/rewards
  tier TEXT DEFAULT 'standard', -- 'founding_30', 'top_referrer', 'standard'
  
  -- Metadata
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  ip_address INET, -- for abuse detection
  user_agent TEXT
);

-- Indexes
CREATE INDEX idx_waitlist_email ON public.waitlist_users(email);
CREATE INDEX idx_waitlist_referral_code ON public.waitlist_users(referral_code);
CREATE INDEX idx_waitlist_referred_by ON public.waitlist_users(referred_by);
CREATE INDEX idx_waitlist_queue_position ON public.waitlist_users(queue_position);
CREATE INDEX idx_waitlist_created_at ON public.waitlist_users(created_at);

-- Auto-assign queue position via trigger
CREATE OR REPLACE FUNCTION assign_queue_position()
RETURNS TRIGGER AS $$
BEGIN
  NEW.queue_position := (SELECT COALESCE(MAX(queue_position), 0) + 1 FROM public.waitlist_users);
  -- First 30 signups get founding_30 tier
  IF NEW.queue_position <= 30 THEN
    NEW.tier := 'founding_30';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_assign_queue_position
  BEFORE INSERT ON public.waitlist_users
  FOR EACH ROW
  EXECUTE FUNCTION assign_queue_position();

-- Auto-update updated_at
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_updated_at
  BEFORE UPDATE ON public.waitlist_users
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at();

-- Referral leaderboard view
CREATE OR REPLACE VIEW public.referral_leaderboard AS
SELECT
  wu.id,
  wu.referral_code,
  CASE WHEN wu.show_name THEN wu.display_name ELSE 'Anonymous #' || LEFT(wu.referral_code, 4) END AS display_name,
  wu.show_name,
  COUNT(ref.id) AS referral_count,
  wu.queue_position,
  wu.created_at
FROM public.waitlist_users wu
LEFT JOIN public.waitlist_users ref ON ref.referred_by = wu.referral_code
GROUP BY wu.id, wu.referral_code, wu.display_name, wu.show_name, wu.queue_position, wu.created_at
ORDER BY referral_count DESC, wu.created_at ASC
LIMIT 10;

-- Waitlist stats view
CREATE OR REPLACE VIEW public.waitlist_stats AS
SELECT
  COUNT(*) AS total_signups,
  COUNT(*) FILTER (WHERE created_at > now() - INTERVAL '24 hours') AS signups_last_24h,
  COUNT(*) FILTER (WHERE created_at > now() - INTERVAL '7 days') AS signups_last_7d,
  MAX(queue_position) AS latest_position
FROM public.waitlist_users;

-- Row Level Security
ALTER TABLE public.waitlist_users ENABLE ROW LEVEL SECURITY;

-- Public can read leaderboard view (no personal data exposed)
-- Only service role can insert/update (via API routes)
CREATE POLICY "Service role full access" ON public.waitlist_users
  FOR ALL
  USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');

-- Anon can read limited data (for leaderboard)
CREATE POLICY "Anon read leaderboard data" ON public.waitlist_users
  FOR SELECT
  USING (true); -- View already limits columns exposed
```

**Steps:**

1. **Run migration in Supabase SQL editor or via CLI**
2. **Generate TypeScript types**

```bash
npx supabase gen types typescript --project-id your-project-id > web/src/types/database.ts
```

Or manually create the type definitions matching the schema.

3. **Verify: insert a test row and query it**
4. **Commit types file**

```bash
git add web/src/types/
git commit -m "feat(web): waitlist database schema and TypeScript types"
```

**Exit Criteria:**
- `waitlist_users` table exists with all columns
- Queue position auto-assigns on insert
- First 30 signups auto-tagged as `founding_30`
- `referral_leaderboard` view returns top 10 referrers
- `waitlist_stats` view returns aggregate counts
- RLS policies restrict writes to service role only
- TypeScript types generated

---

## Task 3.2.2: Waitlist API Routes

**What:** Create Next.js Route Handlers for the waitlist: join, check status, and leaderboard. All routes rate-limited via Upstash Redis.

**Why:** API routes are the backend for the waitlist form. They validate input, insert into Supabase, generate referral codes, trigger emails via Resend, and serve leaderboard data.

**Files:**
- Create: `web/src/app/api/waitlist/join/route.ts`
- Create: `web/src/app/api/waitlist/status/[code]/route.ts`
- Create: `web/src/app/api/waitlist/leaderboard/route.ts`
- Create: `web/src/app/api/waitlist/stats/route.ts`
- Create: `web/src/lib/rate-limit.ts` (Upstash rate limiter)
- Create: `web/src/lib/referral.ts` (nanoid code generator)
- Create: `web/src/lib/validations.ts` (Zod schemas)

**Steps:**

1. **Install dependencies**

```bash
npm install @upstash/ratelimit @upstash/redis nanoid zod
```

2. **Create rate limiter**

```typescript
// web/src/lib/rate-limit.ts
import { Ratelimit } from '@upstash/ratelimit';
import { Redis } from '@upstash/redis';

export const rateLimiter = new Ratelimit({
  redis: Redis.fromEnv(),
  limiter: Ratelimit.slidingWindow(5, '60 s'), // 5 requests per minute
  analytics: true,
});
```

3. **Create referral code generator**

```typescript
// web/src/lib/referral.ts
import { nanoid } from 'nanoid';

export function generateReferralCode(): string {
  return nanoid(8); // 8-character unique code, e.g. "V1StGXR8"
}
```

4. **Create Zod validation schemas**

```typescript
// web/src/lib/validations.ts
import { z } from 'zod';

export const joinWaitlistSchema = z.object({
  email: z.string().email('Please enter a valid email'),
  referredBy: z.string().optional(),
  displayName: z.string().max(50).optional(),
  showName: z.boolean().optional().default(false),
  quizAppsUsed: z.array(z.string()).optional().default([]),
  quizFrustration: z.string().optional(),
  quizGoal: z.string().optional(),
});

export type JoinWaitlistInput = z.infer<typeof joinWaitlistSchema>;
```

5. **Create `POST /api/waitlist/join` route**

- Rate limit check (by IP)
- Validate body with Zod
- Check if email already exists → return existing referral code
- Generate referral code via nanoid
- Insert into `waitlist_users` table (queue position auto-assigned by trigger)
- Send confirmation email via Resend (Task 3.2.3)
- If `referredBy` is provided, send referral notification to the referrer
- Return: `{ referralCode, queuePosition, totalSignups }`

6. **Create `GET /api/waitlist/status/[code]` route**

- Lookup by referral code
- Return: `{ queuePosition, referralCount, totalSignups, tier }`

7. **Create `GET /api/waitlist/leaderboard` route**

- Query `referral_leaderboard` view
- Return: top 10 array with display names and counts
- Cache with `Cache-Control: s-maxage=30` (30-second CDN cache)

8. **Create `GET /api/waitlist/stats` route**

- Query `waitlist_stats` view
- Return: `{ totalSignups, signupsLast24h }`
- Cache with `Cache-Control: s-maxage=60`

9. **Verify: test all endpoints with curl or Thunder Client**

10. **Commit**

```bash
git add .
git commit -m "feat(web): waitlist API routes - join, status, leaderboard, stats"
```

**Exit Criteria:**
- `POST /api/waitlist/join` creates a user, returns referral code + position
- Duplicate emails return existing data (idempotent)
- Rate limiting blocks more than 5 requests per minute per IP
- `GET /api/waitlist/status/:code` returns position and referral count
- `GET /api/waitlist/leaderboard` returns top 10
- All inputs validated with Zod; invalid requests return 400

---

## Task 3.2.3: Resend Email Integration

**What:** Configure Resend SDK and create React Email templates for waitlist transactional emails: welcome/confirmation, referral success notification.

**Why:** Email confirmation builds trust (users know they're on the list). Referral notifications drive viral growth ("Your friend just joined using your link!"). React Email lets us build beautiful HTML emails in JSX.

**Files:**
- Create: `web/src/lib/resend.ts` (Resend client)
- Create: `web/src/emails/waitlist-welcome.tsx` (React Email template)
- Create: `web/src/emails/referral-notification.tsx` (React Email template)

**Steps:**

1. **Install Resend and React Email**

```bash
npm install resend @react-email/components
```

2. **Create Resend client**

```typescript
// web/src/lib/resend.ts
import { Resend } from 'resend';

export const resend = new Resend(process.env.RESEND_API_KEY);
```

3. **Create Welcome Email template**

A branded React Email component showing:
- Zuralog logo
- "You're in! Position #[X]"
- Referral link: "Share this to move up the queue"
- Copy-pasteable referral URL
- Brand colors (Sage Green accent on dark background)

4. **Create Referral Notification template**

- "Someone joined using your link!"
- Updated referral count
- Current position
- CTA: "Keep sharing to climb higher"

5. **Integrate sending into the `POST /api/waitlist/join` route**

After successful insert:
- Send welcome email to the new user
- If `referredBy` is provided, send referral notification to the referrer (lookup their email by referral code)

6. **Verify: sign up with a test email, confirm both emails arrive**

7. **Commit**

```bash
git add .
git commit -m "feat(web): Resend email integration with React Email templates"
```

**Exit Criteria:**
- Welcome email arrives within 30 seconds of signup
- Referral notification arrives when someone uses a referral link
- Emails render correctly in Gmail, Apple Mail, Outlook (test with Resend preview)
- Emails use Zuralog brand colors and logo

---

## Task 3.2.4: Navbar Component

**What:** Build the sticky frosted-glass navbar with logo, smooth-scroll navigation links, "Join Waitlist" CTA, and mobile hamburger menu.

**Why:** The navbar is the persistent navigation element. Frosted glass aesthetic with scroll-aware opacity changes creates the premium feel. The CTA is always visible.

**Files:**
- Create: `web/src/components/sections/navbar.tsx`
- Create: `web/src/components/mobile-nav.tsx` (sheet-based mobile menu)
- Create: `web/src/hooks/use-scroll-progress.ts` (scroll position hook)

**Implementation Notes:**
- Frosted glass: `backdrop-filter: blur(20px) saturate(180%)` + semi-transparent surface bg
- Background opacity increases from 0% to 80% as user scrolls past 100px
- Nav links use smooth scroll to anchor IDs (#features, #how-it-works, #join)
- Mobile: hamburger icon → shadcn Sheet (full-screen overlay with Framer Motion)
- "Join Waitlist" CTA uses the primary pill button style from design system
- CTA has a subtle Sage Green glow pulse animation on idle

**Exit Criteria:**
- Navbar sticks to top on scroll
- Frosted glass effect visible
- Background opacity transitions on scroll
- Nav links smooth-scroll to correct sections
- Mobile menu opens/closes with animation
- CTA scrolls to quiz/form section

---

## Task 3.2.5: Hero Section + 3D Scene

**What:** Build the full-viewport hero section with the centerpiece 3D convergence scene: app brand icons orbiting in space, converging toward a floating iPhone model where animated Zuralog UI components assemble on the screen.

**Why:** This is the single most impactful element of the entire website. It visually communicates the product's core metaphor — fragmented health data converging into one intelligent hub. It's the "unforgettable" moment referenced in the design doc.

**Files:**
- Create: `web/src/components/sections/hero.tsx` (section wrapper)
- Create: `web/src/components/3d/hero-scene.tsx` (R3F scene)
- Create: `web/src/components/3d/phone-model.tsx` (floating phone mesh)
- Create: `web/src/components/3d/app-icon.tsx` (3D icon badge component)
- Create: `web/src/components/3d/ui-elements.tsx` (animated UI planes on phone screen)
- Create: `web/src/components/3d/effects.tsx` (bloom, ambient particles)

**3D Scene Architecture:**

```
<Canvas3D>
  ├── <ambientLight />
  ├── <Environment preset="city" /> (subtle reflections)
  ├── <PhoneModel />
  │   ├── Rounded rectangle mesh (phone body)
  │   └── <UIElements /> (planes with animated textures on "screen")
  │       ├── Chat bubble plane (fades in)
  │       ├── Metric card plane (slides in)
  │       └── Activity ring plane (scales in)
  ├── <AppIcon brand="strava" /> (orbiting, then converging)
  ├── <AppIcon brand="oura" />
  ├── <AppIcon brand="calai" />
  ├── <AppIcon brand="apple-health" />
  ├── <AppIcon brand="fitbit" />
  ├── <EffectComposer>
  │   └── <Bloom intensity={0.5} luminanceThreshold={0.8} />
  └── <AmbientParticles /> (subtle floating dust)
</Canvas3D>
```

**Animation Sequence:**
1. **Load (0–0.5s):** Phone fades in at center, slight scale-up
2. **Orbit (0.5–2s):** App icons appear at random positions, begin orbiting the phone
3. **Converge (2–3.5s or on scroll):** Icons accelerate toward phone, streak into the screen
4. **Assemble (3.5–5s):** UI components on the phone screen fade/slide in one by one
5. **Idle:** Phone gently floats (Drei `<Float>`), mouse parallax tilts 5–10°

**Performance:**
- All 3D loaded via `next/dynamic` with `ssr: false`
- DPR clamped: `Math.min(devicePixelRatio, 2)`
- Mobile: fewer icons (3 of 6), no postprocessing, simpler geometry
- Fallback: if WebGL unavailable → high-quality CSS animation or static hero image
- `<Suspense>` with styled loading skeleton (pulsing Sage Green gradient)

**Text Overlay (positioned via CSS, not 3D):**
- Headline: `display-hero` size, Satoshi Black, positioned left or center
- Sub-headline: `body-lg`, Inter Regular
- CTA button: Primary pill, scrolls to #join section
- GSAP entrance: text stagger-reveals after 3D scene loads

**Exit Criteria:**
- 3D scene renders with phone + orbiting icons
- Convergence animation plays (on load or scroll trigger)
- UI components animate onto phone screen
- Mouse parallax works on desktop
- Mobile shows simplified 3D (fewer elements, no bloom)
- WebGL fallback works
- Text overlay is readable and positioned correctly
- No layout shift during 3D load (skeleton placeholder)

---

## Task 3.2.6: Problem Statement Section

**What:** Build the "Your apps don't talk to each other" section with 3 pain-point cards and a scroll-triggered animation of scattered icons reorganizing.

**Files:**
- Create: `web/src/components/sections/problem.tsx`

**Implementation:**
- Background: subtle gradient transition from hero
- Headline: `display-section`, GSAP fade-up on scroll
- 3 cards in a responsive grid (1 col mobile, 3 col desktop)
- Each card: icon + headline + body text, staggered entrance (GSAP, 0.15s delay each)
- Visual accent: scattered app icons in background that reorganize on scroll

**Exit Criteria:**
- Section reveals on scroll with staggered card animations
- Cards match the design system (surface bg, border, radius-lg)
- Responsive: single column on mobile

---

## Task 3.2.7: Features Showcase Section

**What:** Build the 4-feature showcase with alternating text/visual layout and scroll-triggered animations for each block.

**Files:**
- Create: `web/src/components/sections/features.tsx`
- Create: `web/src/components/feature-block.tsx` (reusable alternating layout)

**4 Features:**
1. **Cross-App AI Reasoning** — Visual: animated neural network or brain mesh
2. **Autonomous Actions** — Visual: chat bubble with action cards flying out
3. **Zero-Friction Logging** — Visual: data stream from app icons into timeline
4. **One Dashboard** — Visual: metric cards assembling into a dashboard

Each block:
- Alternates text-left/visual-right and text-right/visual-left
- GSAP ScrollTrigger pins the section during animation
- Parallax depth on visual elements
- Visuals can be Framer Motion animations, Lottie, or mini R3F scenes (decide per feature based on complexity budget)

**Exit Criteria:**
- 4 feature blocks render with alternating layout
- Each block animates on scroll entry
- Responsive: stacks vertically on mobile
- Pinning works correctly without scroll jank

---

## Task 3.2.8: How It Works Section

**What:** Build the 3-step "Connect → Learn → Act" section with sequential reveal and animated connecting lines.

**Files:**
- Create: `web/src/components/sections/how-it-works.tsx`

**Implementation:**
- 3 steps displayed horizontally (desktop) or vertically (mobile)
- Each step: numbered badge + icon/animation + title + description
- Connecting line/path animates between steps as user scrolls
- Steps reveal sequentially (GSAP stagger)
- Icons: Lucide React or custom SVG with Framer Motion

**Exit Criteria:**
- 3 steps render with connecting animated lines
- Sequential reveal on scroll
- Responsive layout switches from horizontal to vertical

---

## Task 3.2.9: Interactive Quiz Component

**What:** Build the 3-question multi-step quiz with animated transitions between questions, progress indicator, and state management for answers.

**Files:**
- Create: `web/src/components/quiz/quiz-container.tsx`
- Create: `web/src/components/quiz/quiz-step.tsx` (generic step wrapper)
- Create: `web/src/components/quiz/apps-selection.tsx` (Q1: multi-select grid)
- Create: `web/src/components/quiz/frustration-selection.tsx` (Q2: single-select)
- Create: `web/src/components/quiz/goal-selection.tsx` (Q3: single-select)
- Create: `web/src/components/quiz/progress-indicator.tsx` (3-dot stepper)
- Create: `web/src/hooks/use-quiz.ts` (quiz state management)

**Quiz Flow:**

```
Q1: "What fitness apps do you use?"
→ Multi-select grid of app icons with labels:
  [ Strava ] [ CalAI ] [ MyFitnessPal ] [ Fitbit ] [ Oura ]
  [ Apple Health ] [ Google Fit ] [ WHOOP ] [ Garmin ] [ Other ]
→ "Next" button (enabled after ≥1 selection)

Q2: "What's your biggest frustration?"
→ Single-select radio cards:
  [ Too many apps, none connected ]
  [ I have data but no insights ]
  [ Logging everything is exhausting ]
→ Auto-advance on selection (or "Next" button)

Q3: "What's your primary health goal?"
→ Single-select radio cards:
  [ Lose weight ] [ Build muscle ] [ Sleep better ]
  [ General wellness ] [ Train for an event ]
→ Auto-advance on selection

→ Transition to email input (Task 3.2.10)
```

**Animation:**
- Framer Motion `AnimatePresence` with `mode="wait"` for step transitions
- Each step slides in from right, exits to left
- Progress indicator: 3 dots with Sage Green fill animation
- Selection cards have hover scale + border glow

**Exit Criteria:**
- 3-question quiz navigates forward and backward
- Multi-select works for Q1, single-select for Q2 and Q3
- Progress indicator updates
- Answers stored in state for submission with email
- Smooth animated transitions between steps
- Accessible: keyboard navigable, focus management

---

## Task 3.2.10: Waitlist Signup Form

**What:** Build the email signup form that appears after the quiz. On submit, sends quiz answers + email to the API. Shows success state with referral code, position, and share buttons.

**Files:**
- Create: `web/src/components/waitlist-form.tsx`
- Create: `web/src/components/success-panel.tsx` (post-signup reveal)
- Create: `web/src/components/share-buttons.tsx` (X/Twitter, copy link)

**Implementation:**
- Large email input (design system Input component) + "Join the Waitlist" CTA
- React Hook Form + Zod validation
- On submit:
  - Show loading state (CTA button → spinner)
  - `POST /api/waitlist/join` with email + quiz answers + referral code (from URL param)
  - On success: `AnimatePresence` transition to success panel
  - On error: Sonner toast with error message
- Success panel:
  - Confetti/particle burst animation (can use canvas-confetti or Framer Motion)
  - "You're #[position] of [total]!"
  - Referral link (copyable): `https://domain.com?ref=[code]`
  - "Copy Link" button with Sonner toast "Link copied!"
  - "Share on X" button (pre-filled tweet)
  - "Invite 3 friends to jump 50 spots" incentive text
- Detect returning users: check `localStorage` for referral code → auto-show success panel

**Exit Criteria:**
- Email validates before submit
- API call succeeds and returns referral code + position
- Success panel reveals with animation
- Referral link is correct and copyable
- Share on X opens pre-filled tweet
- Returning users see their existing status
- Error states handled with toast messages

---

## Task 3.2.11: Referral System & Leaderboard

**What:** Build the social proof section: live waitlist counter, top-10 referral leaderboard, and personal rank card for returning users.

**Files:**
- Create: `web/src/components/sections/social-proof.tsx`
- Create: `web/src/components/leaderboard.tsx`
- Create: `web/src/components/waitlist-counter.tsx`
- Create: `web/src/components/personal-rank.tsx`

**Implementation:**
- **Live counter:** Fetches from `/api/waitlist/stats`. Animated number counting up (Framer Motion `useMotionValue` + `useTransform`).
- **Leaderboard:** Fetches from `/api/waitlist/leaderboard`. Table/list with rank, display name, referral count. Anonymized by default ("Anonymous #V1St") with real names for opt-in users. Styled as a card with subtle glow.
- **Personal rank card:** Shown if user's referral code is in `localStorage`. Shows their position, referral count, and CTA to share more. Positioned above the leaderboard.
- **Referral URL handling:** On page load, check for `?ref=` query parameter. Store in `sessionStorage` to pass to the join API when the user signs up.

**Exit Criteria:**
- Live counter animates on scroll-into-view
- Leaderboard shows top 10 with correct anonymization
- Returning users see their personal rank
- `?ref=` parameter is captured and used during signup
- Data refreshes on a reasonable interval (30s for leaderboard)

---

## Task 3.2.12: Footer Component

**What:** Build the minimal footer with logo, tagline, legal links, and social icons.

**Files:**
- Create: `web/src/components/sections/footer.tsx`

**Implementation:**
- Dark background (slightly elevated from page bg)
- Logo + tagline placeholder
- Links: Privacy Policy (placeholder `/privacy`), Terms of Service (placeholder `/terms`), Contact (mailto)
- Social icons: X/Twitter, Instagram (Lucide icons)
- "© 2026 Zuralog. All rights reserved."
- Responsive: single column on mobile

**Exit Criteria:**
- Footer renders at the bottom of the page
- Links are functional (even if pointing to placeholder pages)
- Social icons link to correct profiles (or placeholder URLs)

---

## Task 3.2.13: Responsive Design & Mobile Optimization

**What:** Full responsive audit and optimization pass across all sections. Ensure the 3D scene degrades gracefully on mobile.

**Files:**
- Modify: All section components
- Create: `web/src/hooks/use-device.ts` (device detection for 3D)

**Key Areas:**
- **Navbar:** Hamburger menu on < 768px
- **Hero 3D:** On mobile: reduce icons to 3, disable bloom, lower DPR to 1.5, or show CSS-animated static fallback
- **Feature blocks:** Stack vertically on mobile
- **Quiz:** Full-width cards on mobile
- **Leaderboard:** Horizontal scroll on small screens
- **Typography:** `clamp()` values verified at all breakpoints
- **Touch targets:** Minimum 44x44px on all interactive elements
- **Test:** iOS Safari, Android Chrome, tablet landscape

**Exit Criteria:**
- No horizontal overflow at any breakpoint
- 3D scene doesn't crash or freeze on mobile devices
- All interactive elements meet minimum touch target size
- Typography is readable at all sizes
- Layout looks intentional (not just "squeezed") on mobile

---

## Task 3.2.14: Performance Optimization

**What:** Optimize bundle size, loading strategy, and runtime performance to hit Lighthouse targets.

**Files:**
- Modify: `web/next.config.ts` (bundle analyzer)
- Modify: Various components (dynamic imports)

**Key Optimizations:**
- **Dynamic imports:** All Three.js/R3F components loaded via `next/dynamic({ ssr: false })`
- **Font optimization:** `next/font` with `display: swap`, subset to Latin
- **Image optimization:** All images via `next/image` with WebP/AVIF
- **Bundle analysis:** Run `@next/bundle-analyzer` to identify heavy chunks
- **Code splitting:** Ensure the 3D chunk doesn't block initial paint
- **Prefetch:** Quiz section lazy-loaded, prefetched on hero CTA hover
- **Cache headers:** Static assets with long cache, API responses with short cache

**Performance Targets:**
| Metric | Desktop | Mobile |
|---|---|---|
| Lighthouse Performance | > 95 | > 85 |
| FCP | < 1.2s | < 1.8s |
| LCP | < 2.0s | < 3.0s |
| CLS | < 0.05 | < 0.1 |
| TBT | < 150ms | < 300ms |

**Exit Criteria:**
- Lighthouse desktop > 95, mobile > 85
- 3D chunk loads asynchronously (doesn't block FCP)
- Total initial JS < 200KB gzipped (excluding lazy chunks)
- No layout shifts visible during page load

---

## Task 3.2.15: Custom Cursor + Immersive Polish

**What:** Add the Awwwards-tier polish: custom cursor, page load animation sequence, grain texture refinement, and micro-interactions.

**Files:**
- Create: `web/src/components/custom-cursor.tsx`
- Create: `web/src/components/page-loader.tsx` (initial load sequence)
- Modify: Various components (hover micro-interactions)

**Custom Cursor:**
- Outer ring (24px, border, follows mouse with spring physics `damping: 30`)
- Inner dot (8px, Sage Green, direct follow)
- Expands on hovering interactive elements
- Hidden on mobile (touch devices)
- Disabled when `prefers-reduced-motion`

**Page Load Sequence:**
1. Black screen with Zuralog logo centered → logo fades in (0.3s)
2. Logo scales down and moves to navbar position (0.4s)
3. Headline text reveals (staggered characters or words, 0.5s)
4. Sub-headline fades in (0.2s)
5. CTA slides up (0.2s)
6. 3D scene begins rendering
7. Total sequence: ~1.5s before full interaction

**Micro-Interactions:**
- Button hover: scale(1.02) + subtle glow
- Card hover: border brightens + slight lift
- Nav link hover: underline draws from left
- Input focus: border glows Sage Green
- Copy button: checkmark animation on click

**Exit Criteria:**
- Custom cursor follows mouse with smooth spring physics
- Cursor expands on interactive elements
- Page load sequence plays on first visit
- All hover states have subtle but noticeable interactions
- Everything disabled with `prefers-reduced-motion`

---

## Task 3.2.16: SEO, Open Graph & Launch Readiness

**What:** Finalize all SEO meta tags, Open Graph images, structured data, and ensure the site is ready for social sharing.

**Files:**
- Modify: `web/src/app/layout.tsx` (finalize metadata)
- Create: `web/src/app/opengraph-image.tsx` (dynamic OG image, optional)
- Create: `web/public/og-image.png` (static OG image)
- Modify: `web/next-sitemap.config.js`

**Checklist:**
- [ ] Title tag: "Zuralog — [Tagline]"
- [ ] Meta description: compelling 155-char summary
- [ ] OG image (1200x630): dark bg, logo, tagline, "Join the waitlist"
- [ ] Twitter card: `summary_large_image`
- [ ] JSON-LD structured data: Organization schema
- [ ] Canonical URL set
- [ ] `robots.txt` allows indexing
- [ ] `sitemap.xml` includes `/`
- [ ] Test with: Facebook Sharing Debugger, Twitter Card Validator, LinkedIn Post Inspector
- [ ] Verify Google can render the page (Google Search Console URL inspection)

**Exit Criteria:**
- Sharing the URL on Twitter/X shows a rich card with OG image
- Sharing on LinkedIn shows correct preview
- Google Search Console can crawl and index the page
- No SEO warnings in Lighthouse

---

## Task 3.2.17: E2E Testing & Final QA

**What:** Write Playwright end-to-end tests for the critical user flow and perform cross-browser QA.

**Files:**
- Create: `web/e2e/waitlist-flow.spec.ts`
- Create: `web/e2e/referral-flow.spec.ts`
- Create: `web/e2e/responsive.spec.ts`
- Create: `web/playwright.config.ts`

**Steps:**

1. **Install Playwright**

```bash
cd web
npm install -D @playwright/test
npx playwright install
```

2. **Write E2E tests:**

```typescript
// e2e/waitlist-flow.spec.ts
test('full waitlist signup flow', async ({ page }) => {
  await page.goto('/');
  
  // Navigate to quiz section
  await page.click('text=Join the Waitlist');
  
  // Complete quiz
  await page.click('[data-app="strava"]'); // Q1: select Strava
  await page.click('text=Next');
  await page.click('text=Too many apps'); // Q2
  await page.click('text=Lose weight'); // Q3
  
  // Submit email
  await page.fill('[name="email"]', 'test@example.com');
  await page.click('text=Join the Waitlist');
  
  // Verify success
  await expect(page.locator('text=You\'re in!')).toBeVisible();
  await expect(page.locator('[data-testid="referral-code"]')).toBeVisible();
  await expect(page.locator('[data-testid="queue-position"]')).toBeVisible();
});

test('referral link captured from URL', async ({ page }) => {
  await page.goto('/?ref=TEST1234');
  // ... complete signup
  // Verify referral was tracked
});
```

3. **Cross-browser testing:**
- Chrome (latest)
- Firefox (latest)
- Safari (latest, macOS)
- Edge (latest)
- Mobile Safari (iOS)
- Mobile Chrome (Android)

4. **Accessibility audit:**
- Run Lighthouse accessibility audit (target > 90)
- Keyboard-only navigation test (tab through entire page)
- Screen reader test with VoiceOver/NVDA
- Color contrast verification

5. **Final QA checklist:**
- [ ] All sections render correctly
- [ ] 3D scene loads without errors
- [ ] Quiz flow works end-to-end
- [ ] Emails deliver
- [ ] Leaderboard updates
- [ ] Responsive on all breakpoints
- [ ] Dark mode is default
- [ ] Light mode works
- [ ] `prefers-reduced-motion` respected
- [ ] No console errors
- [ ] No memory leaks (3D cleanup)
- [ ] Custom domain SSL valid
- [ ] OG image previews correctly

6. **Commit**

```bash
git add .
git commit -m "test(web): E2E Playwright tests for waitlist flow"
```

**Exit Criteria:**
- All Playwright tests pass
- Cross-browser visual check complete
- Lighthouse: Performance > 85 mobile / > 95 desktop, Accessibility > 90
- No console errors in any browser
- Full signup → referral → leaderboard flow works in production environment

---

## Phase 3.2 Exit Criteria (All Tasks)

- [ ] Full single-page waitlist site live on custom domain
- [ ] 3D hero renders on desktop and degrades gracefully on mobile
- [ ] Quiz → Signup → Referral code flow works end-to-end
- [ ] Confirmation email arrives via Resend within 30 seconds
- [ ] Referral notification email sent to referrer
- [ ] Leaderboard displays top 10 referrers (anonymous/named)
- [ ] Queue position updates when referred users sign up
- [ ] First 30 signups auto-flagged as `founding_30` tier
- [ ] Live waitlist counter shows total signups
- [ ] Custom cursor, smooth scroll, page load sequence all functional
- [ ] Lighthouse desktop > 95, mobile > 85
- [ ] All Playwright E2E tests pass
- [ ] OG image renders correctly on Twitter/X and LinkedIn
- [ ] `prefers-reduced-motion` disables all heavy animations
- [ ] PostHog tracks: page views, quiz starts, quiz completions, signups, referral link clicks, leaderboard views
- [ ] No console errors, no memory leaks, no layout shifts

---

## Rewards Logic Summary

| Reward | Trigger | Database Field |
|---|---|---|
| **Founding 30** — 1 month free Pro | First 30 signups (by queue_position) | `tier = 'founding_30'` (auto-set by trigger) |
| **Top 30 Referrers** — 3 months free Pro | Top 30 by referral_count at app launch | `tier = 'top_referrer'` (computed at launch time) |

Both tiers are flagged in the database. Actual Pro subscription provisioning happens at mobile app launch (Phase 2+) — the waitlist just tracks eligibility.

---

## PostHog Event Tracking Plan

| Event | When | Properties |
|---|---|---|
| `page_view` | Auto (PostHog default) | URL, referrer |
| `waitlist_quiz_started` | User clicks first quiz option | — |
| `waitlist_quiz_completed` | User finishes Q3 | `apps_used`, `frustration`, `goal` |
| `waitlist_signup_attempted` | User submits email | `has_referral: bool` |
| `waitlist_signup_success` | API returns 200 | `queue_position`, `tier` |
| `waitlist_signup_error` | API returns error | `error_type` |
| `waitlist_referral_copied` | User copies referral link | `referral_code` |
| `waitlist_share_twitter` | User clicks X/Twitter share | `referral_code` |
| `waitlist_leaderboard_viewed` | Leaderboard section enters viewport | — |
