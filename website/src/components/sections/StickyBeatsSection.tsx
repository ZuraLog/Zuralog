"use client";

import { useEffect, useRef } from "react";
import gsap from "gsap";
import { ScrollTrigger } from "gsap/ScrollTrigger";
import Image from "next/image";

if (typeof window !== "undefined") {
  gsap.registerPlugin(ScrollTrigger);
}

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface Beat {
  headline: string;
  body: string;
  image: string;
}

interface StickyBeatsSectionProps {
  id: string;
  beats: Beat[];
  layout?: "image-left" | "image-right";
}

// ---------------------------------------------------------------------------
// StickyBeatsSection
// ---------------------------------------------------------------------------

export function StickyBeatsSection({
  id,
  beats,
  layout = "image-right",
}: StickyBeatsSectionProps) {
  const sectionRef = useRef<HTMLElement>(null);
  const isImageLeft = layout === "image-left";

  useEffect(() => {
    const section = sectionRef.current;
    if (!section) return;
    if (window.innerWidth < 768) return;
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;

    const ctx = gsap.context(() => {
      const beatHeadlines = gsap.utils.toArray<HTMLElement>(".beat-headline", section);
      const beatHeadlinePatterns = gsap.utils.toArray<HTMLElement>(".beat-headline-pattern", section);
      const beatBodies = gsap.utils.toArray<HTMLElement>(".beat-body", section);
      const beatImages = gsap.utils.toArray<HTMLElement>(".beat-image", section);

      if (beatHeadlines.length !== beats.length) {
        if (process.env.NODE_ENV === "development") {
          console.warn("[StickyBeatsSection] Headline count mismatch — animation skipped.");
        }
        return;
      }

      // Everything starts invisible
      gsap.set(beatHeadlines, { opacity: 0 });
      gsap.set(beatHeadlinePatterns, { opacity: 0 });
      gsap.set(beatBodies, { opacity: 0, y: 60 });
      gsap.set(beatImages, { opacity: 0, scale: 1.06 });

      // ── Entrance: fires at real speed as section approaches viewport ──────
      ScrollTrigger.create({
        trigger: section,
        start: "top 75%",
        once: true,
        onEnter: () => {
          gsap.to(beatHeadlines[0],
            { opacity: 1, duration: 0.6, ease: "power2.out", delay: 0.05 });
          gsap.to(beatHeadlinePatterns[0],
            { opacity: 1, duration: 0.6, ease: "power2.out", delay: 0.25 });
          gsap.to(beatBodies[0],
            { opacity: 1, y: 0, duration: 0.7, ease: "power3.out", delay: 0.15 });
          gsap.to(beatImages[0],
            { opacity: 1, scale: 1, duration: 0.8, ease: "power2.out", delay: 0.05 });
        },
      });

      // ── Scrubbed timeline: beat transitions only ──────────────────────────
      const tl = gsap.timeline({
        scrollTrigger: {
          trigger: section,
          pin: true,
          scrub: 1,
          start: "top top",
          end: "+=" + (beats.length - 1) * 100 + "%",
          invalidateOnRefresh: true,
          snap: {
            snapTo: "labels",
            duration: { min: 0.2, max: 3 },
            delay: 0.2,
            ease: "power1.inOut",
          },
        },
      });

      // Labels at 0, 1, 2… — no entrance phase in the scrubbed window
      beats.forEach((_, i) => tl.addLabel("beat" + i, i));

      // ── Beat transitions ──────────────────────────────────────────────────
      for (let i = 0; i < beats.length - 1; i++) {
        const label = "beat" + i;

        // Pattern on outgoing headline deactivates (turns dark base visible)
        tl.to(beatHeadlinePatterns[i],
          { opacity: 0, duration: 0.3, ease: "power2.inOut" },
          label + "+=0.10");
        // Body outgoing: explosive slide up + fade
        tl.to(beatBodies[i],
          { opacity: 0, y: -60, duration: 0.4, ease: "power3.in" },
          label + "+=0.10");
        // Image outgoing: fades out
        tl.to(beatImages[i],
          { opacity: 0, duration: 0.45, ease: "power2.inOut" },
          label + "+=0.10");

        // Next headline appears (progressive reveal — stays visible once in)
        tl.to(beatHeadlines[i + 1],
          { opacity: 1, duration: 0.4, ease: "power2.out" },
          label + "+=0.20");
        // Image incoming: zoom-breathe entrance
        tl.to(beatImages[i + 1],
          { opacity: 1, scale: 1, duration: 0.55, ease: "power2.out" },
          label + "+=0.35");
        // Pattern on incoming headline activates
        tl.to(beatHeadlinePatterns[i + 1],
          { opacity: 1, duration: 0.3, ease: "power2.out" },
          label + "+=0.35");
        // Body incoming: explosive slide in from below
        tl.to(beatBodies[i + 1],
          { opacity: 1, y: 0, duration: 0.5, ease: "power3.out" },
          label + "+=0.40");
      }

      // Dummy tween so snap can reach the last label
      tl.to({}, { duration: 0.5 }, "beat" + (beats.length - 1));
    }, sectionRef);

    return () => ctx.revert();
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  return (
    <>
      {/* ── Desktop ──────────────────────────────────────────────────────── */}
      <section
        ref={sectionRef}
        id={id}
        className="hidden md:flex relative min-h-screen overflow-hidden items-center"
      >
        {/* Image panel — absolute, behind text */}
        <div
          className={`absolute top-1/2 -translate-y-1/2 w-[62%] pointer-events-none select-none ${
            isImageLeft ? "left-[-4%]" : "right-[-4%]"
          }`}
          aria-hidden="true"
        >
          <div className="relative" style={{ paddingBottom: "100%" }}>
            {beats.map((beat, i) => (
              <Image
                key={i}
                src={beat.image}
                alt=""
                fill
                className="beat-image object-contain"
                style={{ opacity: 0 }}
              />
            ))}
          </div>
        </div>

        {/* Text — z-10, overlapping image */}
        <div
          className={`relative z-10 w-full flex ${
            isImageLeft ? "justify-end" : "justify-start"
          }`}
        >
          <div
            className={`w-full max-w-[70%] py-24 ${
              isImageLeft
                ? "pl-8 md:pl-16 pr-10 md:pr-16 lg:pr-24"
                : "pl-10 md:pl-16 lg:pl-24 pr-8 md:pr-16"
            }`}
          >
            {/* Headlines — progressively revealed, pattern overlay for active state */}
            {beats.map((beat, i) => (
              <div
                key={i}
                className="beat-headline relative"
                style={{ opacity: 0 }}
              >
                {/* Dark base — shows when headline is visible but inactive */}
                <h2
                  className="font-jakarta font-bold uppercase tracking-tighter leading-[0.85] text-[#161618]"
                  style={{ fontSize: "clamp(3rem, 8.5vw, 10.5rem)" }}
                >
                  {beat.headline}
                </h2>
                {/* Pattern overlay — fades in when beat is active */}
                <h2
                  className="beat-headline-pattern ds-pattern-text font-jakarta font-bold uppercase tracking-tighter leading-[0.85] absolute inset-0"
                  style={{
                    fontSize: "clamp(3rem, 8.5vw, 10.5rem)",
                    backgroundImage: "var(--ds-pattern-sage)",
                    opacity: 0,
                  }}
                  aria-hidden="true"
                >
                  {beat.headline}
                </h2>
              </div>
            ))}

            {/* Body text area — one at a time, explosive transitions */}
            <div className="relative mt-10 max-w-xl">
              {/* Ghost — invisible, reserves container height */}
              <p
                className="invisible pointer-events-none font-jakarta text-xl md:text-2xl leading-relaxed"
                aria-hidden="true"
              >
                {beats[0].body}
              </p>
              {beats.map((beat, i) => (
                <p
                  key={i}
                  className="beat-body absolute top-0 left-0 right-0 font-jakarta text-xl md:text-2xl leading-relaxed text-[#6B6864]"
                  style={{ opacity: 0, transform: "translateY(60px)" }}
                >
                  {beat.body}
                </p>
              ))}
            </div>
          </div>
        </div>
      </section>

      {/* ── Mobile ───────────────────────────────────────────────────────── */}
      <div id={`${id}-mobile`} className="md:hidden">
        {beats.map((beat, i) => (
          <div key={i} className="py-16 px-8">
            <h3
              className="beat-headline-pattern ds-pattern-text font-jakarta font-bold uppercase tracking-tighter leading-[0.85]"
              style={{
                fontSize: "clamp(2.5rem, 10vw, 4rem)",
                backgroundImage: "var(--ds-pattern-sage)",
              }}
            >
              {beat.headline}
            </h3>
            <p
              className="font-jakarta mt-6 text-lg leading-relaxed text-[#6B6864]"
            >
              {beat.body}
            </p>
            <div className="mt-8 relative aspect-square w-full max-w-md mx-auto">
              <Image src={beat.image} alt="" fill className="object-contain" />
            </div>
          </div>
        ))}
      </div>
    </>
  );
}
