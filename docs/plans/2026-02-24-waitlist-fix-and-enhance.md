# Waitlist Fix & Enhancement Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix the broken waitlist signup (schema mismatch root cause), add animated live counters, interactive graphics, and remove the light theme entirely.

**Architecture:** The fix is purely a code-to-database alignment issue. The API routes send column names that don't exist in the actual Supabase schema. All 7 tasks follow the critical path: DB fixes first, then API fixes, then UI enhancements in parallel.

**Tech Stack:** Next.js 16, Supabase (PostgreSQL), TypeScript, Framer Motion, canvas-confetti, Tailwind v4

---

## Root Cause

The `"Failed to join waitlist"` error at `web/src/app/api/waitlist/join/route.ts:126-131` is caused by the API inserting columns that **don't exist** in the `waitlist_users` table:

| Code sends                | Actual DB column                                     |
|--------------------------|------------------------------------------------------|
| `referred_by_id` (UUID)  | `referred_by` (TEXT FK to referral_code)             |
| `quiz_answers` (JSONB)   | `quiz_apps_used` (TEXT[]), `quiz_frustration` (TEXT), `quiz_goal` (TEXT) |

Additionally:
- `increment_referral_count` RPC function does not exist in DB
- `waitlist_stats` view is missing `founding_members` and `total_referrals` columns
- `referral_count` column doesn't exist on `waitlist_users` (leaderboard computes via JOIN)

---

## Task 1: Fix Database — Stats View + RPC

**Files:**
- Supabase SQL (applied via migration)

**Step 1: Apply the migration via Supabase MCP**

SQL to execute:
```sql
-- Create the missing increment_referral_count RPC
-- (no-op stub so the fire-and-forget call in join/route.ts doesn't error)
CREATE OR REPLACE FUNCTION public.increment_referral_count(user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  NULL; -- Referral counts are computed via JOIN in referral_leaderboard view
END;
$$;

-- Recreate waitlist_stats view with all columns the stats API expects
DROP VIEW IF EXISTS public.waitlist_stats;
CREATE VIEW public.waitlist_stats AS
SELECT
  count(*)::int AS total_signups,
  count(*) FILTER (WHERE tier = 'founding_30')::int AS founding_members,
  (SELECT count(*) FROM waitlist_users WHERE referred_by IS NOT NULL)::int AS total_referrals,
  count(*) FILTER (WHERE created_at > now() - interval '24 hours')::int AS signups_last_24h,
  max(queue_position) AS latest_position
FROM public.waitlist_users;
```

**Step 2: Verify views and functions exist**
```sql
SELECT routine_name FROM information_schema.routines WHERE routine_schema = 'public';
SELECT table_name FROM information_schema.views WHERE table_schema = 'public';
```

**Step 3: Commit**
```bash
git add .
git commit -m "fix(db): add increment_referral_count RPC and fix waitlist_stats view"
```

---

## Task 2: Fix API — `join/route.ts` Column Mapping (THE CRITICAL FIX)

**Files:**
- Modify: `web/src/app/api/waitlist/join/route.ts`

**Step 1: Fix the referrer resolution (lines 102-111)**

The `referred_by` column is a TEXT FK to `referral_code`, not a UUID. Change the insert to pass the referral code string, not the UUID.

Replace:
```typescript
let referrerId: string | null = null;
if (referrerCode) {
  const { data: referrer } = await supabase
    .from('waitlist_users')
    .select('id')
    .eq('referral_code', referrerCode.toUpperCase())
    .maybeSingle();
  if (referrer) referrerId = referrer.id;
}
```

With:
```typescript
let referredByCode: string | null = null;
let referrerId: string | null = null;
if (referrerCode) {
  const { data: referrer } = await supabase
    .from('waitlist_users')
    .select('id, referral_code')
    .eq('referral_code', referrerCode.toUpperCase())
    .maybeSingle();
  if (referrer) {
    referredByCode = referrer.referral_code;
    referrerId = referrer.id;
  }
}
```

