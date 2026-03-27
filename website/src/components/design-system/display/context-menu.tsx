"use client";

import React from "react";
import {
  ContextMenu,
  ContextMenuTrigger,
  ContextMenuContent as BaseContent,
  ContextMenuItem as BaseItem,
  ContextMenuCheckboxItem as BaseCheckboxItem,
  ContextMenuRadioItem as BaseRadioItem,
  ContextMenuLabel as BaseLabel,
  ContextMenuSeparator as BaseSeparator,
  ContextMenuShortcut as BaseShortcut,
  ContextMenuGroup,
  ContextMenuPortal,
  ContextMenuSub,
  ContextMenuSubContent as BaseSubContent,
  ContextMenuSubTrigger as BaseSubTrigger,
  ContextMenuRadioGroup,
} from "@/components/ui/context-menu";
import { cn } from "@/lib/utils";

/* ------------------------------------------------------------------ */
/*  DSContextMenu — root wrapper                                       */
/* ------------------------------------------------------------------ */

export function DSContextMenu(
  props: React.ComponentProps<typeof ContextMenu>,
) {
  return <ContextMenu {...props} />;
}

/* ------------------------------------------------------------------ */
/*  DSContextMenuTrigger                                               */
/* ------------------------------------------------------------------ */

export function DSContextMenuTrigger(
  props: React.ComponentProps<typeof ContextMenuTrigger>,
) {
  return <ContextMenuTrigger {...props} />;
}

/* ------------------------------------------------------------------ */
/*  DSContextMenuContent                                               */
/* ------------------------------------------------------------------ */

export function DSContextMenuContent({
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
/*  DSContextMenuItem                                                  */
/* ------------------------------------------------------------------ */

export function DSContextMenuItem({
  className,
  ...props
}: React.ComponentProps<typeof BaseItem>) {
  return (
    <BaseItem
      className={cn(
        "text-ds-text-primary text-[0.875rem] font-jakarta",
        "px-3 py-2 rounded-ds-xs",
        "focus:bg-[rgba(207,225,185,0.08)] focus:text-ds-sage",
        "[&_svg]:text-ds-sage",
        "cursor-pointer",
        "min-h-[44px] flex items-center",
        className,
      )}
      {...props}
    />
  );
}

/* ------------------------------------------------------------------ */
/*  DSContextMenuCheckboxItem                                          */
/* ------------------------------------------------------------------ */

export function DSContextMenuCheckboxItem({
  className,
  ...props
}: React.ComponentProps<typeof BaseCheckboxItem>) {
  return (
    <BaseCheckboxItem
      className={cn(
        "text-ds-text-primary text-[0.875rem] font-jakarta",
        "px-3 py-2 rounded-ds-xs",
        "focus:bg-[rgba(207,225,185,0.08)] focus:text-ds-sage",
        "[&_svg]:text-ds-sage",
        "min-h-[44px] flex items-center",
        "[&_span]:text-ds-sage",
        className,
      )}
      {...props}
    />
  );
}

/* ------------------------------------------------------------------ */
/*  DSContextMenuRadioGroup                                            */
/* ------------------------------------------------------------------ */

export function DSContextMenuRadioGroup(
  props: React.ComponentProps<typeof ContextMenuRadioGroup>,
) {
  return <ContextMenuRadioGroup {...props} />;
}

/* ------------------------------------------------------------------ */
/*  DSContextMenuRadioItem                                             */
/* ------------------------------------------------------------------ */

export function DSContextMenuRadioItem({
  className,
  ...props
}: React.ComponentProps<typeof BaseRadioItem>) {
  return (
    <BaseRadioItem
      className={cn(
        "text-ds-text-primary text-[0.875rem] font-jakarta",
        "px-3 py-2 rounded-ds-xs",
        "focus:bg-[rgba(207,225,185,0.08)] focus:text-ds-sage",
        "min-h-[44px] flex items-center",
        "[&_span]:text-ds-sage",
        className,
      )}
      {...props}
    />
  );
}

/* ------------------------------------------------------------------ */
/*  DSContextMenuLabel                                                 */
/* ------------------------------------------------------------------ */

export function DSContextMenuLabel({
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
/*  DSContextMenuSeparator                                             */
/* ------------------------------------------------------------------ */

export function DSContextMenuSeparator({
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
/*  DSContextMenuShortcut                                              */
/* ------------------------------------------------------------------ */

export function DSContextMenuShortcut({
  className,
  ...props
}: React.ComponentProps<typeof BaseShortcut>) {
  return (
    <BaseShortcut
      className={cn(
        "text-ds-text-secondary text-[0.6875rem] ml-auto font-jakarta",
        className,
      )}
      {...props}
    />
  );
}

/* ------------------------------------------------------------------ */
/*  DSContextMenuGroup                                                 */
/* ------------------------------------------------------------------ */

export function DSContextMenuGroup(
  props: React.ComponentProps<typeof ContextMenuGroup>,
) {
  return <ContextMenuGroup {...props} />;
}

/* ------------------------------------------------------------------ */
/*  DSContextMenuSub                                                   */
/* ------------------------------------------------------------------ */

export function DSContextMenuSub(
  props: React.ComponentProps<typeof ContextMenuSub>,
) {
  return <ContextMenuSub {...props} />;
}

/* ------------------------------------------------------------------ */
/*  DSContextMenuSubTrigger                                            */
/* ------------------------------------------------------------------ */

export function DSContextMenuSubTrigger({
  className,
  ...props
}: React.ComponentProps<typeof BaseSubTrigger>) {
  return (
    <BaseSubTrigger
      className={cn(
        "text-ds-text-primary text-[0.875rem] font-jakarta",
        "px-3 py-2 rounded-ds-xs",
        "focus:bg-[rgba(207,225,185,0.08)] focus:text-ds-sage",
        "[&_svg]:text-ds-sage",
        "min-h-[44px] flex items-center",
        className,
      )}
      {...props}
    />
  );
}

/* ------------------------------------------------------------------ */
/*  DSContextMenuSubContent                                            */
/* ------------------------------------------------------------------ */

export function DSContextMenuSubContent({
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
