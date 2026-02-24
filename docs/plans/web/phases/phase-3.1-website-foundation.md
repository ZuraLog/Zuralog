# Phase 3.1: Website Foundation & Infrastructure — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Set up the Next.js project within the monorepo at `web/`, configure all tooling (Tailwind v4, shadcn/ui, Three.js/R3F, GSAP, Framer Motion, Lenis), establish the web design system tokens (matching Zuralog's brand while using a distinct "Bold Convergence" web aesthetic), connect to the existing Supabase project, configure Vercel deployment with Namecheap domain, and establish analytics baseline.

**Architecture:** Next.js 15 App Router with TypeScript. The website is a standalone project at `web/` in the monorepo, sharing `assets/brand/` with the Flutter mobile app. It connects to the same Supabase project for waitlist data. Deployed on Vercel with a Namecheap custom domain.

**Tech Stack:**

| Category | Technology | Version |
|---|---|---|
| Framework | Next.js (App Router) | 15.x |
| Runtime | Node.js | 20+ |
| UI Library | React | 19.x |
| Language | TypeScript | 5.x |
| CSS | Tailwind CSS | v4 |
| Components | shadcn/ui (Radix + Tailwind) | latest |
| Animation (declarative) | Framer Motion | 11.x |
| Animation (imperative) | GSAP + ScrollTrigger | 3.x |
| 3D Engine | Three.js | latest |
| 3D React | @react-three/fiber + drei | latest |
| 3D Post-processing | @react-three/postprocessing | latest |
| Smooth Scroll | Lenis | latest |
| Database | Supabase (PostgreSQL) | existing project |
| Email | Resend + React Email | latest |
| Analytics | Vercel Analytics + PostHog | latest |
| Form | Zod + React Hook Form | latest |
| Rate Limiting | Upstash Redis | latest |
| Notifications | Sonner | latest |
| Icons | Lucide React | latest |
| Referral IDs | nanoid | latest |
| SEO | next-sitemap | latest |
| Fonts | Satoshi (display) + Inter (body) + JetBrains Mono (code) | variable |
| Deployment | Vercel | — |
| Domain | Namecheap → Vercel DNS | — |

**Companion Document:** `docs/plans/web/web-view-design.md` — the full visual design specification for the website. Must be created alongside this plan.

---

## Dependencies

- Existing Supabase project (from Phase 1.1.2)
- `assets/brand/logo/` directory with at least a placeholder logo
- Namecheap account with purchased domain
- Vercel account linked to the repository

---

## Phase 3.1 Sub-Phase Checklist

- [ ] **3.1.1** Next.js Project Scaffold
- [ ] **3.1.2** Tailwind CSS + shadcn/ui Setup
- [ ] **3.1.3** Design System Tokens (Web)
- [ ] **3.1.4** Animation Stack Setup (GSAP + Framer Motion + Lenis)
- [ ] **3.1.5** Three.js / React Three Fiber Setup
- [ ] **3.1.6** Supabase Client Configuration
- [ ] **3.1.7** Vercel Deployment + Namecheap DNS
- [ ] **3.1.8** Analytics & SEO Baseline
- [ ] **3.1.9** Brand Asset Pipeline

---

## Task 3.1.1: Next.js Project Scaffold

**What:** Initialize a new Next.js 15 project with TypeScript in the `web/` directory of the monorepo.

**Why:** The website is a separate frontend from the Flutter mobile app. Next.js App Router gives us SSR/SSG, file-based routing, API routes for the waitlist backend, and optimal Vercel integration.

**Files:**
- Create: `web/` (entire Next.js project)
- Create: `web/package.json`
- Create: `web/tsconfig.json`
- Create: `web/next.config.ts`
- Create: `web/.env.local` (gitignored)
- Create: `web/.env.example`
- Create: `web/src/app/layout.tsx`
- Create: `web/src/app/page.tsx`
- Create: `web/src/app/globals.css`

**Steps:**

1. **Create the Next.js project**

```bash
cd C:\Projects\life-logger
npx create-next-app@latest web --typescript --tailwind --eslint --app --src-dir --import-alias "@/*" --no-turbopack
```

2. **Verify the project structure**

```
web/
├── src/
│   ├── app/
│   │   ├── layout.tsx
│   │   ├── page.tsx
│   │   └── globals.css
│   ├── components/   (create)
│   ├── lib/          (create)
│   ├── hooks/        (create)
│   └── types/        (create)
├── public/
├── package.json
├── tsconfig.json
├── next.config.ts
├── tailwind.config.ts
└── .env.local
```

