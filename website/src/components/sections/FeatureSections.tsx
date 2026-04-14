"use client";

import type { ReactNode } from "react";
import Image from "next/image";
import { StickyBeatsSection, type Beat } from "./StickyBeatsSection";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

type SectionLayout = "image-right" | "image-left" | "image-center";

interface SectionData {
  key: string;
  headline: ReactNode;
  body: string;
  layout: SectionLayout;
  image: string | null;
}

// ---------------------------------------------------------------------------
// Beat data
// ---------------------------------------------------------------------------

const CONNECT_BEATS: Beat[] = [
  {
    headline: "Every app.",
    body: "Most health apps make you start from scratch. ZuraLog connects directly to Apple Health, Google Health Connect, Strava, and more.",
    image: "/images/feature/connect.png",
  },
  {
    headline: "Every device.",
    body: "It doesn't matter what you track it on. Phone, watch, ring, or scale — if it has health data, ZuraLog reads it.",
    image: "/images/feature/connect.png",
  },
  {
    headline: "One place.",
    body: "Everything you've already been tracking is ready from day one. No setup. No manual entry. Just your data.",
    image: "/images/feature/connect.png",
  },
];

// ---------------------------------------------------------------------------
// Section data
// ---------------------------------------------------------------------------

const SECTIONS: SectionData[] = [
  {
    key: "nutrition",
    layout: "image-left",
    image: null,
    headline: (
      <>
        Snap it.<br />
        Scan it.<br />
        Say it.{" "}
        <span
          className="ds-pattern-text"
          style={{ backgroundImage: "var(--ds-pattern-sage)" }}
        >
          Done.
        </span>
      </>
    ),
    body: "No more nutrition apps that take longer than the meal itself. Snap a photo, scan a label, tell Zura what you had, or log it manually. It figures out everything automatically.",
  },
  {
    key: "workouts",
    layout: "image-right",
    image: null,
    headline: (
      <>
        Log it live.<br />
        Log it later.<br />
        <span
          className="ds-pattern-text"
          style={{ backgroundImage: "var(--ds-pattern-sage)" }}
        >
          Or let it log itself.
        </span>
      </>
    ),
    body: "Track your sets and reps live, log a workout you already finished, or let Zura pull it in automatically from Apple Health or Google Health Connect. Every session counts.",
  },
  {
    key: "sleep",
    layout: "image-left",
    image: null,
    headline: (
      <>
        Sleep better.<br />
        Know{" "}
        <span
          className="ds-pattern-text"
          style={{ backgroundImage: "var(--ds-pattern-sage)" }}
        >
          exactly<br />why you&apos;re not.
        </span>
      </>
    ),
    body: "Most apps show you a sleep chart and call it done. Zura goes further\u2014connecting your sleep patterns to your workouts, stress, and daily habits.",
  },
  {
    key: "heart",
    layout: "image-right",
    image: null,
    headline: (
      <>
        Know your heart.<br />
        <span
          className="ds-pattern-text"
          style={{ backgroundImage: "var(--ds-pattern-sage)" }}
        >
          Know your health.
        </span>
      </>
    ),
    body: "Your heart responds to everything\u2014your workouts, your meals, your sleep, your steps. Zura connects all of it so you stop seeing isolated numbers.",
  },
  {
    key: "more",
    layout: "image-center",
    image: null,
    headline: (
      <>
        And that&apos;s just<br />the beginning.
      </>
    ),
    body: "The more you track, the more Zura understands. And the more Zura understands, the better it gets.",
  },
  {
    key: "coach",
    layout: "image-left",
    image: null,
    headline: (
      <>
        Meet Zura.<br />
        The coach who<br />
        knows your{" "}
        <span
          className="ds-pattern-text"
          style={{ backgroundImage: "var(--ds-pattern-sage)" }}
        >
          whole story.
        </span>
      </>
    ),
    body: "You\u2019ve been tracking everything. Now finally get something back. Zura tells you what\u2019s working, what isn\u2019t, and exactly what to do next.",
  },
];

// ---------------------------------------------------------------------------
// FeatureSection — full-screen, overlapping text + image
// ---------------------------------------------------------------------------

function FeatureSection({ section }: { section: SectionData }) {
  const isImageLeft = section.layout === "image-left";

  // ── Centered (More section) ──────────────────────────────────────────────
  if (section.layout === "image-center") {
    return (
      <section
        id={`${section.key}-section`}
        className="relative min-h-screen flex flex-col items-center justify-center overflow-hidden px-8 md:px-16 text-center"
      >
        <h2
          className="font-bold uppercase tracking-tighter leading-[0.85] text-[#161618]"
          style={{ fontSize: "clamp(3.5rem, 9vw, 11rem)" }}
        >
          {section.headline}
        </h2>
        <p className="mt-10 text-xl md:text-2xl text-[#6B6864] max-w-2xl">
          {section.body}
        </p>
      </section>
    );
  }

  // ── Split with overlap ───────────────────────────────────────────────────
  return (
    <section
      id={`${section.key}-section`}
      className="relative min-h-screen overflow-hidden flex items-center"
    >
      {/* Image — absolutely placed, behind text */}
      {section.image && (
        <div
          className={`absolute top-1/2 -translate-y-1/2 w-[62%] pointer-events-none select-none ${
            isImageLeft ? "left-[-4%]" : "right-[-4%]"
          }`}
          aria-hidden="true"
        >
          <Image
            src={section.image}
            alt=""
            width={1000}
            height={1000}
            className="w-full h-auto"
          />
        </div>
      )}

      {/* Placeholder when no image yet */}
      {!section.image && (
        <div
          className={`absolute top-1/2 -translate-y-1/2 w-[55%] aspect-square rounded-3xl bg-black/5 pointer-events-none ${
            isImageLeft ? "left-0" : "right-0"
          }`}
          aria-hidden="true"
        />
      )}

      {/* Text — z above image, anchored left or right */}
      <div
        className={`relative z-10 w-full flex ${
          isImageLeft ? "justify-end" : "justify-start"
        }`}
      >
        <div
          className={`w-full max-w-[70%] py-24 ${
            isImageLeft
              ? "pl-8 md:pl-16 pr-10 md:pr-16 lg:pr-24"
              : "pl-10 md:pl-16 lg:pl-24 pr-8 md:pr-16"
          }`}
        >
          <h2
            className="font-bold uppercase tracking-tighter leading-[0.85] text-[#161618]"
            style={{ fontSize: "clamp(3rem, 8.5vw, 10.5rem)" }}
          >
            {section.headline}
          </h2>
          <p className="mt-10 text-xl md:text-2xl leading-relaxed text-[#6B6864] max-w-xl">
            {section.body}
          </p>
        </div>
      </div>
    </section>
  );
}

// ---------------------------------------------------------------------------
// FeatureSections
// ---------------------------------------------------------------------------

export function FeatureSections() {
  return (
    <div id="feature-sections">
      <StickyBeatsSection id="connect-section" beats={CONNECT_BEATS} />
      {SECTIONS.map((section) => (
        <FeatureSection key={section.key} section={section} />
      ))}
    </div>
  );
}
