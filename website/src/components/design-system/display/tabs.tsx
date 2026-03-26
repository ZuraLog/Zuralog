"use client";

import React from "react";
import { Tabs as TabsPrimitive } from "@base-ui/react/tabs";
import { cn } from "@/lib/utils";
import { PatternOverlay } from "@/components/design-system/primitives/pattern-overlay";

/* ------------------------------------------------------------------ */
/*  DSTabs — wraps Root                                                */
/* ------------------------------------------------------------------ */

export function DSTabs({
  className,
  ...props
}: React.ComponentProps<typeof TabsPrimitive.Root>) {
  return (
    <TabsPrimitive.Root className={cn(className)} {...props} />
  );
}

/* ------------------------------------------------------------------ */
/*  DSTabsList — the track with pattern overlay                        */
/* ------------------------------------------------------------------ */

export function DSTabsList({
  className,
  children,
  ...props
}: React.ComponentProps<typeof TabsPrimitive.List>) {
  return (
    <TabsPrimitive.List
      className={cn(
        "relative overflow-hidden",
        "bg-ds-surface rounded-ds-sm p-1 inline-flex",
        className,
      )}
      {...props}
    >
      <PatternOverlay variant="original" opacity={0.06} blend="screen" />
      <div className="relative z-10 inline-flex">{children}</div>
    </TabsPrimitive.List>
  );
}

/* ------------------------------------------------------------------ */
/*  DSTabsTrigger                                                      */
/* ------------------------------------------------------------------ */

export function DSTabsTrigger({
  className,
  ...props
}: React.ComponentProps<typeof TabsPrimitive.Tab>) {
  return (
    <TabsPrimitive.Tab
      className={cn(
        "px-3 py-1.5",
        "text-[0.8125rem] font-medium font-jakarta",
        "transition-colors duration-200",
        "text-ds-text-secondary bg-transparent",
        "cursor-pointer",
        "data-[selected]:bg-ds-warm-white data-[selected]:text-ds-text-on-warm-white data-[selected]:rounded-[9px]",
        className,
      )}
      {...props}
    />
  );
}

/* ------------------------------------------------------------------ */
/*  DSTabsContent                                                      */
/* ------------------------------------------------------------------ */

export function DSTabsContent({
  className,
  ...props
}: React.ComponentProps<typeof TabsPrimitive.Panel>) {
  return (
    <TabsPrimitive.Panel
      className={cn(
        "py-4 text-[0.875rem] font-jakarta text-ds-text-primary",
        "outline-none",
        className,
      )}
      {...props}
    />
  );
}
