# Zuralog Website (`web/`)

The Zuralog marketing website and waitlist — a Next.js application within the monorepo.

**Live:** [https://www.zuralog.com](https://www.zuralog.com)

---

## Stack

| Layer | Technology |
|---|---|
| Framework | Next.js 16.x (App Router, TypeScript) |
| Styling | Tailwind v4 (CSS-first, `@theme inline` tokens) |
| Components | shadcn/ui |
| 3D | Three.js + React Three Fiber + Drei + Postprocessing |
| Animation | GSAP + ScrollTrigger, Framer Motion, Lenis |
| Backend | Supabase (shared project with Cloud Brain) |
| Analytics | PostHog + Vercel Analytics + Vercel SpeedInsights |
| Deployment | Vercel (auto-deploys on push to `main`, root dir: `web`) |

---

## Quick Start

```bash
# From repo root
cd web
cp .env.example .env.local   # Fill in Supabase + PostHog credentials
npm install
npm run dev                  # http://localhost:3000
```

See [`SETUP.md`](../SETUP.md#4-website-nextjs) at the repo root for full setup instructions including all environment variables.

---

## Commands

| Command | Description |
|---|---|
| `npm run dev` | Start local dev server with hot reload |
| `npm run build` | Production build (run before opening a PR) |
| `npm run start` | Serve the production build locally |
| `npm run lint` | ESLint check |
| `npx tsc --noEmit` | TypeScript type-check |
| `npx shadcn add <component>` | Add a shadcn/ui component |

---

## Environment Variables

Copy `.env.example` → `.env.local` and fill in:

| Variable | Required | Notes |
|---|---|---|
| `NEXT_PUBLIC_SUPABASE_URL` | Yes | Same Supabase project as Cloud Brain |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | Yes | Public anon key — safe to expose client-side |
| `SUPABASE_SERVICE_ROLE_KEY` | Yes | **Secret** — server-side only, never expose client-side |
| `NEXT_PUBLIC_SITE_URL` | Yes | `http://localhost:3000` locally, `https://www.zuralog.com` in production |
| `NEXT_PUBLIC_POSTHOG_KEY` | Optional | PostHog project API key |
| `NEXT_PUBLIC_POSTHOG_HOST` | Optional | Default: `https://us.i.posthog.com` |
| `RESEND_API_KEY` | Phase 3.2 | Transactional email — not needed yet |
| `UPSTASH_REDIS_REST_URL` | Phase 3.2 | Rate limiting — not needed yet |
| `UPSTASH_REDIS_REST_TOKEN` | Phase 3.2 | Rate limiting — not needed yet |

---

## Design System

The "**Bold Convergence**" design system. Key rules:

- **All tokens are in `src/app/globals.css`** — never hardcode hex values in component files.
- **Dark-first:** OLED black (`#000000`) background by default; light mode is `#FAFAFA`.
- **Sage Green primary:** `#CFE1B9`
- **Fonts:** Satoshi Variable (display, local `.woff2`) / Inter (body) / JetBrains Mono (code)
- **3D components** must be loaded via `next/dynamic` with `ssr: false` inside a `'use client'` wrapper.

---

## Key Files

```
src/
├── app/
│   ├── globals.css          # All design tokens (Tailwind v4 @theme inline)
│   ├── layout.tsx           # Root layout — all providers wired here
│   ├── page.tsx             # Home page (placeholder → replaced in Phase 3.2)
│   ├── fonts.ts             # Satoshi + Inter + JetBrains Mono config
│   └── opengraph-image.tsx  # Dynamic OG image (Next.js ImageResponse)
├── components/
│   ├── 3d/
│   │   ├── canvas-3d.tsx          # R3F Canvas wrapper
│   │   └── hero-scene-loader.tsx  # 'use client' dynamic import wrapper
│   ├── smooth-scroll.tsx    # Lenis provider (synced to GSAP ticker)
│   ├── motion-wrapper.tsx   # Framer Motion preset variants
│   └── scroll-reveal.tsx    # GSAP ScrollTrigger fade-up wrapper
├── lib/
│   ├── supabase/
│   │   ├── client.ts        # Browser Supabase client (anon key)
│   │   └── server.ts        # Server Supabase client (service role)
│   └── gsap.ts              # GSAP + ScrollTrigger registration
└── types/
    └── database.ts          # Supabase TypeScript types (regenerate after schema changes)
```

---

## Deployment

Every push to `main` triggers a Vercel deploy. No manual steps needed.

- **Vercel project root:** `web`
- **Domain:** `www.zuralog.com` (primary) — `zuralog.com` redirects 301 → `www`
- **Environment variables:** Managed in the Vercel dashboard (not committed to Git)
