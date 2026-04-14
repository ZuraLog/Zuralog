"use client";

import { useState, useEffect, useCallback, useRef } from "react";
import { useSoundContext } from "@/components/design-system/interactions/sound-provider";
import { useCursorParallax } from "@/hooks/use-cursor-parallax";
import { motion } from "framer-motion";
import { useGSAP } from "@gsap/react";
import gsap from "gsap";
import { ScrollTrigger } from "gsap/ScrollTrigger";
import {
  Camera, ScanBarcode, Mic, PenLine,
  Dumbbell, History, Zap,
  Moon, BarChart2, BrainCircuit,
  Heart, Activity, TrendingDown,
  LucideIcon,
} from "lucide-react";
import { PhoneMockup } from "@/components/phone/PhoneMockup";

if (typeof window !== "undefined") {
  gsap.registerPlugin(ScrollTrigger);
}

// ---------------------------------------------------------------------------
// Shared pattern style for block elements (icon box, progress bar, pill)
// ---------------------------------------------------------------------------
const PATTERN_BG: React.CSSProperties = {
  backgroundImage: "var(--ds-pattern-sage)",
  backgroundSize: "200px auto",
  backgroundRepeat: "repeat",
};

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface ShowcaseFeature {
  icon: LucideIcon;
  title: string;
  subtitle: string;
  description: string;
}

interface ShowcaseCategory {
  id: string;
  label: string;
  headline: string;
  subheadline: string;
  features: ShowcaseFeature[];
}

const DURATION = 5000;

// ---------------------------------------------------------------------------
// All categories data
// ---------------------------------------------------------------------------

const CATEGORIES: ShowcaseCategory[] = [
  {
    id: "nutrition",
    label: "Nutrition",
    headline: "Log food\nthe way you want.",
    subheadline: "Four ways to track what you eat — pick the one that fits the moment.",
    features: [
      {
        icon: Camera,
        title: "Photo",
        subtitle: "Snap any meal instantly",
        description:
          "Point your camera at any meal and Zura reads it. Calories, macros, and portion size — all filled in automatically. No typing.",
      },
      {
        icon: ScanBarcode,
        title: "Scan",
        subtitle: "Point at any barcode",
        description:
          "Got a label? Scan it. ZuraLog reads any barcode and fills in the nutrition facts automatically. Works on every packaged food.",
      },
      {
        icon: Mic,
        title: "Talk to Zura",
        subtitle: "Just say what you ate",
        description:
          "Tell Zura what you had — \"a bowl of oatmeal with berries\" — and it logs it. No searching, no scrolling. Just talk.",
      },
      {
        icon: PenLine,
        title: "Manual",
        subtitle: "Search and log anything",
        description:
          "Prefer to look it up yourself? Search our database of millions of foods and log exactly what you want.",
      },
    ],
  },
  {
    id: "workouts",
    label: "Workouts",
    headline: "Track your\ntraining, your way.",
    subheadline: "Log in the moment, after the fact, or let your apps do it automatically.",
    features: [
      {
        icon: Dumbbell,
        title: "Log it live",
        subtitle: "Track as you train",
        description:
          "Log your sets, reps, and weight in real time as you go. No fumbling with paper, no trying to remember after.",
      },
      {
        icon: History,
        title: "Log it later",
        subtitle: "Add any session after the fact",
        description:
          "Finished a workout you didn't log? Just tell Zura. Add any session after the fact and it slots right into your history.",
      },
      {
        icon: Zap,
        title: "Let it log itself",
        subtitle: "Auto-sync from your apps",
        description:
          "Connect Apple Health, Google Health Connect, or Strava and your workouts appear automatically — no extra steps, ever.",
      },
    ],
  },
  {
    id: "sleep",
    label: "Sleep",
    headline: "See how well\nyou really slept.",
    subheadline: "Duration, quality, stages — and what they actually mean for your day.",
    features: [
      {
        icon: Moon,
        title: "Duration & quality",
        subtitle: "Every morning, automatically",
        description:
          "See exactly how long you slept and how good it was — synced automatically from your phone, watch, or ring every morning.",
      },
      {
        icon: BarChart2,
        title: "Sleep stages",
        subtitle: "Light, deep, and REM breakdown",
        description:
          "See how much time you spent in light sleep, deep sleep, and REM. Know which stages you're getting enough of — and which you're not.",
      },
      {
        icon: BrainCircuit,
        title: "The full picture",
        subtitle: "How sleep connects everything",
        description:
          "Zura connects your sleep to your training load, meals, and stress. Not just a chart — an explanation of why you feel the way you do.",
      },
    ],
  },
  {
    id: "heart",
    label: "Heart",
    headline: "Know your heart\ninside and out.",
    subheadline: "Resting heart rate, HRV, and recovery — tracked automatically, shown in context.",
    features: [
      {
        icon: Heart,
        title: "Resting heart rate & HRV",
        subtitle: "Tracked automatically every day",
        description:
          "Your resting heart rate and heart rate variability are tracked automatically and shown in context — so you know what the numbers actually mean.",
      },
      {
        icon: Activity,
        title: "How your heart responds",
        subtitle: "To workouts, meals, and sleep",
        description:
          "Your heart responds to everything — training load, what you ate, how you slept, stress. Zura shows you exactly which levers are moving it.",
      },
      {
        icon: TrendingDown,
        title: "Recovery score",
        subtitle: "Know when to push, know when to rest",
        description:
          "Each morning you get a recovery score based on your heart data overnight. Push hard when it's high. Pull back when it's low.",
      },
    ],
  },
];

