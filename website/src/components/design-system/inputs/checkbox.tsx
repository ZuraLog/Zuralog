"use client";

import React from "react";
import { Checkbox as CheckboxPrimitive } from "@base-ui/react/checkbox";
import { cn } from "@/lib/utils";
import { PatternOverlay } from "@/components/design-system/primitives/pattern-overlay";

export interface CheckboxProps {
  checked?: boolean;
  defaultChecked?: boolean;
  onCheckedChange?: (checked: boolean) => void;
  disabled?: boolean;
  label?: string;
  className?: string;
}

function CheckIcon() {
  return (
    <svg
      width="12"
      height="12"
      viewBox="0 0 12 12"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      aria-hidden="true"
    >
      <path
        d="M2.5 6L5 8.5L9.5 3.5"
        stroke="currentColor"
        strokeWidth="1.75"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
}

export function DSCheckbox({
  checked,
  defaultChecked,
  onCheckedChange,
  disabled = false,
  label,
  className,
}: CheckboxProps) {
  return (
    <div className={cn("inline-flex items-center gap-3", className)}>
      <CheckboxPrimitive.Root
        checked={checked}
        defaultChecked={defaultChecked}
        onCheckedChange={onCheckedChange}
        disabled={disabled}
        className={cn(
          "relative flex items-center justify-center w-[20px] h-[20px] rounded-[4px] overflow-hidden transition-colors",
          "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ds-sage focus-visible:ring-offset-2 focus-visible:ring-offset-ds-dark",
          "after:absolute after:-inset-3",
          "data-checked:bg-ds-sage",
          "data-unchecked:border-2 data-unchecked:border-ds-text-secondary data-unchecked:bg-transparent",
          disabled && "opacity-40 cursor-not-allowed",
        )}
      >
        <CheckboxPrimitive.Indicator className="relative z-10 text-ds-text-on-sage flex items-center justify-center">
          <CheckIcon />
        </CheckboxPrimitive.Indicator>

        {/* Pattern overlay when checked — rendered always but only visible when parent has sage bg */}
        <PatternOverlay
          variant="sage"
          opacity={0.28}
          blend="color-burn"
        />
      </CheckboxPrimitive.Root>

      {label && (
        <span className="text-ds-text-primary font-jakarta text-[0.9375rem]">
          {label}
        </span>
      )}
    </div>
  );
}
