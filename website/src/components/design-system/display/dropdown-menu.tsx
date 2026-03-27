"use client";

import React from "react";
import {
  DropdownMenu,
  DropdownMenuTrigger,
  DropdownMenuContent as BaseContent,
  DropdownMenuItem as BaseItem,
  DropdownMenuSeparator as BaseSeparator,
  DropdownMenuLabel as BaseLabel,
  DropdownMenuCheckboxItem as BaseCheckboxItem,
  DropdownMenuRadioGroup,
  DropdownMenuRadioItem as BaseRadioItem,
  DropdownMenuSub,
  DropdownMenuSubTrigger as BaseSubTrigger,
  DropdownMenuSubContent as BaseSubContent,
} from "@/components/ui/dropdown-menu";
import { cn } from "@/lib/utils";

/* ------------------------------------------------------------------ */
/*  DSDropdownMenu — root wrapper                                       */
/* ------------------------------------------------------------------ */

export function DSDropdownMenu(
  props: React.ComponentProps<typeof DropdownMenu>,
) {
  return <DropdownMenu {...props} />;
}

/* ------------------------------------------------------------------ */
/*  DSDropdownMenuTrigger                                               */
/* ------------------------------------------------------------------ */

export function DSDropdownMenuTrigger(
  props: React.ComponentProps<typeof DropdownMenuTrigger>,
) {
  return <DropdownMenuTrigger {...props} />;
}

/* ------------------------------------------------------------------ */
/*  DSDropdownMenuContent — styled popup                                */
/* ------------------------------------------------------------------ */

export function DSDropdownMenuContent({
  className,
  ...props
}: React.ComponentProps<typeof BaseContent>) {
  return (
    <BaseContent
      className={cn(
        "bg-ds-surface-raised rounded-ds-sm p-1",
        "border border-[rgba(240,238,233,0.06)]",
        "font-jakarta",
        className,
      )}
      {...props}
    />
  );
}

/* ------------------------------------------------------------------ */
/*  DSDropdownMenuItem                                                  */
/* ------------------------------------------------------------------ */

export function DSDropdownMenuItem({
  className,
  ...props
}: React.ComponentProps<typeof BaseItem>) {
  return (
    <BaseItem
      className={cn(
        "text-ds-text-primary text-[0.875rem] font-jakarta",
        "px-3 py-2 rounded-ds-xs",
        "focus:bg-ds-surface",
        "cursor-pointer",
        "min-h-[44px] flex items-center",
        className,
      )}
      {...props}
    />
  );
}

/* ------------------------------------------------------------------ */
/*  DSDropdownMenuSeparator                                             */
/* ------------------------------------------------------------------ */

export function DSDropdownMenuSeparator({
  className,
  ...props
}: React.ComponentProps<typeof BaseSeparator>) {
  return (
    <BaseSeparator
      className={cn("h-px bg-[rgba(240,238,233,0.06)] my-1", className)}
      {...props}
    />
  );
}

/* ------------------------------------------------------------------ */
/*  DSDropdownMenuLabel                                                 */
/* ------------------------------------------------------------------ */

export function DSDropdownMenuLabel({
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
/*  DSDropdownMenuCheckboxItem                                          */
/* ------------------------------------------------------------------ */

export function DSDropdownMenuCheckboxItem({
  className,
  ...props
}: React.ComponentProps<typeof BaseCheckboxItem>) {
  return (
    <BaseCheckboxItem
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
/*  DSDropdownMenuRadioGroup                                            */
/* ------------------------------------------------------------------ */

export function DSDropdownMenuRadioGroup(
  props: React.ComponentProps<typeof DropdownMenuRadioGroup>,
) {
  return <DropdownMenuRadioGroup {...props} />;
}

/* ------------------------------------------------------------------ */
/*  DSDropdownMenuRadioItem                                             */
/* ------------------------------------------------------------------ */

export function DSDropdownMenuRadioItem({
  className,
  ...props
}: React.ComponentProps<typeof BaseRadioItem>) {
  return (
    <BaseRadioItem
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
/*  DSDropdownMenuSub                                                   */
/* ------------------------------------------------------------------ */

export function DSDropdownMenuSub(
  props: React.ComponentProps<typeof DropdownMenuSub>,
) {
  return <DropdownMenuSub {...props} />;
}

/* ------------------------------------------------------------------ */
/*  DSDropdownMenuSubTrigger                                            */
/* ------------------------------------------------------------------ */

export function DSDropdownMenuSubTrigger({
  className,
  ...props
}: React.ComponentProps<typeof BaseSubTrigger>) {
  return (
    <BaseSubTrigger
      className={cn(
        "text-ds-text-primary text-[0.875rem] font-jakarta",
        "px-3 py-2 rounded-ds-xs",
        "focus:bg-ds-surface",
        "min-h-[44px] flex items-center",
        className,
      )}
      {...props}
    />
  );
}

/* ------------------------------------------------------------------ */
/*  DSDropdownMenuSubContent                                            */
/* ------------------------------------------------------------------ */

export function DSDropdownMenuSubContent({
  className,
  ...props
}: React.ComponentProps<typeof BaseSubContent>) {
  return (
    <BaseSubContent
      className={cn(
        "bg-ds-surface-raised rounded-ds-sm p-1",
        "border border-[rgba(240,238,233,0.06)]",
        "font-jakarta",
        className,
      )}
      {...props}
    />
  );
}