// ---------------------------------------------------------------------------
// PhonePlaceholder
// ---------------------------------------------------------------------------

function PhonePlaceholder({ label }: { label: string }) {
  return (
    <div
      style={{ minHeight: 540 }}
      className="w-full flex flex-col items-center justify-center gap-3"
    >
      <div className="w-12 h-12 rounded-full flex items-center justify-center" style={{ ...PATTERN_BG, backgroundSize: "120px auto" }}>
        <div className="w-5 h-5 rounded-full bg-[#F0EEE9]/60" />
      </div>
      <p className="text-[#6B6864] text-sm font-medium text-center px-4">{label}</p>
      <p className="text-[#6B6864]/50 text-xs text-center px-6">Screenshot coming soon</p>
    </div>
  );
}

// ---------------------------------------------------------------------------
// FeatureShowcaseSection
// ---------------------------------------------------------------------------

export function FeatureShowcaseSection() {
  const [activeCat, setActiveCat] = useState(0);
  const [activeFeature, setActiveFeature] = useState(0);

  // Display state lags behind active state by one fade animation (~250ms)
  // so GSAP can fade out the old content before React renders new content.
  const [displayCat, setDisplayCat] = useState(0);
  const [displayFeature, setDisplayFeature] = useState(0);

  const [phoneWidth, setPhoneWidth] = useState(370);

  const { playSound } = useSoundContext();
  const sectionRef = useRef<HTMLElement>(null);
  const headlineRef = useRef<HTMLHeadingElement>(null);
  const subheadRef = useRef<HTMLParagraphElement>(null);
  const accordionRef = useRef<HTMLDivElement>(null);
  const phoneColRef = useRef<HTMLDivElement>(null);
  const progressRef = useRef<HTMLDivElement>(null);
  const timerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  // Cursor parallax — independent wrappers so they don't conflict with GSAP
  // ScrollTrigger tweens that target headlineRef / phoneColRef directly.
  const headlineCursorRef = useCursorParallax<HTMLDivElement>({ depth: 0.4 });
  const phoneCursorRef = useCursorParallax<HTMLDivElement>({ depth: 0.7 });

  const displayCategory = CATEGORIES[displayCat];

  // Responsive phone width
  useEffect(() => {
    const update = () => setPhoneWidth(window.innerWidth < 640 ? 290 : 370);
    update();
    window.addEventListener("resize", update);
    return () => window.removeEventListener("resize", update);
  }, []);

  // -------------------------------------------------------------------------
  // Section entrance — ScrollTrigger
  // -------------------------------------------------------------------------
  useGSAP(() => {
    const section = sectionRef.current;
    if (!section) return;
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;

    const tabBar = section.querySelector<HTMLElement>(".showcase-tabbar");
    const headlineEl = headlineRef.current;
    const subEl = subheadRef.current;
    const phoneCol = phoneColRef.current;
    const accordionItems = accordionRef.current?.querySelectorAll<HTMLElement>(".accordion-item");

    const targets = [tabBar, headlineEl, subEl, ...(accordionItems ?? []), phoneCol].filter(Boolean);

    gsap.fromTo(
      targets,
      { opacity: 0, y: 28 },
      {
        opacity: 1,
        y: 0,
        duration: 0.65,
        stagger: 0.07,
        ease: "power3.out",
        scrollTrigger: {
          trigger: section,
          start: "top 78%",
          toggleActions: "play none none none",
        },
      },
    );
  }, { scope: sectionRef });

  // -------------------------------------------------------------------------
  // Animate progress bar
  // -------------------------------------------------------------------------
  useEffect(() => {
    const bar = progressRef.current;
    if (!bar) return;
    gsap.killTweensOf(bar);
    gsap.set(bar, { width: "0%" });
    gsap.to(bar, { width: "100%", duration: DURATION / 1000, ease: "none" });
    return () => { gsap.killTweensOf(bar); };
  }, [activeCat, activeFeature]);

  // -------------------------------------------------------------------------
  // Active icon pulse on feature change
  // -------------------------------------------------------------------------
  useGSAP(() => {
    const icon = accordionRef.current?.querySelector<HTMLElement>(".accordion-icon-active");
    if (!icon) return;
    gsap.fromTo(icon, { scale: 0.8, opacity: 0.6 }, { scale: 1, opacity: 1, duration: 0.35, ease: "back.out(2)" });
  }, { scope: accordionRef, dependencies: [activeFeature, activeCat] });

  // -------------------------------------------------------------------------
  // Simple cross-fade for headline + subheadline when category/feature changes
  // (No SplitText — avoids DOM restructure that causes wrapping inconsistency)
  // -------------------------------------------------------------------------
  const swapContent = useCallback((newCat: number, newFeature: number) => {
    const els = [headlineRef.current, subheadRef.current].filter(Boolean);

    gsap.to(els, {
      opacity: 0,
      y: -8,
      duration: 0.22,
      ease: "power2.in",
      onComplete: () => {
        setDisplayCat(newCat);
        setDisplayFeature(newFeature);
        // Next frame: content has updated, fade back in
        requestAnimationFrame(() => {
          gsap.fromTo(els, { y: 12, opacity: 0 }, { y: 0, opacity: 1, duration: 0.35, ease: "power2.out" });
        });
      },
    });
  }, []);

  // Animate accordion items in after category change
  const staggerAccordionIn = useCallback(() => {
    const items = accordionRef.current?.querySelectorAll<HTMLElement>(".accordion-item");
    if (!items?.length) return;
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;
    gsap.fromTo(items, { opacity: 0, x: -16 }, { opacity: 1, x: 0, duration: 0.38, stagger: 0.06, ease: "power2.out" });
  }, []);

  // -------------------------------------------------------------------------
  // Auto-advance timer
  // -------------------------------------------------------------------------
  const advance = useCallback(() => {
    const cat = CATEGORIES[activeCat];
    const isLastFeature = activeFeature === cat.features.length - 1;
    const newCat = isLastFeature ? (activeCat + 1) % CATEGORIES.length : activeCat;
    const newFeature = isLastFeature ? 0 : activeFeature + 1;

    if (isLastFeature) {
      // Category is changing — animate headline/subheadline out and back in
      swapContent(newCat, newFeature);
      setTimeout(() => {
        setActiveCat(newCat);
        setActiveFeature(newFeature);
        setTimeout(staggerAccordionIn, 60);
      }, 240);
    } else {
      // Same category, next feature — no headline animation needed
      setActiveFeature(newFeature);
      setDisplayFeature(newFeature);
    }
  }, [activeCat, activeFeature, swapContent, staggerAccordionIn]);

  useEffect(() => {
    timerRef.current = setTimeout(advance, DURATION);
    return () => { if (timerRef.current) clearTimeout(timerRef.current); };
  }, [advance]);

  // -------------------------------------------------------------------------
  // Manual category change
  // -------------------------------------------------------------------------
  const handleCategoryChange = useCallback((index: number) => {
    if (index === activeCat) return;
    if (timerRef.current) clearTimeout(timerRef.current);
    playSound("tab-click");

    swapContent(index, 0);
    setTimeout(() => {
      setActiveCat(index);
      setActiveFeature(0);
      setTimeout(staggerAccordionIn, 60);
    }, 240);
  }, [activeCat, swapContent, staggerAccordionIn, playSound]);

  // -------------------------------------------------------------------------
  // Manual feature select
  // -------------------------------------------------------------------------
  const handleFeatureSelect = useCallback((index: number) => {
    if (index === activeFeature) return;
    if (timerRef.current) clearTimeout(timerRef.current);
    playSound("tick");
    setActiveFeature(index);
    setDisplayFeature(index);
  }, [activeFeature, playSound]);

  // -------------------------------------------------------------------------
  // Render
  // -------------------------------------------------------------------------

  return (
    <section
      ref={sectionRef}
      id="feature-showcase"
      className="relative py-20 md:py-28 px-6 md:px-12 font-jakarta"
      style={{ backgroundColor: "transparent" }}
    >
      <div className="mx-auto max-w-6xl">

        {/* ── Category tab bar ── */}
        <div className="showcase-tabbar mb-12 md:mb-16">
          <div className="inline-flex rounded-full bg-[#E8E6E1] p-1 gap-1">
            {CATEGORIES.map((cat, i) => {
              const isActive = i === activeCat;
              return (
                <button
                  key={cat.id}
                  onClick={() => handleCategoryChange(i)}
                  className="relative px-5 py-2 rounded-full text-sm font-semibold transition-colors duration-200 focus:outline-none"
                >
                  {isActive && (
                    <motion.div
                      layoutId="cat-pill"
                      className="absolute inset-0 rounded-full overflow-hidden"
                      style={{
                        ...PATTERN_BG,
                        boxShadow: "0 1px 4px rgba(22,22,24,0.15)",
                      }}
                      transition={{ type: "spring", stiffness: 400, damping: 30 }}
                    />
                  )}
                  <span
                    className="relative z-10"
                    style={{ color: isActive ? "#ffffff" : "#6B6864" }}
                  >
                    {cat.label}
                  </span>
                </button>
              );
            })}
          </div>
        </div>

        {/* ── Main layout: left col + persistent phone ── */}
        <div className="flex flex-col lg:flex-row gap-12 lg:gap-20 items-center">

          {/* Left: header + accordion */}
          <div className="w-full lg:w-[52%] flex flex-col">
            <div ref={headlineCursorRef} className="will-change-transform mb-10">
              <h2
                ref={headlineRef}
                className="font-bold uppercase tracking-tighter leading-[0.9] text-[#161618] whitespace-pre-line"
                style={{ fontSize: "clamp(2rem, 3.5vw, 3.8rem)" }}
              >
                {displayCategory.headline}
              </h2>
              <p
                ref={subheadRef}
                className="mt-4 text-base md:text-lg text-[#6B6864] max-w-md"
              >
                {displayCategory.subheadline}
              </p>
            </div>

            {/* Accordion */}
            <div ref={accordionRef} className="flex flex-col gap-1">
              {CATEGORIES[activeCat].features.map((feature, i) => {
                const Icon = feature.icon;
                const isActive = i === activeFeature;

                return (
                  <button
                    key={`${activeCat}-${i}`}
                    onClick={() => handleFeatureSelect(i)}
                    className="accordion-item w-full text-left focus:outline-none group"
                  >
                    <div
                      className="rounded-[16px] px-5 py-4 transition-colors duration-300"
                      style={{ backgroundColor: isActive ? "#E8E6E1" : "transparent" }}
                    >
                      <div className="flex items-center gap-3">
                        {/* Icon wrapper — pattern fill when active */}
                        <div
                          className={`flex-shrink-0 w-9 h-9 rounded-[10px] flex items-center justify-center transition-all duration-300 ${isActive ? "accordion-icon-active" : "group-hover:opacity-80"}`}
                          style={
                            isActive
                              ? { ...PATTERN_BG, backgroundSize: "120px auto" }
                              : { background: "rgba(22,22,24,0.07)" }
                          }
                        >
                          <Icon
                            size={17}
                            style={{ color: isActive ? "#F0EEE9" : "#6B6864" }}
                          />
                        </div>

                        <div className="flex-1 min-w-0">
                          <span
                            className="font-semibold text-[15px] transition-colors duration-300"
                            style={{ color: isActive ? "#161618" : "#6B6864" }}
                          >
                            {feature.title}
                          </span>
                          {!isActive && (
                            <p className="text-[13px] text-[#6B6864]/60 truncate group-hover:text-[#6B6864]/80 transition-colors duration-200">
                              {feature.subtitle}
                            </p>
                          )}
                        </div>
                      </div>

                      {/* Expanded content */}
                      {isActive && (
                        <div>
                          <p className="mt-3 text-[#6B6864] text-[15px] leading-relaxed pl-12">
                            {feature.description}
                          </p>
                          <div className="mt-4 pl-12">
                            {/* Progress bar — pattern fill */}
                            <div className="h-0.5 w-full rounded-full bg-[#161618]/10 overflow-hidden">
                              <div
                                ref={progressRef}
                                className="h-full rounded-full"
                                style={{ width: "0%", ...PATTERN_BG, backgroundSize: "120px auto" }}
                              />
                            </div>
                          </div>
                        </div>
                      )}
                    </div>
                  </button>
                );
              })}
            </div>
          </div>

          {/* Right: persistent phone — never remounts between categories */}
          <div
            ref={phoneColRef}
            className="w-full lg:w-[48%] flex justify-center lg:justify-end"
          >
            <div ref={phoneCursorRef} className="will-change-transform">
            <div className="relative">
              {/* Soft glow behind phone */}
              <div
                className="absolute -inset-8 rounded-full pointer-events-none"
                style={{
                  background: "radial-gradient(ellipse at center, rgba(52,78,65,0.10) 0%, transparent 70%)",
                  filter: "blur(24px)",
                }}
              />
              <PhoneMockup frameWidth={phoneWidth}>
                <PhonePlaceholder
                  label={CATEGORIES[displayCat].features[displayFeature]?.title ?? ""}
                />
              </PhoneMockup>
            </div>
            </div>
          </div>

        </div>
      </div>
    </section>
  );
}
