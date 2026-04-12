// website/src/app/page.tsx
import { FloatingNav } from "@/components/layout/FloatingNav";
import { Footer } from "@/components/layout/Footer";
import { HeroSection } from "@/components/sections/HeroSection";
import { FeatureSections } from "@/components/sections/FeatureSections";
import { FeatureSectionsMobile } from "@/components/sections/FeatureSectionsMobile";
import { WaitlistSection } from "@/components/sections/WaitlistSection";
import { ClientShellGate } from "@/components/ClientShellGate";
import { PageBackground } from "@/components/PageBackground";
import { HashScrollHandler } from "@/components/HashScrollHandler";
import { ClientProviders } from "@/components/providers/ClientProviders";

export default function Home() {
  return (
    <ClientProviders>
      <div data-theme="light">
        <PageBackground />
        <HashScrollHandler />
        <main className="relative min-h-screen">
          <FloatingNav />
          <HeroSection />
          <FeatureSections />
          <FeatureSectionsMobile />
          <WaitlistSection />
        </main>
        <Footer />
        <ClientShellGate />
      </div>
    </ClientProviders>
  );
}
