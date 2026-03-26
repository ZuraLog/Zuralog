"use client";

import React from "react";
import { cn } from "@/lib/utils";
import { PatternOverlay } from "@/components/design-system/primitives/pattern-overlay";

export interface ChipProps {
  active?: boolean;
  children: React.ReactNode;
  onClick?: () => void;
  className?: string;
}

export function Chip({ active = false, children, onClick, className }: ChipProps) {
  const Tag = onClick ? "button" : "span";

  return (
    <Tag
      type={onClick ? "button" : undefined}
      onClick={onClick}
      className={cn(
        "relative overflow-hidden rounded-ds-pill py-2 px-4",
        "text-[0.8125rem] font-medium font-jakarta",
        "transition-colors duration-200",
        active
          ? "bg-[rgba(207,225,185,0.15)] text-ds-sage"
          : "bg-ds-surface text-ds-text-secondary",
        onClick && "cursor-pointer",
        className,
      )}
    >
      {active && (
        <PatternOverlay variant="original" opacity={0.08} blend="screen" />
      )}
      <span className="relative z-10">{children}</span>
    </Tag>
  );
}