3. **Create the folder structure**

```bash
cd web
mkdir -p src/components/ui src/components/sections src/components/3d src/lib src/hooks src/types src/styles
```

4. **Create `.env.example`**

```env
# Supabase
NEXT_PUBLIC_SUPABASE_URL=your-supabase-url
NEXT_PUBLIC_SUPABASE_ANON_KEY=your-anon-key
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key

# Resend
RESEND_API_KEY=your-resend-key

# Upstash Redis (rate limiting)
UPSTASH_REDIS_REST_URL=your-upstash-url
UPSTASH_REDIS_REST_TOKEN=your-upstash-token

# PostHog
NEXT_PUBLIC_POSTHOG_KEY=your-posthog-key
NEXT_PUBLIC_POSTHOG_HOST=https://us.i.posthog.com

# Site
NEXT_PUBLIC_SITE_URL=https://yourdomain.com
```

5. **Update `next.config.ts` for monorepo compatibility**

```typescript
import type { NextConfig } from 'next';

const nextConfig: NextConfig = {
  // Allow importing from parent directories (assets/brand/)
  transpilePackages: [],
  images: {
    formats: ['image/avif', 'image/webp'],
  },
  // Headers for security
  async headers() {
    return [
      {
        source: '/(.*)',
        headers: [
          { key: 'X-Frame-Options', value: 'DENY' },
          { key: 'X-Content-Type-Options', value: 'nosniff' },
          { key: 'Referrer-Policy', value: 'strict-origin-when-cross-origin' },
        ],
      },
    ];
  },
};

export default nextConfig;
```

6. **Verify it runs**

```bash
cd web && npm run dev
```
Expected: Next.js dev server starts at `http://localhost:3000`

7. **Commit**

```bash
git add web/
git commit -m "feat(web): scaffold Next.js 15 project at web/"
```

**Exit Criteria:**
- `web/` directory exists with Next.js 15 App Router project
- `npm run dev` serves the default page at localhost:3000
- TypeScript compiles without errors
- `.env.example` documents all required environment variables

---

## Task 3.1.2: Tailwind CSS + shadcn/ui Setup

**What:** Configure Tailwind CSS v4 with the Zuralog design tokens and initialize shadcn/ui with core primitives.

**Why:** Tailwind provides utility-first styling that pairs with shadcn/ui. shadcn gives us accessible, customizable component primitives (Button, Input, Dialog, etc.) without the bloat of a full component library.

**Files:**
- Modify: `web/tailwind.config.ts`
- Modify: `web/src/app/globals.css`
- Create: `web/components.json` (shadcn config)
- Create: `web/src/components/ui/button.tsx` (via shadcn CLI)
- Create: `web/src/components/ui/input.tsx`
- Create: `web/src/components/ui/dialog.tsx`
- Create: `web/src/components/ui/sheet.tsx`
- Create: `web/src/lib/utils.ts`

**Steps:**

1. **Initialize shadcn/ui**

```bash
cd web
npx shadcn@latest init
```

Select: New York style, Zinc base color, CSS variables: yes.

2. **Install core shadcn components**

```bash
npx shadcn@latest add button input dialog sheet sonner badge separator
```

3. **Extend Tailwind config with Zuralog brand tokens**

In `tailwind.config.ts`, add custom colors, fonts, and animations that reference the web design system defined in `web-view-design.md`.

4. **Install Sonner for toast notifications**

```bash
npm install sonner
```

Add `<Toaster />` to `layout.tsx`.

5. **Install Lucide React for icons**

```bash
npm install lucide-react
```

6. **Verify: render a shadcn Button**

Replace default `page.tsx` with a simple page that renders a styled `<Button>` component.

7. **Commit**

```bash
git add .
git commit -m "feat(web): configure Tailwind + shadcn/ui with Zuralog tokens"
```

**Exit Criteria:**
- shadcn/ui initialized with Button, Input, Dialog, Sheet, Sonner
- Tailwind config extended with Zuralog brand colors
- `cn()` utility available from `@/lib/utils`
- A Button renders with correct styling on the page

---

## Task 3.1.3: Design System Tokens (Web)

**What:** Define CSS variables, font loading, and theme configuration for the "Bold Convergence" web design system. Implement light/dark mode with dark as default.

**Why:** Consistent tokens prevent hardcoded values, enable theme switching, and ensure the web aesthetic matches the design doc while being distinct from the mobile app.

