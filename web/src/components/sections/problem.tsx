/**
 * Problem Statement section — "Your apps don't talk to each other."
 * GSAP scroll-triggered reveal with staggered pain-point cards.
 */
"use client";

import { useRef } from "react";
import { useGSAP } from "@gsap/react";
import { gsap } from "gsap";
import { ScrollTrigger } from "gsap/ScrollTrigger";
import { Smartphone, Brain, BarChart3 } from "lucide-react";

gsap.registerPlugin(ScrollTrigger);

const PAIN_POINTS = [
  {
    icon: Smartphone,
    title: "App overload",
    body: "Strava for runs. Oura for sleep. MyFitnessPal for food. CalAI for macros. Each siloed, none talking.",
  },
  {
    icon: Brain,
    title: "No intelligence",
    body: "You have mountains of data but zero insight. Numbers without meaning. Metrics without action.",
  },
  {
    icon: BarChart3,
    title: "Exhausting to maintain",
    body: "Logging every meal, every workout, every night of sleep — manually — is a second job you didn’t sign up for.",
  },
];

/**
 * Renders the problem statement section with scroll-triggered animations.
 */
export function ProblemSection() {
  const sectionRef = useRef<HTMLElement>(null);
  const headingRef = useRef<HTMLHeadingElement>(null);
  const cardsRef = useRef<HTMLDivElement>(null);

  useGSAP(
    () => {
      if (!sectionRef.current) return;

      gsap.fromTo(
        headingRef.current,
        { opacity: 0, y: 60 },
        {
          opacity: 1,
          y: 0,
          duration: 0.9,
          ease: "power3.out",
          scrollTrigger: {
            trigger: headingRef.current,
            start: "top 80%",
          },
        },
      );

      gsap.fromTo(
        cardsRef.current?.querySelectorAll(".pain-card") ?? [],
        { opacity: 0, y: 60 },
        {
          opacity: 1,
          y: 0,
          duration: 0.8,
          ease: "power3.out",
          stagger: 0.15,
          scrollTrigger: {
            trigger: cardsRef.current,
            start: "top 75%",
          },
        },
      );
    },
    { scope: sectionRef },
  );

  return (
    <section ref={sectionRef} className="relative overflow-hidden py-28 md:py-40" id="problem">
      {/* Background accent */}
      <div className="pointer-events-none absolute inset-0">
        <div className="absolute left-1/2 top-1/2 h-[600px] w-[600px] -translate-x-1/2 -translate-y-1/2 rounded-full bg-sage/3 blur-[120px]" />
      </div>

      <div className="relative mx-auto max-w-6xl px-4">
        {/* Heading */}
        <div className="mb-20 text-center">
          <p className="mb-4 text-xs font-semibold tracking-[0.2em] text-sage uppercase">The Problem</p>
          <h2
            ref={headingRef}
            className="font-display text-4xl font-bold leading-tight tracking-tight md:text-6xl lg:text-7xl"
          >
            Your apps{" "}
            <span className="relative inline-block">
              <span className="relative z-10 text-foreground/40">don&apos;t</span>
            </span>{" "}
            talk
            <br className="hidden md:block" />
            to each other.
          </h2>
          <p className="mx-auto mt-6 max-w-xl text-lg text-muted-foreground">
            You&apos;re managing five fitness apps, drowning in data, and somehow knowing less about your health than ever.
          </p>
        </div>

        {/* Pain point cards */}
        <div ref={cardsRef} className="grid gap-6 md:grid-cols-3">
          {PAIN_POINTS.map((point) => {
            const Icon = point.icon;
            return (
              <div
                key={point.title}
                className="pain-card group relative overflow-hidden rounded-3xl border border-border/30 bg-surface p-8 transition-all duration-500 hover:border-sage/30 hover:shadow-[0_0_40px_rgba(207,225,185,0.06)]"
              >
                {/* Subtle corner glow */}
                <div className="pointer-events-none absolute -right-8 -top-8 h-32 w-32 rounded-full bg-sage/5 blur-2xl transition-all duration-500 group-hover:bg-sage/10" />
                
                <div className="relative">
                  <div className="mb-5 inline-flex h-12 w-12 items-center justify-center rounded-2xl border border-border/30 bg-background">
                    <Icon className="h-5 w-5 text-sage" />
                  </div>
                  <h3 className="mb-3 font-display text-xl font-semibold">{point.title}</h3>
                  <p className="leading-relaxed text-muted-foreground">{point.body}</p>
                </div>
              </div>
            );
          })}
        </div>
      </div>
    </section>
  );
}
