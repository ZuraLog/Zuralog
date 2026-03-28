"use client";

import React from "react";
import { cn } from "@/lib/utils";

export interface TextFieldProps
  extends React.InputHTMLAttributes<HTMLInputElement> {
  label?: string;
  error?: string;
  fullWidth?: boolean;
}

export const TextField = React.forwardRef<HTMLInputElement, TextFieldProps>(
  ({ label, error, fullWidth, className, id, ...rest }, ref) => {
    const inputId = id ?? React.useId();

    return (
      <div className={cn(fullWidth && "w-full")}>
        {label && (
          <label
            htmlFor={inputId}
            className="text-ds-text-secondary text-[0.6875rem] font-medium font-jakarta mb-1.5 block"
          >
            {label}
          </label>
        )}
        <input
          ref={ref}
          id={inputId}
          className={cn(
            "bg-ds-surface rounded-ds-sm px-4 py-3",
            "text-ds-text-primary font-jakarta text-[1rem]",
            "placeholder:text-ds-text-secondary",
            "focus:outline-none focus:ring-1 focus:ring-[var(--color-ds-sage-ring)]",
            "disabled:opacity-40",
            error && "ring-1 ring-ds-error/50",
            fullWidth && "w-full",
            className,
          )}
          aria-invalid={error ? true : undefined}
          aria-describedby={error ? `${inputId}-error` : undefined}
          {...rest}
        />
        {error && (
          <p
            id={`${inputId}-error`}
            className="text-ds-error text-[0.6875rem] font-jakarta mt-1.5"
            role="alert"
          >
            {error}
          </p>
        )}
      </div>
    );
  },
);

TextField.displayName = "TextField";
