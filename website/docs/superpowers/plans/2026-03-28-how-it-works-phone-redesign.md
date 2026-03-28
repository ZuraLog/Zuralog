# How It Works — Phone Mockup Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the current tab-based How It Works section with a scroll-triggered sticky phone carousel showcasing all 6 app sections (Connect, Today, Data, Coach, Progress, Trends) through 3 realistic iPhone mockups with floating glassmorphic info cards.

**Architecture:** A single `HowItWorksSection` component (replacing the existing one) using GSAP ScrollTrigger for pin/scrub behavior. The section creates a tall scroll container (~600vh) with the phone group pinned to the viewport center. Scroll progress drives which step is active, updating phone screen content and glass card text via React state. Phone screens are pure CSS/JSX — no images or 3D. Background transitions from the page's light sage to the brand's dark canvas via a CSS gradient.

**Tech Stack:** React, GSAP ScrollTrigger (already in project), Framer Motion (for content transitions), Tailwind CSS, existing design system tokens from globals.css.

---

## File Structure

| Action | File | Responsibility |
|--------|------|---------------|
| Create | `src/components/sections/how-it-works/HowItWorksSection.tsx` | Main section: scroll container, GSAP pin, step state, layout |
| Create | `src/components/sections/how-it-works/PhoneFrame.tsx` | Reusable iPhone frame shell (bezel, dynamic island, status bar) |
| Create | `src/components/sections/how-it-works/PhoneScreens.tsx` | All 6 screen content components (Connect, Today, Data, Coach, Progress, Trends) |
| Create | `src/components/sections/how-it-works/GlassCard.tsx` | Floating glassmorphic info card (step number, headline, description) |
| Create | `src/components/sections/how-it-works/constants.ts` | Step data array (headlines, descriptions, accents) |
| Modify | `src/app/page.tsx:3` | Update import path to new HowItWorksSection |
| Delete | `src/components/sections/HowItWorksSection.tsx` | Old tab-based component (replaced) |

---

## Task 1: Create branch and constants file

**Files:**
- Create: `src/components/sections/how-it-works/constants.ts`

- [ ] **Step 1: Create feature branch**

```bash
git checkout -b feat/how-it-works-phone-redesign
```

- [ ] **Step 2: Create the constants file with all step data**

Create `src/components/sections/how-it-works/constants.ts` with the 6-step data array. Each step has an id, label, headline, description, and accent color.

```typescript
export const STEPS = [
  {
    id: "connect",
    label: "Connect",
    headline: "Link your world",
    description:
      "One tap to connect Apple Health, Google Health Connect, and 50+ more. Your data flows in automatically — no exports, no friction, no manual entry ever again.",
    accent: "#CFE1B9",
  },
  {
    id: "today",
    label: "Today",
    headline: "Your day, at a glance",
    description:
      "Daily insights, quick logging for water, calories, workouts — everything you need to know and do, all in one place.",
    accent: "#D4F291",
  },
  {
    id: "data",
    label: "Data",
    headline: "Your data, your way",
    description:
      "Organize, customize, and explore every metric. Built around you, not a template — your own personal health dashboard.",
    accent: "#E8F5A8",
  },
  {
    id: "coach",
    label: "Coach",
    headline: "Talk to your data",
    description:
      "Ask anything in plain English. \"Why am I tired?\" \"What should I eat tonight?\" Your AI health coach has all the context it needs.",
    accent: "#CFE1B9",
  },
  {
    id: "progress",
    label: "Progress",
    headline: "Set goals, earn wins",
    description:
      "Track goals, unlock achievements, journal your journey, and watch yourself grow — all your progress in one place.",
    accent: "#D4F291",
  },
  {
    id: "trends",
    label: "Trends",
    headline: "Discover what you can't see",
    description:
      "AI finds correlations in your data you'd never notice — like why your pace dropped after a bad night's sleep.",
    accent: "#E8F5A8",
  },
] as const;

export type Step = (typeof STEPS)[number];
```

- [ ] **Step 3: Commit**

```bash
git add src/components/sections/how-it-works/constants.ts
git commit -m "feat(how-it-works): add step constants for 6-section phone redesign"
```

---

## Task 2: Build the PhoneFrame component

**Files:**
- Create: `src/components/sections/how-it-works/PhoneFrame.tsx`

- [ ] **Step 1: Create the PhoneFrame component**

