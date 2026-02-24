/**
 * How It Works section — 3-step sequential reveal.
 * "Connect → Learn → Act" with animated connecting lines.
 */
"use client";

import { useRef } from "react";
import { useGSAP } from "@gsap/react";
import { gsap } from "gsap";
import { ScrollTrigger } from "gsap/ScrollTrigger";
import { Link2, Sparkles, Zap } from "lucide-react";

gsap.registerPlugin(ScrollTrigger);

const STEPS = [
  {
    number: "01",
    icon: Link2,
    title: "Connect",
    body: "Link your fitness apps in seconds. Strava, Oura, CalAI, Apple Health, Fitbit — one tap per app.",
  },
  {
    number: "02",
    icon: Sparkles,
    title: "Learn",
    body: "Zuralog’s AI studies your patterns across all connected data. It learns what works for YOUR body.",
  },
  {
    number: "03",
    icon: Zap,
    title: "Act",
    body: "Get personalized insights, automated adjustments, and AI-powered coaching — all in one place.",
  },
];

/**
 * Renders the 3-step How It Works section.
 */
export function HowItWorksSection() {
  const sectionRef = useRef<HTMLElement>(null);
  const stepsRef = useRef<HTMLDivElement>(null);

  useGSAP(
    () => {
      if (!stepsRef.current) return;

      gsap.fromTo(
        stepsRef.current.querySelectorAll(".step-item"),
        { opacity: 0, y: 50 },
        {
          opacity: 1,
          y: 0,
          duration: 0.8,
          ease: "power3.out",
          stagger: 0.2,
          scrollTrigger: {
            trigger: stepsRef.current,
            start: "top 75%",
          },
        },
      );

      gsap.fromTo(
        ".connector-line",
        { scaleX: 0, transformOrigin: "left center" },
        {
          scaleX: 1,
          duration: 0.6,
          ease: "power2.out",
          stagger: 0.2,
          scrollTrigger: {
            trigger: stepsRef.current,
            start: "top 75%",
          },
        },
      );
    },
    { scope: sectionRef },
  );

  return (
    <section ref={sectionRef} className="relative overflow-hidden py-28 md:py-40" id="how-it-works">
      <div className="pointer-events-none absolute inset-0">
        <div className="absolute right-0 top-1/2 h-[500px] w-[500px] -translate-y-1/2 rounded-full bg-sage/3 blur-[100px]" />
      </div>

      <div className="relative mx-auto max-w-6xl px-4">
        <div className="mb-20 text-center">
          <p className="mb-4 text-xs font-semibold tracking-[0.2em] text-sage uppercase">How It Works</p>
          <h2 className="font-display text-4xl font-bold tracking-tight md:text-5xl">
            Three steps to your AI health hub
          </h2>
          <p className="mx-auto mt-4 max-w-lg text-lg text-muted-foreground">
            From scattered apps to unified intelligence in minutes.
          </p>
        </div>

        <div ref={stepsRef} className="relative">
          {/* Desktop: horizontal layout with connecting lines */}
          <div className="hidden md:grid md:grid-cols-3 md:gap-8">
            {STEPS.map((step, i) => {
              const Icon = step.icon;
              return (
                <div key={step.number} className="step-item relative flex flex-col items-center text-center">
                  {/* Connecting line (not after last) */}
                  {i < STEPS.length - 1 && (
                    <div className="connector-line absolute left-[calc(50%+2.5rem)] right-[-50%] top-7 h-px bg-gradient-to-r from-sage/40 to-sage/10" />
                  )}

                  <div className="relative mb-6 flex h-14 w-14 items-center justify-center rounded-2xl border border-sage/30 bg-surface">
                    <Icon className="h-6 w-6 text-sage" />
                    <span className="absolute -right-2 -top-2 flex h-5 w-5 items-center justify-center rounded-full bg-sage text-[10px] font-bold text-background">
                      {i + 1}
                    </span>
                  </div>
                  <h3 className="mb-3 font-display text-2xl font-bold">{step.title}</h3>
                  <p className="text-muted-foreground">{step.body}</p>
                </div>
              );
            })}
          </div>

          {/* Mobile: vertical layout */}
          <div className="flex flex-col gap-0 md:hidden">
            {STEPS.map((step, i) => {
              const Icon = step.icon;
              return (
                <div key={step.number} className="step-item flex gap-6">
                  <div className="flex flex-col items-center">
                    <div className="flex h-12 w-12 flex-shrink-0 items-center justify-center rounded-2xl border border-sage/30 bg-surface">
                      <Icon className="h-5 w-5 text-sage" />
                    </div>
                    {i < STEPS.length - 1 && (
                      <div className="connector-line mt-2 h-16 w-px bg-gradient-to-b from-sage/40 to-sage/10" style={{ transform: "scaleX(1) scaleY(1)", transformOrigin: "top center" }} />
                    )}
                  </div>
                  <div className="pb-8 pt-2">
                    <p className="mb-1 text-xs font-bold tracking-[0.1em] text-sage">{step.number}</p>
                    <h3 className="mb-2 font-display text-xl font-bold">{step.title}</h3>
                    <p className="text-muted-foreground">{step.body}</p>
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      </div>
    </section>
  );
}
