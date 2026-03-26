"use client";

import React from "react";
import { Accordion as AccordionPrimitive } from "@base-ui/react/accordion";
import { ChevronDown } from "lucide-react";
import { cn } from "@/lib/utils";

/* ------------------------------------------------------------------ */
/*  DSAccordion — wraps Root with surface styling                      */
/* ------------------------------------------------------------------ */

export function DSAccordion({
  className,
  ...props
}: React.ComponentProps<typeof AccordionPrimitive.Root>) {
  return (
    <AccordionPrimitive.Root
      className={cn(
        "flex flex-col bg-ds-surface rounded-ds-lg overflow-hidden",
        className,
      )}
      {...props}
    />
  );
}

/* ------------------------------------------------------------------ */
/*  DSAccordionItem                                                    */
/* ------------------------------------------------------------------ */

export function DSAccordionItem({
  className,
  ...props
}: React.ComponentProps<typeof AccordionPrimitive.Item>) {
  return (
    <AccordionPrimitive.Item
      className={cn("group", className)}
      {...props}
    />
  );
}

/* ------------------------------------------------------------------ */
/*  DSAccordionTrigger                                                 */
/* ------------------------------------------------------------------ */

export function DSAccordionTrigger({
  className,
  children,
  ...props
}: React.ComponentProps<typeof AccordionPrimitive.Trigger>) {
  return (
    <AccordionPrimitive.Header>
      <AccordionPrimitive.Trigger
        className={cn(
          "flex w-full items-center justify-between py-3 px-4",
          "text-ds-text-primary font-jakarta font-medium text-left",
          "cursor-pointer",
          className,
        )}
        {...props}
      >
        {children}
        <ChevronDown
          className={cn(
            "size-4 text-ds-sage shrink-0 ml-2",
            "transition-transform duration-250",
            "group-data-[panel-open]:rotate-180",
          )}
          aria-hidden="true"
        />
      </AccordionPrimitive.Trigger>
    </AccordionPrimitive.Header>
  );
}

/* ------------------------------------------------------------------ */
/*  DSAccordionContent                                                 */
/* ------------------------------------------------------------------ */

export function DSAccordionContent({
  className,
  children,
  ...props
}: React.ComponentProps<typeof AccordionPrimitive.Panel>) {
  return (
    <AccordionPrimitive.Panel
      className={cn(
        "px-4 pb-4",
        "text-ds-text-secondary text-[0.875rem] font-jakarta",
        className,
      )}
      {...props}
    >
      {children}
    </AccordionPrimitive.Panel>
  );
}
