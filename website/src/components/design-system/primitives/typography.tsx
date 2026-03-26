import { cva, type VariantProps } from "class-variance-authority";
import { cn } from "@/lib/utils";

const textVariants = cva("font-jakarta", {
  variants: {
    variant: {
      "display-lg": "text-[2.125rem] font-bold",
      "display-md": "text-[1.75rem] font-semibold",
      "display-sm": "text-[1.5rem] font-semibold",
      "title-lg": "text-[1.25rem] font-medium",
      "title-md": "text-[1.0625rem] font-medium",
      "body-lg": "text-[1rem] font-normal",
      "body-md": "text-[0.875rem] font-normal",
      "body-sm": "text-[0.75rem] font-normal",
      "label-lg": "text-[0.9375rem] font-semibold",
      "label-md": "text-[0.8125rem] font-medium",
      "label-sm": "text-[0.6875rem] font-medium",
    },
    color: {
      primary: "text-ds-text-primary",
      secondary: "text-ds-text-secondary",
      "on-sage": "text-ds-text-on-sage",
      "on-warm-white": "text-ds-text-on-warm-white",
      sage: "text-ds-sage",
      "warm-white": "text-ds-warm-white",
      error: "text-ds-error",
      success: "text-ds-success",
      warning: "text-ds-warning",
      inherit: "",
    },
  },
  defaultVariants: {
    variant: "body-md",
    color: "primary",
  },
});

type TextVariant = NonNullable<VariantProps<typeof textVariants>["variant"]>;

const DEFAULT_TAGS: Record<TextVariant, React.ElementType> = {
  "display-lg": "h1",
  "display-md": "h2",
  "display-sm": "h3",
  "title-lg": "h4",
  "title-md": "h5",
  "body-lg": "p",
  "body-md": "p",
  "body-sm": "p",
  "label-lg": "span",
  "label-md": "span",
  "label-sm": "span",
};

export interface TextProps {
  variant?: TextVariant;
  color?: NonNullable<VariantProps<typeof textVariants>["color"]>;
  pattern?: "sage" | "crimson" | "amber" | "original";
  as?: React.ElementType;
  className?: string;
  children: React.ReactNode;
  ref?: React.Ref<HTMLElement>;
  /** Custom data attributes for animation hooks */
  [key: `data-${string}`]: string | undefined;
}

export function Text({
  variant = "body-md",
  color = "primary",
  pattern,
  as,
  className,
  children,
  ref,
  ...rest
}: TextProps) {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const Tag = (as ?? DEFAULT_TAGS[variant]) as any;

  const usePattern = !!pattern;
  // Only bold (700) display text gets the animated drift; semibold and below get static pattern
  const isBold = variant === "display-lg";
  const patternClass = usePattern
    ? isBold
      ? "ds-pattern-text"
      : "ds-pattern-text-static"
    : undefined;

  const props: Record<string, unknown> = {
    ref,
    className: cn(
      textVariants({ variant, color: usePattern ? undefined : color }),
      patternClass,
      className,
    ),
    ...rest,
  };

  if (usePattern) {
    props.style = { backgroundImage: `url('/patterns/${pattern}.png')` };
  }

  return <Tag {...props}>{children}</Tag>;
}
