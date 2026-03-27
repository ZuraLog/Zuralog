import React from "react";
import {
  Breadcrumb,
  BreadcrumbList as BaseList,
  BreadcrumbItem as BaseItem,
  BreadcrumbLink as BaseLink,
  BreadcrumbPage as BasePage,
  BreadcrumbSeparator as BaseSeparator,
  BreadcrumbEllipsis as BaseEllipsis,
} from "@/components/ui/breadcrumb";
import { cn } from "@/lib/utils";

/* ------------------------------------------------------------------ */
/*  DSBreadcrumb — root wrapper                                        */
/* ------------------------------------------------------------------ */

export function DSBreadcrumb({
  className,
  ...props
}: React.ComponentProps<typeof Breadcrumb>) {
  return <Breadcrumb className={cn("font-jakarta", className)} {...props} />;
}

/* ------------------------------------------------------------------ */
/*  DSBreadcrumbList                                                   */
/* ------------------------------------------------------------------ */

export function DSBreadcrumbList({
  className,
  ...props
}: React.ComponentProps<typeof BaseList>) {
  return (
    <BaseList
      className={cn(
        "text-ds-text-secondary text-[0.8125rem] font-jakarta",
        className,
      )}
      {...props}
    />
  );
}

/* ------------------------------------------------------------------ */
/*  DSBreadcrumbItem                                                   */
/* ------------------------------------------------------------------ */

export function DSBreadcrumbItem({
  className,
  ...props
}: React.ComponentProps<typeof BaseItem>) {
  return <BaseItem className={cn("font-jakarta", className)} {...props} />;
}

/* ------------------------------------------------------------------ */
/*  DSBreadcrumbLink                                                   */
/* ------------------------------------------------------------------ */

export function DSBreadcrumbLink({
  className,
  ...props
}: React.ComponentProps<typeof BaseLink>) {
  return (
    <BaseLink
      className={cn(
        "text-ds-text-secondary hover:text-ds-sage transition-colors font-jakarta",
        className,
      )}
      {...props}
    />
  );
}

/* ------------------------------------------------------------------ */
/*  DSBreadcrumbPage — current (active) item                           */
/* ------------------------------------------------------------------ */

export function DSBreadcrumbPage({
  className,
  ...props
}: React.ComponentProps<typeof BasePage>) {
  return (
    <BasePage
      className={cn("text-ds-text-primary font-jakarta", className)}
      {...props}
    />
  );
}

/* ------------------------------------------------------------------ */
/*  DSBreadcrumbSeparator                                              */
/* ------------------------------------------------------------------ */

export function DSBreadcrumbSeparator({
  className,
  children,
  ...props
}: React.ComponentProps<typeof BaseSeparator>) {
  return (
    <BaseSeparator
      className={cn("text-ds-text-secondary/40", className)}
      {...props}
    >
      {children ?? "/"}
    </BaseSeparator>
  );
}

/* ------------------------------------------------------------------ */
/*  DSBreadcrumbEllipsis                                               */
/* ------------------------------------------------------------------ */

export function DSBreadcrumbEllipsis({
  className,
  ...props
}: React.ComponentProps<typeof BaseEllipsis>) {
  return (
    <BaseEllipsis
      className={cn("text-ds-text-secondary", className)}
      {...props}
    />
  );
}
