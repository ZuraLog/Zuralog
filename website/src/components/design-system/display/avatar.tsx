"use client";

import React from "react";
import { cn } from "@/lib/utils";
import { PatternOverlay } from "@/components/design-system/primitives/pattern-overlay";

export interface AvatarProps {
  src?: string;
  alt?: string;
  initials?: string;
  size?: "lg" | "md" | "sm";
  className?: string;
}

const sizeClasses = {
  lg: "size-12",
  md: "size-9",
  sm: "size-6",
} as const;

const initialsTextSize = {
  lg: "text-base",
  md: "text-sm",
  sm: "text-[0.5rem]",
} as const;

export function Avatar({
  src,
  alt = "",
  initials,
  size = "md",
  className,
}: AvatarProps) {
  return (
    <div
      className={cn(
        "relative overflow-hidden rounded-full",
        sizeClasses[size],
        !src && "bg-ds-surface-raised",
        className,
      )}
    >
      {src ? (
        <img
          src={src}
          alt={alt}
          className="size-full rounded-full object-cover"
        />
      ) : (
        <>
          <PatternOverlay variant="original" opacity={0.20} blend="screen" />
          {initials && (
            <span
              className={cn(
                "relative z-10 flex items-center justify-center size-full",
                "text-ds-sage font-semibold font-jakarta",
                initialsTextSize[size],
              )}
              aria-label={alt || initials}
            >
              {initials}
            </span>
          )}
        </>
      )}
    </div>
  );
}