**Step 2: Fix the insert (lines 113-124)**

Replace:
```typescript
const { data: inserted, error: insertError } = await supabase
  .from('waitlist_users')
  .insert({
    email,
    referral_code: newCode,
    referred_by_id: referrerId,
    quiz_answers: quizAnswers ?? null,
  })
  .select('id, queue_position, tier')
  .single();
```

With:
```typescript
const { data: inserted, error: insertError } = await supabase
  .from('waitlist_users')
  .insert({
    email,
    referral_code: newCode,
    referred_by: referredByCode,
    quiz_apps_used: quizAnswers?.apps ?? [],
    quiz_frustration: quizAnswers?.frustrations?.[0] ?? null,
    quiz_goal: quizAnswers?.goal ?? null,
  })
  .select('id, queue_position, tier')
  .single();
```

**Step 3: Fix the RPC call (line 136)**

The function takes a UUID but we renamed the variable. Update:
```typescript
supabase.rpc('increment_referral_count', { user_id: referrerId }).then(...)
```
(Keep this as-is — `referrerId` still holds the UUID from the updated lookup.)

**Step 4: Verify the fix compiles**
```bash
cd web && npx tsc --noEmit 2>&1
```
Expected: No errors on this file.

**Step 5: Commit**
```bash
git add web/src/app/api/waitlist/join/route.ts
git commit -m "fix(waitlist): correct column mapping in join API - referred_by and quiz fields"
```

---

## Task 3: Fix API — Leaderboard Route

**Files:**
- Modify: `web/src/app/api/waitlist/leaderboard/route.ts`

**Step 1: Switch to referral_leaderboard view**

The current query selects `referral_count` which doesn't exist as a column on `waitlist_users`. The `referral_leaderboard` view already computes it correctly via JOIN.

Replace:
```typescript
const { data, error } = await supabase
  .from('waitlist_users')
  .select('email, referral_count, tier')
  .gt('referral_count', 0)
  .order('referral_count', { ascending: false })
  .limit(10);

// ...
const leaderboard = (data ?? []).map((row, i) => ({
  rank: i + 1,
  email_masked: row.email.replace(/^(.{2}).*?(@.*)$/, '$1***$2'),
  referral_count: row.referral_count,
  tier: row.tier,
}));
```

With:
```typescript
const { data, error } = await supabase
  .from('referral_leaderboard')
  .select('display_name, referral_count, queue_position')
  .gt('referral_count', 0)
  .limit(10);

// ...
const leaderboard = (data ?? []).map((row, i) => ({
  rank: i + 1,
  display_name: row.display_name ?? `Anonymous #${i + 1}`,
  referral_count: row.referral_count,
  queue_position: row.queue_position,
}));
```

**Step 2: Update WaitlistSection to use display_name**

In `web/src/components/sections/waitlist-section.tsx`, update `LeaderboardEntry` interface:
```typescript
interface LeaderboardEntry {
  rank: number;
  display_name: string;   // was email_masked
  referral_count: number;
  queue_position?: number;
}
```

And update the JSX to render `entry.display_name` instead of `entry.email_masked`.

**Step 3: Verify types**
```bash
cd web && npx tsc --noEmit 2>&1
```

**Step 4: Commit**
```bash
git add web/src/app/api/waitlist/leaderboard/route.ts web/src/components/sections/waitlist-section.tsx
git commit -m "fix(waitlist): use referral_leaderboard view in leaderboard API"
```

---

## Task 4: Regenerate Database Types

**Files:**
- Modify: `web/src/types/database.ts`

Replace the entire placeholder file with types matching the actual `waitlist_users` schema (confirmed from Supabase):

```typescript
/**
 * Supabase Database type definitions for the Zuralog website.
 * Generated to match the actual waitlist_users table schema.
 * 
 * To regenerate:
 *   npx supabase gen types typescript --project-id enccjffwpnwkxfkhargr > src/types/database.ts
 */

