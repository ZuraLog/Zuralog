// website/src/components/sections/WorkoutsSection.tsx
"use client";

import { useRef } from "react";
import { useGSAP } from "@gsap/react";
import gsap from "gsap";
import ScrollTrigger from "gsap/ScrollTrigger";
import { usePhoneContext } from "@/components/phone/PhoneContext";
import { PhoneMockup } from "@/components/phone";
import { WorkoutScreen } from "@/components/phone/screens/WorkoutScreen";

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

export function WorkoutsSection() {
  const sectionRef = useRef<HTMLDivElement>(null);
  const phoneCtx = usePhoneContext();

  useGSAP(
    () => {
      if (typeof window === "undefined" || window.innerWidth < 768) return;
      if (!phoneCtx) return;

      const {
        containerRef,
        phoneRef,
        nutritionScreenRef,
        workoutScreenRef,
      } = phoneCtx;
      const section = sectionRef.current;
      if (!section) return;

      let targetX = 0;

      const recalcPositions = () => {
        const sectionRect = section.getBoundingClientRect();
        const leftColCenter = sectionRect.left + sectionRect.width * 0.25;
        const viewportCenter = window.innerWidth / 2;
        targetX = Math.round(leftColCenter - viewportCenter);
      };

      recalcPositions();

      const prefersReduced = window.matchMedia(
        "(prefers-reduced-motion: reduce)"
      ).matches;

      const lines = gsap.utils.toArray<HTMLElement>(".workouts-line", section);

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
          const nutrition = nutritionScreenRef.current;
          const workout = workoutScreenRef.current;
          if (!container || !phone || !nutrition || !workout) return;

          // Phone arrives from center (Nutrition). Animate to left column.
          gsap.to(container, { opacity: 1, duration: 0.6, ease: "power2.out" });
          gsap.to(phone, { x: targetX, y: 0, duration: 1.0, ease: "power3.out" });
          blurOut(nutrition);
          blurIn(workout);
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
          const nutrition = nutritionScreenRef.current;
          const workout = workoutScreenRef.current;
          if (!container || !phone || !nutrition || !workout) return;

          gsap.to(container, { opacity: 1, duration: 0.6, ease: "power2.out" });
          gsap.to(phone, { x: targetX, y: 0, duration: 0.8, ease: "power3.out" });
          blurOut(nutrition, 0);
          blurIn(workout, 0.1);
          animateTextIn();
        },

        onLeaveBack: () => {
          const nutrition = nutritionScreenRef.current;
          const workout = workoutScreenRef.current;
          if (!nutrition || !workout) return;
          // Restore Nutrition screen — Nutrition's onEnterBack will move the phone.
          blurOut(workout, 0);
          blurIn(nutrition, 0.1);
          resetText();
        },
      });
    },
    { scope: sectionRef, dependencies: [] }
  );

  return (
    <section
      ref={sectionRef}
      id="workouts-section"
      className="relative min-h-screen flex items-center"
    >
      <div className="w-full max-w-7xl mx-auto px-6 md:px-12 lg:px-20">
        {/* Desktop: phone-spacer left, text right. Mobile: text then phone stacked. */}
        <div className="grid grid-cols-1 md:grid-cols-2 gap-12 items-center">
          {/* Desktop spacer — phone (fixed overlay) lives in the left column */}
          <div className="hidden md:block" aria-hidden="true" />

          {/* Right column — text */}
          <div className="max-w-lg">
            <h2 className="workouts-line text-4xl md:text-5xl lg:text-6xl font-bold tracking-tight leading-[1.05] text-[var(--color-ds-text-on-warm-white)]">
              Log it live, log it later, or{" "}
              <span
                className="ds-pattern-text"
                style={{ backgroundImage: "var(--ds-pattern-sage)" }}
              >
                let it log itself.
              </span>
            </h2>

            <p className="workouts-line mt-6 text-base md:text-lg lg:text-xl leading-relaxed text-[var(--color-ds-text-secondary)]">
              Track your sets and reps live, log a workout you already finished,
              or let Zura pull it in automatically from Apple Health or Google
              Health Connect. Every session counts, no matter how you log it.
            </p>
          </div>

          {/* Mobile: static inline phone (appears below text) */}
          <div className="flex md:hidden justify-center">
            <PhoneMockup frameWidth={260}>
              <WorkoutScreen />
            </PhoneMockup>
          </div>
        </div>
      </div>
    </section>
  );
}
