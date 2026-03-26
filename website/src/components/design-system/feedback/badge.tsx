import { cva, type VariantProps } from "class-variance-authority";
import { cn } from "@/lib/utils";

const badgeVariants = cva(
  "inline-flex items-center justify-center rounded-ds-pill text-[0.6875rem] font-bold font-jakarta min-w-[16px] h-4 px-1.5",
  {
    variants: {
      variant: {
        error: "bg-ds-error text-white",
        sage: "bg-ds-sage text-ds-text-on-sage",
        neutral: "bg-ds-surface-raised text-ds-text-secondary",
      },
    },
    defaultVariants: {
      variant: "error",
    },
  },
);

export interface BadgeProps extends VariantProps<typeof badgeVariants> {
  variant?: "error" | "sage" | "neutral";
  children: React.ReactNode;
  className?: string;
}

export function Badge({ variant, children, className }: BadgeProps) {
  return (
    <span className={cn(badgeVariants({ variant }), className)}>
      {children}
    </span>
  );
}
