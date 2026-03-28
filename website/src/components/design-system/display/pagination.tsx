"use client";

import React from "react";
import { ChevronLeft, ChevronRight, MoreHorizontal } from "lucide-react";
import { cn } from "@/lib/utils";

/* ------------------------------------------------------------------ */
/*  DSPagination — nav wrapper                                          */
/* ------------------------------------------------------------------ */

export function DSPagination({
  className,
  ...props
}: React.HTMLAttributes<HTMLElement>) {
  return (
    <nav
      role="navigation"
      aria-label="Pagination"
      className={cn(
        "mx-auto flex w-full justify-center font-jakarta",
        className,
      )}
      {...props}
    />
  );
}

/* ------------------------------------------------------------------ */
/*  DSPaginationContent — list                                          */
/* ------------------------------------------------------------------ */

export function DSPaginationContent({
  className,
  ...props
}: React.HTMLAttributes<HTMLUListElement>) {
  return (
    <ul
      className={cn("flex items-center gap-1", className)}
      {...props}
    />
  );
}

/* ------------------------------------------------------------------ */
/*  DSPaginationItem — list item                                        */
/* ------------------------------------------------------------------ */

export function DSPaginationItem(
  props: React.LiHTMLAttributes<HTMLLIElement>,
) {
  return <li {...props} />;
}

/* ------------------------------------------------------------------ */
/*  DSPaginationLink — page button                                      */
/* ------------------------------------------------------------------ */

interface DSPaginationLinkProps
  extends React.AnchorHTMLAttributes<HTMLAnchorElement> {
  isActive?: boolean;
}

export function DSPaginationLink({
  isActive,
  className,
  style,
  ...props
}: DSPaginationLinkProps) {
  return (
    <a
      aria-current={isActive ? "page" : undefined}
      className={cn(
        "inline-flex items-center justify-center",
        "min-w-[36px] min-h-[36px] rounded-ds-xs",
        "text-[0.875rem] font-medium font-jakarta",
        "transition-colors duration-150",
        "cursor-pointer select-none",
        "focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-[rgba(207,225,185,0.3)]",
        isActive
          ? "bg-ds-sage text-ds-text-on-sage bg-cover bg-center bg-no-repeat"
          : "text-ds-text-secondary hover:text-ds-text-primary",
        className,
      )}
      style={
        isActive
          ? { backgroundImage: "var(--ds-pattern-sage)", ...style }
          : style
      }
      {...props}
    />
  );
}

/* ------------------------------------------------------------------ */
/*  DSPaginationPrevious                                                */
/* ------------------------------------------------------------------ */

export function DSPaginationPrevious({
  className,
  ...props
}: React.AnchorHTMLAttributes<HTMLAnchorElement>) {
  return (
    <a
      aria-label="Go to previous page"
      className={cn(
        "inline-flex items-center gap-1.5 px-2",
        "min-h-[36px]",
        "text-ds-text-secondary hover:text-ds-text-primary",
        "text-[0.875rem] font-jakarta",
        "transition-colors duration-150",
        "cursor-pointer select-none",
        "focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-[rgba(207,225,185,0.3)]",
        className,
      )}
      {...props}
    >
      <ChevronLeft className="size-4" />
      <span className="hidden sm:inline">Previous</span>
    </a>
  );
}

/* ------------------------------------------------------------------ */
/*  DSPaginationNext                                                    */
/* ------------------------------------------------------------------ */

export function DSPaginationNext({
  className,
  ...props
}: React.AnchorHTMLAttributes<HTMLAnchorElement>) {
  return (
    <a
      aria-label="Go to next page"
      className={cn(
        "inline-flex items-center gap-1.5 px-2",
        "min-h-[36px]",
        "text-ds-text-secondary hover:text-ds-text-primary",
        "text-[0.875rem] font-jakarta",
        "transition-colors duration-150",
        "cursor-pointer select-none",
        "focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-[rgba(207,225,185,0.3)]",
        className,
      )}
      {...props}
    >
      <span className="hidden sm:inline">Next</span>
      <ChevronRight className="size-4" />
    </a>
  );
}

/* ------------------------------------------------------------------ */
/*  DSPaginationEllipsis                                                */
/* ------------------------------------------------------------------ */

export function DSPaginationEllipsis({
  className,
  ...props
}: React.HTMLAttributes<HTMLSpanElement>) {
  return (
    <span
      aria-hidden
      className={cn(
        "flex items-center justify-center min-w-[36px] min-h-[36px]",
        "text-ds-text-secondary",
        className,
      )}
      {...props}
    >
      <MoreHorizontal className="size-4" />
      <span className="sr-only">More pages</span>
    </span>
  );
}
