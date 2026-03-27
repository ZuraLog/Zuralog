"use client";

import React from "react";
import {
  InputOTP,
  InputOTPGroup,
  InputOTPSlot as BaseSlot,
  InputOTPSeparator as BaseSeparator,
} from "@/components/ui/input-otp";
import { cn } from "@/lib/utils";

/* ------------------------------------------------------------------ */
/*  DSInputOTP — root wrapper                                          */
/* ------------------------------------------------------------------ */

export function DSInputOTP({
  className,
  containerClassName,
  ...props
}: React.ComponentProps<typeof InputOTP>) {
  return (
    <InputOTP
      className={cn("font-jakarta", className)}
      containerClassName={cn("gap-2", containerClassName)}
      {...props}
    />
  );
}

/* ------------------------------------------------------------------ */
/*  DSInputOTPGroup                                                    */
/* ------------------------------------------------------------------ */

export function DSInputOTPGroup({
  className,
  ...props
}: React.ComponentProps<typeof InputOTPGroup>) {
  return (
    <InputOTPGroup className={cn("gap-2", className)} {...props} />
  );
}

/* ------------------------------------------------------------------ */
/*  DSInputOTPSlot                                                     */
/* ------------------------------------------------------------------ */

export function DSInputOTPSlot({
  className,
  ...props
}: React.ComponentProps<typeof BaseSlot>) {
  return (
    <BaseSlot
      className={cn(
        "bg-ds-surface rounded-ds-sm w-10 h-12",
        "text-ds-text-primary text-[1.25rem] font-semibold font-jakarta",
        "border-none",
        "data-[active=true]:ring-2 data-[active=true]:ring-ds-sage",
        className,
      )}
      {...props}
    />
  );
}

/* ------------------------------------------------------------------ */
/*  DSInputOTPSeparator                                                */
/* ------------------------------------------------------------------ */

export function DSInputOTPSeparator({
  className,
  ...props
}: React.ComponentProps<"div"> & { className?: string }) {
  return (
    <BaseSeparator
      className={cn("text-ds-text-secondary [&_svg]:text-ds-text-secondary", className)}
      {...props}
    />
  );
}
