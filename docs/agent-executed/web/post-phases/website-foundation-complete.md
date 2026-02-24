# Website Foundation Complete — Phase 3.1 Post-Phase Summary

**Date:** 2026-02-24
**Branch:** `feat/phase-3.1` (merged to `main`)
**Agent:** Claude Code (claude-sonnet-4-6)
**Status:** Complete — live at `https://www.zuralog.com`

---

## Overview

Phase 3.1 delivered the complete Next.js website foundation at `web/` within the monorepo. The site is deployed to Vercel, pointing at the custom domain `www.zuralog.com`, with all infrastructure wired: Supabase client, PostHog analytics, design tokens, animation stack, 3D (Three.js/R3F), and brand assets.

This document covers the post-phase state — what a developer needs to know to continue work on the website.

---

## What Was Delivered

### Infrastructure
- **Next.js 16.x** with TypeScript and App Router, at `web/` in the monorepo
- **Tailwind v4** (CSS-first, no `tailwind.config.ts`) — all tokens in `globals.css` via `@theme inline`
- **shadcn/ui** (Button, Input, Dialog, Sheet, Badge, Separator, Sonner) — via `components.json`
- **Vercel** deployment — root directory set to `web`, auto-deploys on push to `main`

### Design System (Bold Convergence)
- OLED black (`#000000`) dark background, `#FAFAFA` light background
- Sage Green primary: `#CFE1B9`
- Fonts: Satoshi Variable (local `.woff2` in `public/fonts/`), Inter, JetBrains Mono
- Film grain overlay: `src/styles/grain.css`
- All tokens exported as CSS variables from `globals.css`

### Animation Stack
- **GSAP + ScrollTrigger** — registered in `src/lib/gsap.ts`, hook in `src/hooks/use-gsap.ts`
- **Framer Motion** — preset variants in `src/components/motion-wrapper.tsx`
- **Lenis smooth scroll** — synced to GSAP ticker in `src/components/smooth-scroll.tsx`

### 3D (Three.js / React Three Fiber)
- `Canvas3D` wrapper at `src/components/3d/canvas-3d.tsx` (DPR clamped, alpha, WebGL-compatible)
- `hero-scene-loader.tsx` — a `'use client'` wrapper required because `next/dynamic` with `ssr: false` cannot be used directly in Server Component pages
- `test-scene.tsx` — floating Sage Green sphere for verification (to be replaced in Phase 3.2)

### Backend Connections
- Supabase browser client (anon key): `src/lib/supabase/client.ts`
- Supabase server client (service role): `src/lib/supabase/server.ts`
- Typed schema placeholder: `src/types/database.ts` — regenerate when tables are created

### Analytics & SEO
- Vercel Analytics + SpeedInsights wired in root layout
- PostHog provider in `src/components/analytics.tsx`
- `robots.ts` and `sitemap.ts` (programmatic generation)
- Dynamic OG image via `opengraph-image.tsx` using Next.js `ImageResponse`

### Brand Assets
- Favicon set: 16×16, 32×32, 180×180 (Apple Touch), 512×512
- `logo.svg` and `logo.png` in `public/`
- `site.webmanifest`

---

## Live Environment

| Item | Value |
|---|---|
| Production URL | `https://www.zuralog.com` |
| Redirect | `zuralog.com` → 301 → `www.zuralog.com` |
| SSL | Auto-provisioned by Vercel |
| Vercel root directory | `web` |
| Supabase project | ZuraLog Project (`enccjffwpnwkxfkhargr`) |
| Supabase region | `us-east-1` |
| DNS (Namecheap) | A `@` → `216.198.79.1`; CNAME `www` → `0a7f1a4c89fcdba7.vercel-dns-017.com.` |

---

## Environment Variables

All env vars are documented in `web/.env.example`. Developers copy this to `web/.env.local` and fill in real values.

| Variable | Required | Source |
|---|---|---|
| `NEXT_PUBLIC_SUPABASE_URL` | Yes | Supabase → Project Settings → API → Project URL |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | Yes | Supabase → Project Settings → API → `anon public` key |
| `SUPABASE_SERVICE_ROLE_KEY` | Yes | Supabase → Project Settings → API → `service_role` key |
| `RESEND_API_KEY` | Phase 3.2 | [resend.com](https://resend.com) → API Keys |
| `UPSTASH_REDIS_REST_URL` | Phase 3.2 | [console.upstash.com](https://console.upstash.com) → Redis → REST URL |
| `UPSTASH_REDIS_REST_TOKEN` | Phase 3.2 | [console.upstash.com](https://console.upstash.com) → Redis → REST Token |
| `NEXT_PUBLIC_POSTHOG_KEY` | Optional | [posthog.com](https://posthog.com) → Project Settings → API Key |
| `NEXT_PUBLIC_POSTHOG_HOST` | Optional | Default: `https://us.i.posthog.com` |
| `NEXT_PUBLIC_SITE_URL` | Yes | `https://www.zuralog.com` (production) or `http://localhost:3000` (local) |

> `SUPABASE_SERVICE_ROLE_KEY` has full admin access. Never commit it to Git.

---

## Key Deviations from Original Phase 3.1 Plan

1. **Next.js 16.x** — `create-next-app@latest` resolved to 16.1.6 (not 15.x). No functional difference.
2. **Tailwind v4 CSS-first** — no `tailwind.config.ts`; all tokens live in `globals.css` via `@theme inline`.
3. **Satoshi font via local files** — not on Google Fonts or @fontsource. Downloaded from Fontshare, extracted `Satoshi-Variable.woff2` / `Satoshi-VariableItalic.woff2`, committed to `public/fonts/`.
4. **`next/dynamic` SSR wrapper** — `ssr: false` requires a `'use client'` component. Created `hero-scene-loader.tsx` as the bridge so `page.tsx` stays a Server Component.
5. **Dynamic OG image** — implemented as `opengraph-image.tsx` (Next.js `ImageResponse`) rather than a static PNG for maintainability.

---

## What Phase 3.2 Will Need

Phase 3.2 is the Waitlist Landing Page. Before starting, confirm:

- [ ] Resend account created (free tier: 100 emails/day, 3,000/month)
- [ ] Upstash Redis instance created (free tier: 10,000 requests/day)
- [ ] `RESEND_API_KEY` and `UPSTASH_REDIS_REST_*` added to both `web/.env.local` and Vercel dashboard
- [ ] Plan: `docs/plans/web/phases/phase-3.2-waitlist-landing-page.md`
- [ ] Replace `src/components/3d/test-scene.tsx` with the real hero convergence scene
- [ ] Regenerate `src/types/database.ts` after creating the `waitlist_users` table in Supabase