export type Database = {
  public: {
    Tables: {
      waitlist_users: {
        Row: {
          id: string;
          email: string;
          referral_code: string;
          referred_by: string | null;
          display_name: string | null;
          show_name: boolean | null;
          queue_position: number | null;
          quiz_apps_used: string[] | null;
          quiz_frustration: string | null;
          quiz_goal: string | null;
          tier: string | null;
          created_at: string | null;
          updated_at: string | null;
          ip_address: string | null;
          user_agent: string | null;
        };
        Insert: {
          id?: string;
          email: string;
          referral_code: string;
          referred_by?: string | null;
          display_name?: string | null;
          show_name?: boolean | null;
          queue_position?: number | null;
          quiz_apps_used?: string[] | null;
          quiz_frustration?: string | null;
          quiz_goal?: string | null;
          tier?: string | null;
          created_at?: string | null;
          updated_at?: string | null;
          ip_address?: string | null;
          user_agent?: string | null;
        };
        Update: Partial<Database['public']['Tables']['waitlist_users']['Insert']>;
      };
    };
    Views: {
      waitlist_stats: {
        Row: {
          total_signups: number | null;
          founding_members: number | null;
          total_referrals: number | null;
          signups_last_24h: number | null;
          latest_position: number | null;
        };
      };
      referral_leaderboard: {
        Row: {
          id: string | null;
          referral_code: string | null;
          display_name: string | null;
          show_name: boolean | null;
          referral_count: number | null;
          queue_position: number | null;
          created_at: string | null;
        };
      };
    };
    Functions: {
      increment_referral_count: {
        Args: { user_id: string };
        Returns: void;
      };
    };
    Enums: Record<string, never>;
  };
};
```

**Step 2: Verify types**
```bash
cd web && npx tsc --noEmit 2>&1
```

**Step 3: Commit**
```bash
git add web/src/types/database.ts
git commit -m "fix(types): update Database types to match actual waitlist_users schema"
```

---

## Task 5: Remove Light Theme Entirely

**Files:**
- Modify: `web/src/app/globals.css`
- Modify: `web/src/app/layout.tsx`
- Modify: `web/src/components/sections/navbar.tsx`
- Delete: `web/src/components/theme-provider.tsx`

**Step 1: globals.css — merge light tokens into :root as dark tokens**

Remove the `:root { ... }` light mode block entirely (lines 87-135).
Move the `.dark { ... }` block to `:root { ... }` (remove the `.dark` selector wrapper).
Remove the `@custom-variant dark (&:is(.dark *));` line.

The result: all CSS variables are always the dark values.

**Step 2: layout.tsx — remove ThemeProvider, add static dark class**

Remove:
```tsx
import { ThemeProvider } from '@/components/theme-provider';
```

Change:
```tsx
<html lang="en" suppressHydrationWarning className={...}>
  <body>
    <ThemeProvider attribute="class" defaultTheme="dark" enableSystem={false} disableTransitionOnChange>
      ...
    </ThemeProvider>
  </body>
</html>
```

To:
```tsx
<html lang="en" className={`dark ${satoshi.variable} ${inter.variable} ${jetbrainsMono.variable}`}>
  <body>
    ...children directly (no ThemeProvider)...
  </body>
</html>
```

Remove `suppressHydrationWarning` since we no longer need theme hydration.

**Step 3: navbar.tsx — remove ThemeToggle**

Delete the entire `ThemeToggle` function (lines 25-53).
Remove `useTheme` import.
Remove `<ThemeToggle />` from the JSX (line 121).

**Step 4: Delete theme-provider.tsx**
```bash
rm web/src/components/theme-provider.tsx
```

**Step 5: Verify**
```bash
cd web && npx tsc --noEmit 2>&1
```

**Step 6: Commit**
```bash
git add -A
git commit -m "feat: remove light theme - dark-only mode, delete ThemeProvider and ThemeToggle"
```

---

## Task 6: Add Animated Waitlist Counter

**New files:**
- Create: `web/src/components/waitlist-counter.tsx`
- Create: `web/src/components/waitlist-stats-bar.tsx`
- Modify: `web/src/components/sections/hero.tsx`
- Modify: `web/src/components/sections/waitlist-section.tsx`

### WaitlistCounter component (reusable animated number)

```tsx
// web/src/components/waitlist-counter.tsx
'use client';
import { useEffect, useRef, useState } from 'react';
import { motion, useSpring, useTransform, useInView } from 'framer-motion';

