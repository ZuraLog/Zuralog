"use client";

import { useEffect, useRef } from "react";
import { cva, type VariantProps } from "class-variance-authority";
import { cn } from "@/lib/utils";
import gsap from "gsap";
import { PatternOverlay } from "@/components/design-system/primitives/pattern-overlay";

/* ------------------------------------------------------------------ */
/*  Category → pattern variant mapping                                 */
/* ------------------------------------------------------------------ */

const CATEGORY_PATTERN = {
  activity: "green",
  sleep: "periwinkle",
  heart: "rose",
  nutrition: "amber",
  body: "sky-blue",
  vitals: "teal",
  wellness: "purple",
  cycle: "rose",
  mobility: "yellow",
  environment: "teal",
} as const;

type Category = keyof typeof CATEGORY_PATTERN;

/* ------------------------------------------------------------------ */
/*  CVA variants                                                       */
/* ------------------------------------------------------------------ */

const cardVariants = cva(
  "relative overflow-hidden bg-ds-surface",
  {
    variants: {
      elevation: {
        standard: "rounded-ds-lg p-ds-md-plus",
        hero: "rounded-ds-lg p-ds-md-plus",
        feature: "rounded-ds-lg p-ds-md-plus",
        data: "rounded-ds-md p-ds-md",
      },
    },
    defaultVariants: {
      elevation: "standard",
    },
  },
);

/* ------------------------------------------------------------------ */
/*  Props                                                              */
/* ------------------------------------------------------------------ */

export interface CardProps
  extends VariantProps<typeof cardVariants> {
  elevation?: "standard" | "hero" | "feature" | "data";
  category?: Category;
  as?: "div" | "article" | "section";
  className?: string;
  children: React.ReactNode;
  /** Disable the 3D tilt effect on this card */
  noTilt?: boolean;
}

/* ------------------------------------------------------------------ */
/*  Component                                                          */
/* ------------------------------------------------------------------ */

export function Card({
  elevation = "standard",
  category,
  as: Tag = "div",
  className,
  children,
  noTilt = false,
}: CardProps) {
  const cardRef = useRef<HTMLDivElement>(null);

  const showHeroPattern = elevation === "hero";
  const showFeaturePattern = elevation === "feature";

  const featureVariant =
    category && CATEGORY_PATTERN[category]
      ? CATEGORY_PATTERN[category]
      : "original";

  // 3D tilt effect — applied to all cards unless noTilt is set
  useEffect(() => {
    const el = cardRef.current;
    if (!el || noTilt) return;
    if (typeof window === "undefined") return;
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;
    if (!window.matchMedia("(pointer: fine)").matches) return;

    let rafId = 0;

    const onMove = (e: MouseEvent) => {
      cancelAnimationFrame(rafId);
      rafId = requestAnimationFrame(() => {
        const rect = el.getBoundingClientRect();
        const cx = rect.left + rect.width / 2;
        const cy = rect.top + rect.height / 2;
        const dx = (e.clientX - cx) / (rect.width / 2);
        const dy = (e.clientY - cy) / (rect.height / 2);

        // Scale tilt inversely with card size so all cards feel the same.
        // Small cards (~150px) get up to 10deg, large (~900px) get ~2deg.
        const diagonal = Math.sqrt(rect.width ** 2 + rect.height ** 2);
        const maxTilt = Math.max(2, Math.min(10, 1200 / diagonal));

        gsap.to(el, {
          rotateY: dx * maxTilt,
          rotateX: -dy * maxTilt,
          transformPerspective: 800,
          duration: 0.4,
          ease: "power2.out",
          overwrite: "auto",
        });
      });
    };

    const onLeave = () => {
      cancelAnimationFrame(rafId);
      gsap.to(el, {
        rotateY: 0,
        rotateX: 0,
        scale: 1,
        duration: 0.7,
        ease: "elastic.out(1, 0.4)",
        overwrite: "auto",
      });
    };

    el.addEventListener("mousemove", onMove);
    el.addEventListener("mouseleave", onLeave);

    return () => {
      cancelAnimationFrame(rafId);
      gsap.killTweensOf(el);
      el.removeEventListener("mousemove", onMove);
      el.removeEventListener("mouseleave", onLeave);
    };
  }, [noTilt]);

  return (
    <Tag
      ref={cardRef as React.Ref<HTMLDivElement>}
      className={cn(cardVariants({ elevation }), className)}
      style={{ willChange: "transform", transformStyle: "preserve-3d" }}
    >
      {showHeroPattern && (
        <PatternOverlay variant="original" opacity={0.18} blend="screen" />
      )}

      {showFeaturePattern && (
        <PatternOverlay variant={featureVariant} opacity={0.15} blend="screen" />
      )}

      <div className="relative z-10">{children}</div>
    </Tag>
  );
}
