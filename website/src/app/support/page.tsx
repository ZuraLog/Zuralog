/**
 * /support — Support Us page.
 *
 * Showcases multiple ways to support ZuraLog:
 *   1. Buy Me a Coffee (primary CTA)
 *   2. Share on social media
 *   3. Join the waitlist / refer friends
 *   4. Spread the word
 *   5. Corporate sponsorship inquiry
 *
 * Also displays:
 *   - Total Funds Raised (BMC + all other sources)
 *   - Top 10 Funder Leaderboard (non-anonymous only)
 */
import type { Metadata } from 'next';
import { Navbar } from '@/components/layout/Navbar';
import { Footer } from '@/components/layout/Footer';
import { PageBackground } from '@/components/PageBackground';
import { SupportSection } from '@/components/sections/SupportSection';

export const metadata: Metadata = {
  title: 'Support Us | ZuraLog',
  description:
    'Help ZuraLog grow — buy us a coffee, share with friends, become a sponsor, or spread the word. Every contribution counts.',
  openGraph: {
    title: 'Support ZuraLog',
    description: 'Every contribution — big or small — helps us build the future of unified health.',
    url: 'https://zuralog.com/support',
  },
};

export default function SupportPage() {
  return (
    <>
      <PageBackground />
      <div className="relative flex min-h-screen flex-col">
        <Navbar />
        <main className="flex-1">
          <SupportSection />
        </main>
        <Footer />
      </div>
    </>
  );
}
