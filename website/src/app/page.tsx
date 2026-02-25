import { Navbar } from "@/components/layout/Navbar";
import { Footer } from "@/components/layout/Footer";
import { ScrollProgress } from "@/components/layout/ScrollProgress";
import { HeroSection } from "@/components/sections/HeroSection";
import { MobileSection } from "@/components/sections/MobileSection";
import { BentoSection } from "@/components/sections/BentoSection";
import { WaitlistSection } from "@/components/sections/WaitlistSection";
import { ClientShellGate } from "@/components/ClientShellGate";
import { PageBackground } from "@/components/PageBackground";

export default function Home() {
    return (
        <>
            <PageBackground />
            <main className="relative min-h-screen">
                <ScrollProgress />
                <Navbar />
                <HeroSection />
                <MobileSection />
                <BentoSection />
                <WaitlistSection />
            </main>
            <Footer />
            {/* ClientShellGate skips the 3D phone on mobile (<768px) to avoid
                downloading ~2-5MB of GLTF/textures and running WebGL on low-power
                devices. On desktop it delegates to ClientShellLoader (dynamic, ssr:false)
                which renders PhoneCanvas + LoadingScreen. */}
            <ClientShellGate />
        </>
    );
}
