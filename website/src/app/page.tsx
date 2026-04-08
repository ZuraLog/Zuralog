// website/src/app/page.tsx
import { FloatingNav } from "@/components/layout/FloatingNav";
import { Footer } from "@/components/layout/Footer";
import { HeroSection } from "@/components/sections/HeroSection";
import { ConnectSection } from "@/components/sections/ConnectSection";
import { NutritionSection } from "@/components/sections/NutritionSection";
import { WorkoutsSection } from "@/components/sections/WorkoutsSection";
import { SleepSection } from "@/components/sections/SleepSection";
import { HeartSection } from "@/components/sections/HeartSection";
import { MoreSection } from "@/components/sections/MoreSection";
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
          <ConnectSection />
          <NutritionSection />
          <WorkoutsSection />
          <SleepSection />
          <HeartSection />
          <MoreSection />
          <CoachSection />
          <WaitlistSection />
        </main>
        <Footer />
        <ClientShellGate />
      </div>
    </ClientProviders>
  );
}