**Files:**
- Modify: `web/src/app/globals.css` (CSS variables)
- Create: `web/src/app/fonts.ts` (next/font configuration for Satoshi, Inter, JetBrains Mono)
- Modify: `web/src/app/layout.tsx` (font classes, theme provider)
- Create: `web/src/components/theme-provider.tsx` (next-themes wrapper)
- Create: `web/src/styles/grain.css` (noise texture overlay)

**Steps:**

1. **Install `next-themes` for dark mode toggling**

```bash
npm install next-themes
```

2. **Configure fonts in `web/src/app/fonts.ts`**

Use `next/font/google` for Inter and JetBrains Mono. For Satoshi (not on Google Fonts), download the variable font file to `web/public/fonts/` and use `next/font/local`.

3. **Define all CSS variables in `globals.css`**

Map the full color palette, spacing tokens, and typography scale from `web-view-design.md` as CSS variables under `:root` (light) and `.dark` (dark) selectors.

4. **Create `ThemeProvider` wrapper**

Wrap `{children}` in `layout.tsx` with `<ThemeProvider attribute="class" defaultTheme="dark">`.

5. **Create grain texture overlay**

A CSS-only noise overlay using a tiny base64-encoded noise PNG at 3-5% opacity, applied via `::after` pseudo-element on `<body>`.

6. **Verify: page renders in dark mode with correct fonts and colors**

7. **Commit**

```bash
git add .
git commit -m "feat(web): design system tokens, fonts, dark mode, grain texture"
```

**Exit Criteria:**
- Dark mode is the default theme
- Satoshi renders for headlines, Inter for body, JetBrains Mono available
- All CSS variables match `web-view-design.md` color palette
- Grain texture overlay visible on page
- Theme toggle works between light/dark

---

## Task 3.1.4: Animation Stack Setup (GSAP + Framer Motion + Lenis)

**What:** Install and configure the three animation layers: GSAP with ScrollTrigger for scroll-driven animations, Framer Motion for declarative component animations, and Lenis for smooth scrolling.

**Why:** Three tools, three jobs: GSAP for timeline/scroll choreography (best-in-class for complex sequences), Framer Motion for React-idiomatic component animations (layout, presence, gestures), Lenis for the buttery smooth scroll feel that Awwwards sites use.

**Files:**
- Create: `web/src/lib/gsap.ts` (GSAP registration + ScrollTrigger plugin)
- Create: `web/src/hooks/use-gsap.ts` (React hook for GSAP scoped animations)
- Create: `web/src/components/smooth-scroll.tsx` (Lenis provider)
- Create: `web/src/components/scroll-reveal.tsx` (reusable GSAP ScrollTrigger wrapper)
- Create: `web/src/components/motion-wrapper.tsx` (Framer Motion common presets)
- Modify: `web/src/app/layout.tsx` (add SmoothScroll provider)

**Steps:**

1. **Install dependencies**

```bash
npm install gsap @gsap/react lenis framer-motion
```

2. **Register GSAP plugins in `web/src/lib/gsap.ts`**

```typescript
import { gsap } from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';
import { useGSAP } from '@gsap/react';

gsap.registerPlugin(ScrollTrigger);

export { gsap, ScrollTrigger, useGSAP };
```

3. **Create Lenis smooth scroll provider**

A React component that initializes Lenis, syncs it with GSAP ScrollTrigger's `scrollerProxy`, and provides the Lenis instance via context. Respects `prefers-reduced-motion`.

4. **Create `<ScrollReveal>` wrapper component**

A reusable component that wraps children in a GSAP ScrollTrigger animation (fade up from 20px below, opacity 0 → 1). Accepts props for `delay`, `duration`, `y` offset. Disabled when `prefers-reduced-motion`.

5. **Create Framer Motion presets**

Export commonly-used `variants` objects (fadeIn, slideUp, staggerContainer, scaleIn) as a shared file.

6. **Wrap layout with `<SmoothScroll>`**

7. **Verify: create a tall test page with multiple `<ScrollReveal>` sections**

Scroll through and confirm elements animate into view smoothly.

8. **Commit**

```bash
git add .
git commit -m "feat(web): animation stack - GSAP ScrollTrigger + Framer Motion + Lenis"
```

**Exit Criteria:**
- GSAP ScrollTrigger fires animations on scroll
- Lenis provides smooth scroll behavior
- Framer Motion `<motion.div>` animates components
- `prefers-reduced-motion` disables all animations
- No memory leaks (animations cleaned up on unmount)

---

