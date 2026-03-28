"use client";

import React from "react";
import { cva, type VariantProps } from "class-variance-authority";
import { motion, type HTMLMotionProps } from "framer-motion";
import { cn } from "@/lib/utils";

/* ------------------------------------------------------------------ */
/*  Spinner (internal only)                                           */
/* ------------------------------------------------------------------ */

function Spinner({ className }: { className?: string }) {
  return (
    <svg
      className={cn("animate-spin h-5 w-5", className)}
      viewBox="0 0 24 24"
      fill="none"
    >
      <circle
        className="opacity-25"
        cx="12"
        cy="12"
        r="10"
        stroke="currentColor"
        strokeWidth="3"
      />
      <path
        className="opacity-75"
        fill="currentColor"
        d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"
      />
    </svg>
  );
}

/* ------------------------------------------------------------------ */
/*  CVA variants                                                      */
/* ------------------------------------------------------------------ */

const buttonVariants = cva(
  [
    "relative isolate overflow-hidden inline-flex items-center justify-center",
    "font-jakarta rounded-ds-pill",
    "transition-all duration-300 ease-[cubic-bezier(0.16,1,0.3,1)]",
    "disabled:opacity-40 disabled:pointer-events-none",
    "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ds-sage focus-visible:ring-offset-2 focus-visible:ring-offset-ds-canvas",
  ],
  {
    variants: {
      intent: {
        primary: "text-ds-text-on-sage ds-pattern-drift active:shadow-[inset_0_2px_4px_rgba(0,0,0,0.2)]",
        destructive: "text-white ds-pattern-drift active:shadow-[inset_0_2px_4px_rgba(0,0,0,0.3)]",
        secondary:
          "bg-transparent border-[1.5px] border-[var(--color-ds-secondary-border)] text-ds-text-primary",
        text: "bg-transparent text-ds-sage font-semibold",
      },
      size: {
        lg: "h-[52px] px-7 text-[0.9375rem] font-semibold",
        md: "h-[44px] px-6 text-[0.9375rem] font-semibold",
        sm: "h-[32px] px-[18px] text-[0.8125rem] font-medium",
      },
    },
    defaultVariants: {
      intent: "primary",
      size: "md",
    },
  },
);

/* ------------------------------------------------------------------ */
/*  Hover glow per intent                                              */
/* ------------------------------------------------------------------ */

const HOVER_GLOW: Record<string, string> = {
  primary: "0 0 20px rgba(207,225,185,0.35), 0 0 6px rgba(207,225,185,0.2)",
  destructive: "0 0 20px rgba(255,59,48,0.3), 0 0 6px rgba(255,59,48,0.15)",
  secondary: "0 0 16px rgba(240,238,233,0.1), 0 0 4px rgba(240,238,233,0.06)",
  text: "none",
};

/* ------------------------------------------------------------------ */
/*  Spinner color per intent                                          */
/* ------------------------------------------------------------------ */

const SPINNER_COLOR: Record<string, string> = {
  primary: "text-ds-text-on-sage",
  destructive: "text-white",
  secondary: "text-ds-text-primary",
  text: "text-ds-text-primary",
};

/* ------------------------------------------------------------------ */
/*  Props                                                             */
/* ------------------------------------------------------------------ */

export interface ButtonProps
  extends Omit<
      HTMLMotionProps<"button">,
      "children" | keyof VariantProps<typeof buttonVariants>
    >,
    VariantProps<typeof buttonVariants> {
  children?: React.ReactNode;
  loading?: boolean;
  leftIcon?: React.ReactNode;
  rightIcon?: React.ReactNode;
}

/* ------------------------------------------------------------------ */
/*  Component                                                         */
/* ------------------------------------------------------------------ */

export const Button = React.forwardRef<HTMLButtonElement, ButtonProps>(
  (
    {
      className,
      intent = "primary",
      size = "md",
      loading = false,
      disabled,
      leftIcon,
      rightIcon,
      children,
      style,
      ...rest
    },
    ref,
  ) => {
    const resolvedIntent = intent ?? "primary";
    const isDisabled = disabled || loading;
    const bgImage =
      resolvedIntent === "primary"
        ? "var(--ds-pattern-sage)"
        : resolvedIntent === "destructive"
          ? "url('/patterns/crimson.png')"
          : undefined;

    const hoverGlow = HOVER_GLOW[resolvedIntent] ?? "none";

    return (
      <motion.button
        ref={ref}
        className={cn(buttonVariants({ intent, size }), className)}
        disabled={isDisabled}
        aria-busy={loading || undefined}
        aria-disabled={isDisabled || undefined}
        whileHover={
          isDisabled
            ? undefined
            : {
                scale: 1.03,
                boxShadow: hoverGlow,
              }
        }
        whileTap={isDisabled ? undefined : { scale: 0.97, opacity: 0.85 }}
        transition={{ type: "spring", stiffness: 400, damping: 25 }}
        style={bgImage ? { backgroundImage: bgImage, ...style } : style}
        {...rest}
      >
        <span className="relative z-[2] inline-flex items-center justify-center gap-2">
          {loading ? (
            <Spinner className={SPINNER_COLOR[resolvedIntent]} />
          ) : (
            <>
              {leftIcon && (
                <span className="inline-flex shrink-0">{leftIcon}</span>
              )}
              {children}
              {rightIcon && (
                <span className="inline-flex shrink-0">{rightIcon}</span>
              )}
            </>
          )}
        </span>
      </motion.button>
    );
  },
);

Button.displayName = "Button";
