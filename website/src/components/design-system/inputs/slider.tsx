"use client";

import * as React from "react";
import { Slider as SliderPrimitive } from "@base-ui/react/slider";
import { cn } from "@/lib/utils";

export interface SliderProps {
  value?: number[];
  defaultValue?: number[];
  onValueChange?: (value: number[]) => void;
  min?: number;
  max?: number;
  step?: number;
  disabled?: boolean;
  className?: string;
}

export function DSSlider({
  value,
  defaultValue,
  onValueChange,
  min = 0,
  max = 100,
  step = 1,
  disabled = false,
  className,
}: SliderProps) {
  const values = React.useMemo(
    () =>
      Array.isArray(value)
        ? value
        : Array.isArray(defaultValue)
          ? defaultValue
          : [min],
    [value, defaultValue, min],
  );

  return (
    <SliderPrimitive.Root
      className={cn("data-horizontal:w-full", disabled && "opacity-40", className)}
      value={value}
      defaultValue={defaultValue}
      onValueChange={onValueChange}
      min={min}
      max={max}
      step={step}
      disabled={disabled}
    >
      <SliderPrimitive.Control className="relative flex w-full touch-none items-center select-none py-2">
        <SliderPrimitive.Track className="relative w-full h-[6px] rounded-full bg-ds-surface-raised overflow-hidden">
          <SliderPrimitive.Indicator
            className="h-full rounded-full ds-pattern-drift"
            style={{ backgroundImage: "var(--ds-pattern-sage)" }}
          />
        </SliderPrimitive.Track>

        {Array.from({ length: values.length }, (_, index) => (
          <SliderPrimitive.Thumb
            key={index}
            className={cn(
              "block w-[18px] h-[18px] rounded-full ds-pattern-drift",
              "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ds-sage focus-visible:ring-offset-2 focus-visible:ring-offset-ds-canvas",
              "after:absolute after:-inset-2",
            )}
            style={{ backgroundImage: "var(--ds-pattern-sage)", backgroundSize: "80px auto" }}
          />
        ))}
      </SliderPrimitive.Control>
    </SliderPrimitive.Root>
  );
}
