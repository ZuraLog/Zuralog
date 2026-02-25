/**
 * Root layout for the ZuraLog marketing website.
 *
 * Provides:
 * - Geist Sans + Geist Mono font variables
 * - Full SEO metadata (title, description, OG, Twitter, robots, icons)
 * - Sonner toast notifications
 */
import type { Metadata } from "next";
import { Geist, Geist_Mono } from "next/font/google";
import { Toaster } from "sonner";
import { LenisProvider } from "@/components/layout/LenisProvider";
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
        <LenisProvider>
          {children}
        </LenisProvider>
        <Toaster richColors position="bottom-right" />
      </body>
    </html>
  );
}
