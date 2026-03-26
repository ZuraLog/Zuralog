import { cva, type VariantProps } from "class-variance-authority";
import { cn } from "@/lib/utils";
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
  // base — every card gets these
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
  /** Health category — only applies when elevation is "feature" */
  category?: Category;
  as?: "div" | "article" | "section";
  className?: string;
  children: React.ReactNode;
}

/* ------------------------------------------------------------------ */
/*  Component (server component — no "use client")                     */
/* ------------------------------------------------------------------ */

export function Card({
  elevation = "standard",
  category,
  as: Tag = "div",
  className,
  children,
}: CardProps) {
  const showHeroPattern = elevation === "hero";
  const showFeaturePattern = elevation === "feature";

  const featureVariant =
    category && CATEGORY_PATTERN[category]
      ? CATEGORY_PATTERN[category]
      : "original";

  const hoverClass = elevation !== "data" ? "ds-card-hover" : undefined;

  return (
    <Tag className={cn(cardVariants({ elevation }), hoverClass, className)}>
      {/* Hero pattern overlay */}
      {showHeroPattern && (
        <PatternOverlay variant="original" opacity={0.18} blend="screen" />
      )}

      {/* Feature pattern overlay */}
      {showFeaturePattern && (
        <PatternOverlay variant={featureVariant} opacity={0.15} blend="screen" />
      )}

      {/* Content sits above the pattern */}
      <div className="relative z-10">{children}</div>
    </Tag>
  );
}
