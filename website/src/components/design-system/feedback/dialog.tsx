"use client";

import React from "react";
import { Dialog as DialogPrimitive } from "@base-ui/react/dialog";
import { cn } from "@/lib/utils";

/* ------------------------------------------------------------------ */
/*  DSDialog — wraps Root                                              */
/* ------------------------------------------------------------------ */

export function DSDialog(props: React.ComponentProps<typeof DialogPrimitive.Root>) {
  return <DialogPrimitive.Root {...props} />;
}

/* ------------------------------------------------------------------ */
/*  DSDialogTrigger — wraps Trigger                                    */
/* ------------------------------------------------------------------ */

export function DSDialogTrigger({
  children,
  ...props
}: React.ComponentProps<typeof DialogPrimitive.Trigger>) {
  // If children is a single React element, use render prop to avoid button-in-button nesting
  if (React.isValidElement(children)) {
    return (
      <DialogPrimitive.Trigger render={children} {...props} />
    );
  }
  return <DialogPrimitive.Trigger {...props}>{children}</DialogPrimitive.Trigger>;
}

/* ------------------------------------------------------------------ */
/*  DSDialogContent — wraps Portal + Backdrop + Popup                  */
/* ------------------------------------------------------------------ */

interface DSDialogContentProps {
  children: React.ReactNode;
  className?: string;
}

export function DSDialogContent({ children, className }: DSDialogContentProps) {
  return (
    <DialogPrimitive.Portal>
      <DialogPrimitive.Backdrop
        className={cn(
          "fixed inset-0 bg-black/50 z-50",
          "transition-opacity duration-200",
          "data-[state=open]:opacity-100 data-[state=closed]:opacity-0",
        )}
      />
      <DialogPrimitive.Popup
        className={cn(
          "fixed left-1/2 top-1/2 z-50 -translate-x-1/2 -translate-y-1/2",
          "bg-ds-surface-overlay rounded-ds-xl",
          "max-w-sm sm:max-w-md w-[calc(100%-2rem)]",
          "p-6",
          "transition-all duration-300 ease-[cubic-bezier(0.34,1.56,0.64,1)] origin-center",
          "data-[state=open]:opacity-100 data-[state=open]:scale-100",
          "data-[state=closed]:opacity-0 data-[state=closed]:scale-95",
          className,
        )}
      >
        {children}
      </DialogPrimitive.Popup>
    </DialogPrimitive.Portal>
  );
}

/* ------------------------------------------------------------------ */
/*  DSDialogTitle                                                      */
/* ------------------------------------------------------------------ */

export function DSDialogTitle({
  className,
  ...props
}: React.ComponentProps<typeof DialogPrimitive.Title>) {
  return (
    <DialogPrimitive.Title
      className={cn(
        "text-ds-text-primary text-[1.0625rem] font-medium font-jakarta",
        className,
      )}
      {...props}
    />
  );
}

/* ------------------------------------------------------------------ */
/*  DSDialogDescription                                                */
/* ------------------------------------------------------------------ */

export function DSDialogDescription({
  className,
  ...props
}: React.ComponentProps<typeof DialogPrimitive.Description>) {
  return (
    <DialogPrimitive.Description
      className={cn(
        "text-ds-text-secondary text-[0.875rem] font-jakarta",
        className,
      )}
      {...props}
    />
  );
}

/* ------------------------------------------------------------------ */
/*  DSDialogClose                                                      */
/* ------------------------------------------------------------------ */

export function DSDialogClose({
  children,
  ...props
}: React.ComponentProps<typeof DialogPrimitive.Close>) {
  if (React.isValidElement(children)) {
    return (
      <DialogPrimitive.Close render={children} {...props} />
    );
  }
  return <DialogPrimitive.Close {...props}>{children}</DialogPrimitive.Close>;
}
