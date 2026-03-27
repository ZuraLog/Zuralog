"use client";

import React from "react";
import { cn } from "@/lib/utils";

export interface DSProgressProps extends React.HTMLAttributes<HTMLDivElement> {
  /** Progress value between 0 and 100 */
  value?: number;
  /** Optional label text */
  label?: string;
  /** Show the percentage number */
  showValue?: boolean;
}

export function DSProgress({
  value = 0,
  label,
  showValue,
  className,
  ...props
}: DSProgressProps) {
  const clampedValue = Math.max(0, Math.min(100, value));

  return (
    <div className={cn("w-full", className)} {...props}>
      {(label || showValue) && (
        <div className="flex items-center justify-between mb-2">
          {label && (
            <span className="text-ds-text-primary text-[0.875rem] font-medium font-jakarta">
              {label}
            </span>
          )}
          {showValue && (
            <span className="text-ds-text-secondary text-[0.75rem] font-jakarta tabular-nums">
              {Math.round(clampedValue)}%
            </span>
          )}
        </div>
      )}
      <div
        className="bg-ds-surface-raised h-2 rounded-full overflow-hidden"
        role="progressbar"
        aria-valuenow={clampedValue}
        aria-valuemin={0}
        aria-valuemax={100}
        aria-label={label || "Progress"}
      >
        <div
          className={cn(
            "h-full rounded-full",
            "ds-pattern-drift",
            "bg-ds-sage",
            "transition-all duration-500 ease-[cubic-bezier(0.16,1,0.3,1)]",
            "motion-reduce:transition-none",
          )}
          style={{
            width: `${clampedValue}%`,
            backgroundImage: "url(/patterns/sage.png)",
            backgroundSize: "200px",
          }}
        />
      </div>
    </div>
  );
}