## Task 3.1.5: Three.js / React Three Fiber Setup

**What:** Install and configure Three.js via React Three Fiber, Drei helpers, and postprocessing. Create a reusable `<Canvas3D>` wrapper with performance defaults and verify with a test scene.

**Why:** The 3D hero scene (orbiting app icons converging into a floating phone) is the centerpiece of the website. R3F gives us React bindings for Three.js, Drei provides helper components (OrbitControls, Float, Environment, etc.), and postprocessing adds polish (bloom glow behind the phone).

**Files:**
- Create: `web/src/components/3d/canvas-3d.tsx` (reusable Canvas wrapper)
- Create: `web/src/components/3d/test-scene.tsx` (verification sphere)
- Create: `web/src/hooks/use-media-query.ts` (for responsive 3D)
- Modify: `web/src/app/page.tsx` (render test scene)

**Steps:**

1. **Install Three.js ecosystem**

```bash
npm install three @react-three/fiber @react-three/drei @react-three/postprocessing @types/three
```

2. **Create `<Canvas3D>` wrapper**

```tsx
// web/src/components/3d/canvas-3d.tsx
'use client';

import { Canvas } from '@react-three/fiber';
import { Preload } from '@react-three/drei';
import { Suspense } from 'react';

interface Canvas3DProps {
  children: React.ReactNode;
  className?: string;
}

export function Canvas3D({ children, className }: Canvas3DProps) {
  return (
    <Canvas
      className={className}
      dpr={[1, Math.min(window.devicePixelRatio, 2)]}
      gl={{
        antialias: true,
        alpha: true,
        powerPreference: 'high-performance',
      }}
      camera={{ position: [0, 0, 5], fov: 45 }}
    >
      <Suspense fallback={null}>
        {children}
        <Preload all />
      </Suspense>
    </Canvas>
  );
}
```

Key performance decisions:
- DPR clamped to max 2 (saves GPU on retina displays)
- `alpha: true` for transparent background (composites over CSS)
- Suspense with fallback for lazy-loaded 3D assets
- `powerPreference: 'high-performance'` for discrete GPU selection

3. **Create test scene with a floating sphere**

A simple `<mesh>` with `<Float>` from Drei, Sage Green material, subtle bloom glow. Verifies the full pipeline works.

4. **Dynamic import the Canvas to avoid SSR issues**

Three.js cannot render server-side. Use `next/dynamic` with `ssr: false` for all Canvas components.

```tsx
const HeroScene = dynamic(() => import('@/components/3d/test-scene'), {
  ssr: false,
  loading: () => <div className="h-screen" />,
});
```

5. **Create `useMediaQuery` hook for responsive 3D**

Returns boolean for breakpoints. Used to reduce 3D complexity on mobile (fewer objects, lower DPR, no postprocessing).

6. **Verify: floating green sphere renders on the page, responds to resize**

7. **Commit**

```bash
git add .
git commit -m "feat(web): Three.js + R3F + Drei + postprocessing setup with Canvas3D wrapper"
```

**Exit Criteria:**
- 3D sphere renders on the page with correct Sage Green color
- Float animation works (gentle bobbing)
- Canvas is transparent (background shows through)
- No SSR errors (dynamic import works)
- Resizing the browser updates the canvas
- DPR is clamped

---

## Task 3.1.6: Supabase Client Configuration

**What:** Configure the Supabase JavaScript client for both client-side and server-side usage in Next.js. Connect to the existing Supabase project used by the mobile app backend.

**Why:** The waitlist data (users, referrals, quiz answers, leaderboard) lives in Supabase PostgreSQL. We need both a browser client (for real-time leaderboard updates) and a server client (for API routes with service role key).

**Files:**
- Create: `web/src/lib/supabase/client.ts` (browser client)
- Create: `web/src/lib/supabase/server.ts` (server-side client for API routes)
- Create: `web/src/types/database.ts` (typed schema for waitlist tables — placeholder until schema is created in 3.2.1)
- Modify: `web/.env.local` (add Supabase credentials)

**Steps:**

1. **Install Supabase client**

```bash
npm install @supabase/supabase-js @supabase/ssr
```

2. **Create browser client**

```typescript
// web/src/lib/supabase/client.ts
import { createBrowserClient } from '@supabase/ssr';

export function createClient() {
  return createBrowserClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
  );
}
```

3. **Create server client for API routes**

```typescript
// web/src/lib/supabase/server.ts
import { createClient as createSupabaseClient } from '@supabase/supabase-js';

export function createServerClient() {
  return createSupabaseClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!,
  );
}
```

