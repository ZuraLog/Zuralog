"use client";

import { useRef, useEffect } from "react";
import gsap from "gsap";
import { SplitText } from "gsap/SplitText";

if (typeof window !== "undefined") {
  gsap.registerPlugin(SplitText);
}

/**
 * Rolling text demo — 1:1 port of the GreenSock CodePen dPMjJWv.
 * Four stacked copies of "ZuraLog" rotate on a 3D cylinder.
 * Each character gets the animated topographic pattern fill.
 */
export function RollingTextDemo() {
  const containerRef = useRef<HTMLDivElement>(null);
  const lineRefs = useRef<(HTMLHeadingElement | null)[]>([]);

  useEffect(() => {
    const container = containerRef.current;
    const lines = lineRefs.current.filter(Boolean) as HTMLElement[];
    if (!container || lines.length === 0) return;

    const prefersReducedMotion = window.matchMedia(
      "(prefers-reduced-motion: reduce)",
    ).matches;

    gsap.set(container, { visibility: "visible" });
    if (prefersReducedMotion) return;

    const splitLines = lines.map(
      (line) => new SplitText(line, { type: "chars", charsClass: "char" }),
    );

    // Apply pattern fill to each character
    splitLines.forEach((split) => {
      (split.chars as HTMLElement[]).forEach((charEl) => {
        charEl.style.backgroundImage = "url('/patterns/sage.png')";
        charEl.style.backgroundSize = "300px auto";
        charEl.style.backgroundRepeat = "repeat";
        charEl.style.backgroundClip = "text";
        charEl.style.webkitBackgroundClip = "text";
        charEl.style.color = "transparent";
        charEl.style.backfaceVisibility = "hidden";
      });
    });

    // 3D setup — match original CodePen
    const width = container.offsetWidth;
    const depth = -width / 8;
    const transformOrigin = `50% 50% ${depth}px`;

    gsap.set(lines, { perspective: 700, transformStyle: "preserve-3d" });

    const animTime = 0.9;
    const tl = gsap.timeline({ repeat: -1 });

    splitLines.forEach((split, index) => {
      tl.fromTo(
        split.chars,
        { rotationX: -90 },
        {
          rotationX: 90,
          stagger: 0.08,
          duration: animTime,
          ease: "none",
          transformOrigin,
        },
        index * 0.45,
      );
    });

    return () => {
      tl.kill();
      splitLines.forEach((s) => s.revert());
    };
  }, []);

  return (
    <div
      ref={containerRef}
      className="flex items-center justify-center w-full"
      style={{ visibility: "hidden", height: 110 }}
    >
      <div className="relative w-full" style={{ height: 110 }}>
        {[0, 1, 2, 3].map((i) => (
          <h1
            key={i}
            ref={(el) => {
              lineRefs.current[i] = el;
            }}
            className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 leading-none m-0 whitespace-nowrap text-center font-bold"
            style={{ fontSize: "clamp(3rem, 10cqw, 90px)", letterSpacing: "-0.06em" }}
          >
            ZuraLog
          </h1>
        ))}
      </div>
    </div>
  );
}
