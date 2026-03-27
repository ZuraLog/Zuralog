import type { Metadata } from "next";
import { BrandBibleInteractions } from "@/components/design-system/interactions/brand-bible-interactions";
import { SoundProvider } from "@/components/design-system/interactions/sound-provider";

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
    <SoundProvider>
      <div className="min-h-screen bg-ds-canvas font-jakarta text-ds-text-primary relative">
        {/* Aurora + ambient effects sit between the bg and content */}
        <BrandBibleInteractions />
        {/* Content floats above everything */}
        <div className="relative z-10">
          {children}
        </div>
      </div>
    </SoundProvider>
  );
}
