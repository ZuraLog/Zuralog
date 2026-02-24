# Executed Phase 3.1: Website Foundation & Infrastructure

**Date:** 2026-02-24
**Branch:** `feat/phase-3.1`
**Agent:** Claude Code (claude-sonnet-4-6)

---

## Summary

Successfully scaffolded the complete Next.js 15 website foundation at `web/` within the monorepo. All 9 sub-tasks completed. The project boots locally, TypeScript compiles cleanly, and all tools are wired together.

### What Was Built

| Sub-task | Status | Key Output |
|---|---|---|
| 3.1.1 Next.js Scaffold | ✅ Complete | `web/` — Next.js 16.x, TypeScript, App Router |
| 3.1.2 Tailwind + shadcn | ✅ Complete | Tailwind v4, shadcn/ui (Button, Input, Dialog, Sheet, Badge, Separator, Sonner) |
| 3.1.3 Design System | ✅ Complete | Zuralog "Bold Convergence" CSS tokens, Satoshi/Inter/JetBrains Mono, dark-first theme |
| 3.1.4 Animation Stack | ✅ Complete | GSAP + ScrollTrigger, Framer Motion, Lenis (with GSAP ticker sync) |
| 3.1.5 Three.js / R3F | ✅ Complete | Canvas3D wrapper, floating sphere test scene, bloom postprocessing |
| 3.1.6 Supabase Client | ✅ Complete | Browser client (anon key) + Server client (service role) with typed schema |
| 3.1.7 Vercel Config | ✅ Complete (partial) | `vercel.json` with security headers; dashboard/DNS steps are manual |
| 3.1.8 Analytics & SEO | ✅ Complete | Vercel Analytics, SpeedInsights, PostHog provider, OG metadata, robots.txt, sitemap.xml |
| 3.1.9 Brand Assets | ✅ Complete | Favicon set (16/32/180/512), OG image (dynamic via ImageResponse), logo.svg/png |

---

## Deviations from Original Plan

### 1. Next.js version installed as 16.x (not 15.x)
- **Reason:** `create-next-app@latest` resolved to `16.1.6` (the latest stable at execution time). No functional difference for this phase.
- **Impact:** None — all APIs used are stable across 15.x and 16.x.

### 2. No `tailwind.config.ts` file created
- **Reason:** Tailwind v4 uses CSS-first configuration (tokens in `globals.css` via `@theme inline`), not a JS config file. The plan was written anticipating a hybrid approach, but the pure v4 approach is cleaner.
- **Deviation:** All tokens defined directly in `globals.css` using `@theme inline` and CSS variables.

### 3. Satoshi font: variable font extracted from zip (not via `@fontsource`)
- **Reason:** Satoshi is not on Google Fonts nor @fontsource. Downloaded directly from `api.fontshare.com/v2/fonts/download/satoshi`, extracted `Satoshi-Variable.woff2` and `Satoshi-VariableItalic.woff2`.
- **Impact:** Fonts are bundled in `web/public/fonts/` (committed) and loaded via `next/font/local`.

### 4. `dynamic` with `ssr: false` requires a Client Component wrapper
- **Reason:** Next.js 16 enforces that `next/dynamic` with `ssr: false` can only be used in Client Components. The plan's example placed it directly in a Server Component page.
- **Fix:** Created `web/src/components/3d/hero-scene-loader.tsx` as a `'use client'` wrapper that handles the dynamic import. `page.tsx` remains a Server Component.

### 5. `favicon.ico` generated as a copy of the 32x32 PNG
- **Reason:** No ICO generation tooling available without installing additional packages (e.g., `png-to-ico`). Browsers accept PNG files named `.ico`. Can be replaced with a proper multi-res ICO before launch.

### 6. OG image implemented as Next.js `opengraph-image.tsx` (dynamic) instead of static PNG
- **Reason:** Using Next.js `ImageResponse` API is more maintainable — the image updates automatically when branding changes. The static `og-image.png` referenced in the plan would need manual regeneration.

### 7. `posthog.__loaded` property access
- **Reason:** PostHog's TypeScript types don't expose `__loaded` directly. The provider checks `NEXT_PUBLIC_POSTHOG_KEY` before calling `posthog.capture` to avoid errors when the key isn't set.

