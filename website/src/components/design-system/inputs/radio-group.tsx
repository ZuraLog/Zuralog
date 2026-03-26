"use client";

import React from "react";
import { Radio as RadioPrimitive } from "@base-ui/react/radio";
import { RadioGroup as RadioGroupPrimitive } from "@base-ui/react/radio-group";
import { cn } from "@/lib/utils";

export interface RadioGroupProps {
  value?: string;
  defaultValue?: string;
  onValueChange?: (value: string) => void;
  children: React.ReactNode;
  className?: string;
}

export interface RadioItemProps {
  value: string;
  label?: string;
  disabled?: boolean;
  className?: string;
}

export function DSRadioGroup({
  value,
  defaultValue,
  onValueChange,
  children,
  className,
}: RadioGroupProps) {
  return (
    <RadioGroupPrimitive
      value={value}
      defaultValue={defaultValue}
      onValueChange={onValueChange}
      className={cn("flex flex-col gap-3", className)}
    >
      {children}
    </RadioGroupPrimitive>
  );
}

export function RadioItem({
  value,
  label,
  disabled = false,
  className,
}: RadioItemProps) {
  return (
    <div className={cn("inline-flex items-center gap-3", className)}>
      <RadioPrimitive.Root
        value={value}
        disabled={disabled}
        className={cn(
          "relative flex items-center justify-center w-[20px] h-[20px] rounded-full transition-colors",
          "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ds-sage focus-visible:ring-offset-2 focus-visible:ring-offset-ds-dark",
          "border-2",
          "data-checked:border-ds-sage",
          "data-unchecked:border-ds-text-secondary",
          disabled && "opacity-40 cursor-not-allowed",
        )}
      >
        <RadioPrimitive.Indicator className="block w-[10px] h-[10px] rounded-full bg-ds-sage" />
      </RadioPrimitive.Root>

      {label && (
        <span className="text-ds-text-primary font-jakarta text-[0.9375rem]">
          {label}
        </span>
      )}
    </div>
  );
}