interface WaitlistCounterProps {
  value: number;
  label?: string;
  className?: string;
  prefix?: string;
  suffix?: string;
  delay?: number;
}

export function WaitlistCounter({ value, label, className, prefix, suffix, delay = 0 }: WaitlistCounterProps) {
  const ref = useRef<HTMLDivElement>(null);
  const isInView = useInView(ref, { once: true });
  const spring = useSpring(0, { stiffness: 60, damping: 20 });
  const display = useTransform(spring, (v) => Math.round(v).toLocaleString());

  useEffect(() => {
    if (isInView && value > 0) {
      const timer = setTimeout(() => spring.set(value), delay);
      return () => clearTimeout(timer);
    }
  }, [isInView, value, spring, delay]);

  return (
    <div ref={ref} className={className}>
      <div className="font-display text-3xl font-bold text-white tabular-nums">
        {prefix}<motion.span>{display}</motion.span>{suffix}
      </div>
      {label && <p className="mt-1 text-xs font-medium uppercase tracking-widest text-zinc-500">{label}</p>}
    </div>
  );
}
```

### WaitlistStatsBar component (3 stat cards for the waitlist section)

```tsx
// web/src/components/waitlist-stats-bar.tsx
'use client';
import { useEffect, useState } from 'react';
import { motion } from 'framer-motion';
import { WaitlistCounter } from './waitlist-counter';

interface Stats {
  totalSignups: number;
  foundingMembersLeft: number;
  totalReferrals: number;
}

export function WaitlistStatsBar() {
  const [stats, setStats] = useState<Stats | null>(null);

  useEffect(() => {
    fetch('/api/waitlist/stats')
      .then((r) => r.json())
      .then(setStats)
      .catch(() => {});
  }, []);

  if (!stats) return null;

  const cards = [
    { value: stats.totalSignups, label: 'People Waiting', icon: '👥', delay: 0 },
    { value: stats.foundingMembersLeft, label: 'Founding Spots Left', icon: '⭐', delay: 150, glow: stats.foundingMembersLeft < 10 },
    { value: stats.totalReferrals, label: 'Referrals Made', icon: '🔗', delay: 300 },
  ];

  return (
    <div className="mb-12 grid grid-cols-3 gap-4">
      {cards.map((card, i) => (
        <motion.div
          key={i}
          initial={{ opacity: 0, y: 16 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.5, delay: i * 0.1 }}
          className={`relative rounded-2xl border bg-white/3 p-4 text-center backdrop-blur-sm transition-all ${
            card.glow
              ? 'border-sage/40 shadow-[0_0_30px_rgba(207,225,185,0.12)]'
              : 'border-white/8'
          }`}
        >
          {card.glow && (
            <motion.div
              animate={{ opacity: [0.4, 0.8, 0.4] }}
              transition={{ repeat: Infinity, duration: 2 }}
              className="pointer-events-none absolute inset-0 rounded-2xl bg-sage/5"
            />
          )}
          <div className="mb-1 text-lg">{card.icon}</div>
          <WaitlistCounter value={card.value} delay={card.delay} />
          <p className="mt-1 text-xs font-medium uppercase tracking-widest text-zinc-500">{card.label}</p>
        </motion.div>
      ))}
    </div>
  );
}
```

### Hero section — add subtle counter pill

In `hero.tsx`, add below the CTA buttons (before the scroll cue):
```tsx
// Fetched stats displayed as subtle pill
<HeroWaitlistBadge />
```

Create `web/src/components/hero/hero-waitlist-badge.tsx`:
```tsx
'use client';
import { useEffect, useState } from 'react';
import { motion } from 'framer-motion';

