import { cn } from "@/lib/utils";

export interface DividerProps {
  inset?: boolean;
  className?: string;
}

export function Divider({ inset = false, className }: DividerProps) {
  return (
    <div
      role="separator"
      className={cn(
        "h-px bg-[rgba(240,238,233,0.06)]",
        inset && "mx-4",
        className,
      )}
    />
  );
}
