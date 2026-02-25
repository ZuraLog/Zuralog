import { HeroText } from "./hero/HeroText";
import { FloatingIcons } from "./hero/FloatingIcons";

export function HeroSection() {
    return (
        <section id="hero-section" className="relative w-full h-screen overflow-hidden">
            <FloatingIcons />
            <HeroText />
        </section>
    );
}
