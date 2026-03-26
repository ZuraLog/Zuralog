"use client";

import { motion, useReducedMotion } from "framer-motion";
import { cn } from "@/lib/utils";

const VARIANT_FILES = {
  sage: "sage.png",
  crimson: "crimson.png",
  green: "green.png",
  periwinkle: "periwinkle.png",
  rose: "rose.png",
  amber: "amber.png",
  "sky-blue": "sky-blue.png",
  teal: "teal.png",
  purple: "purple.png",
  yellow: "yellow.png",
  original: "original.png",
  mint: "mint.png",
} as const;

type PatternVariant = keyof typeof VARIANT_FILES;

export interface PatternOverlayProps {
  variant: PatternVariant;
  opacity?: number;
  blend: "color-burn" | "screen";
  animate?: boolean;
  className?: string;
}

const DEFAULT_OPACITY: Record<PatternOverlayProps["blend"], number> = {
  "color-burn": 0.15,
  screen: 0.07,
};

export function PatternOverlay({
  variant,
  opacity,
  blend,
  animate = false,
  className,
}: PatternOverlayProps) {
  const prefersReducedMotion = useReducedMotion();
  const resolvedOpacity = opacity ?? DEFAULT_OPACITY[blend];
  const file = VARIANT_FILES[variant];
  const shouldAnimate = animate && !prefersReducedMotion;

  const style: React.CSSProperties = {
    backgroundImage: `url('/patterns/${file}')`,
    backgroundSize: "cover",
    backgroundPosition: "center",
    opacity: resolvedOpacity,
    mixBlendMode: blend,
  };

  if (shouldAnimate) {
    return (
      <motion.div
        aria-hidden="true"
        className={cn(
          "absolute inset-0 pointer-events-none rounded-[inherit]",
          className,
        )}
        style={style}
        animate={{ backgroundPosition: ["0% 0%", "100% 100%"] }}
        transition={{
          duration: 20,
          repeat: Infinity,
          ease: "linear",
        }}
      />
    );
  }

  return (
    <div
      aria-hidden="true"
      className={cn(
        "absolute inset-0 pointer-events-none rounded-[inherit]",
        className,
      )}
      style={style}
    />
  );
}
