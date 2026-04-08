// website/src/components/sections/hero/HeroText.tsx
"use client";

import { useRef, useCallback } from "react";
import { useGSAP } from "@gsap/react";
import gsap from "gsap";
import { DSButton } from "@/components/design-system";
import { useMagnetic } from "@/hooks/use-magnetic";
import { PhoneMockup } from "@/components/phone";
import { PlaceholderScreen } from "@/components/phone/screens/PlaceholderScreen";

export function HeroText() {
  const containerRef = useRef<HTMLDivElement>(null);
  const magnetRef = useMagnetic<HTMLDivElement>({ strength: 0.3 });

  // Scroll to waitlist section on CTA click
  const handleWaitlistClick = useCallback(() => {
    const el = document.getElementById("waitlist");
    if (el) el.scrollIntoView({ behavior: "smooth" });
  }, []);

  useGSAP(
    () => {
      const prefersReduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
      const lines = gsap.utils.toArray<HTMLElement>(".hero-line", containerRef.current);

      if (!prefersReduced) {
        gsap.fromTo(
          lines,
          { y: 40, opacity: 0 },
          {
            y: 0,
            opacity: 1,
            duration: 0.9,
            ease: "power3.out",
            stagger: 0.12,
            delay: 0.2,
          }
        );
      } else {
        gsap.set(lines, { opacity: 1 });
      }

      if (!prefersReduced) {
        // Subtle mouse parallax on the inner content
        const parallax = containerRef.current?.querySelector<HTMLElement>(".hero-parallax");
        if (!parallax) return;

        const xTo = gsap.quickTo(parallax, "x", { duration: 1.2, ease: "power2.out" });
        const yTo = gsap.quickTo(parallax, "y", { duration: 1.2, ease: "power2.out" });

        const handleMouseMove = (e: MouseEvent) => {
          const dx = (e.clientX / window.innerWidth - 0.5) * 2;
          const dy = (e.clientY / window.innerHeight - 0.5) * 2;
          xTo(dx * 12);
          yTo(dy * 8);
        };

        window.addEventListener("mousemove", handleMouseMove);
        return () => window.removeEventListener("mousemove", handleMouseMove);
      }
    },
    { scope: containerRef, dependencies: [] }
  );

  return (
    <div
      ref={containerRef}
      className="relative min-h-screen md:absolute md:inset-0 md:min-h-0 flex flex-col items-center justify-center z-50 pointer-events-none"
    >
      <div className="hero-parallax will-change-transform flex flex-col items-center text-center px-6 py-16 md:py-0 md:mt-20 max-w-5xl mx-auto">
        {/* Headline */}
        <h1 className="hero-line font-jakarta text-5xl sm:text-6xl md:text-7xl lg:text-8xl font-bold tracking-tight text-[var(--color-ds-text-on-warm-white)] leading-[1.05]">
          The last health app{" "}
          <span
            className="ds-pattern-text"
            style={{ backgroundImage: "var(--ds-pattern-sage)" }}
          >
            you&apos;ll ever need.
          </span>
        </h1>

        {/* Subheadline */}
        <p className="hero-line font-jakarta mt-6 text-base sm:text-lg md:text-xl text-[var(--color-ds-text-secondary)] max-w-2xl leading-relaxed">
          One place for every workout, every meal, every night&apos;s sleep, and
          everything else your health needs — powered by an AI coach that makes
          sense of all of it.
        </p>

        {/* Mobile-only inline phone — shown when the fixed ScrollPhone is hidden */}
        <div className="hero-line block md:hidden mt-10 pointer-events-auto">
          <PhoneMockup screenWidth={200}>
            <PlaceholderScreen label="ZuraLog" />
          </PhoneMockup>
        </div>

        {/* CTA */}
        <div ref={magnetRef} className="hero-line hero-cta mt-8 pointer-events-auto">
          <DSButton intent="primary" size="lg" onClick={handleWaitlistClick} aria-label="Join the ZuraLog waitlist">
            Waitlist Now
          </DSButton>
        </div>
      </div>
    </div>
  );
}
