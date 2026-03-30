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
import "./globals.css";

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
    icon: [{ url: "/logo/ZuraLog-Logo-Sage.png", type: "image/png" }],
    apple: [{ url: "/logo/ZuraLog-Logo-Sage.png", type: "image/png" }],
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
      <body className="font-sans antialiased">
        {/* OverlayDismisser: layout-level safety net. Ensures the loading
            overlay is dismissed on EVERY page — not just the home page.
            On non-home pages it dismisses quickly; on the home page it acts
            as a fallback if LoadingScreen's 3D progress tracking fails. */}
        <OverlayDismisser />
        {/* SSR loading overlay: visible from first paint; dismissed by client JS.
            Spinner CSS lives in globals.css to avoid a React hydration mismatch
            from Next.js hoisting inline style tags out of the body element.
            ID "ssr-loading-overlay" is the contract between server and client. */}
        <div
          id="ssr-loading-overlay"
          suppressHydrationWarning
          style={{
            position: "fixed",
            inset: 0,
            display: "flex",
            flexDirection: "column",
            alignItems: "center",
            justifyContent: "center",
            backgroundColor: "#161618",
            zIndex: 9999,
            transition: "opacity 0.6s ease",
          }}
          aria-hidden="true"
        >
          <span
            style={{
              fontSize: "1.5rem",
              fontWeight: 300,
              letterSpacing: "0.3em",
              color: "#F0EEE9",
              textTransform: "uppercase" as const,
              opacity: 0.85,
            }}
          >
            Zuralog
          </span>
          {/* Pure-CSS spinner — animates without JS */}
          <div id="ssr-loader" />
        </div>
        {/* Fallback: auto-dismiss the SSR overlay on mobile where ClientShellGate
            returns null (no 3D, no LoadingScreen). Fires after 600ms — much faster
            than OverlayDismisser's 10s safety timeout for the home page. On desktop
            the overlay is dismissed by LoadingScreen; this script is a no-op once
            opacity has already been set to '0'. */}
        <script
          dangerouslySetInnerHTML={{
            __html: `
              setTimeout(function() {
                var el = document.getElementById('ssr-loading-overlay');
                if (el && el.style.opacity !== '0') {
                  el.style.transition = 'opacity 0.4s ease-out';
                  el.style.opacity = '0';
                  setTimeout(function() { if (el.parentNode) el.parentNode.removeChild(el); }, 400);
                }
              }, 600);
            `,
          }}
        />
        <PostHogProvider>
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
