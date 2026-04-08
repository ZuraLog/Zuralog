// website/src/app/page.tsx
import { FloatingNav } from "@/components/layout/FloatingNav";
import { Footer } from "@/components/layout/Footer";
import { HeroSection } from "@/components/sections/HeroSection";
import { WaitlistSection } from "@/components/sections/WaitlistSection";
import { ClientShellGate } from "@/components/ClientShellGate";
import { PageBackground } from "@/components/PageBackground";
import { HashScrollHandler } from "@/components/HashScrollHandler";
import { ClientProviders } from "@/components/providers/ClientProviders";

/**
 * Scroll anchor IDs referenced by ScrollPhoneCanvas GSAP triggers,
 * FloatingNav links, and Footer links. Each anchor is a minimal
 * <section> with enough height (100vh) to give GSAP ScrollTrigger
 * a trigger range. Real section content will be built directly into
 * these anchors (or as lightweight child components) — they must NOT
 * have their own overflow constraints or scroll contexts.
 */
const SCROLL_ANCHORS = [
  "coach-section",
] as const;

export default function Home() {
  return (
    <ClientProviders>
      <div data-theme="light">
        <PageBackground />
        <HashScrollHandler />
        <main className="relative min-h-screen">
          <FloatingNav />
          <HeroSection />

          {/* Scroll zone ------------------------------------------------
              Flat container for GSAP ScrollTrigger anchors.
              relative positioning so pinned elements and ScrollTrigger
              markers resolve against this container.
              No overflow constraints — the ScrollPhone fixed overlay
              (z-40) must flow freely across all anchors. */}
          <div className="relative">
            {SCROLL_ANCHORS.map((id) => (
              <section
                key={id}
                id={id}
                className="min-h-screen"
                aria-hidden="true"
              />
            ))}
          </div>

          <WaitlistSection />
        </main>
        <Footer />
        <ClientShellGate />
      </div>
    </ClientProviders>
  );
}
