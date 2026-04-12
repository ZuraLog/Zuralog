"use client";

import { useEffect, useRef, useState, type ReactNode } from "react";
import gsap from "gsap";
import ScrollTrigger from "gsap/ScrollTrigger";
import { PhoneMockup } from "@/components/phone/PhoneMockup";
import { ConnectScreen } from "@/components/phone/screens/ConnectScreen";
import { NutritionScreen } from "@/components/phone/screens/NutritionScreen";
import { WorkoutScreen } from "@/components/phone/screens/WorkoutScreen";
import { SleepScreen } from "@/components/phone/screens/SleepScreen";
import { HeartScreen } from "@/components/phone/screens/HeartScreen";
import { MoreScreen } from "@/components/phone/screens/MoreScreen";
import { CoachScreen } from "@/components/phone/screens/CoachScreen";
import { computeFrameWidth } from "@/components/phone/PhoneContext";
import { loadingBridge } from "@/lib/loading-bridge";

if (typeof window !== "undefined") {
  gsap.registerPlugin(ScrollTrigger);
}

// ---------------------------------------------------------------------------
// Type definitions
// ---------------------------------------------------------------------------

type PhonePosition = "left" | "center" | "right";
type PanelLayout = "split-left" | "split-right" | "centered";

interface SectionData {
  key: string;
  headline: ReactNode;
  body: string;
  phonePosition: PhonePosition;
  layout: PanelLayout;
}

// ---------------------------------------------------------------------------
// Phone position helpers
// ---------------------------------------------------------------------------

function getTargetX(pos: PhonePosition, layout: PanelLayout, vw: number): number {
  if (layout === "centered") return 0;
  return pos === "right" ? Math.round(vw * 0.25) : Math.round(vw * -0.25);
}

function getTargetY(layout: PanelLayout, vh: number): number {
  // For centered sections, push the phone slightly below the section's
  // vertical midpoint so it sits below the text block at the top.
  return layout === "centered" ? Math.round(vh * 0.10) : 0;
}

function getTargetScale(layout: PanelLayout): number {
  // Centered layout uses a smaller phone so the top text has room.
  return layout === "centered" ? 0.65 : 1;
}

// ---------------------------------------------------------------------------
// SECTIONS constant — 7 entries matching the design spec
// ---------------------------------------------------------------------------

const SECTIONS: SectionData[] = [
  {
    key: "connect",
    phonePosition: "right",
    layout: "split-left",
    headline: (
      <>
        Every app. Every device.{" "}
        <span
          className="ds-pattern-text"
          style={{ backgroundImage: "var(--ds-pattern-sage)" }}
        >
          One place.
        </span>
      </>
    ),
    body: "Most health apps make you start from scratch. ZuraLog connects directly to Apple Health, Google Health Connect, Strava, and more\u2014so everything you have already been tracking is ready from day one.",
  },
  {
    key: "nutrition",
    phonePosition: "center",
    layout: "centered",
    headline: (
      <>
        Snap it. Scan it. Say it.{" "}
        <span
          className="ds-pattern-text"
          style={{ backgroundImage: "var(--ds-pattern-sage)" }}
        >
          Done.
        </span>
      </>
    ),
    body: "No more nutrition apps that take longer than the meal itself. Snap a photo, scan a label, tell Zura what you had, or log it manually. It figures out everything automatically.",
  },
  {
    key: "workouts",
    phonePosition: "left",
    layout: "split-right",
    headline: (
      <>
        Log it live, log it later, or{" "}
        <span
          className="ds-pattern-text"
          style={{ backgroundImage: "var(--ds-pattern-sage)" }}
        >
          let it log itself.
        </span>
      </>
    ),
    body: "Track your sets and reps live, log a workout you already finished, or let Zura pull it in automatically from Apple Health or Google Health Connect. Every session counts, no matter how you log it.",
  },
  {
    key: "sleep",
    phonePosition: "center",
    layout: "centered",
    headline: (
      <>
        Sleep better. Know{" "}
        <span
          className="ds-pattern-text"
          style={{ backgroundImage: "var(--ds-pattern-sage)" }}
        >
          exactly why you&apos;re not.
        </span>
      </>
    ),
    body: "Most apps show you a sleep chart and call it done. Zura goes further\u2014connecting your sleep patterns to your workouts, stress, and daily habits to tell you what is actually working and what is not.",
  },
  {
    key: "heart",
    phonePosition: "right",
    layout: "split-left",
    headline: (
      <>
        Know your heart.{" "}
        <span
          className="ds-pattern-text"
          style={{ backgroundImage: "var(--ds-pattern-sage)" }}
        >
          Know your health.
        </span>
      </>
    ),
    body: "Your heart responds to everything\u2014your workouts, your meals, your sleep, your steps. Zura connects all of it so you stop seeing isolated numbers and start seeing the full picture.",
  },
  {
    key: "more",
    phonePosition: "center",
    layout: "centered",
    headline: <>And that&apos;s just the beginning.</>,
    body: "The more you track, the more Zura understands. And the more Zura understands, the better it gets.",
  },
  {
    key: "coach",
    phonePosition: "left",
    layout: "split-right",
    headline: (
      <>
        Meet Zura. The coach who knows your{" "}
        <span
          className="ds-pattern-text"
          style={{ backgroundImage: "var(--ds-pattern-sage)" }}
        >
          whole story.
        </span>
      </>
    ),
    body: "You\u2019ve been tracking everything. Now finally get something back. Zura reads across your workouts, meals, sleep, and heart rate to tell you what\u2019s working, what isn\u2019t, and exactly what to do next.",
  },
];

