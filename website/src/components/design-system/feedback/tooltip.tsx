"use client";

import React from "react";
import { Tooltip as TooltipPrimitive } from "@base-ui/react/tooltip";
import { cn } from "@/lib/utils";

/* ------------------------------------------------------------------ */
/*  DSTooltip — wraps Root                                             */
/* ------------------------------------------------------------------ */

export function DSTooltip(props: React.ComponentProps<typeof TooltipPrimitive.Root>) {
  return <TooltipPrimitive.Root {...props} />;
}

/* ------------------------------------------------------------------ */
/*  DSTooltipTrigger — wraps Trigger                                   */
/* ------------------------------------------------------------------ */

export function DSTooltipTrigger({
  children,
  ...props
}: React.ComponentProps<typeof TooltipPrimitive.Trigger>) {
  if (React.isValidElement(children)) {
    return <TooltipPrimitive.Trigger render={children} {...props} />;
  }
  return <TooltipPrimitive.Trigger {...props}>{children}</TooltipPrimitive.Trigger>;
}

/* ------------------------------------------------------------------ */
/*  DSTooltipContent — wraps Portal + Positioner + Popup               */
/* ------------------------------------------------------------------ */

interface DSTooltipContentProps {
  children: React.ReactNode;
  side?: "top" | "bottom" | "left" | "right";
  sideOffset?: number;
  className?: string;
}

export function DSTooltipContent({
  children,
  side = "top",
  sideOffset = 8,
  className,
}: DSTooltipContentProps) {
  return (
    <TooltipPrimitive.Portal>
      <TooltipPrimitive.Positioner side={side} sideOffset={sideOffset}>
        <TooltipPrimitive.Popup
          className={cn(
            "bg-ds-surface-raised rounded-ds-xs",
            "text-ds-text-primary text-[0.75rem] font-jakarta",
            "px-3 py-1.5",
            "transition-opacity duration-200",
            "data-[state=open]:opacity-100 data-[state=closed]:opacity-0",
            className,
          )}
        >
          {children}
          <TooltipPrimitive.Arrow className="fill-ds-surface-raised" />
        </TooltipPrimitive.Popup>
      </TooltipPrimitive.Positioner>
    </TooltipPrimitive.Portal>
  );
}
