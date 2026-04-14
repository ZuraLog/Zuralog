/**
 * Root layout for the ZuraLog marketing website.
 *
 * Provides:
 * - Geist Sans + Geist Mono font variables
 * - Full SEO metadata (title, description, OG, Twitter, robots, icons)
 * - Sonner toast notifications
 * - SSR loading overlay (visible from first paint, dismissed by client JS)
 * - OverlayDismisser (ensures the loading overlay is dismissed on ALL pages)
 */
import type { Metadata } from "next";
import { Geist, Geist_Mono, Plus_Jakarta_Sans } from "next/font/google";
import { DSToaster } from "@/components/design-system/feedback/sonner";
import { Analytics } from "@vercel/analytics/next";
import { LenisProvider } from "@/components/layout/LenisProvider";
import { OverlayDismisser } from "@/components/OverlayDismisser";
import { PostHogProvider } from "@/components/providers/PostHogProvider";
import { ScrollProgress } from "@/components/design-system/interactions/scroll-progress";
import { CustomCursor } from "@/components/design-system/interactions/custom-cursor";
import { SpotlightFollow } from "@/components/design-system/interactions/spotlight-follow";
import "./globals.css";
import "react-device-frameset/styles/marvel-devices.css";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

const plusJakartaSans = Plus_Jakarta_Sans({
  variable: "--font-jakarta",
  subsets: ["latin"],
  weight: ["400", "500", "600", "700"],
});

const siteUrl = process.env.NEXT_PUBLIC_SITE_URL || "https://zuralog.com";

export const metadata: Metadata = {
  metadataBase: new URL(siteUrl),
  title: {
    default: "ZuraLog",
    template: "%s | ZuraLog",
  },
  description:
    "The AI that connects your fitness apps and actually thinks. Join the waitlist for early access.",
  keywords: ["fitness AI", "health tracker", "fitness app", "AI coach", "ZuraLog"],
  openGraph: {
    type: "website",
    locale: "en_US",
    url: siteUrl,
    siteName: "ZuraLog",
    title: "ZuraLog — Unified Health. Made Smart.",
    description:
      "The AI that connects your fitness apps and actually thinks. Join the waitlist for early access.",
  },
  twitter: {
    card: "summary_large_image",
    creator: "@zuralog",
    title: "ZuraLog — Unified Health. Made Smart.",
    description:
      "The AI that connects your fitness apps and actually thinks. Join the waitlist for early access.",
  },
  robots: {
    index: true,
    follow: true,
    googleBot: {
      index: true,
      follow: true,
      "max-video-preview": -1,
      "max-image-preview": "large",
      "max-snippet": -1,
    },
  },
  icons: {
    icon: [{ url: "/logo/ZuraLog-Sage.svg", type: "image/svg+xml" }],
    apple: [{ url: "/logo/ZuraLog-Sage.svg", type: "image/svg+xml" }],
  },
  manifest: "/site.webmanifest",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className={`${geistSans.variable} ${geistMono.variable} ${plusJakartaSans.variable}`}>
      <body className="font-jakarta antialiased" data-theme="light">
        {/* OverlayDismisser: layout-level safety net. Ensures the loading
            overlay is dismissed on EVERY page — not just the home page.
            On non-home pages it dismisses quickly; on the home page it acts
            as a fallback if LoadingScreen's 3D progress tracking fails. */}
        <OverlayDismisser />
        {/* SSR loading overlay: rendered in the initial HTML so it's visible
            from the very first paint. Client-side LoadingScreen.tsx will
            fade this out and remove it once 3D assets finish loading.
            ID "ssr-loading-overlay" is the contract between server and client.

            The spinner uses a pure-CSS rotating dot pattern (no JS needed). */}
        {/* eslint-disable-next-line @next/next/no-css-tags -- inline style tag for SSR overlay */}
        <style
          dangerouslySetInnerHTML={{
            __html: `
              /* Pattern drift — matches ds-pattern-text on the hero section */
              @keyframes ssr-drift {
                0%   { background-position: 0px 0px; }
                100% { background-position: 300px 300px; }
              }
              /* Only transform + opacity are GPU-composited — no paint per frame */
              @keyframes ssr-bounce {
                25%  { transform: translateY(20px) rotate(22.5deg); }
                50%  { transform: translateY(40px) scale(1, .9) rotate(45deg); }
                75%  { transform: translateY(20px) rotate(67.5deg); }
                100% { transform: translateY(0) rotate(90deg); }
              }
              @keyframes ssr-shadow {
                0%, 100% { transform: scale(1, 1); }
                50%       { transform: scale(1.25, 1); }
              }
              #ssr-loader-wrap {
                display: flex;
                flex-direction: column;
                align-items: center;
                gap: 48px;
              }
              #ssr-logo {
                width: 120px;
                height: 120px;
                background-image: url('/patterns/original.png');
                background-size: 300px auto;
                background-repeat: repeat;
                -webkit-mask-image: url('/logo/ZuraLog-Sage.svg');
                mask-image: url('/logo/ZuraLog-Sage.svg');
                -webkit-mask-mode: alpha;
                mask-mode: alpha;
                -webkit-mask-size: contain;
                mask-size: contain;
                -webkit-mask-repeat: no-repeat;
                mask-repeat: no-repeat;
                -webkit-mask-position: center;
                mask-position: center;
                animation: ssr-drift 45s linear infinite;
              }
              #ssr-spinner {
                width: 80px;
                height: 80px;
                position: relative;
                will-change: transform;
              }
              #ssr-spinner::before {
                content: '';
                width: 80px;
                height: 8px;
                background: #344E41;
                opacity: 0.15;
                position: absolute;
                top: 126px;
                left: 0;
                border-radius: 50%;
                animation: ssr-shadow 0.55s linear infinite;
                will-change: transform;
              }
              #ssr-spinner::after {
                content: '';
                width: 100%;
                height: 100%;
                background-image: url('/patterns/original.png');
                background-size: 200px auto;
                background-repeat: repeat;
                animation: ssr-bounce 0.55s linear infinite;
                position: absolute;
                top: 0;
                left: 0;
                border-radius: 10px;
                will-change: transform;
              }
            `,
          }}
        />
        <div
          id="ssr-loading-overlay"
          suppressHydrationWarning
          style={{
            position: "fixed",
            inset: 0,
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            backgroundColor: "#F0EEE9",
            zIndex: 9999,
            transition: "opacity 0.6s ease",
          }}
          aria-hidden="true"
        >
          {/* Bouncing-box spinner with brand pattern + logo above — pure CSS */}
          <div id="ssr-loader-wrap">
            <div id="ssr-logo" />
            <div id="ssr-spinner" />
          </div>
        </div>
        {/* No inline dismiss script — LoadingScreen.tsx and OverlayDismisser
            handle all dismissal logic so the overlay is never cut short. */}
        <PostHogProvider>
          <ScrollProgress />
          <CustomCursor />
          <SpotlightFollow />
          <LenisProvider>
            {children}
          </LenisProvider>
          <DSToaster />
          <Analytics />
        </PostHogProvider>
      </body>
    </html>
  );
}
