# Executed Phase 3.2 — Waitlist Landing Page

**Branch:** `feat/phase-3.2-waitlist-landing-page`
**Latest commit:** `8de00a6`
**Date:** 2026-02-24
**Build status:** Clean — zero TypeScript errors, `npm run build` succeeds across all sessions

---

## Summary

Full ZuraLog waitlist landing page implemented as a single-page Next.js 16 app. This document covers
the complete work across two sessions: the initial build (commits `43ceb6b`–`9efcd9c`) and the
improvement pass (commits `783024b`–`8de00a6`).

### Core infrastructure (session 1)
- **7 content sections** — Navbar, Hero, Problem, Features, HowItWorks, WaitlistSection, Footer
- **Interactive quiz funnel** — 3-step onboarding (AppsStep, FrustrationsStep, GoalStep) before signup, managed by `useQuiz` hook
- **Waitlist signup form** — email + optional referral code, submits to `/api/waitlist/join`, shows success panel with referral code + share buttons
- **Referral leaderboard** — live sidebar on desktop showing top referrers, polling `/api/waitlist/leaderboard`
- **4 API routes** — `/join` (rate-limited, Zod-validated), `/status/[code]`, `/leaderboard`, `/stats`
- **Email templates** — `WaitlistWelcome` and `ReferralNotification` built with `@react-email/components`
- **PageLoader** — animated logo splash screen that fades out after 1.8s

### Improvements (session 2 — commit `783024b`)
- **Branding** — corrected capitalisation from `Zuralog` → `ZuraLog` across all 20 user-facing files (comments/docs untouched)
- **Light/dark theme toggle** — sun/moon button added to Navbar; uses `next-themes` `useTheme`; `ThemeProvider` was already wired in `layout.tsx`, only the UI was missing
- **Real brand logos in quiz** — `@icons-pack/react-simple-icons` replaces emoji in `apps-step.tsx`; Strava, Apple, Garmin, Fitbit, Peloton, Google use SVG icons; WHOOP, Oura, and MyFitnessPal fall back to styled letter badges
- **Logo image** — `public/logo.png` (existing transparent PNG) replaces the `ZURALOG` text wordmark in Navbar, PageLoader, and Footer
- **`/waitlist` redirect route** — `app/waitlist/page.tsx` issues a server-side `redirect('/?scroll=waitlist')`; `ScrollHandler` client component reads the `?scroll=` param on the homepage and auto-scrolls to `#waitlist`
- **Preview/dev mode** — `NEXT_PUBLIC_PREVIEW_MODE=true` in `.env.local` bypasses all Supabase calls and email sends in `/api/waitlist/join`, returning a simulated success response; safe to commit since default is `false`
- **Cursor trail** — `CursorTrail` component added to root `layout.tsx`; a sage-green radial glow lerps toward the mouse via `requestAnimationFrame`; renders only on `pointer: fine` devices

### 3D hero scene fix (session 2 — commits `1063e9c`, `8de00a6`)
The original Three.js hero scene was invisible due to three compounding bugs. After an incorrect
intermediate fix (CSS-only glow fallback), the 3D scene was fully restored:

| Bug | Cause | Fix |
|-----|-------|-----|
| `alpha: false` on Canvas | WebGL painted a solid black background, hiding all geometry | Changed to `alpha: true` |
| Canvas in `-z-10` wrapper | Sat behind the `bg-black` section div — completely occluded | Moved to `z-10`, above CSS glow layer |
| No `scene.background = null` | Three.js defaulted to an opaque scene background | Explicit `scene.background = null` in `useEffect` |

Additional scene improvements made alongside the fix:
- `emissiveIntensity` on app icons raised to **2.5**; screen UI bars at **1.8** — clearly visible against dark background
- Lighting: ambient **2.0**, front point light **8 intensity**, directional **3** — scene unmistakably lit
- 6 orbiting app icons (was 5), representing: Strava, Spotify, Garmin, Apple Health, Oura, Fitbit
- Mouse parallax multipliers strengthened (0.15 → 0.3 on Y, 0.1 → 0.2 on X)
- Bloom: `luminanceThreshold` lowered to **0.1**, `intensity` raised to **1.5** with `mipmapBlur`
- `HeroGlow` (CSS radial sage gradient) kept as the atmospheric underlay beneath the transparent Canvas

**Final hero layer stack (back → front):**
```
z-0   HeroGlow       — CSS sage radial glow (atmosphere)
z-10  Canvas         — transparent WebGL (phone + orbiting icons)
z-20  bottom fade    — gradient blending into next section
z-30  text content   — headline, CTAs
```

---

## Deviations from Plan