4. **Add environment variables to `.env.local`**

Get the URL and keys from the existing Supabase project dashboard. The service role key is for server-side only (never exposed to the browser).

5. **Verify: query a test table or call `supabase.from('...').select()` and confirm connection**

6. **Commit**

```bash
git add .
git commit -m "feat(web): Supabase client configuration (browser + server)"
```

**Exit Criteria:**
- Browser client connects to Supabase from client components
- Server client connects with service role key from API routes
- Environment variables are set in `.env.local` and documented in `.env.example`
- No credentials exposed to the browser bundle

---

## Task 3.1.7: Vercel Deployment + Namecheap DNS

**What:** Deploy the `web/` project to Vercel. Configure the monorepo root directory setting so Vercel builds only the `web/` subfolder. Point the Namecheap domain to Vercel. SSL is auto-provisioned.

**Why:** Vercel is the official hosting platform for Next.js with zero-config deployment, edge CDN, and automatic preview deployments on PRs.

**Files:**
- Create: `web/vercel.json` (optional, for headers/redirects)
- Modify: Vercel dashboard settings (root directory, env vars)
- Modify: Namecheap DNS settings (CNAME/A records)

**Steps:**

1. **Import the repository into Vercel**
   - Go to vercel.com → New Project → Import the `life-logger` GitHub repo
   - **Root Directory:** Set to `web`
   - **Framework Preset:** Next.js (auto-detected)
   - **Build Command:** `npm run build` (default)
   - **Output Directory:** `.next` (default)

2. **Set environment variables in Vercel dashboard**
   - Add all variables from `.env.example` as Production + Preview environment variables
   - `SUPABASE_SERVICE_ROLE_KEY` should be set as a secret (encrypted)

3. **Deploy and verify the build succeeds**

Expected: Vercel provides a `*.vercel.app` URL. The site should render.