// ---------------------------------------------------------------------------
// Panel sub-component — text content only (phone is a sibling element)
// ---------------------------------------------------------------------------

interface PanelProps {
  section: SectionData;
  index: number;
}

function Panel({ section, index }: PanelProps) {
  const isFirst = index === 0;
  const isCentered = section.layout === "centered";

  const textBlock = (
    <div className={isCentered ? "text-center" : ""}>
      <h2 className="panel-headline text-4xl md:text-5xl lg:text-6xl font-bold tracking-tight leading-[1.05] text-[var(--color-ds-text-on-warm-white)]">
        {section.headline}
      </h2>
      <p
        className={`panel-body mt-6 text-base md:text-lg lg:text-xl leading-relaxed text-[var(--color-ds-text-secondary)] ${
          isCentered ? "max-w-xl mx-auto" : ""
        }`}
      >
        {section.body}
      </p>
    </div>
  );

  let inner: ReactNode;

  if (section.layout === "split-left") {
    // Text in left column, phone (absolute sibling) fills right column
    inner = (
      <div className="h-full flex items-center">
        <div className="w-full max-w-7xl mx-auto px-6 md:px-12 lg:px-20">
          <div className="grid grid-cols-2 gap-12 items-center">
            <div className="max-w-lg">{textBlock}</div>
            <div aria-hidden="true" />
          </div>
        </div>
      </div>
    );
  } else if (section.layout === "split-right") {
    // Phone (absolute sibling) fills left column, text in right column
    inner = (
      <div className="h-full flex items-center">
        <div className="w-full max-w-7xl mx-auto px-6 md:px-12 lg:px-20">
          <div className="grid grid-cols-2 gap-12 items-center">
            <div aria-hidden="true" />
            <div className="max-w-lg">{textBlock}</div>
          </div>
        </div>
      </div>
    );
  } else {
    // Centered: text at top, phone (absolute sibling) sits below center
    inner = (
      <div className="h-full flex flex-col items-center justify-start pt-16 md:pt-24">
        <div className="max-w-2xl px-6 md:px-12 text-center">
          {textBlock}
        </div>
      </div>
    );
  }

  return (
    <div
      className="feature-panel absolute inset-0"
      data-panel={section.key}
      style={{ opacity: isFirst ? 1 : 0 }}
    >
      {inner}
    </div>
  );
}