export function HeroWaitlistBadge() {
  const [count, setCount] = useState<number | null>(null);

  useEffect(() => {
    fetch('/api/waitlist/stats')
      .then((r) => r.json())
      .then((d) => setCount(d.totalSignups ?? 0))
      .catch(() => {});
  }, []);

  if (!count) return null;

  return (
    <motion.div
      initial={{ opacity: 0, y: 10 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ delay: 0.5 }}
      className="flex items-center gap-2 rounded-full border border-white/10 bg-white/5 px-4 py-2 backdrop-blur-sm"
    >
      <motion.span
        animate={{ scale: [1, 1.3, 1] }}
        transition={{ repeat: Infinity, duration: 2 }}
        className="h-2 w-2 rounded-full bg-sage"
      />
      <span className="text-sm text-zinc-300">
        <span className="font-semibold text-white">{count.toLocaleString()}</span> people waiting
      </span>
    </motion.div>
  );
}
```

In `hero.tsx`, add:
```tsx
import dynamic from 'next/dynamic';
const HeroWaitlistBadge = dynamic(
  () => import('@/components/hero/hero-waitlist-badge').then((m) => m.HeroWaitlistBadge),
  { ssr: false }
);
```

Place `<HeroWaitlistBadge />` between the CTA buttons and scroll indicator.

### Waitlist section — add WaitlistStatsBar

In `waitlist-section.tsx`, import and render `<WaitlistStatsBar />` above the quiz:
```tsx
import { WaitlistStatsBar } from '@/components/waitlist-stats-bar';
// Inside the <div className="relative mx-auto max-w-6xl px-6"> block, before the section header motion.div
<WaitlistStatsBar />
```

**Step: Verify**
```bash
cd web && npx tsc --noEmit 2>&1
```

**Step: Commit**
```bash
git add -A
git commit -m "feat(waitlist): add animated live counters in hero and waitlist section"
```

---

## Task 7: Interactive Graphics (Confetti, Particles, Micro-interactions)

**New files:**
- Create: `web/src/components/confetti-burst.tsx`
- Create: `web/src/components/waitlist-particles.tsx`

**Modified files:**
- Modify: `web/src/components/quiz/waitlist-form.tsx`
- Modify: `web/src/components/quiz/completion-step.tsx`
- Modify: `web/src/components/sections/waitlist-section.tsx`

### 7a. Install canvas-confetti
```bash
cd web && npm install canvas-confetti @types/canvas-confetti
```

### 7b. ConfettiBurst component

```tsx
// web/src/components/confetti-burst.tsx
'use client';
import { useEffect } from 'react';
import confetti from 'canvas-confetti';

interface ConfettiBurstProps {
  trigger: boolean;
}

export function ConfettiBurst({ trigger }: ConfettiBurstProps) {
  useEffect(() => {
    if (!trigger) return;
    // Sage green + white + gold burst
    const colors = ['#CFE1B9', '#ffffff', '#FFD700', '#A8C98A'];
    confetti({
      particleCount: 120,
      spread: 80,
      origin: { x: 0.5, y: 0.7 },
      colors,
      ticks: 200,
      gravity: 0.8,
      scalar: 0.9,
    });
    // Second burst 300ms later
    setTimeout(() => {
      confetti({
        particleCount: 60,
        spread: 50,
        origin: { x: 0.45, y: 0.65 },
        colors,
        ticks: 150,
      });
    }, 300);
  }, [trigger]);

  return null;
}
```

Add `<ConfettiBurst trigger={true} />` in `CompletionStep` (completion-step.tsx) to fire on mount.

### 7c. Floating particles for waitlist section

```tsx
// web/src/components/waitlist-particles.tsx
'use client';
import { useMemo } from 'react';

