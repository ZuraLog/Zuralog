"use client";

import { useRef, type ReactNode } from "react";
import { useGSAP } from "@gsap/react";
import gsap from "gsap";
import ScrollTrigger from "gsap/ScrollTrigger";
import {
  usePhoneContext,
  computeFrameWidth,
  computeHeroY,
} from "@/components/phone/PhoneContext";

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
  screenRefKey:
    | "connectScreenRef"
    | "nutritionScreenRef"
    | "workoutScreenRef"
    | "sleepScreenRef"
    | "heartScreenRef"
    | "moreScreenRef"
    | "coachScreenRef";
}

// ---------------------------------------------------------------------------
// SECTIONS constant — 7 entries matching the design spec
// ---------------------------------------------------------------------------

const SECTIONS: SectionData[] = [
  {
    key: "connect",
    phonePosition: "right",
    layout: "split-left",
    screenRefKey: "connectScreenRef",
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
    screenRefKey: "nutritionScreenRef",
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
    screenRefKey: "workoutScreenRef",
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
    screenRefKey: "sleepScreenRef",
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
    screenRefKey: "heartScreenRef",
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
    screenRefKey: "moreScreenRef",
    headline: <>And that&apos;s just the beginning.</>,
    body: "The more you track, the more Zura understands. And the more Zura understands, the better it gets.",
  },
  {
    key: "coach",
    phonePosition: "left",
    layout: "split-right",
    screenRefKey: "coachScreenRef",
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
// Panel sub-component — renders one section's text content
// ---------------------------------------------------------------------------

interface PanelProps {
  section: SectionData;
  index: number;
}

function Panel({ section, index }: PanelProps) {
  const isFirst = index === 0;

  const textBlock = (
    <div className={section.layout === "centered" ? "text-center" : ""}>
      <h2 className="panel-headline text-4xl md:text-5xl lg:text-6xl font-bold tracking-tight leading-[1.05] text-[var(--color-ds-text-on-warm-white)]">
        {section.headline}
      </h2>
      <p
        className={`panel-body mt-6 text-base md:text-lg lg:text-xl leading-relaxed text-[var(--color-ds-text-secondary)] ${
          section.layout === "centered" ? "max-w-2xl mx-auto" : ""
        }`}
      >
        {section.body}
      </p>
    </div>
  );

  let inner: ReactNode;

  if (section.layout === "split-left") {
    // Text left, empty spacer right (phone overlay fills right)
    inner = (
      <div className="w-full max-w-7xl mx-auto px-6 md:px-12 lg:px-20">
        <div className="grid grid-cols-2 gap-12 items-center">
          <div className="max-w-lg">{textBlock}</div>
          <div aria-hidden="true" />
        </div>
      </div>
    );
  } else if (section.layout === "split-right") {
    // Empty spacer left (phone overlay fills left), text right
    inner = (
      <div className="w-full max-w-7xl mx-auto px-6 md:px-12 lg:px-20">
        <div className="grid grid-cols-2 gap-12 items-center">
          <div aria-hidden="true" />
          <div className="max-w-lg">{textBlock}</div>
        </div>
      </div>
    );
  } else {
    // Centered: text centered above, spacer below for phone
    inner = (
      <div className="w-full max-w-7xl mx-auto px-6 md:px-12 lg:px-20 text-center">
        {textBlock}
        <div className="h-[420px]" aria-hidden="true" />
      </div>
    );
  }

  return (
    <div
      className="feature-panel absolute inset-0 flex items-center"
      data-panel={section.key}
      style={{ opacity: isFirst ? 1 : 0 }}
    >
      {inner}
    </div>
  );
}

// ---------------------------------------------------------------------------
// FeatureSections — pinned ScrollTrigger container with single GSAP timeline
// ---------------------------------------------------------------------------

export function FeatureSections() {
  const containerRef = useRef<HTMLDivElement>(null);
  const phoneCtx = usePhoneContext();

  useGSAP(
    () => {
      if (typeof window === "undefined") return;
      if (window.innerWidth < 768) return;
      if (!phoneCtx) return;

      const container = containerRef.current;
      if (!container) return;

      const {
        containerRef: phoneContainerRef,
        phoneRef,
        placeholderScreenRef,
        connectScreenRef,
        nutritionScreenRef,
        workoutScreenRef,
        sleepScreenRef,
        heartScreenRef,
        moreScreenRef,
        coachScreenRef,
      } = phoneCtx;

      const phone = phoneRef.current;
      const phoneContainer = phoneContainerRef.current;
      if (!phone || !phoneContainer) return;

      const screenRefs = [
        connectScreenRef,
        nutritionScreenRef,
        workoutScreenRef,
        sleepScreenRef,
        heartScreenRef,
        moreScreenRef,
        coachScreenRef,
      ];

      const panels = gsap.utils.toArray<HTMLElement>(".feature-panel", container);
      if (panels.length !== SECTIONS.length) return;

      let rightX = 0;
      let leftX = 0;
      let heroY = 0;

      const recalcPositions = () => {
        const vw = window.innerWidth;
        rightX = Math.round(vw * 0.25);
        leftX = Math.round(vw * -0.25);
        heroY = computeHeroY(computeFrameWidth());
      };
      recalcPositions();

      const positionX = (pos: PhonePosition): number => {
        if (pos === "right") return rightX;
        if (pos === "left") return leftX;
        return 0;
      };

      const prefersReduced = window.matchMedia(
        "(prefers-reduced-motion: reduce)"
      ).matches;

      // Safety: ensure all feature screens start hidden
      screenRefs.forEach((ref) => {
        if (ref.current) {
          gsap.set(ref.current, { opacity: 0, filter: "blur(10px)" });
        }
      });

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
            {
              y: -30,
              opacity: 0,
              duration: 0.4,
              stagger: 0.05,
              ease: "power2.in",
            },
            label + "+=0.3"
          );
          tl.to(fromPanel, { opacity: 0, duration: 0.1 }, label + "+=0.7");
          tl.to(toPanel, { opacity: 1, duration: 0.1 }, label + "+=0.7");
          tl.fromTo(
            toTextEls,
            { y: 30, opacity: 0 },
            {
              y: 0,
              opacity: 1,
              duration: 0.4,
              stagger: 0.05,
              ease: "power3.out",
              immediateRender: false,
            },
            label + "+=0.7"
          );
        } else {
          tl.to(fromPanel, { opacity: 0, duration: 0.1 }, label + "+=0.5");
          tl.to(toPanel, { opacity: 1, duration: 0.1 }, label + "+=0.5");
        }

        tl.to(
          phone,
          {
            x: positionX(toSection.phonePosition),
            duration: 0.6,
            ease: "power3.inOut",
          },
          label + "+=0.3"
        );
        tl.to(
          fromScreen,
          {
            opacity: 0,
            filter: "blur(10px)",
            duration: 0.4,
            ease: "power2.in",
          },
          label + "+=0.3"
        );
        tl.to(
          toScreen,
          {
            opacity: 1,
            filter: "blur(0px)",
            duration: 0.4,
            ease: "power2.out",
          },
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
        onRefresh: () => {
          recalcPositions();
        },

        onEnter: () => {
          const cs = connectScreenRef.current;
          const ph = placeholderScreenRef.current;
          if (!cs || !ph) return;
          gsap.to(phone, {
            x: positionX(SECTIONS[0].phonePosition),
            y: 0,
            duration: 1.0,
            ease: "power3.out",
            overwrite: "auto",
          });
          gsap.to(ph, {
            opacity: 0,
            filter: "blur(10px)",
            duration: 0.45,
            ease: "power2.in",
          });
          gsap.to(cs, {
            opacity: 1,
            filter: "blur(0px)",
            duration: 0.5,
            delay: 0.1,
            ease: "power2.out",
          });
          gsap.to(phoneContainer, {
            opacity: 1,
            duration: 0.3,
            ease: "power2.out",
          });
        },
        onLeave: () => {
          gsap.to(phoneContainer, {
            opacity: 0,
            duration: 0.5,
            ease: "power2.in",
          });
        },
        onEnterBack: () => {
          gsap.to(phoneContainer, {
            opacity: 1,
            duration: 0.5,
            ease: "power2.out",
          });
        },
        onLeaveBack: () => {
          const cs = connectScreenRef.current;
          const ph = placeholderScreenRef.current;
          if (!cs || !ph) return;
          gsap.to(phone, {
            x: 0,
            y: heroY,
            duration: 1.0,
            ease: "power3.out",
            overwrite: "auto",
          });
          gsap.to(cs, {
            opacity: 0,
            filter: "blur(10px)",
            duration: 0.45,
            ease: "power2.in",
          });
          gsap.to(ph, {
            opacity: 1,
            filter: "blur(0px)",
            duration: 0.5,
            delay: 0.1,
            ease: "power2.out",
          });
        },
      });
    },
    { scope: containerRef, dependencies: [] }
  );

  return (
    <section
      ref={containerRef}
      id="feature-sections"
      className="relative hidden md:block"
      style={{ height: "100vh" }}
    >
      {SECTIONS.map((section, i) => (
        <Panel key={section.key} section={section} index={i} />
      ))}
    </section>
  );
}
