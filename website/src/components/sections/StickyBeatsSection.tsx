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
  const sectionRef = useRef<HTMLDivElement>(null);
  const isImageLeft = layout === "image-left";

  useEffect(() => {
    const section = sectionRef.current;
    if (!section) return;

    if (window.innerWidth < 768) return;

    const prefersReduced = window.matchMedia(
      "(prefers-reduced-motion: reduce)"
    ).matches;
    if (prefersReduced) return;

    const ctx = gsap.context(() => {
      const beatHeadlines = gsap.utils.toArray<HTMLElement>(
        ".beat-headline",
        section
      );
      const beatBodies = gsap.utils.toArray<HTMLElement>(
        ".beat-body",
        section
      );
      const beatImages = gsap.utils.toArray<HTMLElement>(
        ".beat-image",
        section
      );

      if (beatHeadlines.length !== beats.length) {
        if (process.env.NODE_ENV === "development") {
          console.warn(
            "[StickyBeatsSection] Headline count mismatch — animation skipped."
          );
        }
        return;
      }

      gsap.set(beatHeadlines,    { color: "#161618" });
      gsap.set(beatHeadlines[0], { color: "#344E41" });
      gsap.set(beatBodies,       { opacity: 0, y: 60 });
      gsap.set(beatBodies[0],    { opacity: 1, y: 0  });
      gsap.set(beatImages,       { opacity: 0, scale: 1.06 });
      gsap.set(beatImages[0],    { opacity: 1, scale: 1    });

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

      beats.forEach((_, i) => tl.addLabel("beat" + i, i));

      for (let i = 0; i < beats.length - 1; i++) {
        const label = "beat" + i;

        tl.to(
          beatBodies[i],
          { opacity: 0, y: -60, duration: 0.4, ease: "power3.in" },
          label + "+=0.10"
        );
        tl.to(
          beatImages[i],
          { opacity: 0, duration: 0.45, ease: "power2.inOut" },
          label + "+=0.10"
        );
        tl.to(
          beatHeadlines[i],
          { color: "#161618", duration: 0.3, ease: "power2.inOut" },
          label + "+=0.20"
        );
        tl.to(
          beatHeadlines[i + 1],
          { color: "#344E41", duration: 0.3, ease: "power2.inOut" },
          label + "+=0.35"
        );
        tl.to(
          beatBodies[i + 1],
          { opacity: 1, y: 0, duration: 0.5, ease: "power3.out" },
          label + "+=0.40"
        );
        tl.to(
          beatImages[i + 1],
          { opacity: 1, scale: 1, duration: 0.55, ease: "power2.out" },
          label + "+=0.35"
        );
      }

      tl.to({}, { duration: 0.5 }, "beat" + (beats.length - 1));
    }, sectionRef);

    return () => ctx.revert();
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  return (
    <>
      {/* Desktop */}
      <section
        ref={sectionRef}
        id={id}
        className="hidden md:flex relative min-h-screen overflow-hidden items-center"
      >
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
            {beats.map((beat, i) => (
              <h2
                key={i}
                className="beat-headline font-bold uppercase tracking-tighter leading-[0.85]"
                style={{
                  fontSize: "clamp(3rem, 8.5vw, 10.5rem)",
                  color: i === 0 ? "#344E41" : "#161618",
                }}
              >
                {beat.headline}
              </h2>
            ))}

            <div className="relative mt-10 max-w-xl">
              <p
                className="invisible pointer-events-none text-xl md:text-2xl leading-relaxed"
                aria-hidden="true"
              >
                {beats[0].body}
              </p>
              {beats.map((beat, i) => (
                <p
                  key={i}
                  className="beat-body absolute top-0 left-0 right-0 text-xl md:text-2xl leading-relaxed text-[#6B6864]"
                  style={{
                    opacity: i === 0 ? 1 : 0,
                    transform: `translateY(${i === 0 ? 0 : 60}px)`,
                  }}
                >
                  {beat.body}
                </p>
              ))}
            </div>
          </div>
        </div>
      </section>

      {/* Mobile */}
      <div id={`${id}-mobile`} className="md:hidden">
        {beats.map((beat, i) => (
          <div key={i} className="py-16 px-8">
            <h3
              className="font-bold uppercase tracking-tighter leading-[0.85]"
              style={{
                fontSize: "clamp(2.5rem, 10vw, 4rem)",
                color: "#344E41",
              }}
            >
              {beat.headline}
            </h3>
            <p
              className="mt-6 text-lg leading-relaxed"
              style={{ color: "#6B6864" }}
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
