"use client";

import React from "react";
import {
  HoverCard,
  HoverCardTrigger,
  HoverCardContent as BaseContent,
} from "@/components/ui/hover-card";
import { cn } from "@/lib/utils";

/* ------------------------------------------------------------------ */
/*  DSHoverCard — root wrapper                                          */
/* ------------------------------------------------------------------ */

export function DSHoverCard(props: React.ComponentProps<typeof HoverCard>) {
  return <HoverCard {...props} />;
}

/* ------------------------------------------------------------------ */
/*  DSHoverCardTrigger                                                  */
/* ------------------------------------------------------------------ */

export function DSHoverCardTrigger(
  props: React.ComponentProps<typeof HoverCardTrigger>,
) {
  return <HoverCardTrigger {...props} />;
}

/* ------------------------------------------------------------------ */
/*  DSHoverCardContent                                                  */
/* ------------------------------------------------------------------ */

export function DSHoverCardContent({
  className,
  ...props
}: React.ComponentProps<typeof BaseContent>) {
  return (
    <BaseContent
      className={cn(
        "bg-ds-surface-raised rounded-ds-sm p-4",
        "border border-[rgba(240,238,233,0.06)]",
        "shadow-lg shadow-black/20",
        "font-jakarta text-ds-text-primary",
        className,
      )}
      {...props}
    />
  );
}