This is a pure presentational component — a CSS iPhone shell with dynamic island, status bar, and a children slot for screen content. It accepts `className` and `style` for positioning (tilt, opacity) from the parent.

```tsx
"use client";

import { type ReactNode } from "react";

interface PhoneFrameProps {
  children: ReactNode;
  className?: string;
  style?: React.CSSProperties;
}

export function PhoneFrame({ children, className = "", style }: PhoneFrameProps) {
  return (
    <div
      className={`relative flex-shrink-0 ${className}`}
      style={style}
    >
      {/* Outer bezel */}
      <div
        className="relative overflow-hidden rounded-[2.8rem]"
        style={{
          background: "#1a1a1a",
          border: "2.5px solid #2a2a2a",
          boxShadow:
            "0 0 0 1px rgba(255,255,255,0.05) inset, 0 20px 60px rgba(0,0,0,0.5)",
        }}
      >
        {/* Dynamic Island */}
        <div
          className="absolute left-1/2 top-3 z-20 -translate-x-1/2 rounded-full"
          style={{
            width: 72,
            height: 20,
            backgroundColor: "#000",
          }}
        />

        {/* Screen area */}
        <div className="relative m-[3px] overflow-hidden rounded-[2.6rem]" style={{ backgroundColor: "#161618" }}>
          {/* Status bar */}
          <div className="relative z-10 flex items-center justify-between px-7 pb-1 pt-4">
            <span className="text-[10px] font-semibold" style={{ color: "#F0EEE9" }}>
              9:41
            </span>
            <div className="flex items-center gap-1">
              {/* Signal bars */}
              <svg width="14" height="10" viewBox="0 0 14 10" fill="#F0EEE9">
                <rect x="0" y="6" width="2.5" height="4" rx="0.5" />
                <rect x="3.5" y="4" width="2.5" height="6" rx="0.5" />
                <rect x="7" y="2" width="2.5" height="8" rx="0.5" />
                <rect x="10.5" y="0" width="2.5" height="10" rx="0.5" />
              </svg>
              {/* Battery */}
              <svg width="14" height="10" viewBox="0 0 24 12" fill="#F0EEE9">
                <rect x="0" y="1" width="20" height="10" rx="2" stroke="#F0EEE9" strokeWidth="1.5" fill="none" />
                <rect x="21" y="4" width="2" height="4" rx="1" />
                <rect x="2" y="3" width="14" height="6" rx="1" />
              </svg>
            </div>
          </div>

          {/* Content slot */}
          <div className="relative" style={{ minHeight: 420 }}>
            {children}
          </div>

          {/* Home indicator */}
          <div
            className="mx-auto mb-2 mt-1 rounded-full"
            style={{ width: 100, height: 4, backgroundColor: "rgba(240,238,233,0.2)" }}
          />
        </div>
      </div>
    </div>
  );
}
```

- [ ] **Step 2: Commit**

```bash
git add src/components/sections/how-it-works/PhoneFrame.tsx
git commit -m "feat(how-it-works): add reusable PhoneFrame component"
```

---

## Task 3: Build the 6 phone screen content components

**Files:**
- Create: `src/components/sections/how-it-works/PhoneScreens.tsx`

- [ ] **Step 1: Create PhoneScreens.tsx with all 6 screen components**

Each screen is a self-contained component rendering fake app UI for its section. All use brand design tokens (dark canvas, sage accents, health category colors). Export a lookup object keyed by step id.

