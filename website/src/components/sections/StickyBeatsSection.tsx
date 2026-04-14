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
}

// ---------------------------------------------------------------------------
// StickyBeatsSection
// ---------------------------------------------------------------------------

export function StickyBeatsSection({ id, beats }: StickyBeatsSectionProps) {
  const sectionRef = useRef<HTMLElement>(null);

  useEffect(() => {
    const section = sectionRef.current;
    if (!section) return;
    if (window.innerWidth < 768) return;
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;

    const ctx = gsap.context(() => {
      const beatRows = gsap.utils.toArray<HTMLElement>(".beat-row", section);
      const beatImages = gsap.utils.toArray<HTMLElement>(".beat-image", section);
      const beatBodies = gsap.utils.toArray<HTMLElement>(".beat-body", section);
      const beatHeadlines = gsap.utils.toArray<HTMLElement>(".beat-headline", section);

      if (beatRows.length !== beats.length) return;

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

      beats.forEach((_, i) => {
        tl.addLabel("beat" + i, i);
      });

      for (let i = 0; i < beats.length - 1; i++) {
        const label = "beat" + i;
        // Outgoing dims
        tl.to(beatRows[i], { opacity: 0.2, duration: 0.5, ease: "power2.inOut" }, label + "+=0.2");
        tl.to(beatHeadlines[i], { color: "#161618", duration: 0.5, ease: "power2.inOut" }, label + "+=0.2");
        tl.to(beatBodies[i], { opacity: 0, duration: 0.4, ease: "power2.in" }, label + "+=0.2");
        // Incoming activates
        tl.to(beatRows[i + 1], { opacity: 1, duration: 0.5, ease: "power2.inOut" }, label + "+=0.4");
        tl.to(beatHeadlines[i + 1], { color: "#344E41", duration: 0.5, ease: "power2.inOut" }, label + "+=0.4");
        tl.to(beatBodies[i + 1], { opacity: 1, duration: 0.4, ease: "power2.out" }, label + "+=0.5");
        // Image crossfade
        tl.to(beatImages[i], { opacity: 0, duration: 0.5, ease: "power2.inOut" }, label + "+=0.25");
        tl.to(beatImages[i + 1], { opacity: 1, duration: 0.5, ease: "power2.inOut" }, label + "+=0.35");
      }
    }, sectionRef);

    return () => ctx.revert();
  }, [beats]);

  return (
    <>
      {/* ── Desktop layout ─────────────────────────────────────────────────── */}
      <section
        ref={sectionRef}
        id={id}
        className="hidden md:grid grid-cols-12 min-h-screen overflow-hidden"
      >
        {/* Left column — scrolling beat list */}
        <div className="col-span-5 flex flex-col justify-center px-12 lg:px-20 py-16">
          {beats.map((beat, i) => (
            <div
              key={i}
              className={`beat-row${i > 0 ? " mt-10" : ""}`}
              data-beat={i}
              style={{ opacity: i === 0 ? 1 : 0.2 }}
            >
              <h3
                className="beat-headline font-bold uppercase tracking-tighter leading-[0.88]"
                style={{
                  fontSize: "clamp(2.5rem, 5.5vw, 6.5rem)",
                  color: i === 0 ? "#344E41" : "#161618",
                }}
              >
                {beat.headline}
              </h3>
              <p
                className="beat-body mt-3 text-lg md:text-xl leading-relaxed"
                style={{ color: "#6B6864", opacity: i === 0 ? 1 : 0 }}
              >
                {beat.body}
              </p>
            </div>
          ))}
        </div>

        {/* Right column — stacked images */}
        <div className="col-span-7 relative flex items-center justify-center">
          <div className="relative w-full aspect-square">
            {beats.map((beat, i) => (
              <div
                key={i}
                className="beat-image absolute inset-0"
                style={{ opacity: i === 0 ? 1 : 0 }}
              >
                <Image
                  src={beat.image}
                  alt=""
                  fill
                  className="object-contain"
                />
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* ── Mobile layout ──────────────────────────────────────────────────── */}
      <div id={`${id}-mobile`} className="md:hidden">
        {beats.map((beat, i) => (
          <div key={i} className="py-16 px-8">
            <h3
              className="font-bold uppercase tracking-tighter leading-[0.88]"
              style={{
                fontSize: "clamp(2.5rem, 10vw, 4rem)",
                color: "#344E41",
              }}
            >
              {beat.headline}
            </h3>
            <p
              className="mt-3 text-lg leading-relaxed"
              style={{ color: "#6B6864" }}
            >
              {beat.body}
            </p>
            <div className="mt-8 relative aspect-square w-full max-w-md mx-auto">
              <Image
                src={beat.image}
                alt=""
                fill
                className="object-contain"
              />
            </div>
          </div>
        ))}
      </div>
    </>
  );
}