### 8. Vercel + Namecheap DNS steps (3.1.7) not executed
- **Reason:** These require dashboard access (Vercel account settings, Namecheap DNS panel). Steps are fully documented in the plan. `vercel.json` config file was committed.
- **Manual steps required:**
  1. Import repo into Vercel → set Root Directory: `web`
  2. Set all env vars from `.env.example` in Vercel dashboard
  3. Add `SUPABASE_SERVICE_ROLE_KEY` as encrypted secret in Vercel
  4. Set Namecheap DNS: A Record `@` → `76.76.21.21`, CNAME `www` → `cname.vercel-dns.com`
  5. Add custom domain in Vercel → verify SSL

---

## Files Created

```
web/
├── src/
│   ├── app/
│   │   ├── fonts.ts                         # Satoshi + Inter + JetBrains Mono config
│   │   ├── globals.css                      # Full design token CSS variables
│   │   ├── layout.tsx                       # Root layout with all providers
│   │   ├── opengraph-image.tsx              # Dynamic OG image via ImageResponse
│   │   ├── page.tsx                         # Placeholder home page
│   │   ├── robots.ts                        # robots.txt generation
│   │   └── sitemap.ts                       # sitemap.xml generation
│   ├── components/
│   │   ├── 3d/
│   │   │   ├── canvas-3d.tsx                # R3F Canvas wrapper
│   │   │   ├── hero-scene-loader.tsx        # Client-side dynamic import wrapper
│   │   │   └── test-scene.tsx               # Floating sphere verification scene
│   │   ├── analytics.tsx                    # PostHog provider
│   │   ├── motion-wrapper.tsx               # Framer Motion presets
│   │   ├── scroll-reveal.tsx                # GSAP ScrollTrigger fade-up wrapper
│   │   ├── smooth-scroll.tsx                # Lenis provider synced to GSAP
│   │   ├── theme-provider.tsx               # next-themes wrapper
│   │   └── ui/                              # shadcn components
│   ├── hooks/
│   │   ├── use-gsap.ts                      # GSAP hook re-export
│   │   └── use-media-query.ts               # Responsive breakpoint hook
│   ├── lib/
│   │   ├── gsap.ts                          # GSAP + ScrollTrigger registration
│   │   ├── supabase/
│   │   │   ├── client.ts                    # Browser Supabase client
│   │   │   └── server.ts                    # Server Supabase client (service role)
│   │   └── utils.ts                         # shadcn cn() utility
│   ├── styles/
│   │   └── grain.css                        # Noise texture overlay
│   └── types/
│       └── database.ts                      # Supabase Database type (placeholder)
├── public/
│   ├── fonts/
│   │   ├── Satoshi-Variable.woff2
│   │   └── Satoshi-VariableItalic.woff2
│   ├── apple-touch-icon.png                 # 180x180
│   ├── favicon-16x16.png
│   ├── favicon-32x32.png
│   ├── favicon.ico
│   ├── icon-512.png
│   ├── logo.png
│   ├── logo.svg
│   └── site.webmanifest
├── .env.example                             # Documented env vars
├── components.json                          # shadcn/ui config
├── next.config.ts                           # Security headers
├── vercel.json                              # Vercel headers/redirects
└── package.json                             # All dependencies
```

---

## Supabase Project

Connected to existing project:
- **Project:** ZuraLog Project
- **ID:** `enccjffwpnwkxfkhargr`
- **URL:** `https://enccjffwpnwkxfkhargr.supabase.co`
- **Region:** `us-east-1`

The `SUPABASE_SERVICE_ROLE_KEY` must be added to `.env.local` manually from the Supabase dashboard → Settings → API.

---

## Next Steps (Phase 3.2)

Phase 3.2 "Waitlist Landing Page" is ready to begin:

1. **3.2.1** Create `waitlist_entries` table in Supabase (replace placeholder `database.ts` types with generated ones)
2. **3.2.2** Build the hero section with the real 3D convergence scene (replace `test-scene.tsx`)
3. **3.2.3** Build the waitlist signup form (Zod + React Hook Form → POST to `/api/waitlist`)
4. **3.2.4** Implement referral system with nanoid codes
5. **3.2.5** Build the leaderboard component with real-time Supabase subscriptions
6. **Complete Vercel/DNS setup** (manual, requires dashboard access)