```tsx
"use client";

import {
  Zap, Moon, Heart, Flame, Footprints, Activity,
  Droplets, Dumbbell, Brain, TrendingUp, MessageCircle,
  Target, Trophy, BookOpen, Sparkles, Shield,
} from "lucide-react";
import { FaApple } from "react-icons/fa";
import { SiGooglefit } from "react-icons/si";

/* ─── Connect ─────────────────────────────────────────────── */
function ConnectScreen() {
  return (
    <div className="flex flex-col gap-3 px-4 pb-4 pt-2">
      <p className="text-center text-[10px] font-semibold" style={{ color: "#CFE1B9" }}>
        Connect Your Apps
      </p>
      <div className="grid grid-cols-2 gap-2">
        {[
          { icon: <FaApple size={18} />, name: "Apple Health", color: "#F0EEE9" },
          { icon: <SiGooglefit size={18} />, name: "Health Connect", color: "#4285F4" },
          { icon: <Zap size={18} />, name: "Strava", color: "#FC4C02" },
          { icon: <Activity size={18} />, name: "Fitbit", color: "#00B0B9" },
        ].map((app) => (
          <div
            key={app.name}
            className="flex flex-col items-center gap-1.5 rounded-2xl py-3"
            style={{ backgroundColor: "rgba(255,255,255,0.05)", border: "1px solid rgba(207,225,185,0.08)" }}
          >
            <div style={{ color: app.color }}>{app.icon}</div>
            <span className="text-[8px] font-medium" style={{ color: "#9B9894" }}>{app.name}</span>
          </div>
        ))}
      </div>
      <div
        className="rounded-full py-2 text-center text-[10px] font-semibold"
        style={{ backgroundColor: "#CFE1B9", color: "#1A2E22" }}
      >
        Connect Apps
      </div>
      <div className="flex flex-wrap justify-center gap-1">
        {["Sleep", "Heart", "Steps", "Calories"].map((tag) => (
          <span
            key={tag}
            className="rounded-full px-2 py-0.5 text-[7px] font-medium"
            style={{ backgroundColor: "rgba(207,225,185,0.1)", color: "#CFE1B9" }}
          >
            {tag}
          </span>
        ))}
      </div>
    </div>
  );
}

/* ─── Today ───────────────────────────────────────────────── */
function TodayScreen() {
  return (
    <div className="flex flex-col gap-2.5 px-4 pb-4 pt-2">
      <p className="text-[12px] font-bold" style={{ color: "#F0EEE9" }}>Good morning</p>
      {/* Health score card */}
      <div className="rounded-2xl p-3" style={{ backgroundColor: "rgba(207,225,185,0.08)", border: "1px solid rgba(207,225,185,0.12)" }}>
        <p className="text-[8px] font-semibold uppercase tracking-wider" style={{ color: "#9B9894" }}>Health Score</p>
        <p className="text-[22px] font-bold" style={{ color: "#CFE1B9" }}>82</p>
        <div className="mt-1 h-1.5 rounded-full" style={{ backgroundColor: "rgba(207,225,185,0.15)" }}>
          <div className="h-full rounded-full" style={{ width: "82%", backgroundColor: "#CFE1B9" }} />
        </div>
      </div>
      {/* Quick log buttons */}
      <div className="flex gap-1.5">
        {[
          { icon: Droplets, label: "Water", color: "#64D2FF" },
          { icon: Flame, label: "Calories", color: "#FF9F0A" },
          { icon: Dumbbell, label: "Workout", color: "#30D158" },
        ].map((item) => (
          <div
            key={item.label}
            className="flex flex-1 flex-col items-center gap-1 rounded-xl py-2"
            style={{ backgroundColor: `${item.color}10`, border: `1px solid ${item.color}20` }}
          >
            <item.icon size={12} style={{ color: item.color }} />
            <span className="text-[7px] font-medium" style={{ color: "#9B9894" }}>{item.label}</span>
          </div>
        ))}
      </div>
      {/* Insight card */}
      <div className="rounded-xl p-2.5" style={{ backgroundColor: "rgba(94,92,230,0.08)", border: "1px solid rgba(94,92,230,0.15)" }}>
        <div className="flex items-center gap-1.5">
          <Moon size={10} style={{ color: "#5E5CE6" }} />
          <p className="text-[8px] font-medium" style={{ color: "#F0EEE9" }}>Sleep was 8h 12m — above your average</p>
        </div>
      </div>
    </div>
  );
}

/* ─── Data ────────────────────────────────────────────────── */
function DataScreen() {
  return (
    <div className="flex flex-col gap-2 px-4 pb-4 pt-2">
      <p className="text-[10px] font-semibold" style={{ color: "#F0EEE9" }}>Your Data</p>
      <div className="grid grid-cols-2 gap-1.5">
        {[
          { label: "Steps", value: "8,432", icon: Footprints, color: "#30D158" },
          { label: "Heart Rate", value: "62 bpm", icon: Heart, color: "#FF375F" },
          { label: "Sleep", value: "7h 42m", icon: Moon, color: "#5E5CE6" },
          { label: "Calories", value: "1,840", icon: Flame, color: "#FF9F0A" },
        ].map((metric) => (
          <div
            key={metric.label}
            className="rounded-xl p-2.5"
            style={{ backgroundColor: "rgba(255,255,255,0.04)", border: "1px solid rgba(240,238,233,0.06)" }}
          >
            <metric.icon size={10} style={{ color: metric.color }} />
            <p className="mt-1 text-[12px] font-bold" style={{ color: "#F0EEE9" }}>{metric.value}</p>
            <p className="text-[7px]" style={{ color: "#9B9894" }}>{metric.label}</p>
          </div>
        ))}
      </div>
      {/* Mini chart placeholder */}
      <div className="rounded-xl p-2.5" style={{ backgroundColor: "rgba(255,255,255,0.04)", border: "1px solid rgba(240,238,233,0.06)" }}>
        <p className="mb-1.5 text-[8px] font-medium" style={{ color: "#9B9894" }}>Weekly Steps</p>
        <div className="flex items-end gap-1" style={{ height: 32 }}>
          {[60, 80, 45, 90, 70, 85, 75].map((h, i) => (
            <div
              key={i}
              className="flex-1 rounded-sm"
              style={{ height: `${h}%`, backgroundColor: i === 6 ? "#CFE1B9" : "rgba(207,225,185,0.2)" }}
            />
          ))}
        </div>
      </div>
    </div>
  );
}

/* ─── Coach ───────────────────────────────────────────────── */
function CoachScreen() {
  return (
    <div className="flex flex-col gap-2 px-4 pb-4 pt-2">
      <div className="flex items-center gap-1.5">
        <div className="flex h-5 w-5 items-center justify-center rounded-full" style={{ backgroundColor: "#CFE1B9" }}>
          <Sparkles size={10} style={{ color: "#1A2E22" }} />
        </div>
        <p className="text-[10px] font-semibold" style={{ color: "#F0EEE9" }}>Health Coach</p>
      </div>
      {/* Chat messages */}
      <div className="flex flex-col gap-1.5">
        <div className="ml-auto max-w-[80%] rounded-2xl rounded-br-md px-2.5 py-1.5" style={{ backgroundColor: "rgba(207,225,185,0.15)", border: "1px solid rgba(207,225,185,0.25)" }}>
          <p className="text-[8px]" style={{ color: "#F0EEE9" }}>Why am I not losing weight?</p>
        </div>
        <div className="max-w-[85%] rounded-2xl rounded-bl-md px-2.5 py-1.5" style={{ backgroundColor: "rgba(255,255,255,0.06)", border: "1px solid rgba(240,238,233,0.08)" }}>
          <p className="text-[8px] leading-relaxed" style={{ color: "#F0EEE9" }}>
            Your calorie data shows a 230 cal surplus. Evening snacking is the main factor. Plus runs dropped from 8 to 3 this month.
          </p>
        </div>
        <div className="ml-auto max-w-[80%] rounded-2xl rounded-br-md px-2.5 py-1.5" style={{ backgroundColor: "rgba(207,225,185,0.15)", border: "1px solid rgba(207,225,185,0.25)" }}>
          <p className="text-[8px]" style={{ color: "#F0EEE9" }}>What should I change?</p>
        </div>
        <div className="max-w-[85%] rounded-2xl rounded-bl-md px-2.5 py-1.5" style={{ backgroundColor: "rgba(255,255,255,0.06)", border: "1px solid rgba(240,238,233,0.08)" }}>
          <p className="text-[8px] leading-relaxed" style={{ color: "#F0EEE9" }}>
            Cut 250 cals — skip the post-dinner snack — and get back to 5+ runs/week.
          </p>
        </div>
      </div>
    </div>
  );
}

/* ─── Progress ────────────────────────────────────────────── */
function ProgressScreen() {
  return (
    <div className="flex flex-col gap-2.5 px-4 pb-4 pt-2">
      <p className="text-[10px] font-semibold" style={{ color: "#F0EEE9" }}>Your Progress</p>
      {/* Goal card */}
      <div className="rounded-xl p-2.5" style={{ backgroundColor: "rgba(48,209,88,0.08)", border: "1px solid rgba(48,209,88,0.15)" }}>
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-1.5">
            <Target size={10} style={{ color: "#30D158" }} />
            <p className="text-[8px] font-medium" style={{ color: "#F0EEE9" }}>Run 5x this week</p>
          </div>
          <p className="text-[9px] font-bold" style={{ color: "#30D158" }}>3/5</p>
        </div>
        <div className="mt-1.5 h-1 rounded-full" style={{ backgroundColor: "rgba(48,209,88,0.15)" }}>
          <div className="h-full rounded-full" style={{ width: "60%", backgroundColor: "#30D158" }} />
        </div>
      </div>
      {/* Achievement */}
      <div className="flex items-center gap-2 rounded-xl p-2.5" style={{ backgroundColor: "rgba(255,159,10,0.08)", border: "1px solid rgba(255,159,10,0.15)" }}>
        <Trophy size={14} style={{ color: "#FF9F0A" }} />
        <div>
          <p className="text-[8px] font-semibold" style={{ color: "#F0EEE9" }}>7-Day Streak!</p>
          <p className="text-[7px]" style={{ color: "#9B9894" }}>Logged every day this week</p>
        </div>
      </div>
      {/* Journal entry */}
      <div className="rounded-xl p-2.5" style={{ backgroundColor: "rgba(255,255,255,0.04)", border: "1px solid rgba(240,238,233,0.06)" }}>
        <div className="flex items-center gap-1.5 mb-1">
          <BookOpen size={9} style={{ color: "#CFE1B9" }} />
          <p className="text-[8px] font-medium" style={{ color: "#9B9894" }}>Today's Journal</p>
        </div>
        <p className="text-[7px] leading-relaxed" style={{ color: "#F0EEE9" }}>
          Feeling good after morning run. Energy levels are up this week...
        </p>
      </div>
    </div>
  );
}

/* ─── Trends ──────────────────────────────────────────────── */
function TrendsScreen() {
  return (
    <div className="flex flex-col gap-2 px-4 pb-4 pt-2">
      <div className="flex items-center gap-1.5">
        <Brain size={12} style={{ color: "#CFE1B9" }} />
        <p className="text-[10px] font-semibold" style={{ color: "#F0EEE9" }}>AI Trends</p>
      </div>
      {[
        {
          text: "Sleep < 7hrs → pace drops 12% next day",
          icon: Moon,
          color: "#5E5CE6",
        },
        {
          text: "Evening snacking adds 230 cal surplus",
          icon: Flame,
          color: "#FF9F0A",
        },
        {
          text: "HRV trending up 12% this week",
          icon: Heart,
          color: "#30D158",
        },
        {
          text: "Protein > 120g → recovery improves 18%",
          icon: Shield,
          color: "#64D2FF",
        },
      ].map((item, idx) => (
        <div
          key={idx}
          className="flex items-start gap-2 rounded-xl p-2"
          style={{ backgroundColor: `${item.color}08`, border: `1px solid ${item.color}15` }}
        >
          <div
            className="mt-0.5 flex h-5 w-5 flex-shrink-0 items-center justify-center rounded-md"
            style={{ backgroundColor: `${item.color}15` }}
          >
            <item.icon size={10} style={{ color: item.color }} />
          </div>
          <p className="text-[8px] font-medium leading-snug" style={{ color: "#F0EEE9" }}>
            {item.text}
          </p>
        </div>
      ))}
    </div>
  );
}

/* ─── Lookup ──────────────────────────────────────────────── */
export const PHONE_SCREENS: Record<string, () => JSX.Element> = {
  connect: ConnectScreen,
  today: TodayScreen,
  data: DataScreen,
  coach: CoachScreen,
  progress: ProgressScreen,
  trends: TrendsScreen,
};
```

