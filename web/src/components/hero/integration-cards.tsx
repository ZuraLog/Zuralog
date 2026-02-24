/**
 * IntegrationCards — floating HTML/CSS cards with real app logos.
 *
 * Positioned absolutely over the 3D canvas using polar-to-% coordinate conversion.
 * Each card reacts to mouse movement via CSS transform parallax.
 * Cards are driven by the INTEGRATIONS config — add an entry there to add a card.
 */
"use client";

import { motion } from "framer-motion";
import {
  SiStrava,
  SiApple,
  SiGoogle,
  SiGarmin,
} from "@icons-pack/react-simple-icons";
import { INTEGRATIONS, ORBIT_RADIUS_VW, type IntegrationItem } from "@/lib/integration-config";

/** Render the appropriate brand icon for a given integration */
function IntegrationIcon({ item, size }: { item: IntegrationItem; size: number }) {
  const props = { size, color: item.color };

  switch (item.iconKey) {
    case "SiStrava":  return <SiStrava {...props} />;
    case "SiApple":   return <SiApple {...props} />;
    case "SiGoogle":  return <SiGoogle {...props} />;
    case "SiGarmin":  return <SiGarmin {...props} />;
    default:
      // Letter badge fallback for brands without a Simple Icons entry (e.g. Oura)
      return (
        <span
          className="flex items-center justify-center rounded-lg font-bold"
          style={{
            width: size,
            height: size,
            backgroundColor: item.color,
            color: "#000",
            fontSize: size * 0.5,
          }}
        >
          {item.iconKey}
        </span>
      );
  }
}

/** Convert polar angle/distance config to viewport-% CSS position */
function polarToPercent(angleDeg: number, distance: number) {
  const rad = (angleDeg * Math.PI) / 180;
  const x = 50 + Math.cos(rad) * ORBIT_RADIUS_VW * distance;
  const y = 50 - Math.sin(rad) * ORBIT_RADIUS_VW * distance;
  return { x, y };
}

interface IntegrationCardProps {
  item: IntegrationItem;
  mouseX: number;
  mouseY: number;
  index: number;
}

function IntegrationCard({ item, mouseX, mouseY, index }: IntegrationCardProps) {
  const { x, y } = polarToPercent(item.angle, item.distance);

  // Cards farther from center have stronger parallax
  const parallaxStrength = 12 * item.distance;
  const offsetX = mouseX * parallaxStrength;
  const offsetY = -mouseY * parallaxStrength;

  const baseSize = 64 * item.scale;
  const iconSize = Math.round(24 * item.scale);

  return (
    <motion.div
      initial={{ opacity: 0, scale: 0.6 }}
      animate={{ opacity: 1, scale: 1 }}
      transition={{ delay: 0.8 + index * 0.15, duration: 0.6, ease: "easeOut" }}
      className="absolute flex flex-col items-center gap-1.5 pointer-events-none select-none"
      style={{
        left: `${x}%`,
        top: `${y}%`,
        transform: `translate(-50%, -50%) translate(${offsetX}px, ${offsetY}px)`,
        willChange: "transform",
      }}
    >
      {/* Glassmorphic card */}
      <div
        className="flex items-center justify-center rounded-2xl border border-white/10 bg-white/5 backdrop-blur-md"
        style={{
          width: baseSize,
          height: baseSize,
          boxShadow: `0 0 20px ${item.color}15, 0 8px 32px rgba(0,0,0,0.3)`,
        }}
      >
        <IntegrationIcon item={item} size={iconSize} />
      </div>
      {/* Integration label */}
      <span
        className="text-center font-medium tracking-wide text-white/60 whitespace-nowrap"
        style={{ fontSize: Math.max(9, 10 * item.scale) }}
      >
        {item.label}
      </span>
    </motion.div>
  );
}

interface IntegrationCardsProps {
  /** Normalized mouse X in range [-1, 1] */
  mouseX: number;
  /** Normalized mouse Y in range [-1, 1] */
  mouseY: number;
  isMobile: boolean;
}

export function IntegrationCards({ mouseX, mouseY, isMobile }: IntegrationCardsProps) {
  // Show fewer integrations on mobile to avoid clutter
  const visible = isMobile ? INTEGRATIONS.slice(0, 3) : INTEGRATIONS;

  return (
    <div className="absolute inset-0 overflow-hidden pointer-events-none">
      {visible.map((item, i) => (
        <IntegrationCard
          key={item.id}
          item={item}
          mouseX={mouseX}
          mouseY={mouseY}
          index={i}
        />
      ))}
    </div>
  );
}
