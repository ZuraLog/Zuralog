"use client";

import { useScrollReveal } from "@/hooks/use-scroll-reveal";
import { DashboardMockup } from "./DashboardMockup";
import { StatCards } from "./StatCards";

const INTEGRATIONS = ["Strava", "Apple Health", "Fitbit", "Oura"];

export function MetricsSection() {
  const headingRef = useScrollReveal<HTMLDivElement>({ y: 20, duration: 0.5 });
  const dashboardRef = useScrollReveal<HTMLDivElement>({ y: 30, duration: 0.7, delay: 0.1 });
  const stripRef = useScrollReveal<HTMLDivElement>({ y: 16, duration: 0.5, delay: 0.2 });

  return (
    <section
      id="bento-section"
      className="relative w-full py-20 md:py-32 lg:py-40 overflow-hidden"
      style={{ backgroundColor: "transparent" }}
    >
      <div className="relative z-10 max-w-5xl mx-auto px-6 lg:px-12">
        {/* Section heading */}
        <div ref={headingRef} className="text-center mb-12 md:mb-16">
          <div
            className="mx-auto mb-6 h-px w-16"
            style={{ background: "linear-gradient(to right, transparent, #344E41, transparent)" }}
          />
          <p
            className="text-sm font-semibold tracking-[0.25em] uppercase mb-4"
            style={{ color: "#344E41" }}
          >
            Your Dashboard
          </p>
          <h2
            className="text-4xl sm:text-5xl lg:text-[56px] font-bold tracking-tight leading-[1.1]"
            style={{ color: "#1A2E22" }}
          >
            Master Your Metrics
          </h2>
          <p
            className="text-base md:text-lg mt-4 max-w-lg mx-auto"
            style={{ color: "rgba(52, 78, 65, 0.55)" }}
          >
            Every data point from every app — unified, analyzed, and presented beautifully.
          </p>
        </div>

        {/* Dashboard mockup */}
        <div ref={dashboardRef}>
          <DashboardMockup />
        </div>

        {/* Stat cards */}
        <StatCards />

        {/* Integration strip */}
        <div ref={stripRef} className="flex justify-center items-center gap-6 mt-10 md:mt-14 flex-wrap">
          <span
            className="text-[10px] font-semibold uppercase tracking-widest"
            style={{ color: "#9B9894" }}
          >
            Powered by
          </span>
          {INTEGRATIONS.map((name) => (
            <span
              key={name}
              className="text-sm font-medium"
              style={{ color: "#6B7B6E" }}
            >
              {name}
            </span>
          ))}
          <span className="text-sm font-semibold" style={{ color: "#CFE1B9" }}>
            +50 more
          </span>
        </div>
      </div>
    </section>
  );
}