- [ ] **Step 2: Commit**

```bash
git add src/components/sections/how-it-works/PhoneScreens.tsx
git commit -m "feat(how-it-works): add 6 phone screen content components"
```

---

## Task 4: Build the GlassCard component

**Files:**
- Create: `src/components/sections/how-it-works/GlassCard.tsx`

- [ ] **Step 1: Create the GlassCard component**

A floating glassmorphic card that displays step number, headline, and description. Uses Framer Motion for enter/exit animations.

```tsx
"use client";

import { motion, AnimatePresence } from "framer-motion";
import type { Step } from "./constants";

interface GlassCardProps {
  step: Step;
  stepIndex: number;
  isVisible: boolean;
}

export function GlassCard({ step, stepIndex, isVisible }: GlassCardProps) {
  return (
    <AnimatePresence mode="wait">
      {isVisible && (
        <motion.div
          key={step.id}
          initial={{ opacity: 0, y: 20, filter: "blur(8px)" }}
          animate={{ opacity: 1, y: 0, filter: "blur(0px)" }}
          exit={{ opacity: 0, y: -20, filter: "blur(8px)" }}
          transition={{ duration: 0.4, ease: [0.16, 1, 0.3, 1] }}
          className="pointer-events-none absolute bottom-8 left-1/2 z-30 w-[320px] -translate-x-1/2 sm:bottom-12 sm:w-[380px]"
        >
          <div
            className="rounded-2xl px-6 py-5"
            style={{
              backgroundColor: "rgba(22, 22, 24, 0.75)",
              backdropFilter: "blur(16px)",
              WebkitBackdropFilter: "blur(16px)",
              border: `1px solid rgba(207, 225, 185, 0.12)`,
              boxShadow: `0 8px 32px rgba(0,0,0,0.3), 0 0 0 1px rgba(207,225,185,0.04), 0 0 60px ${step.accent}08`,
            }}
          >
            {/* Step badge */}
            <div
              className="mb-3 inline-flex items-center gap-1.5 rounded-full px-3 py-1"
              style={{
                backgroundColor: `${step.accent}15`,
                border: `1px solid ${step.accent}25`,
              }}
            >
              <span className="text-[11px] font-bold" style={{ color: step.accent }}>
                {stepIndex + 1}
              </span>
              <span className="text-[10px] font-semibold" style={{ color: step.accent }}>
                {step.label}
              </span>
            </div>

            {/* Headline */}
            <h3
              className="mb-2 text-xl font-bold tracking-tight sm:text-2xl"
              style={{ color: "#F0EEE9", fontFamily: "var(--font-jakarta)" }}
            >
              {step.headline}
            </h3>

            {/* Description */}
            <p className="text-sm leading-relaxed" style={{ color: "#9B9894" }}>
              {step.description}
            </p>
          </div>
        </motion.div>
      )}
    </AnimatePresence>
  );
}
```

