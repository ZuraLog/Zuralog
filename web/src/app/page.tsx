/**
 * Home page — Zuralog waitlist landing page.
 *
 * Single-page layout composed of:
 * 1. PageLoader  — initial fade-in overlay
 * 2. Navbar      — sticky top nav (appears on scroll)
 * 3. Hero        — full-screen 3D hero + headline
 * 4. Problem     — the fragmentation problem
 * 5. Features    — what Zuralog does
 * 6. HowItWorks  — three-step process
 * 7. Waitlist    — quiz funnel + email signup + leaderboard
 * 8. Footer      — minimal footer
 */
import { Navbar } from '@/components/sections/navbar';
import { Hero } from '@/components/sections/hero';
import { ProblemSection } from '@/components/sections/problem';
import { FeaturesSection } from '@/components/sections/features';
import { HowItWorksSection } from '@/components/sections/how-it-works';
import { WaitlistSection } from '@/components/sections/waitlist-section';
import { Footer } from '@/components/sections/footer';
import { PageLoader } from '@/components/ui/page-loader';

export default function Home() {
  return (
    <>
      <PageLoader />
      <Navbar />
      <main>
        <Hero />
        <ProblemSection />
        <FeaturesSection />
        <HowItWorksSection />
        <WaitlistSection />
      </main>
      <Footer />
    </>
  );
}
