"use client";

import React from "react";
import {
  Command,
  CommandDialog as BaseDialog,
  CommandInput as BaseInput,
  CommandList as BaseList,
  CommandEmpty as BaseEmpty,
  CommandGroup as BaseGroup,
  CommandItem as BaseItem,
  CommandSeparator as BaseSeparator,
  CommandShortcut as BaseShortcut,
} from "@/components/ui/command";
import { cn } from "@/lib/utils";

/* ------------------------------------------------------------------ */
/*  DSCommand — root wrapper                                           */
/* ------------------------------------------------------------------ */

export function DSCommand({
  className,
  ...props
}: React.ComponentProps<typeof Command>) {
  return (
    <Command
      className={cn(
        "bg-ds-surface-overlay rounded-ds-xl font-jakarta",
        className,
      )}
      {...props}
    />
  );
}

/* ------------------------------------------------------------------ */
/*  DSCommandDialog — overlay wrapper                                  */
/* ------------------------------------------------------------------ */

export function DSCommandDialog({
  className,
  children,
  ...props
}: React.ComponentProps<typeof BaseDialog>) {
  return (
    <BaseDialog
      className={cn(
        "bg-ds-surface-overlay rounded-ds-xl max-w-lg mx-auto mt-[20vh]",
        "[&_[data-slot=dialog-overlay]]:bg-black/50",
        className,
      )}
      {...props}
    >
      {children}
    </BaseDialog>
  );
}

/* ------------------------------------------------------------------ */
/*  DSCommandInput                                                     */
/* ------------------------------------------------------------------ */

export function DSCommandInput({
  className,
  ...props
}: React.ComponentProps<typeof BaseInput>) {
  return (
    <BaseInput
      className={cn(
        "bg-ds-surface rounded-ds-sm text-ds-text-primary",
        "placeholder:text-ds-text-secondary",
        "border-none px-4 py-3 font-jakarta",
        "[&_svg]:text-ds-text-secondary",
        className,
      )}
      {...props}
    />
  );
}

/* ------------------------------------------------------------------ */
/*  DSCommandList                                                      */
/* ------------------------------------------------------------------ */

export function DSCommandList({
  className,
  ...props
}: React.ComponentProps<typeof BaseList>) {
  return <BaseList className={cn("font-jakarta", className)} {...props} />;
}

/* ------------------------------------------------------------------ */
/*  DSCommandEmpty                                                     */
/* ------------------------------------------------------------------ */

export function DSCommandEmpty({
  className,
  ...props
}: React.ComponentProps<typeof BaseEmpty>) {
  return (
    <BaseEmpty
      className={cn(
        "text-ds-text-secondary text-center py-8 font-jakarta",
        className,
      )}
      {...props}
    />
  );
}

/* ------------------------------------------------------------------ */
/*  DSCommandGroup                                                     */
/* ------------------------------------------------------------------ */

export function DSCommandGroup({
  className,
  ...props
}: React.ComponentProps<typeof BaseGroup>) {
  return (
    <BaseGroup
      className={cn(
        "text-ds-text-primary font-jakarta",
        "**:[[cmdk-group-heading]]:text-ds-text-secondary **:[[cmdk-group-heading]]:text-[0.6875rem] **:[[cmdk-group-heading]]:font-medium **:[[cmdk-group-heading]]:uppercase **:[[cmdk-group-heading]]:tracking-wider **:[[cmdk-group-heading]]:px-3 **:[[cmdk-group-heading]]:py-2",
        className,
      )}
      {...props}
    />
  );
}

/* ------------------------------------------------------------------ */
/*  DSCommandItem                                                      */
/* ------------------------------------------------------------------ */

export function DSCommandItem({
  className,
  ...props
}: React.ComponentProps<typeof BaseItem>) {
  return (
    <BaseItem
      className={cn(
        "px-3 py-2.5 rounded-ds-xs text-ds-text-primary text-[0.875rem] font-jakarta",
        "data-selected:bg-ds-surface",
        "[&_svg]:text-ds-sage [&_svg]:mr-3",
        "cursor-pointer",
        className,
      )}
      {...props}
    />
  );
}

/* ------------------------------------------------------------------ */
/*  DSCommandSeparator                                                 */
/* ------------------------------------------------------------------ */

export function DSCommandSeparator({
  className,
  ...props
}: React.ComponentProps<typeof BaseSeparator>) {
  return (
    <BaseSeparator
      className={cn("h-px bg-[rgba(240,238,233,0.06)] my-1", className)}
      {...props}
    />
  );
}

/* ------------------------------------------------------------------ */
/*  DSCommandShortcut                                                  */
/* ------------------------------------------------------------------ */

export function DSCommandShortcut({
  className,
  ...props
}: React.ComponentProps<typeof BaseShortcut>) {
  return (
    <BaseShortcut
      className={cn(
        "text-ds-text-secondary text-[0.6875rem] ml-auto font-jakarta",
        className,
      )}
      {...props}
    />
  );
}
