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
import { Geist, Geist_Mono } from "next/font/google";
import { Toaster } from "sonner";
import { Analytics } from "@vercel/analytics/next";
import { LenisProvider } from "@/components/layout/LenisProvider";
import { OverlayDismisser } from "@/components/OverlayDismisser";
import "./globals.css";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
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
    icon: [{ url: "/logo/Zuralog.png", type: "image/png" }],
    apple: [{ url: "/logo/Zuralog.png", type: "image/png" }],
  },
  manifest: "/site.webmanifest",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className={`${geistSans.variable} ${geistMono.variable}`}>
      <body className="font-sans antialiased">
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
              @keyframes ssr-loader-spin {
                100% { transform: rotate(.5turn); }
              }
              #ssr-loader {
                width: 50px;
                aspect-ratio: 1;
                display: grid;
                margin-top: 28px;
              }
              #ssr-loader::before,
              #ssr-loader::after {
                content: "";
                grid-area: 1/1;
                --c: no-repeat radial-gradient(farthest-side, #CFE1B9 92%, #0000);
                background:
                  var(--c) 50%  0,
                  var(--c) 50%  100%,
                  var(--c) 100% 50%,
                  var(--c) 0    50%;
                background-size: 12px 12px;
                animation: ssr-loader-spin 1s infinite;
              }
              #ssr-loader::before {
                margin: 4px;
                --c: no-repeat radial-gradient(farthest-side, #E8F5A8 92%, #0000);
                background-size: 8px 8px;
                animation-timing-function: linear;
              }
            `,
          }}
        />
        <div
          id="ssr-loading-overlay"
          style={{
            position: "fixed",
            inset: 0,
            display: "flex",
            flexDirection: "column",
            alignItems: "center",
            justifyContent: "center",
            backgroundColor: "#FAFAF5",
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
              color: "#2D2D2D",
              textTransform: "uppercase" as const,
              opacity: 0.85,
            }}
          >
            Zuralog
          </span>
          {/* Pure-CSS spinner — animates without JS */}
          <div id="ssr-loader" />
        </div>
        <LenisProvider>
          {children}
        </LenisProvider>
        <Toaster richColors position="bottom-right" />
        <Analytics />
      </body>
    </html>
  );
}
