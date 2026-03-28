"use client";

import React from "react";
import { cn } from "@/lib/utils";

export interface DSSkeletonProps extends React.HTMLAttributes<HTMLDivElement> {
  /** Width — any CSS value (e.g. "100%", "200px") */
  width?: string;
  /** Height — any CSS value */
  height?: string;
}

export function DSSkeleton({
  className,
  width,
  height,
  style,
  ...props
}: DSSkeletonProps) {
  return (
    <div
      className={cn(
        "bg-ds-surface-raised rounded-ds-sm",
        "relative overflow-hidden",
        "motion-safe:after:absolute motion-safe:after:inset-0",
        "motion-safe:after:bg-gradient-to-r motion-safe:after:from-transparent motion-safe:after:via-[var(--color-ds-shimmer)] motion-safe:after:to-transparent",
        "motion-safe:after:animate-[ds-shimmer_2s_ease-in-out_infinite]",
        className,
      )}
      style={{ width, height, ...style }}
      aria-hidden="true"
      {...props}
    />
  );
}
