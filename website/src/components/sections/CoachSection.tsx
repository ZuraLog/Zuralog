// website/src/components/sections/CoachSection.tsx
"use client";

import { useRef } from "react";
import { useGSAP } from "@gsap/react";
import gsap from "gsap";
import ScrollTrigger from "gsap/ScrollTrigger";
import { usePhoneContext } from "@/components/phone/PhoneContext";
import { PhoneMockup } from "@/components/phone";
import { CoachScreen } from "@/components/phone/screens/CoachScreen";

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

export function CoachSection() {
  const sectionRef = useRef<HTMLDivElement>(null);
  const phoneCtx = usePhoneContext();

  useGSAP(
    () => {
      if (typeof window === "undefined" || window.innerWidth < 768) return;
      if (!phoneCtx) return;

      const {
        containerRef,
        phoneRef,
        moreScreenRef,
        coachScreenRef,
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

      const lines = gsap.utils.toArray<HTMLElement>(".coach-line", section);

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
          const more = moreScreenRef.current;
          const coach = coachScreenRef.current;
          if (!container || !phone || !more || !coach) return;

          // Phone arrives from center (More). Animate to left column.
          gsap.to(container, { opacity: 1, duration: 0.6, ease: "power2.out" });
          gsap.to(phone, { x: targetX, y: 0, duration: 1.0, ease: "power3.out" });
          blurOut(more);
          blurIn(coach);
          animateTextIn();
        },

        onLeave: () => {
          const container = containerRef.current;
          if (!container) return;
          // Phone exits before the Waitlist section.
          gsap.to(container, { opacity: 0, duration: 0.5, ease: "power2.in" });
          resetText();
        },

        onEnterBack: () => {
          const container = containerRef.current;
          const phone = phoneRef.current;
          const more = moreScreenRef.current;
          const coach = coachScreenRef.current;
          if (!container || !phone || !more || !coach) return;

          gsap.to(container, { opacity: 1, duration: 0.6, ease: "power2.out" });
          gsap.to(phone, { x: targetX, y: 0, duration: 0.8, ease: "power3.out" });
          blurOut(more, 0);
          blurIn(coach, 0.1);
          animateTextIn();
        },

        onLeaveBack: () => {
          const more = moreScreenRef.current;
          const coach = coachScreenRef.current;
          if (!more || !coach) return;
          // Restore More screen — More's onEnterBack will move the phone.
          blurOut(coach, 0);
          blurIn(more, 0.1);
          resetText();
        },
      });
    },
    { scope: sectionRef, dependencies: [] }
  );

  return (
    <section
      ref={sectionRef}
      id="coach-section"
      className="relative min-h-screen flex items-center"
    >
      <div className="w-full max-w-7xl mx-auto px-6 md:px-12 lg:px-20">
        {/* Desktop: phone-spacer left, text right. Mobile: text then phone stacked. */}
        <div className="grid grid-cols-1 md:grid-cols-2 gap-12 items-center">
          {/* Desktop spacer — phone (fixed overlay) lives in the left column */}
          <div className="hidden md:block" aria-hidden="true" />

          {/* Right column — text */}
          <div className="max-w-lg">
            <h2 className="coach-line text-4xl md:text-5xl lg:text-6xl font-bold tracking-tight leading-[1.05] text-[var(--color-ds-text-on-warm-white)]">
              Meet Zura. The coach who knows your{" "}
              <span
                className="ds-pattern-text"
                style={{ backgroundImage: "var(--ds-pattern-sage)" }}
              >
                whole story.
              </span>
            </h2>

            <p className="coach-line mt-6 text-base md:text-lg lg:text-xl leading-relaxed text-[var(--color-ds-text-secondary)]">
              You&apos;ve been tracking everything. Now finally get something back.
              Zura reads across your workouts, meals, sleep, and heart rate to
              tell you what&apos;s working, what isn&apos;t, and exactly what to do next.
            </p>
          </div>

          {/* Mobile: static inline phone (appears below text) */}
          <div className="flex md:hidden justify-center">
            <PhoneMockup frameWidth={260}>
              <CoachScreen />
            </PhoneMockup>
          </div>
        </div>
      </div>
    </section>
  );
}
