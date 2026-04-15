"use client";

/**
 * Global error boundary — replaces the entire document (including root layout)
 * when a catastrophic error occurs. Must be self-contained: own <html>, <body>,
 * fonts, and styles. Cannot use FloatingNav or Footer (providers not available).
 */

import * as Sentry from "@sentry/nextjs";
import { useEffect } from "react";
import { Plus_Jakarta_Sans } from "next/font/google";
import "./globals.css";

const jakarta = Plus_Jakarta_Sans({
  subsets: ["latin"],
  weight: ["400", "500", "600", "700"],
});

export default function GlobalError({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  useEffect(() => {
    Sentry.captureException(error);
  }, [error]);

  return (
    <html lang="en" className={jakarta.className} data-theme="light">
      <body style={{ margin: 0, backgroundColor: "#F0EEE9" }}>
        <main
          style={{
            minHeight: "100vh",
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            padding: "3rem 1.5rem",
          }}
        >
          <div
            style={{
              display: "flex",
              flexDirection: "column",
              alignItems: "center",
              textAlign: "center",
              maxWidth: "440px",
              width: "100%",
            }}
          >
            {/* Pattern number */}
            <p
              className="ds-pattern-text"
              style={{
                backgroundImage: "var(--ds-pattern-sage)",
                fontSize: "120px",
                fontWeight: 700,
                lineHeight: 1,
                letterSpacing: "-0.04em",
                margin: 0,
                userSelect: "none",
              }}
            >
              500
            </p>

            {/* Eyebrow badge */}
            <span
              style={{
                marginTop: "1rem",
                display: "inline-flex",
                alignItems: "center",
                gap: "0.5rem",
                borderRadius: "9999px",
                border: "1px solid rgba(52,78,65,0.2)",
                background: "rgba(52,78,65,0.08)",
                padding: "0.25rem 0.75rem",
                fontSize: "11px",
                fontWeight: 500,
                textTransform: "uppercase",
                letterSpacing: "0.1em",
                color: "rgba(52,78,65,0.7)",
              }}
            >
              <span
                style={{
                  height: "6px",
                  width: "6px",
                  borderRadius: "9999px",
                  background: "#344E41",
                  animation: "pulse 2s cubic-bezier(0.4,0,0.6,1) infinite",
                }}
              />
              Something went wrong
            </span>

            {/* Headline */}
            <h1
              style={{
                marginTop: "1.25rem",
                marginBottom: 0,
                fontSize: "24px",
                fontWeight: 600,
                letterSpacing: "-0.02em",
                color: "#161618",
              }}
            >
              The app hit an unexpected error.
            </h1>

            {/* Body */}
            <p
              style={{
                marginTop: "1rem",
                fontSize: "14px",
                lineHeight: 1.6,
                color: "rgba(0,0,0,0.45)",
              }}
            >
              Something broke at the deepest level. Try refreshing. If it keeps
              happening, reach out and we will look into it.
            </p>

            {/* Actions */}
            <div
              style={{
                marginTop: "2rem",
                display: "flex",
                flexDirection: "column",
                alignItems: "center",
                gap: "0.75rem",
              }}
            >
              {/* Primary — Try again */}
              <button
                onClick={reset}
                className="ds-pattern-drift"
                style={{
                  backgroundImage: "var(--ds-pattern-sage)",
                  position: "relative",
                  display: "inline-flex",
                  alignItems: "center",
                  justifyContent: "center",
                  height: "44px",
                  padding: "0 1.5rem",
                  borderRadius: "9999px",
                  border: "none",
                  cursor: "pointer",
                  fontSize: "15px",
                  fontWeight: 600,
                  color: "var(--color-ds-text-on-sage)",
                  fontFamily: "inherit",
                  transition: "transform 0.3s ease, filter 0.4s ease",
                }}
                onMouseEnter={(e) => { (e.currentTarget as HTMLButtonElement).style.transform = "scale(1.03)"; }}
                onMouseLeave={(e) => { (e.currentTarget as HTMLButtonElement).style.transform = "scale(1)"; }}
              >
                Try again
              </button>

              {/* Secondary — Go home */}
              <a
                href="/"
                style={{
                  display: "inline-flex",
                  alignItems: "center",
                  justifyContent: "center",
                  height: "44px",
                  padding: "0 1.5rem",
                  borderRadius: "9999px",
                  border: "1.5px solid var(--color-ds-secondary-border)",
                  background: "transparent",
                  fontSize: "15px",
                  fontWeight: 600,
                  color: "var(--color-ds-text-primary)",
                  textDecoration: "none",
                  fontFamily: "inherit",
                  transition: "transform 0.3s ease",
                }}
                onMouseEnter={(e) => { (e.currentTarget as HTMLAnchorElement).style.transform = "scale(1.03)"; }}
                onMouseLeave={(e) => { (e.currentTarget as HTMLAnchorElement).style.transform = "scale(1)"; }}
              >
                Go home
              </a>

              {/* Text — Report */}
              <a
                href="mailto:support@zuralog.com"
                style={{
                  fontSize: "13px",
                  fontWeight: 500,
                  color: "rgba(0,0,0,0.35)",
                  textDecoration: "none",
                  fontFamily: "inherit",
                  transition: "color 0.2s ease",
                }}
                onMouseEnter={(e) => { (e.currentTarget as HTMLAnchorElement).style.color = "#344E41"; }}
                onMouseLeave={(e) => { (e.currentTarget as HTMLAnchorElement).style.color = "rgba(0,0,0,0.35)"; }}
              >
                Report this issue →
              </a>
            </div>

            {error.digest && (
              <p
                style={{
                  marginTop: "2rem",
                  fontFamily: "monospace",
                  fontSize: "11px",
                  color: "rgba(0,0,0,0.2)",
                }}
              >
                Error ID: {error.digest}
              </p>
            )}
          </div>
        </main>
      </body>
    </html>
  );
}
