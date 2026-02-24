/**
 * SectionCard — Reusable card component for the CryptoHub-inspired redesign.
 *
 * Provides two variants based on the section background they sit on:
 * - `light`: White card with subtle shadow (for dark section backgrounds)
 * - `dark`: Dark card with border stroke (for light section backgrounds)
 *
 * All cards use 24px border-radius as specified in the master plan.
 */

import * as React from "react"
import { cva, type VariantProps } from "class-variance-authority"

import { cn } from "@/lib/utils"

const sectionCardVariants = cva(
  "rounded-3xl p-8 transition-all duration-200",
  {
    variants: {
      variant: {
        /** White card for dark backgrounds — prominent shadow */
        light:
          "bg-white text-[var(--text-primary)] shadow-[0_4px_24px_rgba(0,0,0,0.08)] hover:-translate-y-1 hover:shadow-[0_8px_32px_rgba(0,0,0,0.12)]",
        /** Dark card for light backgrounds — subtle tint with border */
        dark:
          "bg-[var(--section-dark)] text-[var(--text-light)] border border-[var(--border-dark)]",
        /** Transparent glass card — for overlays and floating elements */
        glass:
          "bg-white/80 backdrop-blur-xl text-[var(--text-primary)] border border-[var(--border-light)] shadow-[0_4px_20px_rgba(0,0,0,0.05)]",
      },
      size: {
        default: "p-8",
        sm: "p-6",
        lg: "p-10 md:p-12",
      },
    },
    defaultVariants: {
      variant: "light",
      size: "default",
    },
  }
)

/**
 * Props for the SectionCard component.
 *
 * @param variant - Visual style based on surrounding section background.
 * @param size - Internal padding scale.
 */
function SectionCard({
  className,
  variant = "light",
  size = "default",
  ...props
}: React.ComponentProps<"div"> & VariantProps<typeof sectionCardVariants>) {
  return (
    <div
      data-slot="section-card"
      data-variant={variant}
      className={cn(sectionCardVariants({ variant, size }), className)}
      {...props}
    />
  )
}

export { SectionCard, sectionCardVariants }
