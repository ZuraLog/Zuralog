"use client";

import { useRef, useEffect, useState } from "react";
import gsap from "gsap";
import { MorphSVGPlugin } from "gsap/MorphSVGPlugin";

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
 * Text colour flips from white (dark bg) to dark (sage bg) as the
 * curve covers the surface.
 */
export function MorphCurveDemo() {
  const pathRef = useRef<SVGPathElement>(null);
  const tlRef = useRef<gsap.core.Timeline | null>(null);
  const labelRef = useRef<HTMLParagraphElement>(null);
  const [open, setOpen] = useState(false);

  useEffect(() => {
    const path = pathRef.current;
    const label = labelRef.current;
    if (!path || !label) return;

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
      { color: "#1A2E22", duration: 0.2, ease: "power2.inOut" },
      0.3,
    );

    tlRef.current = tl;

    return () => {
      tl.kill();
    };
  }, []);

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
          style={{ color: "#F0EEE9" }}
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
            <stop offset="0.2" stopColor="#CFE1B9" />
            <stop offset="0.7" stopColor="#8CA182" />
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
