"use client";

import { useScrollReveal } from "@/hooks/use-scroll-reveal";

const STATS = [
  {
    number: "50+",
    label: "App Integrations",
    description: "Strava, Apple Health, Fitbit, Oura, and more — all flowing into one place.",
  },
  {
    number: "24/7",
    label: "AI Health Coach",
    description: "Ask anything about your health data, anytime. Your AI coach has full context.",
  },
  {
    number: "100%",
    label: "Personalized",
    description: "Every insight, recommendation, and alert is tailored to YOUR unique data.",
  },
] as const;

export function StatCards() {
  const containerRef = useScrollReveal<HTMLDivElement>({ stagger: 0.08, y: 24 });

  return (
    <div
      ref={containerRef}
      className="grid grid-cols-1 sm:grid-cols-3 gap-4 mt-10 md:mt-14"
    >
      {STATS.map((stat) => (
        <div
          key={stat.label}
          className="rounded-2xl p-6"
          style={{
            backgroundColor: "rgba(255, 255, 255, 0.5)",
            border: "1px solid rgba(207, 225, 185, 0.2)",
            backdropFilter: "blur(8px)",
            WebkitBackdropFilter: "blur(8px)",
          }}
        >
          <p className="text-3xl font-extrabold tracking-tight" style={{ color: "#344E41" }}>
            {stat.number}
          </p>
          <p className="text-sm font-semibold mt-1" style={{ color: "#1A2E22" }}>
            {stat.label}
          </p>
          <p className="text-xs leading-relaxed mt-2" style={{ color: "#6B7B6E" }}>
            {stat.description}
          </p>
        </div>
      ))}
    </div>
  );
}
