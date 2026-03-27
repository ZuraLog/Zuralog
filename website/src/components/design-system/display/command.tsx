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
        "bg-ds-surface-overlay rounded-ds-xl font-jakarta overflow-hidden",
        /* Override cmdk root rendered by shadcn */
        "[&_[data-slot=command]]:bg-ds-surface-overlay [&_[data-slot=command]]:rounded-ds-xl [&_[data-slot=command]]:overflow-hidden [&_[data-slot=command]]:p-0",
        /* Override input wrapper */
        "[&_[data-slot=command-input-wrapper]]:bg-ds-surface [&_[data-slot=command-input-wrapper]]:border-b [&_[data-slot=command-input-wrapper]]:border-[rgba(240,238,233,0.06)] [&_[data-slot=command-input-wrapper]]:p-3",
        /* Override InputGroup inside input wrapper — remove all borders and shadows */
        "[&_[data-slot=command-input-wrapper]_.group]:bg-transparent [&_[data-slot=command-input-wrapper]_.group]:border-none [&_[data-slot=command-input-wrapper]_.group]:shadow-none [&_[data-slot=command-input-wrapper]_.group]:ring-0",
        "[&_[data-slot=command-input-wrapper]_[data-slot=input-group]]:bg-transparent [&_[data-slot=command-input-wrapper]_[data-slot=input-group]]:border-none [&_[data-slot=command-input-wrapper]_[data-slot=input-group]]:shadow-none [&_[data-slot=command-input-wrapper]_[data-slot=input-group]]:ring-0",
        /* Override selected item */
        "[&_[data-slot=command-item][data-selected=true]]:bg-[rgba(207,225,185,0.08)] [&_[data-slot=command-item][data-selected=true]]:text-ds-sage",
        "[&_[data-slot=command-item][data-selected=true]_svg]:text-ds-sage",
        /* Override group headings */
        "[&_[cmdk-group-heading]]:text-ds-text-secondary [&_[cmdk-group-heading]]:text-[0.6875rem] [&_[cmdk-group-heading]]:font-medium [&_[cmdk-group-heading]]:uppercase [&_[cmdk-group-heading]]:tracking-wider",
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
        "text-ds-text-primary bg-transparent border-none font-jakarta text-[0.875rem]",
        "placeholder:text-ds-text-secondary",
        "outline-none",
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
        "data-selected:bg-[rgba(207,225,185,0.08)] data-selected:text-ds-sage",
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
