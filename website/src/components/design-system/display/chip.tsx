"use client";

import React from "react";
import { cn } from "@/lib/utils";

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
          ? "bg-cover bg-center bg-no-repeat text-ds-text-on-sage"
          : "bg-ds-surface text-ds-text-secondary",
        onClick && "cursor-pointer",
        className,
      )}
      {...(active
        ? { style: { backgroundImage: "var(--ds-pattern-sage)" } }
        : undefined)}
    >
      <span className="relative z-10">{children}</span>
    </Tag>
  );
}
