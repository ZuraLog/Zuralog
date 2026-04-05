import { FloatingNav } from "@/components/layout/FloatingNav";
import { Footer } from "@/components/layout/Footer";
import { ScrollProgress } from "@/components/layout/ScrollProgress";
import { HeroSection } from "@/components/sections/HeroSection";
import { IntegrationsSection } from "@/components/sections/IntegrationsSection";
import { TodaySection } from "@/components/sections/TodaySection";
import { DataSection } from "@/components/sections/DataSection";
import { CoachSection } from "@/components/sections/CoachSection";
import { ProgressSection } from "@/components/sections/ProgressSection";
import { TrendsSection } from "@/components/sections/TrendsSection";
import { ClientShellGate } from "@/components/ClientShellGate";
import { PageBackground } from "@/components/PageBackground";
import { HashScrollHandler } from "@/components/HashScrollHandler";

export default function Home() {
    return (
        <div data-theme="light">
            <PageBackground />
            <HashScrollHandler />
            <main className="relative min-h-screen">
                <ScrollProgress />
                <FloatingNav />
                <HeroSection />
                <IntegrationsSection />
                <TodaySection />
                <DataSection />
                <CoachSection />
                <ProgressSection />
                <TrendsSection />
            </main>
            <Footer />
            {/* ClientShellGate skips the 3D phone on mobile (<768px) to avoid
                downloading ~2-5MB of GLTF/textures and running WebGL on low-power
                devices. On desktop it delegates to ClientShellLoader (dynamic, ssr:false)
                which renders ScrollPhoneCanvas + LoadingScreen. */}
            <ClientShellGate />
        </div>
    );
}
