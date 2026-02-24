/**
 * convergence-lines.tsx — animated SVG bezier paths from integrations to phone center.
 *
 * Each line is anchored to its integration card's CSS position (same polarToPercent
 * calculation as integration-cards.tsx). The SVG uses viewBox="0 0 100 100" with
 * preserveAspectRatio="none" so coordinates map 1:1 to viewport percentages.
 *
 * Mouse parallax: each line endpoint shifts by the same parallax offset applied to
 * the corresponding integration card, so the line visually stays anchored to the card.
 * The phone-center terminus (50%, 50%) shifts by a small fraction of mouse movement
 * to simulate the phone tilting in 3D space.
 */
"use client";

import { useMemo } from "react";
import { motion } from "framer-motion";
import {
  INTEGRATIONS,
  ORBIT_RADIUS_VW,
  type IntegrationItem,
} from "@/lib/integration-config";

/** Convert polar angle/distance to SVG viewBox % coordinates */
function polarToSvg(angleDeg: number, distance: number, radiusVw: number): { x: number; y: number } {
  const rad = (angleDeg * Math.PI) / 180;
  return {
    x: 50 + Math.cos(rad) * radiusVw * distance,
    y: 50 - Math.sin(rad) * radiusVw * distance,
  };
}

interface LineProps {
  item: IntegrationItem;
  index: number;
  mouseX: number;
  mouseY: number;
  reducedMotion: boolean;
  isMobile: boolean;
}

function ConvergenceLine({ item, index, mouseX, mouseY, reducedMotion, isMobile }: LineProps) {
  const radiusVw = isMobile ? 22 : ORBIT_RADIUS_VW;

  // The integration card's parallax strength (same formula as integration-cards.tsx)
  const parallaxStrength = reducedMotion ? 0 : 12 * item.distance;
  // Convert px offset → SVG % units (viewport width ≈ 100 SVG units wide)
  // We scale down by a factor — 1vw = 1 SVG unit, and parallaxStrength is in px.
  // At a typical 1440px wide screen, 1px ≈ 0.069 SVG units.
  // We'll use a simple approximation: divide by 14 to get SVG units.
  const cardOffsetX = (mouseX * parallaxStrength) / 14;
  const cardOffsetY = (-mouseY * parallaxStrength) / 14;

  // Phone center also shifts slightly (mimics the 3D tilt from hero-scene.tsx)
  const phoneOffsetX = reducedMotion ? 0 : mouseX * 1.5;
  const phoneOffsetY = reducedMotion ? 0 : -mouseY * 1.0;

  const base = polarToSvg(item.angle, item.distance, radiusVw);
  const start = {
    x: base.x + cardOffsetX,
    y: base.y + cardOffsetY,
  };
  const end = {
    x: 50 + phoneOffsetX,
    y: 50 + phoneOffsetY,
  };

  // Control point: pull perpendicular for organic curvature
  const midX = (start.x + end.x) / 2;
  const midY = (start.y + end.y) / 2;
  const dx = end.x - start.x;
  const dy = end.y - start.y;
  const perpX = -dy * 0.22;
  const perpY = dx * 0.22;
  const ctrl = { x: midX + perpX, y: midY + perpY };

  const d = `M ${start.x.toFixed(2)} ${start.y.toFixed(2)} Q ${ctrl.x.toFixed(2)} ${ctrl.y.toFixed(2)} ${end.x.toFixed(2)} ${end.y.toFixed(2)}`;

  return (
    <g key={item.id}>
      {/* Faint static base path */}
      <path
        d={d}
        fill="none"
        stroke="#CFE1B9"
        strokeWidth="0.15"
        strokeOpacity="0.12"
      />

      {!reducedMotion && (
        <>
          {/* Animated flowing dash */}
          <path
            d={d}
            fill="none"
            stroke="#CFE1B9"
            strokeWidth="0.12"
            strokeOpacity="0.35"
            strokeDasharray="1.5 3"
            strokeLinecap="round"
          >
            <animate
              attributeName="stroke-dashoffset"
              from="20"
              to="0"
              dur={`${3 + index * 0.5}s`}
              repeatCount="indefinite"
            />
          </path>

          {/* Traveling dot 1 */}
          <circle r="0.35" fill="#CFE1B9" opacity="0.6">
            <animateMotion
              dur={`${2.5 + index * 0.4}s`}
              repeatCount="indefinite"
              path={d}
            />
          </circle>

          {/* Traveling dot 2 (offset start) */}
          <circle r="0.22" fill="#CFE1B9" opacity="0.35">
            <animateMotion
              dur={`${3.2 + index * 0.3}s`}
              repeatCount="indefinite"
              path={d}
              begin={`${1.2 + index * 0.2}s`}
            />
          </circle>
        </>
      )}
    </g>
  );
}

interface ConvergenceLinesProps {
  mouseX: number;
  mouseY: number;
  isMobile: boolean;
  reducedMotion?: boolean;
}

export function ConvergenceLines({
  mouseX,
  mouseY,
  isMobile,
  reducedMotion = false,
}: ConvergenceLinesProps) {
  const integrations = isMobile ? INTEGRATIONS.slice(0, 3) : INTEGRATIONS;

  // Memoize only the static integration list — paths now recompute on every
  // mouseX/mouseY change (cheap math, no DOM) so we pass mouse directly to lines.
  const items = useMemo(() => integrations, [isMobile]); // eslint-disable-line react-hooks/exhaustive-deps

  return (
    <motion.div
      initial={{ opacity: reducedMotion ? 1 : 0 }}
      animate={{ opacity: 1 }}
      transition={reducedMotion ? { duration: 0 } : { delay: 1.2, duration: 1.0 }}
      className="pointer-events-none absolute inset-0"
    >
      <svg
        viewBox="0 0 100 100"
        preserveAspectRatio="none"
        className="absolute inset-0 h-full w-full"
        xmlns="http://www.w3.org/2000/svg"
        aria-hidden="true"
      >
        {items.map((item, i) => (
          <ConvergenceLine
            key={item.id}
            item={item}
            index={i}
            mouseX={mouseX}
            mouseY={mouseY}
            reducedMotion={reducedMotion}
            isMobile={isMobile}
          />
        ))}
      </svg>
    </motion.div>
  );
}
