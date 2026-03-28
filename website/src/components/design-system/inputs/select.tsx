"use client";

import React from "react";
import {
  Select,
  SelectContent as BaseContent,
  SelectGroup,
  SelectItem as BaseItem,
  SelectLabel as BaseLabel,
  SelectSeparator as BaseSeparator,
  SelectTrigger as BaseTrigger,
  SelectValue,
} from "@/components/ui/select";
import { cn } from "@/lib/utils";

/* ------------------------------------------------------------------ */
/*  DSSelect — root wrapper                                             */
/* ------------------------------------------------------------------ */

export function DSSelect(props: React.ComponentProps<typeof Select>) {
  return <Select {...props} />;
}

/* ------------------------------------------------------------------ */
/*  DSSelectTrigger                                                     */
/* ------------------------------------------------------------------ */

export function DSSelectTrigger({
  className,
  ...props
}: React.ComponentProps<typeof BaseTrigger>) {
  return (
    <BaseTrigger
      className={cn(
        "bg-ds-surface rounded-ds-sm border-none",
        "text-ds-text-primary font-jakarta",
        "px-4 py-3 h-auto",
        "focus-visible:ring-1 focus-visible:ring-[var(--color-ds-sage-ring)] focus-visible:border-transparent",
        "min-h-[44px]",
        "[&_svg]:text-ds-text-secondary",
        className,
      )}
      {...props}
    />
  );
}

/* ------------------------------------------------------------------ */
/*  DSSelectContent                                                     */
/* ------------------------------------------------------------------ */

export function DSSelectContent({
  className,
  ...props
}: React.ComponentProps<typeof BaseContent>) {
  return (
    <BaseContent
      className={cn(
        "bg-ds-surface-raised rounded-ds-sm",
        "border border-[var(--color-ds-border-subtle)]",
        "font-jakarta",
        className,
      )}
      {...props}
    />
  );
}

/* ------------------------------------------------------------------ */
/*  DSSelectItem                                                        */
/* ------------------------------------------------------------------ */

export function DSSelectItem({
  className,
  ...props
}: React.ComponentProps<typeof BaseItem>) {
  return (
    <BaseItem
      className={cn(
        "text-ds-text-primary text-[0.875rem] font-jakarta",
        "px-3 py-2 rounded-ds-xs",
        "focus:bg-ds-surface",
        "min-h-[44px] flex items-center",
        "[&_span]:text-ds-sage",
        className,
      )}
      {...props}
    />
  );
}

/* ------------------------------------------------------------------ */
/*  DSSelectLabel                                                       */
/* ------------------------------------------------------------------ */

export function DSSelectLabel({
  className,
  ...props
}: React.ComponentProps<typeof BaseLabel>) {
  return (
    <BaseLabel
      className={cn(
        "text-ds-text-secondary text-[0.6875rem] font-medium font-jakarta px-3 py-1.5",
        className,
      )}
      {...props}
    />
  );
}

/* ------------------------------------------------------------------ */
/*  DSSelectSeparator                                                   */
/* ------------------------------------------------------------------ */

export function DSSelectSeparator({
  className,
  ...props
}: React.ComponentProps<typeof BaseSeparator>) {
  return (
    <BaseSeparator
      className={cn("h-px bg-[var(--color-ds-border-subtle)] my-1", className)}
      {...props}
    />
  );
}

/* ------------------------------------------------------------------ */
/*  Re-export passthrough components                                    */
/* ------------------------------------------------------------------ */

export { SelectValue as DSSelectValue, SelectGroup as DSSelectGroup };
