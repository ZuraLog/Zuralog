"use client";

import React, { useCallback } from "react";
import { cn } from "@/lib/utils";

export interface ToggleProps {
  checked?: boolean;
  defaultChecked?: boolean;
  onCheckedChange?: (checked: boolean) => void;
  disabled?: boolean;
  label?: string;
  className?: string;
}

export function Toggle({
  checked: controlledChecked,
  defaultChecked = false,
  onCheckedChange,
  disabled = false,
  label,
  className,
}: ToggleProps) {
  const isControlled = controlledChecked !== undefined;
  const [internalChecked, setInternalChecked] = React.useState(defaultChecked);
  const isOn = isControlled ? controlledChecked : internalChecked;

  const handleClick = useCallback(() => {
    if (disabled) return;
    const next = !isOn;
    if (!isControlled) setInternalChecked(next);
    onCheckedChange?.(next);
  }, [disabled, isOn, isControlled, onCheckedChange]);

  const handleKeyDown = useCallback(
    (e: React.KeyboardEvent) => {
      if (e.key === " " || e.key === "Enter") {
        e.preventDefault();
        handleClick();
      }
    },
    [handleClick],
  );

  return (
    <div className={cn("inline-flex items-center gap-3", className)}>
      <button
        type="button"
        role="switch"
        aria-checked={isOn}
        disabled={disabled}
        onClick={handleClick}
        onKeyDown={handleKeyDown}
        className={cn(
          "relative w-[44px] h-[26px] rounded-full transition-colors duration-150",
          "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ds-sage focus-visible:ring-offset-2 focus-visible:ring-offset-ds-canvas",
          isOn ? "ds-pattern-drift" : "bg-ds-surface-raised",
          disabled && "opacity-40 cursor-not-allowed",
        )}
        style={isOn ? { backgroundImage: "url('/patterns/sage.png')" } : undefined}
      >
        {/* Thumb */}
        <span
          className={cn(
            "absolute top-[3px] block h-[20px] w-[20px] rounded-full z-[2]",
            isOn
              ? "translate-x-[21px] bg-white"
              : "translate-x-[3px] bg-ds-text-secondary",
          )}
          style={{ transition: "transform 0.4s cubic-bezier(0.34, 1.56, 0.64, 1), background-color 0.15s" }}
        />
      </button>

      {label && (
        <span className="text-ds-text-primary font-jakarta text-[0.9375rem]">
          {label}
        </span>
      )}
    </div>
  );
}
