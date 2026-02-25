import { Navbar } from "@/components/layout/Navbar";
import { Footer } from "@/components/layout/Footer";
import { ScrollProgress } from "@/components/layout/ScrollProgress";
import { HeroSection } from "@/components/sections/HeroSection";
import { MobileSection } from "@/components/sections/MobileSection";
import { BentoSection } from "@/components/sections/BentoSection";
import { WaitlistSection } from "@/components/sections/WaitlistSection";
import { ClientShellLoader } from "@/components/ClientShellLoader";
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
            {/* ClientShellLoader uses dynamic(ssr:false) to ensure PhoneCanvas
                and LoadingScreen are never SSR'd — eliminating hydration mismatches
                and making useState(true) for showLoader always correct on first render. */}
            <ClientShellLoader />
        </>
    );
}
