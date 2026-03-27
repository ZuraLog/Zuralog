"use client";

import React from "react";
import {
  Sheet,
  SheetTrigger,
  SheetClose,
  SheetContent as BaseContent,
  SheetHeader as BaseHeader,
  SheetFooter as BaseFooter,
  SheetTitle as BaseTitle,
  SheetDescription as BaseDescription,
} from "@/components/ui/sheet";
import { cn } from "@/lib/utils";

/* ------------------------------------------------------------------ */
/*  DSSheet — root wrapper                                              */
/* ------------------------------------------------------------------ */

export function DSSheet(props: React.ComponentProps<typeof Sheet>) {
  return <Sheet {...props} />;
}

/* ------------------------------------------------------------------ */
/*  DSSheetTrigger                                                      */
/* ------------------------------------------------------------------ */

export function DSSheetTrigger(
  props: React.ComponentProps<typeof SheetTrigger>,
) {
  return <SheetTrigger {...props} />;
}

/* ------------------------------------------------------------------ */
/*  DSSheetClose                                                        */
/* ------------------------------------------------------------------ */

export function DSSheetClose(props: React.ComponentProps<typeof SheetClose>) {
  return <SheetClose {...props} />;
}

/* ------------------------------------------------------------------ */
/*  DSSheetContent                                                      */
/* ------------------------------------------------------------------ */

interface DSSheetContentProps
  extends React.ComponentProps<typeof BaseContent> {
  showHandle?: boolean;
}

export function DSSheetContent({
  className,
  children,
  side = "bottom",
  showHandle = true,
  showCloseButton = true,
  ...props
}: DSSheetContentProps) {
  return (
    <BaseContent
      side={side}
      showCloseButton={showCloseButton}
      className={cn(
        "bg-ds-surface-overlay border-none p-6",
        "font-jakarta",
        side === "bottom" && "rounded-t-ds-xl",
        side === "top" && "rounded-b-ds-xl",
        side === "right" && "rounded-l-ds-xl",
        side === "left" && "rounded-r-ds-xl",
        "[data-slot=sheet-close]:text-ds-text-secondary [data-slot=sheet-close]:hover:text-ds-text-primary",
        className,
      )}
      {...props}
    >
      {showHandle && side === "bottom" && (
        <div
          className="w-10 h-1 bg-ds-text-secondary/30 rounded-full mx-auto mb-4 shrink-0"
          aria-hidden="true"
        />
      )}
      {children}
    </BaseContent>
  );
}

/* ------------------------------------------------------------------ */
/*  DSSheetHeader                                                       */
/* ------------------------------------------------------------------ */

export function DSSheetHeader({
  className,
  ...props
}: React.ComponentProps<typeof BaseHeader>) {
  return <BaseHeader className={cn("p-0 mb-4", className)} {...props} />;
}

/* ------------------------------------------------------------------ */
/*  DSSheetFooter                                                       */
/* ------------------------------------------------------------------ */

export function DSSheetFooter({
  className,
  ...props
}: React.ComponentProps<typeof BaseFooter>) {
  return <BaseFooter className={cn("p-0 mt-4", className)} {...props} />;
}

/* ------------------------------------------------------------------ */
/*  DSSheetTitle                                                        */
/* ------------------------------------------------------------------ */

export function DSSheetTitle({
  className,
  ...props
}: React.ComponentProps<typeof BaseTitle>) {
  return (
    <BaseTitle
      className={cn(
        "text-ds-text-primary text-[1.0625rem] font-medium font-jakarta",
        className,
      )}
      {...props}
    />
  );
}

/* ------------------------------------------------------------------ */
/*  DSSheetDescription                                                  */
/* ------------------------------------------------------------------ */

export function DSSheetDescription({
  className,
  ...props
}: React.ComponentProps<typeof BaseDescription>) {
  return (
    <BaseDescription
      className={cn("text-ds-text-secondary text-[0.875rem] font-jakarta", className)}
      {...props}
    />
  );
}
