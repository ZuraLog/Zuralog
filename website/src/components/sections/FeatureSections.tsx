"use client";

import { StickyBeatsSection, type Beat } from "./StickyBeatsSection";

// ---------------------------------------------------------------------------
// Beat data
// ---------------------------------------------------------------------------

const CONNECT_BEATS: Beat[] = [
  {
    headline: "Every app.",
    body: "Most health apps make you start from scratch. ZuraLog connects directly to Apple Health, Google Health Connect, Strava, and more.",
    image: "/images/feature/connect_1.png",
  },
  {
    headline: "Every device.",
    body: "It doesn\u2019t matter what you track it on. Phone, watch, ring, or scale\u2014if it has health data, ZuraLog reads it.",
    image: "/images/feature/connect_2.png",
  },
  {
    headline: "One place.",
    body: "Everything you\u2019ve already been tracking is ready from day one. No setup. No manual entry. Just your data.",
    image: "/images/feature/connect_3.png",
  },
];

const NUTRITION_BEATS: Beat[] = [
  {
    headline: "Snap it.",
    body: "See it, log it. Snap any meal for an instant nutrition breakdown\u2014no typing, no guessing.",
    image: "/images/feature/nutrition.png",
  },
  {
    headline: "Scan it.",
    body: "Got a label? Scan it. ZuraLog reads any barcode and fills in the nutrition facts automatically.",
    image: "/images/feature/nutrition.png",
  },
  {
    headline: "Say it. Done.",
    body: "Just tell Zura what you had, or log it manually. However you want to do it, it works.",
    image: "/images/feature/nutrition.png",
  },
];

const WORKOUTS_BEATS: Beat[] = [
  {
    headline: "Log it live.",
    body: "Track your sets, reps, and weight in real time as you train. No fumbling with paper, no forgetting after.",
    image: "/images/feature/blank.png",
  },
  {
    headline: "Log it later.",
    body: "Finished a workout you didn\u2019t log? Just tell Zura. Add any session after the fact and it slots right into your history.",
    image: "/images/feature/blank.png",
  },
  {
    headline: "Or let it log itself.",
    body: "Connect Apple Health or Google Health Connect and your workouts appear automatically\u2014no extra steps.",
    image: "/images/feature/blank.png",
  },
];

const SLEEP_BEATS: Beat[] = [
  {
    headline: "Sleep better.",
    body: "Every morning, see exactly how you slept\u2014duration, quality, and stages. All synced automatically from your device.",
    image: "/images/feature/blank.png",
  },
  {
    headline: "Know exactly.",
    body: "ZuraLog connects your sleep to everything else\u2014your training load, your meals, your stress. Not just a chart.",
    image: "/images/feature/blank.png",
  },
  {
    headline: "Why you\u2019re not.",
    body: "Get clear, specific insights. Not \u2018sleep more.\u2019 What\u2019s actually keeping you up, and what to do about it.",
    image: "/images/feature/blank.png",
  },
];

const HEART_BEATS: Beat[] = [
  {
    headline: "Know your heart.",
    body: "Your resting heart rate, HRV, and recovery score\u2014tracked automatically and shown in context.",
    image: "/images/feature/blank.png",
  },
  {
    headline: "Know your patterns.",
    body: "Your heart responds to everything\u2014workouts, meals, sleep, stress. ZuraLog shows you the connections.",
    image: "/images/feature/blank.png",
  },
  {
    headline: "Know your health.",
    body: "Stop seeing isolated numbers. Start seeing what they mean together\u2014and what to do about it.",
    image: "/images/feature/blank.png",
  },
];

const COACH_BEATS: Beat[] = [
  {
    headline: "What\u2019s working.",
    body: "Zura reads across all your data to find what\u2019s actually moving the needle for you\u2014not generic advice.",
    image: "/images/feature/blank.png",
  },
  {
    headline: "What isn\u2019t.",
    body: "Patterns that are holding you back surface automatically. No manual analysis. No spreadsheets.",
    image: "/images/feature/blank.png",
  },
  {
    headline: "What to do next.",
    body: "You\u2019ve been tracking everything. Now finally get something back. Zura tells you exactly what to do next.",
    image: "/images/feature/blank.png",
  },
];

// ---------------------------------------------------------------------------
// More — centered teaser, no beats
// ---------------------------------------------------------------------------

function MoreSection() {
  return (
    <section
      id="more-section"
      className="relative min-h-screen flex flex-col items-center justify-center overflow-hidden px-8 md:px-16 text-center"
    >
      <h2
        className="font-jakarta font-bold uppercase tracking-tighter leading-[0.85] text-[#161618]"
        style={{ fontSize: "clamp(3.5rem, 9vw, 11rem)" }}
      >
        And that&apos;s just<br />the beginning.
      </h2>
      <p className="font-jakarta mt-10 text-xl md:text-2xl text-[#6B6864] max-w-2xl">
        The more you track, the more Zura understands. And the more Zura understands, the better it gets.
      </p>
    </section>
  );
}

// ---------------------------------------------------------------------------
// FeatureSections
// ---------------------------------------------------------------------------

export function FeatureSections() {
  return (
    <div id="feature-sections">
      <StickyBeatsSection id="connect-section"   beats={CONNECT_BEATS}   layout="image-right" />
      <StickyBeatsSection id="nutrition-section" beats={NUTRITION_BEATS} layout="image-left"  />
      <StickyBeatsSection id="workouts-section"  beats={WORKOUTS_BEATS}  layout="image-right" />
      <StickyBeatsSection id="sleep-section"     beats={SLEEP_BEATS}     layout="image-left"  />
      <StickyBeatsSection id="heart-section"     beats={HEART_BEATS}     layout="image-right" />
      <MoreSection />
      <StickyBeatsSection id="coach-section"     beats={COACH_BEATS}     layout="image-left"  />
    </div>
  );
}
