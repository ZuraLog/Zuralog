// website/src/components/sections/hero/HeroText.tsx
"use client";

import { useRef, useCallback } from "react";
import { useGSAP } from "@gsap/react";
import gsap from "gsap";
import { DSButton } from "@/components/design-system";
import { useMagnetic } from "@/hooks/use-magnetic";

export function HeroText() {
  const containerRef = useRef<HTMLDivElement>(null);
  const magnetRef = useMagnetic<HTMLDivElement>({ strength: 0.3 });

  const handleWaitlistClick = useCallback(() => {
    const el = document.getElementById("waitlist");
    if (el) el.scrollIntoView({ behavior: "smooth" });
  }, []);

  useGSAP(
    () => {
      const prefersReduced = window.matchMedia(
        "(prefers-reduced-motion: reduce)"
      ).matches;
      const lines = gsap.utils.toArray<HTMLElement>(
        ".hero-line",
        containerRef.current
      );

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

        // Text mouse parallax — subtle background layer feel.
        // Phone parallax is handled globally in ScrollPhone.
        const parallax =
          containerRef.current?.querySelector<HTMLElement>(".hero-parallax");
        if (!parallax) return;

        const textXTo = gsap.quickTo(parallax, "x", {
          duration: 1.2,
          ease: "power2.out",
        });
        const textYTo = gsap.quickTo(parallax, "y", {
          duration: 1.2,
          ease: "power2.out",
        });

        const handleMouseMove = (e: MouseEvent) => {
          const dx = (e.clientX / window.innerWidth - 0.5) * 2;
          const dy = (e.clientY / window.innerHeight - 0.5) * 2;
          textXTo(dx * 12);
          textYTo(dy * 8);
        };

        window.addEventListener("mousemove", handleMouseMove);
        return () => window.removeEventListener("mousemove", handleMouseMove);
      } else {
        gsap.set(lines, { opacity: 1 });
      }
    },
    { scope: containerRef, dependencies: [] }
  );

  return (
    <div
      ref={containerRef}
      className="absolute inset-0 flex flex-col items-center z-50 pointer-events-none"
    >
      {/* Text group — vertically positioned in the upper viewport */}
      <div className="hero-parallax will-change-transform flex flex-col items-center text-center px-6 mt-[32vh] max-w-5xl mx-auto w-full">
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
          everything else your health needs &mdash; powered by an AI coach that makes
          sense of all of it.
        </p>

        {/* CTA */}
        <div
          ref={magnetRef}
          className="hero-line hero-cta mt-8 pointer-events-auto"
        >
          <DSButton
            intent="primary"
            size="lg"
            onClick={handleWaitlistClick}
            aria-label="Join the ZuraLog waitlist"
          >
            Waitlist Now
          </DSButton>
        </div>
      </div>
    </div>
  );
}
