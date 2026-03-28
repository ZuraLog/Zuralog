"use client";

import { useRef, useEffect, useState } from "react";
import gsap from "gsap";
import { MorphSVGPlugin } from "gsap/MorphSVGPlugin";
import { useBrandBibleThemeOptional } from "@/components/design-system/interactions/brand-bible-theme";

if (typeof window !== "undefined") {
  gsap.registerPlugin(MorphSVGPlugin);
}

const PATH_START = "M 0 100 V 100 Q 50 100 100 100 V 100 z";
const PATH_MID = "M 0 100 V 50 Q 50 0 100 50 V 100 z";
const PATH_END = "M 0 100 V 0 Q 50 0 100 0 V 100 z";

/**
 * MorphSVG curve manipulation demo.
 *
 * Click the container to toggle a curved SVG shape that sweeps up from
 * the bottom with a bowed curve, then flattens to cover everything.
 * Text colour flips as the curve covers the surface — dark text on sage
 * fill in dark mode, light text on deep-forest fill in light mode.
 */
export function MorphCurveDemo() {
  const pathRef = useRef<SVGPathElement>(null);
  const tlRef = useRef<gsap.core.Timeline | null>(null);
  const labelRef = useRef<HTMLParagraphElement>(null);
  const [open, setOpen] = useState(false);
  const themeCtx = useBrandBibleThemeOptional();
  const isLight = themeCtx?.isLight ?? false;

  // Theme-aware colours
  const initialTextColor = isLight ? "#161618" : "#F0EEE9";
  const revealedTextColor = isLight ? "#E8EDE0" : "#1A2E22";
  const gradStart = isLight ? "#344E41" : "#CFE1B9";
  const gradEnd = isLight ? "#2D4537" : "#8CA182";

  useEffect(() => {
    const path = pathRef.current;
    const label = labelRef.current;
    if (!path || !label) return;

    // Reset open state and label colour whenever theme switches
    setOpen(false);
    gsap.set(path, { morphSVG: PATH_START });
    gsap.set(label, { color: initialTextColor });

    const tl = gsap.timeline({ paused: true });

    tl.to(path, {
      morphSVG: PATH_MID,
      duration: 0.4,
      ease: "power2.in",
    }).to(path, {
      morphSVG: PATH_END,
      duration: 0.4,
      ease: "power2.out",
    });

    // Flip label colour halfway through the sweep
    tl.to(
      label,
      { color: revealedTextColor, duration: 0.2, ease: "power2.inOut" },
      0.3,
    );

    tlRef.current = tl;

    return () => {
      tl.kill();
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [isLight]);

  const toggle = () => {
    const tl = tlRef.current;
    if (!tl) return;

    if (open) {
      tl.reverse();
    } else {
      tl.play();
    }
    setOpen(!open);
  };

  return (
    <div
      onClick={toggle}
      className="relative rounded-xl overflow-hidden cursor-pointer select-none bg-ds-canvas"
      style={{ height: 240 }}
    >
      {/* Label — sits above everything */}
      <div className="absolute inset-0 flex items-center justify-center z-30">
        <p
          ref={labelRef}
          className="text-sm font-medium"
          style={{ color: initialTextColor }}
        >
          {open ? "Click to close" : "Click to reveal"}
        </p>
      </div>

      {/* SVG curve overlay */}
      <svg
        viewBox="0 0 100 100"
        preserveAspectRatio="xMidYMin slice"
        className="absolute inset-0 w-full h-full z-20 pointer-events-none"
      >
        <defs>
          <linearGradient
            id="morph-curve-grad"
            x1="0"
            y1="0"
            x2="99"
            y2="99"
            gradientUnits="userSpaceOnUse"
          >
            <stop offset="0.2" stopColor={gradStart} />
            <stop offset="0.7" stopColor={gradEnd} />
          </linearGradient>
        </defs>
        <path
          ref={pathRef}
          stroke="url(#morph-curve-grad)"
          fill="url(#morph-curve-grad)"
          strokeWidth="2px"
          vectorEffect="non-scaling-stroke"
          d={PATH_START}
        />
      </svg>
    </div>
  );
}
