"use client";

import React from "react";
import { cn } from "@/lib/utils";

export interface DSLabelProps
  extends React.LabelHTMLAttributes<HTMLLabelElement> {
  disabled?: boolean;
}

export const DSLabel = React.forwardRef<HTMLLabelElement, DSLabelProps>(
  ({ className, disabled, ...props }, ref) => {
    return (
      <label
        ref={ref}
        className={cn(
          "text-ds-text-secondary text-[0.6875rem] font-medium font-jakarta",
          "select-none",
          disabled && "opacity-50 pointer-events-none",
          className,
        )}
        aria-disabled={disabled || undefined}
        {...props}
      />
    );
  },
);

DSLabel.displayName = "DSLabel";
