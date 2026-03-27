"use client";

import React from "react";
import {
  Collapsible,
  CollapsibleTrigger as BaseTrigger,
  CollapsibleContent as BaseContent,
} from "@/components/ui/collapsible";
import { ChevronDown } from "lucide-react";
import { cn } from "@/lib/utils";

/* ------------------------------------------------------------------ */
/*  DSCollapsible — root wrapper                                        */
/* ------------------------------------------------------------------ */

export function DSCollapsible(
  props: React.ComponentProps<typeof Collapsible>,
) {
  return <Collapsible {...props} />;
}

/* ------------------------------------------------------------------ */
/*  DSCollapsibleTrigger                                                */
/* ------------------------------------------------------------------ */

interface DSCollapsibleTriggerProps
  extends React.ComponentProps<typeof BaseTrigger> {
  /** Show the rotating chevron indicator */
  showChevron?: boolean;
}

export function DSCollapsibleTrigger({
  className,
  children,
  showChevron = true,
  ...props
}: DSCollapsibleTriggerProps) {
  return (
    <BaseTrigger
      className={cn(
        "group flex w-full items-center justify-between",
        "text-ds-text-primary font-jakarta font-medium text-left",
        "min-h-[44px] cursor-pointer",
        "focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-[rgba(207,225,185,0.3)] focus-visible:rounded-ds-xs",
        className,
      )}
      {...props}
    >
      {children}
      {showChevron && (
        <ChevronDown
          className={cn(
            "size-4 text-ds-sage shrink-0 ml-2",
            "transition-transform duration-300 ease-[cubic-bezier(0.34,1.56,0.64,1)]",
            "motion-reduce:transition-none",
            "group-data-[panel-open]:rotate-180",
          )}
          aria-hidden="true"
        />
      )}
    </BaseTrigger>
  );
}

/* ------------------------------------------------------------------ */
/*  DSCollapsibleContent                                                */
/* ------------------------------------------------------------------ */

export function DSCollapsibleContent({
  className,
  ...props
}: React.ComponentProps<typeof BaseContent>) {
  return (
    <BaseContent
      className={cn(
        "text-ds-text-secondary text-[0.875rem] font-jakarta",
        "overflow-hidden",
        "data-[state=open]:animate-[ds-collapse-open_300ms_ease-out]",
        "data-[state=closed]:animate-[ds-collapse-close_300ms_ease-out]",
        className,
      )}
      {...props}
    />
  );
}
