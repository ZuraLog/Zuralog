"use client";

import React from "react";
import {
  Table,
  TableHeader,
  TableBody,
  TableFooter,
  TableHead,
  TableRow,
  TableCell,
  TableCaption,
} from "@/components/ui/table";
import { cn } from "@/lib/utils";

/* ------------------------------------------------------------------ */
/*  DSTable — surface container with Zuralog dark-mode styling          */
/* ------------------------------------------------------------------ */

export function DSTable({
  className,
  ...props
}: React.ComponentProps<typeof Table>) {
  return (
    <div className="bg-ds-surface rounded-ds-lg overflow-hidden">
      <Table className={cn("font-jakarta", className)} {...props} />
    </div>
  );
}

/* ------------------------------------------------------------------ */
/*  DSTableHeader                                                       */
/* ------------------------------------------------------------------ */

export function DSTableHeader({
  className,
  ...props
}: React.ComponentProps<typeof TableHeader>) {
  return (
    <TableHeader
      className={cn("bg-ds-surface-raised/50 [&_tr]:border-none", className)}
      {...props}
    />
  );
}

/* ------------------------------------------------------------------ */
/*  DSTableBody                                                         */
/* ------------------------------------------------------------------ */

export function DSTableBody({
  className,
  ...props
}: React.ComponentProps<typeof TableBody>) {
  return <TableBody className={cn(className)} {...props} />;
}

/* ------------------------------------------------------------------ */
/*  DSTableFooter                                                       */
/* ------------------------------------------------------------------ */

export function DSTableFooter({
  className,
  ...props
}: React.ComponentProps<typeof TableFooter>) {
  return (
    <TableFooter
      className={cn(
        "bg-ds-surface-raised/30 border-t border-[rgba(240,238,233,0.04)]",
        "text-ds-text-secondary font-jakarta",
        className,
      )}
      {...props}
    />
  );
}

/* ------------------------------------------------------------------ */
/*  DSTableHead — header cell                                           */
/* ------------------------------------------------------------------ */

export function DSTableHead({
  className,
  ...props
}: React.ComponentProps<typeof TableHead>) {
  return (
    <TableHead
      className={cn(
        "px-4 py-3 text-ds-text-secondary text-[0.6875rem] font-medium uppercase tracking-wider",
        className,
      )}
      {...props}
    />
  );
}

/* ------------------------------------------------------------------ */
/*  DSTableRow                                                          */
/* ------------------------------------------------------------------ */

export function DSTableRow({
  className,
  ...props
}: React.ComponentProps<typeof TableRow>) {
  return (
    <TableRow
      className={cn(
        "border-b border-[rgba(240,238,233,0.04)]",
        "hover:bg-ds-surface-raised/30",
        "data-[state=selected]:bg-ds-sage/5",
        className,
      )}
      {...props}
    />
  );
}

/* ------------------------------------------------------------------ */
/*  DSTableCell                                                         */
/* ------------------------------------------------------------------ */

export function DSTableCell({
  className,
  ...props
}: React.ComponentProps<typeof TableCell>) {
  return (
    <TableCell
      className={cn(
        "px-4 py-3 text-ds-text-primary text-[0.875rem] font-jakarta",
        className,
      )}
      {...props}
    />
  );
}

/* ------------------------------------------------------------------ */
/*  DSTableCaption                                                      */
/* ------------------------------------------------------------------ */

export function DSTableCaption({
  className,
  ...props
}: React.ComponentProps<typeof TableCaption>) {
  return (
    <TableCaption
      className={cn(
        "text-ds-text-secondary text-[0.75rem] font-jakarta py-3",
        className,
      )}
      {...props}
    />
  );
}
