import { HeroText } from "./hero/HeroText";
import { FloatingIcons } from "./hero/FloatingIcons";

export function HeroSection() {
    return (
        <section id="hero-section" className="relative w-full h-screen overflow-hidden" style={{ backgroundColor: "#F0EEE9" }}>
            <FloatingIcons />
            <HeroText />
        </section>
    );
}
