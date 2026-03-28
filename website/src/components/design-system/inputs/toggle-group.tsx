"use client";

import React from "react";
import { cn } from "@/lib/utils";

/* ------------------------------------------------------------------ */
/*  DSToggleGroup — segmented control (Day / Week / Month style)        */
/* ------------------------------------------------------------------ */

export interface DSToggleGroupProps {
  /** The currently active value */
  value: string;
  /** Fires when a new item is selected */
  onValueChange: (value: string) => void;
  /** Items to render — each has a value and a label */
  items: Array<{ value: string; label: React.ReactNode }>;
  /** Additional className for the container */
  className?: string;
}

export function DSToggleGroup({
  value,
  onValueChange,
  items,
  className,
}: DSToggleGroupProps) {
  return (
    <div
      role="radiogroup"
      className={cn(
        "bg-ds-surface rounded-ds-sm p-1 inline-flex",
        "font-jakarta",
        className,
      )}
    >
      {items.map((item) => {
        const isActive = item.value === value;
        return (
          <button
            key={item.value}
            role="radio"
            type="button"
            aria-checked={isActive}
            onClick={() => onValueChange(item.value)}
            className={cn(
              "px-4 py-2 rounded-[9px] text-[0.875rem] font-medium",
              "min-h-[36px] min-w-[44px]",
              "transition-all duration-200 ease-[cubic-bezier(0.16,1,0.3,1)]",
              "motion-reduce:transition-none",
              "focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-[var(--color-ds-sage-ring)]",
              "bg-cover bg-center bg-no-repeat",
              isActive
                ? "text-ds-text-on-sage shadow-sm"
                : "text-ds-text-secondary bg-transparent hover:text-ds-text-primary",
            )}
            style={isActive ? { backgroundImage: "var(--ds-pattern-sage)" } : undefined}
          >
            {item.label}
          </button>
        );
      })}
    </div>
  );
}
