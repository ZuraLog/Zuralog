// website/src/components/sections/SleepSection.tsx
"use client";

import { useRef } from "react";
import { useGSAP } from "@gsap/react";
import gsap from "gsap";
import ScrollTrigger from "gsap/ScrollTrigger";
import { usePhoneContext } from "@/components/phone/PhoneContext";
import { PhoneMockup } from "@/components/phone";
import { SleepScreen } from "@/components/phone/screens/SleepScreen";

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

export function SleepSection() {
  const sectionRef = useRef<HTMLDivElement>(null);
  const phoneCtx = usePhoneContext();

  useGSAP(
    () => {
      if (typeof window === "undefined" || window.innerWidth < 768) return;
      if (!phoneCtx) return;

      const {
        containerRef,
        phoneRef,
        workoutScreenRef,
        sleepScreenRef,
      } = phoneCtx;
      const section = sectionRef.current;
      if (!section) return;

      const prefersReduced = window.matchMedia(
        "(prefers-reduced-motion: reduce)"
      ).matches;

      const lines = gsap.utils.toArray<HTMLElement>(".sleep-line", section);

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

        onEnter: () => {
          const container = containerRef.current;
          const phone = phoneRef.current;
          const workout = workoutScreenRef.current;
          const sleep = sleepScreenRef.current;
          if (!container || !phone || !workout || !sleep) return;

          // Phone arrives from left-column position (Workouts). Animate to center.
          gsap.to(container, { opacity: 1, duration: 0.6, ease: "power2.out" });
          gsap.to(phone, { x: 0, y: 0, duration: 1.0, ease: "power3.out" });
          blurOut(workout);
          blurIn(sleep);
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
          const workout = workoutScreenRef.current;
          const sleep = sleepScreenRef.current;
          if (!container || !phone || !workout || !sleep) return;

          gsap.to(container, { opacity: 1, duration: 0.6, ease: "power2.out" });
          gsap.to(phone, { x: 0, y: 0, duration: 0.8, ease: "power3.out" });
          blurOut(workout, 0);
          blurIn(sleep, 0.1);
          animateTextIn();
        },

        onLeaveBack: () => {
          const workout = workoutScreenRef.current;
          const sleep = sleepScreenRef.current;
          if (!workout || !sleep) return;
          // Restore Workout screen — Workouts' onEnterBack will move the phone.
          blurOut(sleep, 0);
          blurIn(workout, 0.1);
          resetText();
        },
      });
    },
    { scope: sectionRef, dependencies: [] }
  );

  return (
    <section
      ref={sectionRef}
      id="sleep-section"
      className="relative min-h-screen flex flex-col items-center justify-center"
    >
      <div className="w-full max-w-7xl mx-auto px-6 md:px-12 lg:px-20 text-center">
        <h2 className="sleep-line text-4xl md:text-5xl lg:text-6xl font-bold tracking-tight leading-[1.05] text-[var(--color-ds-text-on-warm-white)]">
          Sleep better. Know{" "}
          <span
            className="ds-pattern-text"
            style={{ backgroundImage: "var(--ds-pattern-sage)" }}
          >
            exactly why you&apos;re not.
          </span>
        </h2>

        <p className="sleep-line mt-6 text-base md:text-lg lg:text-xl leading-relaxed text-[var(--color-ds-text-secondary)] max-w-2xl mx-auto">
          Most apps show you a sleep chart and call it done. Zura goes
          further &mdash; connecting your sleep patterns to your workouts, stress,
          and daily habits to tell you what&apos;s actually working and what isn&apos;t.
        </p>

        {/* Mobile: static inline phone */}
        <div className="flex md:hidden justify-center mt-12">
          <PhoneMockup frameWidth={260}>
            <SleepScreen />
          </PhoneMockup>
        </div>

        {/* Desktop: spacer for the fixed phone overlay */}
        <div className="hidden md:block h-[420px]" aria-hidden="true" />
      </div>
    </section>
  );
}