// ---------------------------------------------------------------------------
// FeatureSections — pinned container with phone living inside the same layer
//
// Architecture change from previous approach:
// - Phone is now a real DOM element inside the section (not a fixed overlay)
// - This eliminates the cross-layer z-index coordination with text
// - No entrance/exit fade needed: phone appears/disappears with the section
// - Centered sections: text at top, phone at bottom-center, scaled to 0.65
// - Split sections: text on one side, phone on the other (no overlap possible)
// ---------------------------------------------------------------------------

export function FeatureSections() {
  const containerRef = useRef<HTMLDivElement>(null);
  const phoneWrapperRef = useRef<HTMLDivElement>(null);

  // Screen refs — one per SECTIONS entry, in order
  const connectScreenRef = useRef<HTMLDivElement>(null);
  const nutritionScreenRef = useRef<HTMLDivElement>(null);
  const workoutScreenRef = useRef<HTMLDivElement>(null);
  const sleepScreenRef = useRef<HTMLDivElement>(null);
  const heartScreenRef = useRef<HTMLDivElement>(null);
  const moreScreenRef = useRef<HTMLDivElement>(null);
  const coachScreenRef = useRef<HTMLDivElement>(null);

  // Responsive phone frame width — updates on resize
  const [frameWidth, setFrameWidth] = useState(computeFrameWidth);

  // Signal the loading screen that there are no heavy assets to wait for.
  // Previously ScrollPhone did this; now FeatureSections does it on mount.
  useEffect(() => {
    loadingBridge.setProgress(100);
  }, []);

  // Resize: update frameWidth so PhoneMockup re-renders at the right size.
  useEffect(() => {
    const onResize = () => setFrameWidth(computeFrameWidth());
    window.addEventListener("resize", onResize);
    return () => window.removeEventListener("resize", onResize);
  }, []);

  // GSAP setup — runs once on mount. All refs are local so no polling needed.
  useEffect(() => {
    if (typeof window === "undefined") return;
    if (window.innerWidth < 768) return;

    const container = containerRef.current;
    const phoneWrapper = phoneWrapperRef.current;
    if (!container || !phoneWrapper) return;

    const screenRefs = [
      connectScreenRef,
      nutritionScreenRef,
      workoutScreenRef,
      sleepScreenRef,
      heartScreenRef,
      moreScreenRef,
      coachScreenRef,
    ];

    const ctx = gsap.context(() => {
      const panels = gsap.utils.toArray<HTMLElement>(".feature-panel", container);
      if (panels.length !== SECTIONS.length) return;

      // Set initial phone position to match the first section (Connect = right)
      gsap.set(phoneWrapper, {
        x: Math.round(window.innerWidth * 0.25),
        y: 0,
        scale: 1,
      });

      const prefersReduced = window.matchMedia(
        "(prefers-reduced-motion: reduce)"
      ).matches;

      // Build master timeline
      const tl = gsap.timeline();
      SECTIONS.forEach((section, i) => {
        tl.addLabel(section.key, i);
      });

      // 6 transitions between 7 sections
      for (let i = 0; i < SECTIONS.length - 1; i++) {
        const fromSection = SECTIONS[i];
        const toSection = SECTIONS[i + 1];
        const fromPanel = panels[i];
        const toPanel = panels[i + 1];
        const fromScreen = screenRefs[i].current;
        const toScreen = screenRefs[i + 1].current;
        const label = fromSection.key;
        if (!fromScreen || !toScreen) continue;

        const fromTextEls = gsap.utils.toArray<HTMLElement>(
          ".panel-headline, .panel-body",
          fromPanel
        );
        const toTextEls = gsap.utils.toArray<HTMLElement>(
          ".panel-headline, .panel-body",
          toPanel
        );

        if (!prefersReduced) {
          tl.to(
            fromTextEls,
            { y: -30, opacity: 0, duration: 0.4, stagger: 0.05, ease: "power2.in" },
            label + "+=0.3"
          );
          tl.to(fromPanel, { opacity: 0, duration: 0.1 }, label + "+=0.7");
          tl.to(toPanel, { opacity: 1, duration: 0.1 }, label + "+=0.7");
          tl.fromTo(
            toTextEls,
            { y: 30, opacity: 0 },
            { y: 0, opacity: 1, duration: 0.4, stagger: 0.05, ease: "power3.out", immediateRender: false },
            label + "+=0.7"
          );
        } else {
          tl.to(fromPanel, { opacity: 0, duration: 0.1 }, label + "+=0.5");
          tl.to(toPanel, { opacity: 1, duration: 0.1 }, label + "+=0.5");
        }

        // Phone position — function-based so invalidateOnRefresh re-evaluates
        tl.to(
          phoneWrapper,
          {
            x: () => getTargetX(toSection.phonePosition, toSection.layout, window.innerWidth),
            y: () => getTargetY(toSection.layout, window.innerHeight),
            scale: getTargetScale(toSection.layout),
            duration: 0.6,
            ease: "power3.inOut",
          },
          label + "+=0.3"
        );

        // Screen crossfades
        tl.to(
          fromScreen,
          { opacity: 0, filter: "blur(10px)", duration: 0.4, ease: "power2.in" },
          label + "+=0.3"
        );
        tl.to(
          toScreen,
          { opacity: 1, filter: "blur(0px)", duration: 0.4, ease: "power2.out" },
          label + "+=0.6"
        );
      }

      ScrollTrigger.create({
        trigger: container,
        pin: true,
        scrub: 1,
        start: "top top",
        end: "+=600%",
        invalidateOnRefresh: true,
        animation: tl,
        onRefresh(self) {
          // Re-apply initial phone position when at the start of the timeline
          // so the phone snaps to the correct position after a resize.
          if (self.progress < 0.01) {
            gsap.set(phoneWrapper, {
              x: Math.round(window.innerWidth * 0.25),
              y: 0,
              scale: 1,
            });
          }
        },
      });
    }, container);

    return () => ctx.revert();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  return (
    <section
      ref={containerRef}
      id="feature-sections"
      className="relative hidden md:block overflow-hidden"
      style={{ height: "100vh" }}
    >
      {/* Text panels — absolutely stacked, GSAP fades between them */}
      {SECTIONS.map((section, i) => (
        <Panel key={section.key} section={section} index={i} />
      ))}

      {/* Phone — lives in the same layer as text panels.
          Centered by CSS, then GSAP applies x/y/scale per section.
          aria-hidden: the phone is decorative (screens have no interactive text). */}
      <div
        ref={phoneWrapperRef}
        className="absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2 will-change-transform pointer-events-none"
        aria-hidden="true"
      >
        <PhoneMockup frameWidth={frameWidth}>
          <div className="relative w-full h-full">
            <div
              ref={connectScreenRef}
              className="absolute inset-0"
              style={{ opacity: 1, filter: "blur(0px)" }}
            >
              <ConnectScreen />
            </div>
            <div
              ref={nutritionScreenRef}
              className="absolute inset-0"
              style={{ opacity: 0, filter: "blur(10px)" }}
            >
              <NutritionScreen />
            </div>
            <div
              ref={workoutScreenRef}
              className="absolute inset-0"
              style={{ opacity: 0, filter: "blur(10px)" }}
            >
              <WorkoutScreen />
            </div>
            <div
              ref={sleepScreenRef}
              className="absolute inset-0"
              style={{ opacity: 0, filter: "blur(10px)" }}
            >
              <SleepScreen />
            </div>
            <div
              ref={heartScreenRef}
              className="absolute inset-0"
              style={{ opacity: 0, filter: "blur(10px)" }}
            >
              <HeartScreen />
            </div>
            <div
              ref={moreScreenRef}
              className="absolute inset-0"
              style={{ opacity: 0, filter: "blur(10px)" }}
            >
              <MoreScreen />
            </div>
            <div
              ref={coachScreenRef}
              className="absolute inset-0"
              style={{ opacity: 0, filter: "blur(10px)" }}
            >
              <CoachScreen />
            </div>
          </div>
        </PhoneMockup>
      </div>
    </section>
  );
}
