# Executed Phase 3.2 — Waitlist Landing Page

**Branch:** `feat/phase-3.2-waitlist-landing-page`
**Commit:** `e3779ee`
**Date:** 2026-02-24
**Build status:** Clean — zero TypeScript errors, `npm run build` succeeds

---

## Summary

Full Zuralog waitlist landing page implemented as a single-page Next.js 16 app with:

- **3D hero section** — Three.js/R3F scene with an animated phone model (rounded box), 5 orbiting app-icon spheres (converge on timeout), ambient particles, bloom postprocessing, and mouse parallax tilt
- **7 content sections** — Navbar, Hero, Problem, Features, HowItWorks, WaitlistSection, Footer
- **Interactive quiz funnel** — 3-step onboarding (AppsStep, FrustrationsStep, GoalStep) before signup, managed by `useQuiz` hook
- **Waitlist signup form** — email + optional referral code, submits to `/api/waitlist/join`, shows success panel with referral code + share buttons
- **Referral leaderboard** — live sidebar on desktop showing top referrers, polling `/api/waitlist/leaderboard`
- **4 API routes** — `/join` (rate-limited, Zod-validated), `/status/[code]`, `/leaderboard`, `/stats`
- **Email templates** — `WaitlistWelcome` and `ReferralNotification` built with `@react-email/components`
- **PageLoader** — animated ZURALOG splash screen that fades out after 1.8s

---

## Deviations from Plan

### 1. Leaderboard route: direct query instead of view
**Plan:** Query the `referral_leaderboard` Supabase view.
**Reality:** The view throws a Postgres error (`WITHIN GROUP is required for ordered-set aggregate rank`) during static generation.
**Fix:** Query `waitlist_users` directly, ordered by `referral_count desc`, with client-side rank computation and email masking. Route marked `force-dynamic`.

### 2. No `supportsWebGL` check in `useDevice`
**Plan (previous session):** `hero-scene-loader.tsx` expected `supportsWebGL` from `useDevice`.
**Reality:** Not implemented in the previous session's `useDevice` hook (which was missing entirely).
**Fix:** Removed the WebGL gating from `hero-scene-loader.tsx`. The Canvas will simply not render on truly incapable devices; Three.js handles this gracefully.

### 3. `roundedBoxGeometry` → `RoundedBox`
**Plan:** Used `<roundedBoxGeometry>` JSX elements (non-standard R3F three.js JSX).
**Reality:** This is not a valid JSX intrinsic — `@react-three/drei` exports `RoundedBox` as a component, not a geometry element.
**Fix:** Replaced all `<mesh><roundedBoxGeometry .../></mesh>` patterns with `<RoundedBox args={[...]} radius={...} smoothness={...}>` from `@react-three/drei`.

### 4. Zod v4 API change
**Plan:** Used `parsed.error.errors[0]`.
**Reality:** Zod v4 uses `.issues` not `.errors`.
**Fix:** Updated to `parsed.error.issues[0]`.

### 5. Email template inline style duplicate
Minor JSX bug — two `style` props on one `<Text>` element.
**Fix:** Merged into `style={{ ...footerText, marginTop: '32px' }}`.

### 6. Previous session claims vs reality
The previous session claimed many files were written but they were not actually on disk (API routes were empty directories, hooks/lib files missing). This session rewrote everything from scratch with verified file writes.

---

## Architecture Decisions

- **Quiz before signup** — shows commitment + personalizes the experience before asking for email; reduces low-intent signups
- **Referral leaderboard as sidebar** — visible during signup to trigger FOMO and motivate sharing immediately after joining
- **`force-dynamic` on leaderboard** — avoids stale data and the broken view issue; leaderboard is fresh on every request
- **PageLoader 1.8s** — gives Three.js Canvas time to initialize WebGL before dismissing the splash, preventing visible blank flash

---

## What's Ready for Next Phase

- The landing page is fully functional and deployable to Vercel
- Remaining to configure (outside code):
  - `RESEND_API_KEY` in `.env.local` / Vercel env vars to enable transactional emails
  - `UPSTASH_REDIS_REST_URL` + `UPSTASH_REDIS_REST_TOKEN` for production rate limiting (falls back gracefully without them)
  - Fix the `referral_leaderboard` Supabase view SQL (the `rank()` window function syntax)
- E2E Playwright tests (Phase 3.2.17) were deferred — can be added in a follow-up
- SEO / OG image (Phase 3.2.16) — the `opengraph-image.tsx` file exists from Phase 3.1; content can be updated