- [ ] **Step 2: Commit**

```bash
git add src/components/sections/how-it-works/GlassCard.tsx
git commit -m "feat(how-it-works): add floating GlassCard component"
```

---

## Task 5: Build the main HowItWorksSection component

**Files:**
- Create: `src/components/sections/how-it-works/HowItWorksSection.tsx`

- [ ] **Step 1: Create the main section component**

This is the core component. It creates a tall scroll container, pins the phone group using GSAP ScrollTrigger, and updates the active step based on scroll progress. The 3 phones use carousel-peek logic: center = active step, left = previous step (dimmed), right = next step (dimmed).

```tsx
"use client";

import { useRef, useState, useEffect, useCallback } from "react";
import gsap from "gsap";
import { ScrollTrigger } from "gsap/ScrollTrigger";
import { AnimatePresence, motion } from "framer-motion";
import { PhoneFrame } from "./PhoneFrame";
import { PHONE_SCREENS } from "./PhoneScreens";
import { GlassCard } from "./GlassCard";
import { STEPS } from "./constants";

const STEP_COUNT = STEPS.length;
const EXPO_OUT: [number, number, number, number] = [0.16, 1, 0.3, 1];

export function HowItWorksSection() {
  const sectionRef = useRef<HTMLDivElement>(null);
  const pinRef = useRef<HTMLDivElement>(null);
  const [activeStep, setActiveStep] = useState(0);

  useEffect(() => {
    const section = sectionRef.current;
    const pin = pinRef.current;
    if (!section || !pin) return;

    const prefersReducedMotion = window.matchMedia(
      "(prefers-reduced-motion: reduce)",
    ).matches;

    if (prefersReducedMotion) return;

    const trigger = ScrollTrigger.create({
      trigger: section,
      start: "top top",
      end: "bottom bottom",
      pin: pin,
      pinSpacing: false,
      onUpdate: (self) => {
        const progress = self.progress;
        const step = Math.min(
          STEP_COUNT - 1,
          Math.floor(progress * STEP_COUNT),
        );
        setActiveStep(step);
      },
    });

    return () => {
      trigger.kill();
    };
  }, []);

  const getScreenId = useCallback(
    (offset: number) => {
      const idx = activeStep + offset;
      if (idx < 0 || idx >= STEP_COUNT) return null;
      return STEPS[idx].id;
    },
    [activeStep],
  );

  const renderScreen = (stepId: string | null) => {
    if (!stepId) return null;
    const Screen = PHONE_SCREENS[stepId];
    return Screen ? <Screen /> : null;
  };

  const leftId = getScreenId(-1);
  const centerId = getScreenId(0);
  const rightId = getScreenId(1);

  return (
    <section
      ref={sectionRef}
      id="how-it-works-section"
      className="relative w-full"
      style={{ height: `${STEP_COUNT * 100}vh` }}
    >
      {/* Background gradient: light sage → deep forest → dark canvas */}
      <div
        className="pointer-events-none absolute inset-0"
        style={{
          background:
            "linear-gradient(to bottom, transparent 0%, #344E41 15%, #1A2E22 30%, #161618 50%, #161618 100%)",
        }}
      />

      {/* Topographic pattern overlay on the dark zone */}
      <div
        className="pointer-events-none absolute inset-0"
        style={{
          backgroundImage: "url(/patterns/original.png)",
          backgroundSize: "600px",
          backgroundRepeat: "repeat",
          opacity: 0.04,
          mixBlendMode: "screen",
          maskImage: "linear-gradient(to bottom, transparent 0%, black 30%, black 100%)",
          WebkitMaskImage: "linear-gradient(to bottom, transparent 0%, black 30%, black 100%)",
        }}
      />

      {/* Pinned viewport container */}
      <div ref={pinRef} className="relative flex h-screen w-full flex-col items-center justify-center overflow-hidden">
        {/* Section heading */}
        <div className="absolute top-8 left-0 right-0 text-center sm:top-12">
          <p
            className="text-xs font-semibold tracking-[0.25em] uppercase mb-2"
            style={{ color: "rgba(207,225,185,0.5)" }}
          >
            How It Works
          </p>
          <h2
            className="text-3xl font-bold tracking-tight sm:text-4xl lg:text-5xl"
            style={{ color: "#F0EEE9" }}
          >
            How ZuraLog Works
          </h2>

          {/* Progress dots */}
          <div className="mt-4 flex items-center justify-center gap-2">
            {STEPS.map((step, i) => (
              <div
                key={step.id}
                className="rounded-full transition-all duration-300"
                style={{
                  width: i === activeStep ? 24 : 6,
                  height: 6,
                  backgroundColor:
                    i === activeStep ? "#CFE1B9" : "rgba(207,225,185,0.2)",
                }}
              />
            ))}
          </div>
        </div>

        {/* Phone group */}
        <div className="relative flex items-end justify-center gap-4 sm:gap-6 lg:gap-8">
          {/* Ambient glow behind center phone */}
          <div
            className="pointer-events-none absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2"
            style={{
              width: 400,
              height: 400,
              borderRadius: "50%",
              background: `radial-gradient(circle, ${STEPS[activeStep].accent}18 0%, transparent 70%)`,
              transition: "background 0.5s ease",
            }}
          />

          {/* Left phone (previous step) */}
          <div className="hidden sm:block">
            <PhoneFrame
              className="w-[140px] md:w-[160px] lg:w-[180px]"
              style={{
                transform: "rotate(-6deg) translateY(-12px)",
                opacity: leftId ? 0.4 : 0,
                transition: "opacity 0.4s ease",
              }}
            >
              <AnimatePresence mode="wait">
                {leftId && (
                  <motion.div
                    key={leftId}
                    initial={{ opacity: 0 }}
                    animate={{ opacity: 1 }}
                    exit={{ opacity: 0 }}
                    transition={{ duration: 0.3, ease: EXPO_OUT }}
                  >
                    {renderScreen(leftId)}
                  </motion.div>
                )}
              </AnimatePresence>
            </PhoneFrame>
          </div>

          {/* Center phone (active step) */}
          <PhoneFrame className="w-[200px] sm:w-[220px] md:w-[240px] lg:w-[260px] z-10">
            <AnimatePresence mode="wait">
              {centerId && (
                <motion.div
                  key={centerId}
                  initial={{ opacity: 0, y: 10 }}
                  animate={{ opacity: 1, y: 0 }}
                  exit={{ opacity: 0, y: -10 }}
                  transition={{ duration: 0.35, ease: EXPO_OUT }}
                >
                  {renderScreen(centerId)}
                </motion.div>
              )}
            </AnimatePresence>
          </PhoneFrame>

          {/* Right phone (next step) */}
          <div className="hidden sm:block">
            <PhoneFrame
              className="w-[140px] md:w-[160px] lg:w-[180px]"
              style={{
                transform: "rotate(6deg) translateY(-12px)",
                opacity: rightId ? 0.4 : 0,
                transition: "opacity 0.4s ease",
              }}
            >
              <AnimatePresence mode="wait">
                {rightId && (
                  <motion.div
                    key={rightId}
                    initial={{ opacity: 0 }}
                    animate={{ opacity: 1 }}
                    exit={{ opacity: 0 }}
                    transition={{ duration: 0.3, ease: EXPO_OUT }}
                  >
                    {renderScreen(rightId)}
                  </motion.div>
                )}
              </AnimatePresence>
            </PhoneFrame>
          </div>
        </div>

        {/* Floating glass card */}
        <GlassCard
          step={STEPS[activeStep]}
          stepIndex={activeStep}
          isVisible={true}
        />
      </div>
    </section>
  );
}
```

