// website/src/components/sections/HeartSection.tsx
"use client";

import { useRef } from "react";
import { useGSAP } from "@gsap/react";
import gsap from "gsap";
import ScrollTrigger from "gsap/ScrollTrigger";
import { usePhoneContext } from "@/components/phone/PhoneContext";
import { PhoneMockup } from "@/components/phone";
import { HeartScreen } from "@/components/phone/screens/HeartScreen";

if (typeof window !== "undefined") {
  gsap.registerPlugin(ScrollTrigger);
}

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

export function HeartSection() {
  const sectionRef = useRef<HTMLDivElement>(null);
  const phoneCtx = usePhoneContext();

  useGSAP(
    () => {
      if (typeof window === "undefined" || window.innerWidth < 768) return;
      if (!phoneCtx) return;

      const {
        containerRef,
        phoneRef,
        sleepScreenRef,
        heartScreenRef,
      } = phoneCtx;
      const section = sectionRef.current;
      if (!section) return;

      let targetX = 0;

      const recalcPositions = () => {
        const sectionRect = section.getBoundingClientRect();
        const rightColCenter = sectionRect.left + sectionRect.width * 0.75;
        const viewportCenter = window.innerWidth / 2;
        targetX = Math.round(rightColCenter - viewportCenter);
      };

      recalcPositions();

      const prefersReduced = window.matchMedia(
        "(prefers-reduced-motion: reduce)"
      ).matches;

      const lines = gsap.utils.toArray<HTMLElement>(".heart-line", section);

      if (!prefersReduced) {
        gsap.set(lines, { y: 30, opacity: 0 });
      }

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
        onRefresh: recalcPositions,

        onEnter: () => {
          const container = containerRef.current;
          const phone = phoneRef.current;
          const sleep = sleepScreenRef.current;
          const heart = heartScreenRef.current;
          if (!container || !phone || !sleep || !heart) return;

          // Phone arrives from center (Sleep). Animate to right column.
          gsap.to(container, { opacity: 1, duration: 0.6, ease: "power2.out" });
          gsap.to(phone, { x: targetX, y: 0, duration: 1.0, ease: "power3.out" });
          blurOut(sleep);
          blurIn(heart);
          animateTextIn();
        },

        onLeave: () => {
          const container = containerRef.current;
          if (!container) return;
          gsap.to(container, { opacity: 0, duration: 0.4, ease: "power2.in" });
          resetText();
        },

        onEnterBack: () => {
          const container = containerRef.current;
          const phone = phoneRef.current;
          const sleep = sleepScreenRef.current;
          const heart = heartScreenRef.current;
          if (!container || !phone || !sleep || !heart) return;

          gsap.to(container, { opacity: 1, duration: 0.6, ease: "power2.out" });
          gsap.to(phone, { x: targetX, y: 0, duration: 0.8, ease: "power3.out" });
          blurOut(sleep, 0);
          blurIn(heart, 0.1);
          animateTextIn();
        },

        onLeaveBack: () => {
          const sleep = sleepScreenRef.current;
          const heart = heartScreenRef.current;
          if (!sleep || !heart) return;
          // Restore Sleep screen — Sleep's onEnterBack will move the phone.
          blurOut(heart, 0);
          blurIn(sleep, 0.1);
          resetText();
        },
      });
    },
    { scope: sectionRef, dependencies: [] }
  );

  return (
    <section
      ref={sectionRef}
      id="heart-section"
      className="relative min-h-screen flex items-center"
    >
      <div className="w-full max-w-7xl mx-auto px-6 md:px-12 lg:px-20">
        {/* Desktop: text left, phone-spacer right. Mobile: text then phone stacked. */}
        <div className="grid grid-cols-1 md:grid-cols-2 gap-12 items-center">
          {/* Left column — text */}
          <div className="max-w-lg">
            <h2 className="heart-line text-4xl md:text-5xl lg:text-6xl font-bold tracking-tight leading-[1.05] text-[var(--color-ds-text-on-warm-white)]">
              Know your heart.{" "}
              <span
                className="ds-pattern-text"
                style={{ backgroundImage: "var(--ds-pattern-sage)" }}
              >
                Know your health.
              </span>
            </h2>

            <p className="heart-line mt-6 text-base md:text-lg lg:text-xl leading-relaxed text-[var(--color-ds-text-secondary)]">
              Your heart responds to everything &mdash; your workouts, your meals,
              your sleep, your steps. Zura connects all of it so you stop seeing
              isolated numbers and start seeing the full picture.
            </p>
          </div>

          {/* Mobile: static inline phone (appears below text) */}
          <div className="flex md:hidden justify-center">
            <PhoneMockup frameWidth={260}>
              <HeartScreen />
            </PhoneMockup>
          </div>

          {/* Desktop spacer — phone (fixed overlay) lives in the right column */}
          <div className="hidden md:block" aria-hidden="true" />
        </div>
      </div>
    </section>
  );
}
