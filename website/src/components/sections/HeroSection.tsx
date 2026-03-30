import { HeroText } from "./hero/HeroText";
import { FloatingIcons } from "./hero/FloatingIcons";

/**
 * HeroSection
 *
 * Premium dark redesign:
 * - Dark canvas background (#161618) via PageBackground
 * - Topographic pattern overlay animating with a slow diagonal drift
 * - Sage glow orb (top-left) + Deep Violet glow orb (bottom-right)
 * - FloatingIcons + HeroText layered on top
 */
export function HeroSection() {
    return (
        <section
            id="hero-section"
            className="relative w-full h-screen overflow-hidden"
        >
            {/* ── Topographic pattern overlay (animated diagonal drift) ── */}
            <div
                aria-hidden="true"
                className="absolute inset-0 z-0 animate-topo-drift pointer-events-none select-none"
                style={{
                    backgroundImage: "url('/patterns/original.png')",
                    backgroundSize: "600px 600px",
                    backgroundRepeat: "repeat",
                    opacity: 0.08,
                    mixBlendMode: "screen",
                }}
            />

            {/* ── Glow orbs ── */}
            <div aria-hidden="true" className="absolute inset-0 z-0 pointer-events-none overflow-hidden">
                {/* Sage orb — top-left, behind headline */}
                <div
                    className="glow-orb"
                    style={{
                        width: "700px",
                        height: "700px",
                        top: "-200px",
                        left: "-150px",
                        background:
                            "radial-gradient(circle, rgba(207,225,185,0.18) 0%, transparent 70%)",
                    }}
                />
                {/* Deep Violet orb — bottom-right, accent */}
                <div
                    className="glow-orb"
                    style={{
                        width: "500px",
                        height: "500px",
                        bottom: "-100px",
                        right: "-100px",
                        background:
                            "radial-gradient(circle, rgba(94,92,230,0.14) 0%, transparent 70%)",
                    }}
                />
            </div>

            {/* ── Content layers ── */}
            <FloatingIcons />
            <HeroText />
        </section>
    );
}