4. **Configure Namecheap DNS**

   In Namecheap → Domain → Advanced DNS:
   - Add `A Record`: `@` → `76.76.21.21` (Vercel's IP)
   - Add `CNAME Record`: `www` → `cname.vercel-dns.com`
   - Remove any conflicting default records (parking page, etc.)

5. **Add the custom domain in Vercel**
   - Go to Vercel Project → Settings → Domains → Add domain
   - Add both `yourdomain.com` and `www.yourdomain.com`
   - Vercel will verify DNS and auto-provision SSL (Let's Encrypt)
   - Set redirect: `www.yourdomain.com` → `yourdomain.com` (or vice versa)

6. **Verify: custom domain resolves with SSL, site renders**

7. **Commit** (if `vercel.json` was created)

```bash
git add web/vercel.json
git commit -m "feat(web): Vercel deployment config"
```

**Exit Criteria:**
- Site deploys automatically on `git push` to main
- Preview deployments created for PRs
- Custom domain resolves with valid SSL certificate
- Environment variables configured in Vercel dashboard
- HTTP → HTTPS redirect works
- www → non-www (or vice versa) redirect configured

---

## Task 3.1.8: Analytics & SEO Baseline

**What:** Install Vercel Analytics for Web Vitals monitoring and PostHog for product analytics. Configure SEO defaults (sitemap, robots.txt, Open Graph meta).

**Why:** We need to track waitlist funnel metrics from day one: visit → quiz start → quiz complete → signup → referral link click. Vercel Analytics gives us performance data; PostHog gives us product analytics with event tracking, funnels, and session replay.

**Files:**
- Modify: `web/package.json` (add dependencies)
- Create: `web/src/components/analytics.tsx` (PostHog provider)
- Modify: `web/src/app/layout.tsx` (add Analytics + PostHog providers)
- Create: `web/next-sitemap.config.js`
- Create: `web/src/app/robots.ts`
- Create: `web/src/app/sitemap.ts`
- Modify: `web/src/app/layout.tsx` (metadata export)

**Steps:**

1. **Install analytics packages**

```bash
npm install @vercel/analytics @vercel/speed-insights posthog-js next-sitemap
```

2. **Add Vercel Analytics to layout**

```tsx
import { Analytics } from '@vercel/analytics/react';
import { SpeedInsights } from '@vercel/speed-insights/next';

// In layout.tsx body:
<Analytics />
<SpeedInsights />
```

3. **Configure PostHog client provider**

Create a `PostHogProvider` component that initializes PostHog on mount with the project API key. Add to layout.

4. **Configure SEO metadata in `layout.tsx`**

```tsx
export const metadata: Metadata = {
  metadataBase: new URL(process.env.NEXT_PUBLIC_SITE_URL || 'https://yourdomain.com'),
  title: {
    default: 'Zuralog — [Placeholder Tagline]',
    template: '%s | Zuralog',
  },
  description: 'The AI that connects your fitness apps and actually thinks. Join the waitlist.',
  openGraph: {
    type: 'website',
    locale: 'en_US',
    siteName: 'Zuralog',
    images: [{ url: '/og-image.png', width: 1200, height: 630 }],
  },
  twitter: {
    card: 'summary_large_image',
    creator: '@zuralog',
  },
  robots: { index: true, follow: true },
};
```

5. **Create `robots.ts` and `sitemap.ts`**

Standard Next.js metadata API files. Sitemap includes `/` (the single page for now).

6. **Verify: Vercel Analytics appears in dashboard, PostHog receives test event**

7. **Commit**

```bash
git add .
git commit -m "feat(web): analytics (Vercel + PostHog) and SEO baseline"
```

**Exit Criteria:**
- Vercel Analytics tracks page views and Web Vitals
- PostHog receives events (page view at minimum)
- `robots.txt` serves correctly
- `sitemap.xml` generates
- OG meta tags render (test with social media debugger tools)

---

## Task 3.1.9: Brand Asset Pipeline

**What:** Sync the Zuralog logo and brand assets from `assets/brand/` to `web/public/`. Generate web-optimized versions: favicon set (ICO, PNG 16/32/180/512, SVG), Apple touch icon, and a placeholder OG image.

**Why:** The website needs brand assets served from `web/public/`. Per the asset strategy doc, `assets/brand/` is the source of truth, and `web/public/` receives copies.

**Files:**
- Create: `web/public/favicon.ico`
- Create: `web/public/favicon-16x16.png`
- Create: `web/public/favicon-32x32.png`
- Create: `web/public/apple-touch-icon.png` (180x180)
- Create: `web/public/icon-512.png`
- Create: `web/public/logo.svg` (wordmark)
- Create: `web/public/og-image.png` (1200x630 placeholder)
- Create: `web/src/app/icon.tsx` (Next.js dynamic favicon, optional)
- Modify: `web/src/app/layout.tsx` (link favicon)

**Steps:**

1. **Check existing assets in `assets/brand/logo/`**

```bash
ls assets/brand/logo/
```

2. **Copy or generate web-optimized versions**

If the current logo is only a temporary placeholder, generate a simple SVG wordmark: "Zuralog" in Satoshi Bold, Sage Green `#CFE1B9` on dark background.

3. **Generate favicon set**

Use a favicon generator (realfavicongenerator.net) or create programmatically:
- `favicon.ico` (16x16 + 32x32 multi-resolution)
- `favicon-16x16.png`
- `favicon-32x32.png`
- `apple-touch-icon.png` (180x180)
- `icon-512.png` (PWA/manifest icon)

4. **Create OG image placeholder**

A 1200x630 PNG with: dark background (`#0A0A0A`), Zuralog logo centered, tagline below. This is the image shown when the site is shared on social media.

5. **Verify: favicon appears in browser tab, OG image renders in social debugger**

6. **Commit**

```bash
git add web/public/
git commit -m "feat(web): brand assets - favicon set, OG image, logo for web"
```

**Exit Criteria:**
- Favicon renders in browser tab
- Apple touch icon configured for iOS bookmark
- OG image renders correctly when URL is shared
- All assets sourced from or synced from `assets/brand/`

---

## Phase 3.1 Exit Criteria (All Tasks)

- [ ] `web/` boots locally with `npm run dev`, shows a styled page with Zuralog brand
- [ ] Light/dark mode toggle works with correct brand colors (dark is default)
- [ ] Satoshi, Inter, and JetBrains Mono fonts load correctly
- [ ] Grain texture overlay visible
- [ ] GSAP ScrollTrigger animation works on scroll
- [ ] Framer Motion component animation works
- [ ] Lenis smooth scroll is active
- [ ] Three.js sphere renders in a Canvas (no SSR errors)
- [ ] Supabase client connects and can query
- [ ] Site deploys to Vercel on git push
- [ ] Custom domain resolves with valid SSL
- [ ] Vercel Analytics and PostHog receive events
- [ ] Favicon, OG image, and meta tags configured
- [ ] Lighthouse score > 90 on performance (desktop)
- [ ] `prefers-reduced-motion` disables animations
