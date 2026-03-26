import type { Metadata } from "next";
import { PatternVideoProvider } from "@/components/design-system";

export const metadata: Metadata = {
  title: "Brand Bible",
  description: "Zuralog Design System — Visual Reference",
  robots: { index: false, follow: false },
};

export default function BrandBibleLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <div className="min-h-screen bg-ds-canvas font-jakarta text-ds-text-primary">
      <PatternVideoProvider>
        {children}
      </PatternVideoProvider>
    </div>
  );
}
