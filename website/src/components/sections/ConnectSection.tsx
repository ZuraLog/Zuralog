// website/src/components/sections/ConnectSection.tsx
"use client";

import { useRef } from "react";
import { useGSAP } from "@gsap/react";
import gsap from "gsap";
import ScrollTrigger from "gsap/ScrollTrigger";
import { usePhoneContext, computeFrameWidth, computeHeroY } from "@/components/phone/PhoneContext";
import { PhoneMockup } from "@/components/phone";
import { ConnectScreen } from "@/components/phone/screens/ConnectScreen";

if (typeof window !== "undefined") {
  gsap.registerPlugin(ScrollTrigger);
}

// Helper: blur-fade a screen out (opacity 0, blur 10px)
function blurOut(el: HTMLElement | null, delay = 0) {
  if (!el) return;
  gsap.to(el, {
    opacity: 0,
    filter: "blur(10px)",
    duration: 0.45,
    delay,
    ease: "power2.in",
    overwrite: "auto",
  });
}

// Helper: blur-fade a screen in (opacity 1, blur cleared)
function blurIn(el: HTMLElement | null, delay = 0.1) {
  if (!el) return;
  gsap.to(el, {
    opacity: 1,
    filter: "blur(0px)",
    duration: 0.5,
    delay,
    ease: "power2.out",
    overwrite: "auto",
  });
}

export function ConnectSection() {
  const sectionRef = useRef<HTMLDivElement>(null);
  const phoneCtx = usePhoneContext();

  useGSAP(
    () => {
      // Skip GSAP scroll animations on mobile -- the static inline phone
      // handles that layout. Also skip if phone context is not available
      // (SSR or outside provider).
      if (typeof window === "undefined" || window.innerWidth < 768) return;
      if (!phoneCtx) return;

      const {
        containerRef,
        phoneRef,
        placeholderScreenRef,
        connectScreenRef,
      } = phoneCtx;
      const section = sectionRef.current;
      if (!section) return;

      // Compute the horizontal offset needed to move the phone (currently centered
      // in the viewport) into the visual center of the right grid column.
      // This is recalculated on each ScrollTrigger refresh via invalidateOnRefresh.
      const sectionRect = section.getBoundingClientRect();
      const rightColCenter = sectionRect.left + sectionRect.width * 0.75;
      const viewportCenter = window.innerWidth / 2;
      const targetX = Math.round(rightColCenter - viewportCenter);
      const heroY = computeHeroY(computeFrameWidth());

      const prefersReduced = window.matchMedia(
        "(prefers-reduced-motion: reduce)"
      ).matches;

      // Text reveal elements
      const lines = gsap.utils.toArray<HTMLElement>(
        ".connect-line",
        section
      );

      // Set initial state for text lines (hidden, shifted down)
      if (!prefersReduced) {
        gsap.set(lines, { y: 30, opacity: 0 });
      }

      // Helper: animate text lines in
      const animateTextIn = () => {
        if (prefersReduced) return;
        gsap.to(lines, {
          y: 0,
          opacity: 1,
          duration: 0.8,
          stagger: 0.1,
          ease: "power3.out",
          overwrite: true,
        });
      };

      // Helper: reset text lines to hidden
      const resetText = () => {
        if (prefersReduced) return;
        gsap.to(lines, {
          y: 30,
          opacity: 0,
          duration: 0.4,
          ease: "power2.in",
          overwrite: true,
        });
      };

      ScrollTrigger.create({
        trigger: section,
        start: "top 60%",
        end: "bottom 40%",
        invalidateOnRefresh: true,

        onEnter: () => {
          const phone = phoneRef.current;
          const placeholder = placeholderScreenRef.current;
          const connect = connectScreenRef.current;
          if (!phone || !placeholder || !connect) return;

          // Phone arrives from hero position (y = heroY). Animate to right column.
          // Container stays at opacity 1 — phone was already visible in the hero.
          gsap.to(phone, {
            x: targetX,
            y: 0,
            duration: 1.0,
            ease: "power3.out",
          });

          blurOut(placeholder);
          blurIn(connect);
          animateTextIn();
        },

        onLeave: () => {
          const container = containerRef.current;
          if (!container) return;

          gsap.to(container, {
            opacity: 0,
            duration: 0.4,
            ease: "power2.in",
          });
          resetText();
        },

        onEnterBack: () => {
          const container = containerRef.current;
          const phone = phoneRef.current;
          const placeholder = placeholderScreenRef.current;
          const connect = connectScreenRef.current;
          if (!container || !phone || !placeholder || !connect) return;

          gsap.to(container, {
            opacity: 1,
            duration: 0.6,
            ease: "power2.out",
          });

          gsap.to(phone, {
            x: targetX,
            y: 0,
            duration: 0.8,
            ease: "power3.out",
          });

          blurOut(placeholder, 0);
          blurIn(connect, 0.1);
          animateTextIn();
        },

        onLeaveBack: () => {
          const phone = phoneRef.current;
          const placeholder = placeholderScreenRef.current;
          const connect = connectScreenRef.current;
          if (!phone || !placeholder || !connect) return;

          // Return phone to hero position. Container stays at opacity 1.
          gsap.to(phone, {
            x: 0,
            y: heroY,
            duration: 1.0,
            ease: "power3.out",
          });

          // Restore PlaceholderScreen for the hero
          blurOut(connect, 0);
          blurIn(placeholder, 0.1);
          resetText();
        },
      });
    },
    { scope: sectionRef, dependencies: [] }
  );

  return (
    <section
      ref={sectionRef}
      id="connect-section"
      className="relative min-h-screen flex items-center"
    >
      <div className="w-full max-w-7xl mx-auto px-6 md:px-12 lg:px-20">
        {/* Desktop: 50/50 grid -- text left, empty right (phone is the
            fixed overlay). Mobile: stacked -- text, then static phone. */}
        <div className="grid grid-cols-1 md:grid-cols-2 gap-12 items-center">
          {/* Left column -- text */}
          <div className="max-w-lg">
            <h2 className="connect-line text-4xl md:text-5xl lg:text-6xl font-bold tracking-tight leading-[1.05] text-[var(--color-ds-text-on-warm-white)]">
              Every app. Every device.{" "}
              <span
                className="ds-pattern-text"
                style={{ backgroundImage: "var(--ds-pattern-sage)" }}
              >
                One place.
              </span>
            </h2>

            <p className="connect-line mt-6 text-base md:text-lg lg:text-xl leading-relaxed text-[var(--color-ds-text-secondary)]">
              Most health apps make you start from scratch. ZuraLog connects
              directly to Apple Health, Google Health Connect, Strava, and
              more &mdash; so everything you&apos;ve already been tracking is ready
              from day one.
            </p>
          </div>

          {/* Right column -- empty on desktop (phone is the fixed overlay
              positioned here via GSAP x offset) */}
          {/* On mobile: static inline phone */}
          <div className="flex md:hidden justify-center">
            <div className="mx-auto">
              <PhoneMockup frameWidth={260}>
                <ConnectScreen />
              </PhoneMockup>
            </div>
          </div>

          {/* Desktop: invisible spacer so the grid keeps 50/50 proportions */}
          <div className="hidden md:block" aria-hidden="true" />
        </div>
      </div>
    </section>
  );
}
