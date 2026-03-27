"use client";

import React from "react";
import { cn } from "@/lib/utils";

type AlertVariant = "default" | "success" | "warning" | "error";

export interface DSAlertProps extends React.HTMLAttributes<HTMLDivElement> {
  variant?: AlertVariant;
  icon?: React.ReactNode;
  title?: string;
  description?: string;
}

const variantStyles: Record<AlertVariant, { bg: string; border: string }> = {
  default: {
    bg: "bg-ds-surface",
    border: "border-l-ds-text-secondary",
  },
  success: {
    bg: "bg-[rgba(52,199,89,0.06)]",
    border: "border-l-ds-success",
  },
  warning: {
    bg: "bg-[rgba(255,149,0,0.06)]",
    border: "border-l-ds-warning",
  },
  error: {
    bg: "bg-[rgba(255,59,48,0.06)]",
    border: "border-l-ds-error",
  },
};

export function DSAlert({
  variant = "default",
  icon,
  title,
  description,
  children,
  className,
  ...props
}: DSAlertProps) {
  const styles = variantStyles[variant];

  return (
    <div
      role="alert"
      className={cn(
        "rounded-ds-sm p-4",
        "border-l-[3px]",
        styles.bg,
        styles.border,
        "font-jakarta",
        className,
      )}
      {...props}
    >
      <div className="flex gap-3">
        {icon && (
          <div className="shrink-0 mt-0.5" aria-hidden="true">
            {icon}
          </div>
        )}
        <div className="flex-1 min-w-0">
          {title && (
            <div className="text-ds-text-primary text-[0.875rem] font-medium leading-snug">
              {title}
            </div>
          )}
          {description && (
            <div
              className={cn(
                "text-ds-text-secondary text-[0.8125rem] leading-relaxed",
                title && "mt-1",
              )}
            >
              {description}
            </div>
          )}
          {children}
        </div>
      </div>
    </div>
  );
}
