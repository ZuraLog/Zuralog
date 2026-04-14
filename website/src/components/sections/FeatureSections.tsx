"use client";

import { StickyBeatsSection, type Beat } from "./StickyBeatsSection";

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

export function FeatureSections() {
  return (
    <div id="feature-sections">
      <StickyBeatsSection id="connect-section" beats={CONNECT_BEATS} layout="image-right" />
    </div>
  );
}
