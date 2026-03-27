"use client";

import React from "react";
import { ScrollArea as ScrollAreaPrimitive } from "@base-ui/react/scroll-area";
import { cn } from "@/lib/utils";

/* ------------------------------------------------------------------ */
/*  DSScrollArea                                                        */
/* ------------------------------------------------------------------ */

interface DSScrollAreaProps extends ScrollAreaPrimitive.Root.Props {
  className?: string;
  children: React.ReactNode;
}

export function DSScrollArea({ className, children, ...props }: DSScrollAreaProps) {
  return (
    <ScrollAreaPrimitive.Root
      className={cn("relative overflow-hidden", className)}
      {...props}
    >
      <ScrollAreaPrimitive.Viewport className="size-full overflow-auto rounded-[inherit]">
        {children}
      </ScrollAreaPrimitive.Viewport>
      <DSScrollBar />
      <DSScrollBar orientation="horizontal" />
      <ScrollAreaPrimitive.Corner />
    </ScrollAreaPrimitive.Root>
  );
}

/* ------------------------------------------------------------------ */
/*  DSScrollBar                                                         */
/* ------------------------------------------------------------------ */

interface DSScrollBarProps extends ScrollAreaPrimitive.Scrollbar.Props {
  className?: string;
}

export function DSScrollBar({
  className,
  orientation = "vertical",
  ...props
}: DSScrollBarProps) {
  return (
    <ScrollAreaPrimitive.Scrollbar
      orientation={orientation}
      className={cn(
        "flex touch-none select-none bg-transparent p-px",
        "transition-colors",
        orientation === "vertical" && "h-full w-2 border-l border-l-transparent",
        orientation === "horizontal" && "h-2 flex-col border-t border-t-transparent",
        className,
      )}
      {...props}
    >
      <ScrollAreaPrimitive.Thumb
        className={cn(
          "relative flex-1 rounded-full",
          "bg-ds-text-secondary/20",
          "hover:bg-ds-text-secondary/40",
          "transition-colors",
        )}
      />
    </ScrollAreaPrimitive.Scrollbar>
  );
}
