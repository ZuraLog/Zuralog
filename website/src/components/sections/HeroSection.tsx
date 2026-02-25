import { HeroText } from "./hero/HeroText";
import { FloatingIcons } from "./hero/FloatingIcons";

export function HeroSection() {
    return (
        <section id="hero-section" className="relative w-full h-screen bg-cream overflow-hidden">
            <FloatingIcons />
            <HeroText />

            {/* Bottom gradient: blends hero cream into the MobileSection's starting green */}
            <div
                className="absolute bottom-0 left-0 w-full h-48 pointer-events-none z-10"
                style={{
                    background: "linear-gradient(to bottom, transparent 0%, #CFE1B9 100%)",
                }}
            />
        </section>
    );
}
