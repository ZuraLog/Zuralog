import React from "react";
import {
  NavigationMenu,
  NavigationMenuList as BaseList,
  NavigationMenuItem as BaseItem,
  NavigationMenuTrigger as BaseTrigger,
  NavigationMenuContent as BaseContent,
  NavigationMenuLink as BaseLink,
  NavigationMenuIndicator as BaseIndicator,
  navigationMenuTriggerStyle,
} from "@/components/ui/navigation-menu";
import { cn } from "@/lib/utils";

/* ------------------------------------------------------------------ */
/*  DSNavigationMenu — root wrapper                                    */
/* ------------------------------------------------------------------ */

export function DSNavigationMenu({
  className,
  ...props
}: React.ComponentProps<typeof NavigationMenu>) {
  return (
    <NavigationMenu
      className={cn("font-jakarta", className)}
      {...props}
    />
  );
}

/* ------------------------------------------------------------------ */
/*  DSNavigationMenuList                                               */
/* ------------------------------------------------------------------ */

export function DSNavigationMenuList({
  className,
  ...props
}: React.ComponentProps<typeof BaseList>) {
  return (
    <BaseList className={cn("font-jakarta", className)} {...props} />
  );
}

/* ------------------------------------------------------------------ */
/*  DSNavigationMenuItem                                               */
/* ------------------------------------------------------------------ */

export function DSNavigationMenuItem({
  className,
  ...props
}: React.ComponentProps<typeof BaseItem>) {
  return <BaseItem className={cn(className)} {...props} />;
}

/* ------------------------------------------------------------------ */
/*  DSNavigationMenuTrigger                                            */
/* ------------------------------------------------------------------ */

export function DSNavigationMenuTrigger({
  className,
  ...props
}: React.ComponentProps<typeof BaseTrigger>) {
  return (
    <BaseTrigger
      className={cn(
        "text-ds-text-primary font-jakarta text-[0.875rem]",
        "hover:bg-ds-surface-raised focus:bg-ds-surface-raised",
        "data-popup-open:bg-ds-surface data-open:bg-ds-surface",
        "rounded-ds-sm",
        className,
      )}
      {...props}
    />
  );
}

/* ------------------------------------------------------------------ */
/*  DSNavigationMenuContent                                            */
/* ------------------------------------------------------------------ */

export function DSNavigationMenuContent({
  className,
  ...props
}: React.ComponentProps<typeof BaseContent>) {
  return (
    <BaseContent
      className={cn(
        "bg-ds-surface-raised rounded-ds-sm font-jakarta",
        "border border-[rgba(240,238,233,0.06)]",
        className,
      )}
      {...props}
    />
  );
}

/* ------------------------------------------------------------------ */
/*  DSNavigationMenuLink                                               */
/* ------------------------------------------------------------------ */

export function DSNavigationMenuLink({
  className,
  ...props
}: React.ComponentProps<typeof BaseLink>) {
  return (
    <BaseLink
      className={cn(
        "text-ds-text-primary text-[0.875rem] font-jakarta",
        "hover:bg-ds-surface rounded-ds-xs",
        "data-active:bg-ds-surface/50",
        className,
      )}
      {...props}
    />
  );
}

/* ------------------------------------------------------------------ */
/*  DSNavigationMenuIndicator                                          */
/* ------------------------------------------------------------------ */

export function DSNavigationMenuIndicator({
  className,
  ...props
}: React.ComponentProps<typeof BaseIndicator>) {
  return (
    <BaseIndicator className={cn(className)} {...props} />
  );
}

export { navigationMenuTriggerStyle };
