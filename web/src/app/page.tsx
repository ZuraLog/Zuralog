/**
 * Home page — ZuraLog waitlist landing page.
 *
 * Single-page layout composed of:
 * 1. PageLoader  — initial fade-in overlay
 * 2. Navbar      — sticky top nav (appears on scroll)
 * 3. Hero        — full-screen 3D hero + headline
 * 4. Problem     — the fragmentation problem
 * 5. Features    — what ZuraLog does
 * 6. HowItWorks  — three-step process
 * 7. Waitlist    — quiz funnel + email signup + leaderboard
 * 8. Footer      — minimal footer
 *
 * Supports ?scroll=waitlist query param (set by /waitlist redirect)
 * to auto-scroll to the waitlist section on load.
 */
import { Suspense } from 'react';
import { Navbar } from '@/components/sections/navbar';
import { Hero } from '@/components/sections/hero';
import { FullMobileSection } from '@/components/sections/full-mobile';
import { ProblemSection } from '@/components/sections/problem';
import { FeaturesSection } from '@/components/sections/features';
import { HowItWorksSection } from '@/components/sections/how-it-works';
import { WaitlistSection } from '@/components/sections/waitlist-section';
import { Footer } from '@/components/sections/footer';
import { PageLoader } from '@/components/ui/page-loader';
import { ScrollHandler } from '@/components/scroll-handler';
import { AnimatedBackground } from '@/components/animated-background';
import { SectionColorTransition } from '@/components/section-color-transition';

export default function Home() {
  return (
    <>
      {/* Global animated background — fixed, behind all content */}
      <AnimatedBackground />
      <PageLoader />
      <Navbar />
      {/* ScrollHandler reads ?scroll= param and scrolls to the target section */}
      <Suspense>
        <ScrollHandler />
      </Suspense>
      <main>
        {/* Wires GSAP scroll color morph: cream → lime between Hero and Full Mobile */}
        <SectionColorTransition />
        <Hero />
        <FullMobileSection />
        <ProblemSection />
        <FeaturesSection />
        <HowItWorksSection />
        <WaitlistSection />
      </main>
      <Footer />
    </>
  );
}
