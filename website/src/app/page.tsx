// website/src/app/page.tsx
import { FloatingNav } from "@/components/layout/FloatingNav";
import { Footer } from "@/components/layout/Footer";
import { HeroSection } from "@/components/sections/HeroSection";
import { FeatureSections } from "@/components/sections/FeatureSections";
import { FeaturesCardSection } from "@/components/sections/FeaturesCardSection";
import { FeatureShowcaseSection } from "@/components/sections/FeatureShowcaseSection";
import { EverythingElseSection } from "@/components/sections/EverythingElseSection";
import { CoachSection } from "@/components/sections/CoachSection";
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
          <div id="connect-section"><FeatureSections /></div>
          <div id="tracking-section"><FeaturesCardSection /></div>
          <div id="deep-dive-section"><FeatureShowcaseSection /></div>
          <div id="more-section"><EverythingElseSection /></div>
          <div id="coach-section"><CoachSection /></div>
          <WaitlistSection />
        </main>
        <Footer />
        <ClientShellGate />
      </div>
    </ClientProviders>
  );
}
