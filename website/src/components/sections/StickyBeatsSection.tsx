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
      const beatRows = gsap.utils.toArray<HTMLElement>(".beat-row", section);
      const beatImages = gsap.utils.toArray<HTMLElement>(".beat-image", section);

      if (beatRows.length !== beats.length) {
        if (process.env.NODE_ENV === "development") {
          console.warn("[StickyBeatsSection] Beat row count mismatch — animation skipped.");
        }
        return;
      }

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
        tl.to(beatRows[i], { opacity: 0, duration: 0.5, ease: "power2.inOut" }, label + "+=0.2");
        tl.to(beatRows[i + 1], { opacity: 1, duration: 0.5, ease: "power2.inOut" }, label + "+=0.3");
        tl.to(beatImages[i], { opacity: 0, duration: 0.5, ease: "power2.inOut" }, label + "+=0.2");
        tl.to(beatImages[i + 1], { opacity: 1, duration: 0.5, ease: "power2.inOut" }, label + "+=0.3");
      }

      // Ensure timeline reaches the last label so snap has room to complete
      tl.to({}, { duration: 0.5 }, "beat" + (beats.length - 1));
    }, sectionRef);

    return () => ctx.revert();
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  return (
    <>
      {/* ── Desktop layout ─────────────────────────────────────────────────── */}
      <section
        ref={sectionRef}
        id={id}
        className="hidden md:flex relative min-h-screen overflow-hidden items-center"
      >
        {/* Image — absolute, behind text */}
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
                style={{ opacity: i === 0 ? 1 : 0 }}
              />
            ))}
          </div>
        </div>

        {/* Text — z-10 overlapping image */}
        <div className={`relative z-10 w-full flex ${isImageLeft ? "justify-end" : "justify-start"}`}>
          <div
            className={`w-full max-w-[70%] ${
              isImageLeft
                ? "pl-8 md:pl-16 pr-10 md:pr-16 lg:pr-24"
                : "pl-10 md:pl-16 lg:pl-24 pr-8 md:pr-16"
            }`}
          >
            <div className="relative">
              {/* Ghost beat — invisible, sets container height */}
              <div className="invisible pointer-events-none py-24" aria-hidden>
                <h2
                  className="font-bold uppercase tracking-tighter leading-[0.85]"
                  style={{ fontSize: "clamp(3rem, 8.5vw, 10.5rem)" }}
                >
                  {beats[0].headline}
                </h2>
                <p className="mt-10 text-xl md:text-2xl leading-relaxed max-w-xl">
                  {beats[0].body}
                </p>
              </div>

              {/* Beats — absolute, crossfade in place */}
              {beats.map((beat, i) => (
                <div
                  key={i}
                  className="beat-row absolute inset-0 py-24"
                  style={{ opacity: i === 0 ? 1 : 0 }}
                >
                  <h2
                    className="beat-headline font-bold uppercase tracking-tighter leading-[0.85] text-[#161618]"
                    style={{ fontSize: "clamp(3rem, 8.5vw, 10.5rem)" }}
                  >
                    {beat.headline}
                  </h2>
                  <p className="beat-body mt-10 text-xl md:text-2xl leading-relaxed text-[#6B6864] max-w-xl">
                    {beat.body}
                  </p>
                </div>
              ))}
            </div>
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
