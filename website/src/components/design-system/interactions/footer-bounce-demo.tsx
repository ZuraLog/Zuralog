"use client";

import { useRef, useEffect } from "react";
import gsap from "gsap";
import { ScrollTrigger } from "gsap/ScrollTrigger";
import { MorphSVGPlugin } from "gsap/MorphSVGPlugin";

if (typeof window !== "undefined") {
  gsap.registerPlugin(ScrollTrigger, MorphSVGPlugin);
}

/* ── SVG path shapes for the wave edge ──────────────────────────────── */

/** Resting state — gentle curve at the top of the "footer" */
const RESTING =
  "M0,30 C200,30 400,30 600,30 C800,30 1000,30 1200,30 L1200,120 L0,120 Z";

/** Stretched state — deep curve that exaggerates the bounce */
const STRETCHED =
  "M0,90 C200,0 400,0 600,0 C800,0 1000,0 1200,90 L1200,120 L0,120 Z";

/**
 * Demonstrates a footer-style wave edge that bounces with elastic energy
 * based on scroll velocity. The faster you scroll into view, the bigger
 * the bounce. The wave is filled with the Sage topographic pattern.
 *
 * Scroll down to the demo container to see it fire.
 */
export function FooterBouncDemo() {
  const containerRef = useRef<HTMLDivElement>(null);
  const pathRef = useRef<SVGPathElement>(null);
  const triggerRef = useRef<ScrollTrigger | null>(null);

  useEffect(() => {
    const container = containerRef.current;
    const path = pathRef.current;
    if (!container || !path) return;

    // Respect reduced-motion
    const prefersReducedMotion = window.matchMedia(
      "(prefers-reduced-motion: reduce)",
    ).matches;

    if (prefersReducedMotion) {
      gsap.set(path, { attr: { d: RESTING } });
      return;
    }

    // Start with the resting shape
    gsap.set(path, { attr: { d: RESTING } });

    triggerRef.current = ScrollTrigger.create({
      trigger: container,
      start: "top 90%",
      onEnter: (self) => {
        const velocity = Math.abs(self.getVelocity());
        // Map velocity to bounce intensity (0.1 to 0.9)
        const intensity = Math.min(velocity / 3000, 0.9);
        const amplitude = 1 + intensity;
        const period = Math.max(0.2, 1 - intensity);

        gsap
          .timeline()
          .set(path, {
            morphSVG: { shape: STRETCHED, shapeIndex: "auto" },
          })
          .to(path, {
            morphSVG: { shape: RESTING, shapeIndex: "auto" },
            duration: 1.4,
            ease: `elastic.out(${amplitude}, ${period})`,
          });
      },
      onLeaveBack: () => {
        // Reset when scrolling back up so the effect can re-trigger
        gsap.set(path, { morphSVG: { shape: RESTING } });
      },
    });

    return () => {
      triggerRef.current?.kill();
    };
  }, []);

  /** Manual replay for users who want to see it again without scrolling */
  const replay = () => {
    const path = pathRef.current;
    if (!path) return;

    gsap
      .timeline()
      .set(path, {
        morphSVG: { shape: STRETCHED, shapeIndex: "auto" },
      })
      .to(path, {
        morphSVG: { shape: RESTING, shapeIndex: "auto" },
        duration: 1.4,
        ease: "elastic.out(1.6, 0.3)",
      });
  };

  return (
    <div className="flex flex-col gap-4">
      {/* The bounce demo container */}
      <div
        ref={containerRef}
        className="relative rounded-xl overflow-hidden bg-ds-canvas"
      >
        {/* Content above the wave — simulates page content */}
        <div className="h-20 flex items-center justify-center">
          <span className="text-sm text-ds-secondary">
            ↑ Scroll speed affects bounce intensity
          </span>
        </div>

        {/* The wave SVG */}
        <svg
          viewBox="0 0 1200 120"
          preserveAspectRatio="none"
          className="w-full h-16 block"
          xmlns="http://www.w3.org/2000/svg"
        >
          <defs>
            <pattern
              id="sage-bounce-pattern"
              patternUnits="userSpaceOnUse"
              width="600"
              height="120"
            >
              <image
                href="/patterns/sage.png"
                width="600"
                height="120"
                preserveAspectRatio="xMidYMid slice"
              />
            </pattern>
          </defs>
          <path
            ref={pathRef}
            d={RESTING}
            fill="url(#sage-bounce-pattern)"
          />
        </svg>

        {/* Footer content below the wave */}
        <div className="bg-ds-sage/10 px-6 py-8 text-center">
          <p className="text-sm font-medium text-ds-sage">
            Zuralog &middot; Your Health, Unified
          </p>
        </div>
      </div>

      {/* Manual replay button */}
      <button
        onClick={replay}
        className="self-center px-3 py-1.5 rounded-lg text-sm font-medium bg-ds-elevated text-ds-secondary hover:text-ds-primary hover:bg-ds-elevated/80 transition-all duration-200"
      >
        Replay Bounce
      </button>
    </div>
  );
}
