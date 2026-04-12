"use client";

import type { ReactNode } from "react";
import { PhoneMockup } from "@/components/phone";
import { ConnectScreen } from "@/components/phone/screens/ConnectScreen";
import { NutritionScreen } from "@/components/phone/screens/NutritionScreen";
import { WorkoutScreen } from "@/components/phone/screens/WorkoutScreen";
import { SleepScreen } from "@/components/phone/screens/SleepScreen";
import { HeartScreen } from "@/components/phone/screens/HeartScreen";
import { MoreScreen } from "@/components/phone/screens/MoreScreen";
import { CoachScreen } from "@/components/phone/screens/CoachScreen";

// ---------------------------------------------------------------------------
// Type definition
// ---------------------------------------------------------------------------

interface MobileSectionData {
  key: string;
  headline: ReactNode;
  body: string;
  screen: ReactNode;
}

// ---------------------------------------------------------------------------
// MOBILE_SECTIONS — 7 entries, headlines/body match FeatureSections.tsx exactly
// ---------------------------------------------------------------------------

const MOBILE_SECTIONS: MobileSectionData[] = [
  {
    key: "connect",
    headline: (
      <>
        Every app. Every device.{" "}
        <span
          className="ds-pattern-text"
          style={{ backgroundImage: "var(--ds-pattern-sage)" }}
        >
          One place.
        </span>
      </>
    ),
    body: "Most health apps make you start from scratch. ZuraLog connects directly to Apple Health, Google Health Connect, Strava, and more\u2014so everything you have already been tracking is ready from day one.",
    screen: <ConnectScreen />,
  },
  {
    key: "nutrition",
    headline: (
      <>
        Snap it. Scan it. Say it.{" "}
        <span
          className="ds-pattern-text"
          style={{ backgroundImage: "var(--ds-pattern-sage)" }}
        >
          Done.
        </span>
      </>
    ),
    body: "No more nutrition apps that take longer than the meal itself. Snap a photo, scan a label, tell Zura what you had, or log it manually. It figures out everything automatically.",
    screen: <NutritionScreen />,
  },
  {
    key: "workouts",
    headline: (
      <>
        Log it live, log it later, or{" "}
        <span
          className="ds-pattern-text"
          style={{ backgroundImage: "var(--ds-pattern-sage)" }}
        >
          let it log itself.
        </span>
      </>
    ),
    body: "Track your sets and reps live, log a workout you already finished, or let Zura pull it in automatically from Apple Health or Google Health Connect. Every session counts, no matter how you log it.",
    screen: <WorkoutScreen />,
  },
  {
    key: "sleep",
    headline: (
      <>
        Sleep better. Know{" "}
        <span
          className="ds-pattern-text"
          style={{ backgroundImage: "var(--ds-pattern-sage)" }}
        >
          exactly why you&apos;re not.
        </span>
      </>
    ),
    body: "Most apps show you a sleep chart and call it done. Zura goes further\u2014connecting your sleep patterns to your workouts, stress, and daily habits to tell you what is actually working and what is not.",
    screen: <SleepScreen />,
  },
  {
    key: "heart",
    headline: (
      <>
        Know your heart.{" "}
        <span
          className="ds-pattern-text"
          style={{ backgroundImage: "var(--ds-pattern-sage)" }}
        >
          Know your health.
        </span>
      </>
    ),
    body: "Your heart responds to everything\u2014your workouts, your meals, your sleep, your steps. Zura connects all of it so you stop seeing isolated numbers and start seeing the full picture.",
    screen: <HeartScreen />,
  },
  {
    key: "more",
    headline: <>And that&apos;s just the beginning.</>,
    body: "The more you track, the more Zura understands. And the more Zura understands, the better it gets.",
    screen: <MoreScreen />,
  },
  {
    key: "coach",
    headline: (
      <>
        Meet Zura. The coach who knows your{" "}
        <span
          className="ds-pattern-text"
          style={{ backgroundImage: "var(--ds-pattern-sage)" }}
        >
          whole story.
        </span>
      </>
    ),
    body: "You\u2019ve been tracking everything. Now finally get something back. Zura reads across your workouts, meals, sleep, and heart rate to tell you what\u2019s working, what isn\u2019t, and exactly what to do next.",
    screen: <CoachScreen />,
  },
];

// ---------------------------------------------------------------------------
// FeatureSectionsMobile — stacked layout, no animations, hidden on desktop
// ---------------------------------------------------------------------------

export function FeatureSectionsMobile() {
  return (
    <div className="md:hidden">
      {MOBILE_SECTIONS.map((section) => (
        <section
          key={section.key}
          id={`${section.key}-section-mobile`}
          className="relative py-16 flex flex-col items-center"
        >
          <div className="w-full max-w-7xl mx-auto px-6 text-center">
            <h2 className="text-3xl sm:text-4xl font-bold tracking-tight leading-[1.05] text-[var(--color-ds-text-on-warm-white)]">
              {section.headline}
            </h2>
            <p className="mt-4 text-base sm:text-lg leading-relaxed text-[var(--color-ds-text-secondary)] max-w-lg mx-auto">
              {section.body}
            </p>
          </div>
          <div className="mt-8 flex justify-center">
            <PhoneMockup frameWidth={260}>{section.screen}</PhoneMockup>
          </div>
        </section>
      ))}
    </div>
  );
}