- [ ] **Step 2: Commit**

```bash
git add src/components/sections/how-it-works/HowItWorksSection.tsx
git commit -m "feat(how-it-works): add scroll-triggered sticky phone carousel section"
```

---

## Task 6: Wire up the new section and remove the old one

**Files:**
- Modify: `src/app/page.tsx:3`
- Delete: `src/components/sections/HowItWorksSection.tsx`

- [ ] **Step 1: Update the import in page.tsx**

Change line 6 from:
```typescript
import { HowItWorksSection } from "@/components/sections/HowItWorksSection";
```
to:
```typescript
import { HowItWorksSection } from "@/components/sections/how-it-works/HowItWorksSection";
```

No other changes needed — the component name and id remain the same.

- [ ] **Step 2: Delete the old component file**

```bash
rm src/components/sections/HowItWorksSection.tsx
```

- [ ] **Step 3: Verify the dev server starts without errors**

```bash
npm run dev
```

Expected: No TypeScript or import errors. The page should load with the new How It Works section.

- [ ] **Step 4: Commit**

```bash
git add src/app/page.tsx
git add -u src/components/sections/HowItWorksSection.tsx
git commit -m "feat(how-it-works): wire new section into page, remove old component"
```

---

## Task 7: Visual QA and polish

**Files:**
- Modify: `src/components/sections/how-it-works/HowItWorksSection.tsx` (as needed)
- Modify: `src/components/sections/how-it-works/PhoneFrame.tsx` (as needed)
- Modify: `src/components/sections/how-it-works/GlassCard.tsx` (as needed)

