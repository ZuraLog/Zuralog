import { HeroText } from "./hero/HeroText";
import { FloatingIcons } from "./hero/FloatingIcons";
import { PhoneCanvas } from "./hero/PhoneCanvas";

export function HeroSection() {
    return (
        <section className="relative w-full h-screen bg-cream overflow-hidden">
            <FloatingIcons />
            <HeroText />
            <PhoneCanvas />
        </section>
    );
}