interface Particle {
  id: number;
  x: number;
  size: number;
  opacity: number;
  duration: number;
  delay: number;
}

export function WaitlistParticles() {
  const particles = useMemo<Particle[]>(() => 
    Array.from({ length: 18 }, (_, i) => ({
      id: i,
      x: Math.random() * 100,
      size: Math.random() * 2 + 1,
      opacity: Math.random() * 0.2 + 0.05,
      duration: Math.random() * 8 + 10,
      delay: Math.random() * 8,
    })),
  []);

  return (
    <div className="pointer-events-none absolute inset-0 overflow-hidden">
      {particles.map((p) => (
        <div
          key={p.id}
          className="absolute rounded-full bg-sage"
          style={{
            left: `${p.x}%`,
            bottom: '-4px',
            width: p.size,
            height: p.size,
            opacity: p.opacity,
            animation: `float-up ${p.duration}s ${p.delay}s infinite linear`,
          }}
        />
      ))}
      <style jsx>{`
        @keyframes float-up {
          from { transform: translateY(0); opacity: var(--op, 0.1); }
          50% { opacity: var(--op, 0.1); }
          to { transform: translateY(-100vh); opacity: 0; }
        }
      `}</style>
    </div>
  );
}
```

Add to `waitlist-section.tsx` background:
```tsx
import { WaitlistParticles } from '@/components/waitlist-particles';
// Inside the pointer-events-none absolute inset-0 overflow-hidden div:
<WaitlistParticles />
```

### 7d. Form micro-interactions (waitlist-form.tsx)

Enhance the submit button with glow animation and loading state:
```tsx
// Enhanced button with pulsing glow when loading
<Button
  type="submit"
  disabled={loading}
  className={`h-14 w-full rounded-full bg-sage text-base font-semibold text-black 
    transition-all duration-300
    hover:bg-sage/90 hover:scale-[1.02] hover:shadow-[0_0_60px_rgba(207,225,185,0.4)]
    disabled:opacity-50
    ${loading ? 'animate-pulse shadow-[0_0_40px_rgba(207,225,185,0.35)]' : 'shadow-[0_0_30px_rgba(207,225,185,0.2)]'}
  `}
>
  {loading ? 'Joining…' : 'Join & Tell Us About Yourself →'}
</Button>
```

Add `ring` focus styles to the email input:
```tsx
className="h-14 rounded-2xl border-white/10 bg-white/5 px-5 text-base placeholder:text-zinc-600 
  focus:border-sage/50 focus:ring-2 focus:ring-sage/20 focus:shadow-[0_0_20px_rgba(207,225,185,0.12)]
  transition-all duration-200"
```

**Step: Install and verify**
```bash
cd web && npm install canvas-confetti @types/canvas-confetti && npx tsc --noEmit 2>&1
```

**Step: Commit**
```bash
git add -A
git commit -m "feat(waitlist): add confetti burst, floating particles, and form micro-interactions"
```

---

## Final Verification

After all 7 tasks:

```bash
cd web && npm run build 2>&1
```

Expected: Clean build, 0 TypeScript errors, 0 linting errors.

Manual checks:
- [ ] Submit an email via the form → gets `201`, row appears in Supabase `waitlist_users`
- [ ] Stats counter animates on scroll in hero and waitlist section
- [ ] Confetti fires on reaching completion step
- [ ] No theme toggle visible anywhere; site is always dark
- [ ] Leaderboard renders (may be empty initially)
- [ ] Floating particles visible in waitlist section background
- [ ] Mobile responsive at 375px width

---

## Execution Order (Critical Path)

```
Task 1 (DB fix)  →  Task 2 (API fix)  →  Task 3 (Leaderboard fix)  →  Task 4 (Types)
                                                                              ↓
Task 5 (Theme)  ←──────────────────── can run in parallel ──────────────────→
Task 6 (Counter) ← depends on Task 3 (stats endpoint working)
Task 7 (Graphics) ← independent
```
