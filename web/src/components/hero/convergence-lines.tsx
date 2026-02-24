/**
 * convergence-lines.tsx — animated SVG bezier paths from integrations to phone center.
 *
 * Each integration has a curved path drawn from its polar position to the
 * viewport center (where the phone sits). Animated dashes and traveling dots
 * show "data flowing in" — communicating ZuraLog's core hub concept.
 *
 * Uses pure SVG SMIL animations (no JS per frame) for GPU-composited performance.
 */
"use client";

import { useMemo } from "react";
import { motion } from "framer-motion";
import {
  INTEGRATIONS,
  ORBIT_RADIUS_VW,
  type IntegrationItem,
} from "@/lib/integration-config";

/** Convert polar angle/distance to SVG viewBox coordinates (0–100 space) */
function polarToSvg(angleDeg: number, distance: number): { x: number; y: number } {
  const rad = (angleDeg * Math.PI) / 180;
  const x = 50 + Math.cos(rad) * ORBIT_RADIUS_VW * distance;
  const y = 50 - Math.sin(rad) * ORBIT_RADIUS_VW * distance;
  return { x, y };
}

/** Generate a smooth quadratic bezier from integration to phone center */
function makePath(item: IntegrationItem): string {
  const start = polarToSvg(item.angle, item.distance);
  const end = { x: 50, y: 50 };

  // Control point: pull perpendicular to the direct line for organic curvature
  const midX = (start.x + end.x) / 2;
  const midY = (start.y + end.y) / 2;
  const dx = end.x - start.x;
  const dy = end.y - start.y;
  const perpX = -dy * 0.25;
  const perpY = dx * 0.25;

  return `M ${start.x.toFixed(2)} ${start.y.toFixed(2)} Q ${(midX + perpX).toFixed(2)} ${(midY + perpY).toFixed(2)} ${end.x} ${end.y}`;
}

interface ConvergenceLinesProps {
  /** Normalized mouse X in range [-1, 1] */
  mouseX: number;
  /** Normalized mouse Y in range [-1, 1] */
  mouseY: number;
  isMobile: boolean;
}

export function ConvergenceLines({
  mouseX,
  mouseY,
  isMobile,
}: ConvergenceLinesProps) {
  const integrations = isMobile ? INTEGRATIONS.slice(0, 3) : INTEGRATIONS;

  const paths = useMemo(
    () => integrations.map((item) => ({ item, d: makePath(item) })),
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [isMobile],
  );

  // Subtle parallax: the whole SVG shifts slightly with mouse
  const parallaxX = mouseX * 3;
  const parallaxY = -mouseY * 3;

  return (
    <motion.div
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      transition={{ delay: 1.2, duration: 1.0 }}
      className="absolute inset-0 pointer-events-none"
      style={{
        transform: `translate(${parallaxX}px, ${parallaxY}px)`,
        willChange: "transform",
      }}
    >
      <svg
        viewBox="0 0 100 100"
        preserveAspectRatio="none"
        className="absolute inset-0 h-full w-full"
        xmlns="http://www.w3.org/2000/svg"
        aria-hidden="true"
      >
        {paths.map(({ item, d }, i) => (
          <g key={item.id}>
            {/* Static faint background path */}
            <path
              d={d}
              fill="none"
              stroke="#CFE1B9"
              strokeWidth="0.15"
              strokeOpacity="0.1"
            />

            {/* Animated dashed flow path — dashes move toward center */}
            <path
              d={d}
              fill="none"
              stroke="#CFE1B9"
              strokeWidth="0.12"
              strokeOpacity="0.3"
              strokeDasharray="1.5 3"
              strokeLinecap="round"
            >
              <animate
                attributeName="stroke-dashoffset"
                from="20"
                to="0"
                dur={`${3 + i * 0.5}s`}
                repeatCount="indefinite"
              />
            </path>

            {/* Primary traveling dot particle */}
            <circle r="0.3" fill="#CFE1B9" opacity="0.55">
              <animateMotion
                dur={`${2.5 + i * 0.4}s`}
                repeatCount="indefinite"
                path={d}
              />
            </circle>

            {/* Secondary staggered dot particle */}
            <circle r="0.2" fill="#CFE1B9" opacity="0.3">
              <animateMotion
                dur={`${3.2 + i * 0.3}s`}
                repeatCount="indefinite"
                path={d}
                begin={`${1.2 + i * 0.2}s`}
              />
            </circle>
          </g>
        ))}
      </svg>
    </motion.div>
  );
}
