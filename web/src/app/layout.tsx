/**
 * Root layout for the ZuraLog website.
 *
 * Provides:
 * - Satoshi (display), Inter (body), JetBrains Mono (code) font variables
 * - ThemeProvider with dark as default (next-themes)
 * - SmoothScroll (Lenis + GSAP ScrollTrigger sync)
 * - Sonner toast notifications
 * - Vercel Analytics + Speed Insights
 * - PostHog product analytics
 * - Full SEO metadata (OG, Twitter, robots)
 */
import type { Metadata } from 'next';
import { Suspense } from 'react';
import { Analytics } from '@vercel/analytics/react';
import { SpeedInsights } from '@vercel/speed-insights/next';
import { Toaster } from 'sonner';
import { ThemeProvider } from '@/components/theme-provider';
import { SmoothScroll } from '@/components/smooth-scroll';
import { PostHogProvider } from '@/components/analytics';
import { CursorTrail } from '@/components/cursor-trail';
import { satoshi, inter, jetbrainsMono } from './fonts';
import './globals.css';

const siteUrl = process.env.NEXT_PUBLIC_SITE_URL || 'https://zuralog.com';

export const metadata: Metadata = {
  metadataBase: new URL(siteUrl),
  title: {
    default: 'ZuraLog — The AI That Connects Your Fitness Apps',
    template: '%s | ZuraLog',
  },
  description:
    'The AI that connects your fitness apps and actually thinks. Join the waitlist for early access.',
  keywords: ['fitness AI', 'health tracker', 'fitness app', 'AI coach', 'ZuraLog'],
  openGraph: {
    type: 'website',
    locale: 'en_US',
    url: siteUrl,
    siteName: 'ZuraLog',
    title: 'ZuraLog — The AI That Connects Your Fitness Apps',
    description:
      'The AI that connects your fitness apps and actually thinks. Join the waitlist for early access.',
    images: [
      {
        url: '/og-image.png',
        width: 1200,
        height: 630,
        alt: 'ZuraLog — AI Fitness Hub',
      },
    ],
  },
  twitter: {
    card: 'summary_large_image',
    creator: '@zuralog',
    title: 'ZuraLog — The AI That Connects Your Fitness Apps',
    description:
      'The AI that connects your fitness apps and actually thinks. Join the waitlist for early access.',
    images: ['/og-image.png'],
  },
  robots: {
    index: true,
    follow: true,
    googleBot: {
      index: true,
      follow: true,
      'max-video-preview': -1,
      'max-image-preview': 'large',
      'max-snippet': -1,
    },
  },
  icons: {
    icon: [
      { url: '/favicon-16x16.png', sizes: '16x16', type: 'image/png' },
      { url: '/favicon-32x32.png', sizes: '32x32', type: 'image/png' },
    ],
    apple: '/apple-touch-icon.png',
    shortcut: '/favicon.ico',
  },
  manifest: '/site.webmanifest',
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html
      lang="en"
      suppressHydrationWarning
      className={`${satoshi.variable} ${inter.variable} ${jetbrainsMono.variable}`}
    >
      <body className="font-sans antialiased">
        <CursorTrail />
        <ThemeProvider
          attribute="class"
          defaultTheme="dark"
          enableSystem={false}
          disableTransitionOnChange
        >
          <SmoothScroll>
            {/* PostHog requires useSearchParams — wrap in Suspense */}
            <Suspense>
              <PostHogProvider>
                {children}
              </PostHogProvider>
            </Suspense>
          </SmoothScroll>
          <Toaster richColors position="bottom-right" />
        </ThemeProvider>

        {/* Vercel Analytics — server-safe, no client init needed */}
        <Analytics />
        <SpeedInsights />
      </body>
    </html>
  );
}
