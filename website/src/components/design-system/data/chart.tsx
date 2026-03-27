"use client";

import React from "react";
import { cn } from "@/lib/utils";

/* ------------------------------------------------------------------ */
/*  Chart color palette — maps health categories to hex colors          */
/* ------------------------------------------------------------------ */

export const CHART_COLORS = {
  sage: "#CFE1B9",
  activity: "#30D158",
  sleep: "#5E5CE6",
  heart: "#FF375F",
  nutrition: "#FF9F0A",
  body: "#64D2FF",
  vitals: "#6AC4DC",
  wellness: "#BF5AF2",
  cycle: "#FF6482",
  mobility: "#FFD60A",
  environment: "#63E6BE",
} as const;

/* ------------------------------------------------------------------ */
/*  Default Recharts theme for dark mode                                */
/* ------------------------------------------------------------------ */

export const DS_CHART_THEME = {
  backgroundColor: "transparent",
  textColor: "#9B9894",
  gridColor: "rgba(240, 238, 233, 0.06)",
  fontSize: 11,
  fontFamily: "var(--font-jakarta), system-ui, sans-serif",
} as const;

/* ------------------------------------------------------------------ */
/*  DSChartContainer — surface wrapper with responsive aspect ratio     */
/* ------------------------------------------------------------------ */

interface DSChartContainerProps extends React.ComponentProps<"div"> {
  /** Override the default 16:9 aspect ratio class */
  aspectRatio?: string;
}

export function DSChartContainer({
  className,
  aspectRatio = "aspect-video",
  children,
  ...props
}: DSChartContainerProps) {
  return (
    <div
      className={cn(
        "bg-ds-surface rounded-ds-lg p-4",
        aspectRatio,
        className,
      )}
      {...props}
    >
      {children}
    </div>
  );
}

/* ------------------------------------------------------------------ */
/*  DSChartTooltip — custom Recharts tooltip content for Zuralog        */
/* ------------------------------------------------------------------ */

interface DSChartTooltipProps {
  active?: boolean;
  payload?: Array<{
    name?: string;
    value?: number | string;
    color?: string;
    dataKey?: string;
  }>;
  label?: string;
  /** Optional formatter for the label */
  labelFormatter?: (label: string) => string;
  /** Optional formatter for individual values */
  valueFormatter?: (value: number | string) => string;
}

export function DSChartTooltip({
  active,
  payload,
  label,
  labelFormatter,
  valueFormatter,
}: DSChartTooltipProps) {
  if (!active || !payload?.length) {
    return null;
  }

  const formattedLabel = labelFormatter ? labelFormatter(label ?? "") : label;

  return (
    <div
      className={cn(
        "bg-ds-surface-raised rounded-ds-xs px-3 py-2",
        "border-none shadow-md",
        "font-jakarta text-[0.8125rem]",
      )}
    >
      {formattedLabel && (
        <p className="text-ds-text-secondary text-[0.6875rem] font-medium mb-1">
          {formattedLabel}
        </p>
      )}
      <div className="flex flex-col gap-0.5">
        {payload.map((entry, index) => (
          <div key={index} className="flex items-center gap-2">
            <span
              className="size-2 rounded-full shrink-0"
              style={{ backgroundColor: entry.color }}
            />
            <span className="text-ds-text-secondary text-[0.75rem]">
              {entry.name}
            </span>
            <span className="text-ds-text-primary font-medium ml-auto tabular-nums">
              {valueFormatter && entry.value != null
                ? valueFormatter(entry.value)
                : entry.value}
            </span>
          </div>
        ))}
      </div>
    </div>
  );
}
