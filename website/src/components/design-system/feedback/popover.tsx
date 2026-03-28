"use client";

import React from "react";
import {
  Popover,
  PopoverContent as BaseContent,
  PopoverTrigger,
  PopoverHeader,
  PopoverTitle as BaseTitle,
  PopoverDescription as BaseDescription,
} from "@/components/ui/popover";
import { cn } from "@/lib/utils";

/* ------------------------------------------------------------------ */
/*  DSPopover — root wrapper                                            */
/* ------------------------------------------------------------------ */

export function DSPopover(props: React.ComponentProps<typeof Popover>) {
  return <Popover {...props} />;
}

/* ------------------------------------------------------------------ */
/*  DSPopoverTrigger                                                    */
/* ------------------------------------------------------------------ */

export function DSPopoverTrigger(
  props: React.ComponentProps<typeof PopoverTrigger>,
) {
  return <PopoverTrigger {...props} />;
}

/* ------------------------------------------------------------------ */
/*  DSPopoverContent                                                    */
/* ------------------------------------------------------------------ */

export function DSPopoverContent({
  className,
  ...props
}: React.ComponentProps<typeof BaseContent>) {
  return (
    <BaseContent
      className={cn(
        "bg-ds-surface-raised rounded-ds-sm p-4",
        "border border-[var(--color-ds-border-subtle)]",
        "font-jakarta text-ds-text-primary",
        className,
      )}
      {...props}
    />
  );
}

/* ------------------------------------------------------------------ */
/*  DSPopoverHeader                                                     */
/* ------------------------------------------------------------------ */

export function DSPopoverHeader(
  props: React.ComponentProps<typeof PopoverHeader>,
) {
  return <PopoverHeader {...props} />;
}

/* ------------------------------------------------------------------ */
/*  DSPopoverTitle                                                      */
/* ------------------------------------------------------------------ */

export function DSPopoverTitle({
  className,
  ...props
}: React.ComponentProps<typeof BaseTitle>) {
  return (
    <BaseTitle
      className={cn(
        "text-ds-text-primary font-medium font-jakarta",
        className,
      )}
      {...props}
    />
  );
}

/* ------------------------------------------------------------------ */
/*  DSPopoverDescription                                                */
/* ------------------------------------------------------------------ */

export function DSPopoverDescription({
  className,
  ...props
}: React.ComponentProps<typeof BaseDescription>) {
  return (
    <BaseDescription
      className={cn("text-ds-text-secondary font-jakarta", className)}
      {...props}
    />
  );
}