- [ ] **Step 1: Open the site in a browser and scroll through the section**

```bash
npm run dev
```

Open `http://localhost:3000` and scroll to the How It Works section. Verify:

1. Background gradient transitions smoothly from the light page to dark
2. Phones pin correctly and stay centered while scrolling
3. All 6 steps trigger correctly — center phone content changes
4. Left/right phones show previous/next steps with dimmed opacity
5. Left phone is hidden on step 1, right phone is hidden on step 6
6. Glass card text updates with each step
7. Progress dots update correctly
8. On mobile (< 640px): only center phone visible, glass card below
9. Topographic pattern is visible but subtle on dark zone
10. No layout shift when phones pin/unpin

- [ ] **Step 2: Fix any issues found during QA**

Address any visual or functional issues. Common things to tune:
- ScrollTrigger start/end positions
- Phone sizes for different breakpoints
- Glass card positioning
- Gradient transition blending with surrounding sections
- Content overflow within phone screens

- [ ] **Step 3: Test the gradient fallback (option B)**

If the gradient transition looks jarring with the surrounding page sections, the user wants to fall back to keeping the light background. Test by temporarily changing the background gradient to match the page background and compare.

- [ ] **Step 4: Commit any polish fixes**

```bash
git add -A src/components/sections/how-it-works/
git commit -m "fix(how-it-works): visual polish and QA fixes"
```

---

## Task 8: Verify patterns file exists and final cleanup

**Files:**
- Check: `public/patterns/original.png`

- [ ] **Step 1: Verify the topographic pattern file exists**

```bash
ls -la public/patterns/original.png
```

If the file doesn't exist, check for alternative paths:

```bash
find public -name "*.png" -path "*pattern*" -o -name "*.png" -path "*topo*" 2>/dev/null
```

If no pattern file exists in `public/`, copy from the brand assets:

```bash
mkdir -p public/patterns
cp "assets/brand/pattern/Original.PNG" public/patterns/original.png
```

- [ ] **Step 2: Final commit**

```bash
git add public/patterns/
git commit -m "chore(how-it-works): ensure topographic pattern asset exists"
```

- [ ] **Step 3: Push the branch**

```bash
git push -u origin feat/how-it-works-phone-redesign
```