### 1. Leaderboard route: direct query instead of view
**Plan:** Query the `referral_leaderboard` Supabase view.
**Reality:** The view throws a Postgres error (`WITHIN GROUP is required for ordered-set aggregate rank`) during static generation.
**Fix:** Query `waitlist_users` directly, ordered by `referral_count desc`, with client-side rank computation and email masking. Route marked `force-dynamic`.

### 2. No `supportsWebGL` check in `useDevice`
**Plan:** `hero-scene-loader.tsx` expected `supportsWebGL` from `useDevice`.
**Reality:** Hook was not implemented in the prior session.
**Fix:** Removed WebGL gating; Three.js handles incapable devices gracefully.

### 3. `roundedBoxGeometry` → `RoundedBox`
**Plan:** Used `<roundedBoxGeometry>` JSX (non-standard).
**Reality:** Not a valid R3F intrinsic — `@react-three/drei` exports `RoundedBox` as a component.
**Fix:** Replaced all instances with `<RoundedBox args={[...]} radius={...} smoothness={...}>`.

### 4. Zod v4 API change
**Plan:** Used `parsed.error.errors[0]`.
**Reality:** Zod v4 uses `.issues` not `.errors`.
**Fix:** Updated to `parsed.error.issues[0]`.

### 5. 3D hero — temporary CSS regression
During debugging the invisible 3D scene, an intermediate commit (`1063e9c`) replaced the Three.js Canvas
entirely with a CSS radial glow. This was identified as incorrect (the original intent was a 3D phone model)
and reverted in `8de00a6` which restored the full Three.js scene with the correct alpha/z-index architecture.

### 6. Previous session claims vs reality
The prior session claimed many files were written but were not on disk. This session rewrote everything from scratch with verified file writes.

---

## Architecture Decisions

- **Quiz before signup** — shows commitment + personalises the experience before asking for email; reduces low-intent signups
- **Referral leaderboard as sidebar** — visible during signup to trigger FOMO and motivate sharing immediately after joining
- **`force-dynamic` on leaderboard** — avoids stale data and the broken view issue; leaderboard is fresh on every request
- **PageLoader 1.8s** — gives Three.js Canvas time to initialise WebGL before dismissing the splash, preventing a visible blank flash
- **CSS glow + 3D Canvas layered** — the `HeroGlow` CSS underlay ensures a visually rich background even during the brief WebGL init window, while the Canvas provides the interactive 3D phone once loaded
- **Preview mode via env var** — `NEXT_PUBLIC_PREVIEW_MODE` pattern is safe to expose client-side (it's a dev toggle, not a secret); makes local iteration fast without a live Supabase project

---

## Files Added / Modified (session 2)

| File | Change |
|------|--------|
| `src/components/sections/navbar.tsx` | Logo image + theme toggle |
| `src/components/sections/footer.tsx` | Logo image + ZuraLog branding |
| `src/components/ui/page-loader.tsx` | Logo image replaces text wordmark |
| `src/components/quiz/apps-step.tsx` | Real brand SVG icons via simple-icons |
| `src/components/3d/hero-scene.tsx` | Full rewrite — scene.background=null, boosted lighting/emissive |
| `src/components/3d/hero-scene-loader.tsx` | alpha:true, correct Canvas positioning |
| `src/components/sections/hero.tsx` | Correct z-index layering, HeroGlow + Canvas stack |
| `src/components/hero-glow.tsx` | New — CSS radial glow underlay with mouse parallax |
| `src/components/cursor-trail.tsx` | New — sage glow that tracks cursor |
| `src/components/scroll-handler.tsx` | New — reads `?scroll=` param, triggers smooth scroll |
| `src/app/waitlist/page.tsx` | New — server redirect to `/?scroll=waitlist` |
| `src/app/page.tsx` | Wires in ScrollHandler |
| `src/app/layout.tsx` | Wires in CursorTrail |
| `src/app/api/waitlist/join/route.ts` | Preview mode bypass |
| 20 user-facing files | `Zuralog` → `ZuraLog` branding fix |

---

## What's Ready for Next Phase

- The landing page is fully functional and deployable to Vercel
- Remaining to configure (outside code):
  - `RESEND_API_KEY` in Vercel env vars to enable transactional emails
  - `UPSTASH_REDIS_REST_URL` + `UPSTASH_REDIS_REST_TOKEN` for production rate limiting (falls back gracefully without them)
  - Fix the `referral_leaderboard` Supabase view SQL (the `rank()` window function syntax)
- E2E Playwright tests were deferred — can be added in a follow-up
- OG image (`opengraph-image.tsx`) exists from Phase 3.1; content can be updated to reflect ZuraLog branding
