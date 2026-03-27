"use client";

import React from "react";
import { Calendar, type CalendarDayButton } from "@/components/ui/calendar";
import { cn } from "@/lib/utils";

/* ------------------------------------------------------------------ */
/*  DSCalendar — themed month view                                     */
/* ------------------------------------------------------------------ */

export function DSCalendar({
  className,
  classNames,
  ...props
}: React.ComponentProps<typeof Calendar>) {
  return (
    <Calendar
      className={cn(
        "bg-ds-surface rounded-ds-lg p-4 font-jakarta",
        "[--cell-radius:var(--radius-ds-xs)] [--cell-size:--spacing(9)]",
        className,
      )}
      classNames={{
        month_caption: cn(
          "flex h-(--cell-size) w-full items-center justify-center px-(--cell-size)",
          "text-ds-text-primary font-jakarta font-medium",
        ),
        nav: "absolute inset-x-0 top-0 flex w-full items-center justify-between gap-1",
        button_previous: cn(
          "size-(--cell-size) p-0 select-none rounded-ds-xs",
          "text-ds-text-secondary hover:bg-ds-surface-raised hover:text-ds-text-primary",
        ),
        button_next: cn(
          "size-(--cell-size) p-0 select-none rounded-ds-xs",
          "text-ds-text-secondary hover:bg-ds-surface-raised hover:text-ds-text-primary",
        ),
        weekday: cn(
          "flex-1 rounded-(--cell-radius) text-[0.6875rem] font-normal",
          "text-ds-text-secondary select-none font-jakarta",
        ),
        day: cn(
          "group/day relative aspect-square h-full w-full rounded-(--cell-radius) p-0 text-center select-none",
          "text-ds-text-primary text-[0.875rem] font-jakarta",
          "[&:first-child[data-selected=true]_button]:rounded-l-(--cell-radius)",
          "[&:last-child[data-selected=true]_button]:rounded-r-(--cell-radius)",
        ),
        today: cn(
          "rounded-ds-xs border border-ds-sage",
          "text-ds-text-primary data-[selected=true]:rounded-none",
        ),
        outside: "text-ds-text-secondary/40",
        disabled: "text-ds-text-secondary/40 opacity-50",
        range_start: cn(
          "relative isolate z-0 rounded-l-ds-xs bg-ds-sage/10",
          "after:absolute after:inset-y-0 after:right-0 after:w-4 after:bg-ds-sage/10",
        ),
        range_middle: "rounded-none bg-ds-sage/10",
        range_end: cn(
          "relative isolate z-0 rounded-r-ds-xs bg-ds-sage/10",
          "after:absolute after:inset-y-0 after:left-0 after:w-4 after:bg-ds-sage/10",
        ),
        caption_label: "font-medium text-sm text-ds-text-primary select-none font-jakarta",
        dropdowns:
          "flex h-(--cell-size) w-full items-center justify-center gap-1.5 text-sm font-medium text-ds-text-primary font-jakarta",
        ...classNames,
      }}
      {...props}
    />
  );
}
