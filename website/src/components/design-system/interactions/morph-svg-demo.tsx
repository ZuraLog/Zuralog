"use client";

import { useRef, useEffect, useState } from "react";
import gsap from "gsap";
import { MorphSVGPlugin } from "gsap/MorphSVGPlugin";

if (typeof window !== "undefined") {
  gsap.registerPlugin(MorphSVGPlugin);
}

/* ── Shape path data (300×300 viewBox) ──────────────────────────────── */

const shapes: Record<string, string> = {
  circle:
    "M150,30 C216.3,30 270,83.7 270,150 C270,216.3 216.3,270 150,270 C83.7,270 30,216.3 30,150 C30,83.7 83.7,30 150,30 Z",
  star:
    "M150,20 L178,108 L270,108 L196,162 L220,252 L150,198 L80,252 L104,162 L30,108 L122,108 Z",
  heart:
    "M150,60 C150,60 105,15 60,50 C15,85 15,145 60,195 C90,230 150,275 150,275 C150,275 210,230 240,195 C285,145 285,85 240,50 C195,15 150,60 150,60 Z",
  blob:
    "M150,25 C210,15 275,65 280,130 C285,195 245,260 185,275 C125,290 55,255 35,195 C15,135 55,55 110,30 C130,20 140,25 150,25 Z",
  hexagon:
    "M150,30 L255,82.5 L255,187.5 L150,240 L45,187.5 L45,82.5 Z",
};

const shapeOrder = ["circle", "star", "heart", "blob", "hexagon"] as const;

const shapeLabels: Record<string, string> = {
  circle: "Circle",
  star: "Star",
  heart: "Heart",
  blob: "Blob",
  hexagon: "Hexagon",
};

/**
 * Interactive SVG shape morphing demo powered by GSAP MorphSVGPlugin.
 *
 * The active shape is filled with the Sage topographic pattern via an
 * SVG `<pattern>` element. Click any shape button to trigger a smooth
 * morph transition.
 */
export function MorphSvgDemo() {
  const svgRef = useRef<SVGSVGElement>(null);
  const pathRef = useRef<SVGPathElement>(null);
  const [active, setActive] = useState<string>("circle");
  const tweenRef = useRef<gsap.core.Tween | null>(null);

  /* Morph to the selected shape */
  useEffect(() => {
    const path = pathRef.current;
    if (!path) return;

    // Kill any running morph so they don't stack
    tweenRef.current?.kill();

    tweenRef.current = gsap.to(path, {
      morphSVG: { shape: shapes[active], shapeIndex: "auto" },
      duration: 0.8,
      ease: "power2.inOut",
    });

    return () => {
      tweenRef.current?.kill();
    };
  }, [active]);

  /* Auto-play loop: cycle through shapes every 3 s */
  useEffect(() => {
    let idx = 0;
    const interval = setInterval(() => {
      idx = (idx + 1) % shapeOrder.length;
      setActive(shapeOrder[idx]);
    }, 3000);
    return () => clearInterval(interval);
  }, []);

  return (
    <div className="flex flex-col items-center gap-6">
      {/* SVG viewport */}
      <div className="relative w-full max-w-[300px] aspect-square">
        <svg
          ref={svgRef}
          viewBox="0 0 300 300"
          className="w-full h-full"
          xmlns="http://www.w3.org/2000/svg"
        >
          {/* Sage pattern fill definition */}
          <defs>
            <pattern
              id="sage-morph-pattern"
              patternUnits="userSpaceOnUse"
              width="300"
              height="300"
            >
              <image
                href="/patterns/sage.png"
                width="300"
                height="300"
                preserveAspectRatio="xMidYMid slice"
              />
            </pattern>
          </defs>

          {/* The morphing shape */}
          <path
            ref={pathRef}
            d={shapes.circle}
            fill="url(#sage-morph-pattern)"
            stroke="rgba(140,161,130,0.3)"
            strokeWidth="2"
          />
        </svg>
      </div>

      {/* Shape selector buttons */}
      <div className="flex flex-wrap justify-center gap-2">
        {shapeOrder.map((key) => (
          <button
            key={key}
            onClick={() => setActive(key)}
            className={`
              px-3 py-1.5 rounded-lg text-sm font-medium transition-all duration-200
              ${
                active === key
                  ? "bg-ds-sage/20 text-ds-sage ring-1 ring-ds-sage/30"
                  : "bg-ds-elevated text-ds-secondary hover:text-ds-primary hover:bg-ds-elevated/80"
              }
            `}
          >
            {shapeLabels[key]}
          </button>
        ))}
      </div>
    </div>
  );
}
