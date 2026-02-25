import { Navbar } from "@/components/layout/Navbar";
import { ScrollProgress } from "@/components/layout/ScrollProgress";
import { HeroSection } from "@/components/sections/HeroSection";
import { MobileSection } from "@/components/sections/MobileSection";
import { BentoSection } from "@/components/sections/BentoSection";
import { WaitlistSection } from "@/components/sections/WaitlistSection";
import { PhoneCanvas } from "@/components/sections/hero/PhoneCanvas";

export default function Home() {
    return (
        <main className="relative min-h-screen">
            <ScrollProgress />
            <Navbar />
            <HeroSection />
            <MobileSection />
            <BentoSection />
            <WaitlistSection />

            {/* 3D phone: lives at page level so it can transition between
                fixed (follows viewport) and absolute (anchored in MobileSection).
                Must be rendered after the sections so it layers on top. */}
            <PhoneCanvas />
        </main>
    );
}
