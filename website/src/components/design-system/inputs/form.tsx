"use client";

import React from "react";
import { cn } from "@/lib/utils";

/* ------------------------------------------------------------------ */
/*  DSFormField — layout wrapper for label + input + description/error  */
/* ------------------------------------------------------------------ */

interface DSFormFieldProps extends React.ComponentProps<"div"> {
  children: React.ReactNode;
}

export function DSFormField({ className, children, ...props }: DSFormFieldProps) {
  return (
    <div className={cn("flex flex-col gap-1.5", className)} {...props}>
      {children}
    </div>
  );
}

/* ------------------------------------------------------------------ */
/*  DSFormLabel — styled label                                          */
/* ------------------------------------------------------------------ */

interface DSFormLabelProps extends React.ComponentProps<"label"> {
  required?: boolean;
}

export function DSFormLabel({
  className,
  required,
  children,
  ...props
}: DSFormLabelProps) {
  return (
    <label
      className={cn(
        "text-ds-text-secondary text-[0.6875rem] font-medium font-jakarta",
        className,
      )}
      {...props}
    >
      {children}
      {required && (
        <span className="text-ds-error ml-0.5" aria-hidden="true">
          *
        </span>
      )}
    </label>
  );
}

/* ------------------------------------------------------------------ */
/*  DSFormDescription — helper text below input                         */
/* ------------------------------------------------------------------ */

export function DSFormDescription({
  className,
  ...props
}: React.ComponentProps<"p">) {
  return (
    <p
      className={cn(
        "text-ds-text-secondary text-[0.75rem] font-jakarta",
        className,
      )}
      {...props}
    />
  );
}

/* ------------------------------------------------------------------ */
/*  DSFormMessage — error message below input                           */
/* ------------------------------------------------------------------ */

export function DSFormMessage({
  className,
  children,
  ...props
}: React.ComponentProps<"p">) {
  if (!children) return null;

  return (
    <p
      className={cn(
        "text-[#FF375F] text-[0.75rem] font-jakarta",
        className,
      )}
      role="alert"
      {...props}
    >
      {children}
    </p>
  );
}
