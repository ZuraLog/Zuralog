"use client";

import { useRef, useEffect } from "react";
import gsap from "gsap";

/**
 * A thin decorative line that draws outward from its centre when it
 * scrolls into view. Uses the sage topographic pattern as its texture.
 *
 * Drop this between major section groups on the brand bible page to
 * create visual breathing room.
 */
export function ScrollDivider() {
  const containerRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const el = containerRef.current;
    if (!el) return;

    const line = el.querySelector<HTMLDivElement>("[data-scroll-line]");
    if (!line) return;

    // Respect reduced-motion — show the line immediately.
    const prefersReducedMotion = window.matchMedia(
      "(prefers-reduced-motion: reduce)",
    ).matches;

    if (prefersReducedMotion) {
      gsap.set(line, { scaleX: 1 });
      return;
    }

    gsap.set(line, { scaleX: 0 });

    const tween = gsap.to(line, {
      scaleX: 1,
      duration: 0.8,
      ease: "power2.inOut",
      scrollTrigger: {
        trigger: el,
        start: "top 85%",
        toggleActions: "play none none none",
      },
    });

    return () => {
      tween.scrollTrigger?.kill();
      tween.kill();
    };
  }, []);

  return (
    <div ref={containerRef} className="my-16 flex justify-center">
      <div
        data-scroll-line
        className="h-px w-full max-w-[200px] ds-pattern-drift origin-center"
        style={{ backgroundImage: "url('/patterns/sage.png')" }}
      />
    </div>
  );
}
