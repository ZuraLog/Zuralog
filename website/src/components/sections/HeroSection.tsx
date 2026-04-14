// website/src/components/sections/HeroSection.tsx
"use client";

import { FloatingIcons } from "./hero/FloatingIcons";
import { HeroText } from "./hero/HeroText";

export function HeroSection() {
  return (
    <section
      id="hero-section"
      className="relative min-h-screen"
    >
      {/* Background decoration — floating fitness icons with mouse repellant physics */}
      <FloatingIcons />

      {/* Text content — z-50 so it sits above the ScrollPhone overlay (z-40) */}
      <HeroText />
    </section>
  );
}
