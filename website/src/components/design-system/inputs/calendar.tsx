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
        /* Override nav arrow hover to sage */
        "[&_.rdp-button_previous]:text-ds-text-secondary [&_.rdp-button_previous:hover]:text-ds-sage",
        "[&_.rdp-button_next]:text-ds-text-secondary [&_.rdp-button_next:hover]:text-ds-sage",
        /* Override day button hover */
        "[&_button[data-day]]:text-ds-text-primary [&_button[data-day]:hover]:bg-ds-surface-raised [&_button[data-day]]:rounded-ds-xs",
        /* Override selected single day — sage pattern */
        "[&_button[data-selected-single=true]]:bg-ds-sage [&_button[data-selected-single=true]]:text-ds-text-on-sage [&_button[data-selected-single=true]]:bg-cover [&_button[data-selected-single=true]]:bg-center [&_button[data-selected-single=true]]:bg-no-repeat [&_button[data-selected-single=true]]:rounded-ds-xs",
        /* Override range start/end */
        "[&_button[data-range-start=true]]:bg-ds-sage [&_button[data-range-start=true]]:text-ds-text-on-sage [&_button[data-range-start=true]]:bg-cover [&_button[data-range-start=true]]:bg-center",
        "[&_button[data-range-end=true]]:bg-ds-sage [&_button[data-range-end=true]]:text-ds-text-on-sage [&_button[data-range-end=true]]:bg-cover [&_button[data-range-end=true]]:bg-center",
        /* Outside month days */
        "[&_td[data-outside]]:text-ds-text-secondary/30",
        className,
      )}
      style={
        {
          "--ds-calendar-sage-bg": "url('/patterns/sage.png')",
        } as React.CSSProperties
      }
      classNames={{
        month_caption: cn(
          "flex h-(--cell-size) w-full items-center justify-center px-(--cell-size)",
          "text-ds-text-primary font-jakarta font-medium",
        ),
        nav: "absolute inset-x-0 top-0 flex w-full items-center justify-between gap-1",
        button_previous: cn(
          "size-(--cell-size) p-0 select-none rounded-ds-xs",
          "text-ds-text-secondary hover:bg-ds-surface-raised hover:text-ds-sage",
        ),
        button_next: cn(
          "size-(--cell-size) p-0 select-none rounded-ds-xs",
          "text-ds-text-secondary hover:bg-ds-surface-raised hover:text-ds-sage",
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
        outside: "text-ds-text-secondary/30",
        disabled: "text-ds-text-secondary/30 opacity-30",
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
