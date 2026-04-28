"use client";

import { useRef, useState, useEffect, useCallback } from "react";
import gsap from "gsap";
import { ScrollTrigger } from "gsap/ScrollTrigger";
import { AnimatePresence, motion } from "framer-motion";
import { PhoneFrame } from "./PhoneFrame";
import { PHONE_SCREENS } from "./PhoneScreens";
import { GlassCard } from "./GlassCard";
import { STEPS } from "./constants";

const STEP_COUNT = STEPS.length;
const EXPO_OUT: [number, number, number, number] = [0.16, 1, 0.3, 1];

export function HowItWorksSection() {
  const sectionRef = useRef<HTMLDivElement>(null);
  const pinRef = useRef<HTMLDivElement>(null);
  const [activeStep, setActiveStep] = useState(0);

  useEffect(() => {
    const section = sectionRef.current;
    const pin = pinRef.current;
    if (!section || !pin) return;

    const prefersReducedMotion = window.matchMedia(
      "(prefers-reduced-motion: reduce)",
    ).matches;

    if (prefersReducedMotion) return;

    const trigger = ScrollTrigger.create({
      trigger: section,
      start: "top top",
      end: "bottom bottom",
      pin: pin,
      pinSpacing: false,
      onUpdate: (self) => {
        const progress = self.progress;
        const step = Math.min(
          STEP_COUNT - 1,
          Math.floor(progress * STEP_COUNT),
        );
        setActiveStep(step);
      },
    });

    return () => {
      trigger.kill();
    };
  }, []);

  const getScreenId = useCallback(
    (offset: number) => {
      const idx = activeStep + offset;
      if (idx < 0 || idx >= STEP_COUNT) return null;
      return STEPS[idx].id;
    },
    [activeStep],
  );

  const renderScreen = (stepId: string | null) => {
    if (!stepId) return null;
    const Screen = PHONE_SCREENS[stepId];
    return Screen ? <Screen /> : null;
  };

  const leftId = getScreenId(-1);
  const centerId = getScreenId(0);
  const rightId = getScreenId(1);

  return (
    <section
      ref={sectionRef}
      id="how-it-works-section"
      className="relative w-full"
      style={{ height: `${STEP_COUNT * 100}vh` }}
    >
      {/* Background gradient: light sage → deep forest → dark canvas */}
      <div
        className="pointer-events-none absolute inset-0"
        style={{
          background:
            "linear-gradient(to bottom, transparent 0%, rgba(52,78,65,0.4) 8%, rgba(26,46,34,0.7) 15%, #161618 25%, #161618 75%, rgba(26,46,34,0.7) 85%, rgba(52,78,65,0.4) 92%, transparent 100%)",
        }}
      />

      {/* Animated topographic pattern overlay — matches page background */}
      <div
        className="pointer-events-none absolute inset-0 overflow-hidden"
        style={{
          opacity: 0.06,
          mixBlendMode: "screen",
          maskImage: "linear-gradient(to bottom, transparent 0%, black 20%, black 80%, transparent 100%)",
          WebkitMaskImage: "linear-gradient(to bottom, transparent 0%, black 20%, black 80%, transparent 100%)",
        }}
      >
        <video
          src="/patterns/Sage.mp4"
          autoPlay
          muted
          loop
          playsInline
          aria-hidden="true"
          className="absolute inset-0 h-full w-full object-cover"
        />
      </div>

      {/* Pinned viewport container */}
      <div ref={pinRef} className="relative flex h-screen w-full flex-col items-center justify-center overflow-hidden">
        {/* Section heading */}
        <div className="absolute top-8 left-0 right-0 text-center sm:top-12">
          <p
            className="text-xs font-semibold tracking-[0.25em] uppercase mb-2"
            style={{ color: "rgba(207,225,185,0.5)" }}
          >
            How It Works
          </p>
          <h2
            className="text-3xl font-bold tracking-tight sm:text-4xl lg:text-5xl"
            style={{ color: "#F0EEE9" }}
          >
            How ZuraLog Works
          </h2>

          {/* Progress dots */}
          <div className="mt-4 flex items-center justify-center gap-2">
            {STEPS.map((step, i) => (
              <div
                key={step.id}
                className="rounded-full transition-all duration-300"
                style={{
                  width: i === activeStep ? 24 : 6,
                  height: 6,
                  backgroundColor:
                    i === activeStep ? "#CFE1B9" : "rgba(207,225,185,0.2)",
                }}
              />
            ))}
          </div>
        </div>

        {/* Phone group */}
        <div className="relative flex items-end justify-center gap-4 sm:gap-6 lg:gap-8">
          {/* Ambient glow behind center phone */}
          <div
            className="pointer-events-none absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2"
            style={{
              width: 400,
              height: 400,
              borderRadius: "50%",
              background: `radial-gradient(circle, ${STEPS[activeStep].accent}18 0%, transparent 70%)`,
              transition: "background 0.5s ease",
            }}
          />

          {/* Left phone (previous step) */}
          <div className="hidden sm:block">
            <PhoneFrame
              className="w-[180px] md:w-[200px] lg:w-[220px]"
              style={{
                transform: "rotate(-6deg) translateY(-12px)",
                opacity: leftId ? 0.4 : 0,
                transition: "opacity 0.6s ease",
              }}
            >
              <AnimatePresence mode="wait">
                {leftId && (
                  <motion.div
                    key={leftId}
                    initial={{ opacity: 0 }}
                    animate={{ opacity: 1 }}
                    exit={{ opacity: 0 }}
                    transition={{ duration: 0.5, ease: EXPO_OUT }}
                  >
                    {renderScreen(leftId)}
                  </motion.div>
                )}
              </AnimatePresence>
            </PhoneFrame>
          </div>

          {/* Center phone (active step) */}
          <PhoneFrame className="w-[220px] sm:w-[240px] md:w-[260px] lg:w-[280px] z-10">
            <AnimatePresence mode="wait">
              {centerId && (
                <motion.div
                  key={centerId}
                  initial={{ opacity: 0, y: 16 }}
                  animate={{ opacity: 1, y: 0 }}
                  exit={{ opacity: 0, y: -16 }}
                  transition={{ duration: 0.5, ease: EXPO_OUT }}
                >
                  {renderScreen(centerId)}
                </motion.div>
              )}
            </AnimatePresence>
          </PhoneFrame>

          {/* Right phone (next step) */}
          <div className="hidden sm:block">
            <PhoneFrame
              className="w-[180px] md:w-[200px] lg:w-[220px]"
              style={{
                transform: "rotate(6deg) translateY(-12px)",
                opacity: rightId ? 0.4 : 0,
                transition: "opacity 0.6s ease",
              }}
            >
              <AnimatePresence mode="wait">
                {rightId && (
                  <motion.div
                    key={rightId}
                    initial={{ opacity: 0 }}
                    animate={{ opacity: 1 }}
                    exit={{ opacity: 0 }}
                    transition={{ duration: 0.5, ease: EXPO_OUT }}
                  >
                    {renderScreen(rightId)}
                  </motion.div>
                )}
              </AnimatePresence>
            </PhoneFrame>
          </div>
        </div>

        {/* Floating glass card */}
        <GlassCard
          step={STEPS[activeStep]}
          stepIndex={activeStep}
          isVisible={true}
        />
      </div>
    </section>
  );
}
