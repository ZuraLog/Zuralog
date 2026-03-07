/**
 * opengraph-image.tsx — dynamically generated Open Graph image.
 *
 * Uses Next.js ImageResponse to render a 1200x630 OG image.
 * Brand-accurate dark palette: OLED black background, Sage Green (#CFE1B9)
 * accents, and the new Zuralog logo mark rendered as inline SVG.
 * Automatically served at /opengraph-image by Next.js metadata routing.
 */
import { ImageResponse } from "next/og";

export const runtime = "edge";
export const alt = "ZuraLog — Unified Health. Made Smart.";
export const size = { width: 1200, height: 630 };
export const contentType = "image/png";

/** Brand tokens (must be static for edge runtime — no imports). */
const SAGE = "#CFE1B9";
const SAGE_DIM = "rgba(207,225,185,0.45)";
const DARK_GREEN = "#344E41";
const SURFACE = "#0F0F0F";
const BG = "#000000";

export default async function Image() {
  return new ImageResponse(
    (
      <div
        style={{
          background: BG,
          width: "100%",
          height: "100%",
          display: "flex",
          flexDirection: "column",
          alignItems: "center",
          justifyContent: "center",
          fontFamily: "system-ui, -apple-system, sans-serif",
          position: "relative",
          overflow: "hidden",
        }}
      >
        {/* Subtle sage radial bloom — top-center, like the app */}
        <div
          style={{
            position: "absolute",
            width: 900,
            height: 900,
            borderRadius: "50%",
            background: `radial-gradient(circle, rgba(52,78,65,0.55) 0%, transparent 60%)`,
            top: -250,
            left: "50%",
            transform: "translateX(-50%)",
          }}
        />

        {/* Top bar — integration source pills */}
        <div
          style={{
            position: "absolute",
            top: 44,
            display: "flex",
            alignItems: "center",
            gap: 10,
          }}
        >
          {[
            { name: "Strava",          dot: "#FC4C02" },
            { name: "Apple Health",    dot: "#FF3B30" },
            { name: "Oura",            dot: "#9B8EFF" },
            { name: "Garmin",          dot: "#007CC3" },
            { name: "Health Connect",  dot: "#4285F4" },
          ].map(({ name, dot }) => (
            <div
              key={name}
              style={{
                display: "flex",
                alignItems: "center",
                gap: 7,
                background: "rgba(207,225,185,0.07)",
                border: "1px solid rgba(207,225,185,0.14)",
                borderRadius: 9999,
                padding: "7px 16px",
                fontSize: 13,
                fontWeight: 500,
                color: SAGE_DIM,
                letterSpacing: "0.01em",
              }}
            >
              <div
                style={{
                  width: 6,
                  height: 6,
                  borderRadius: "50%",
                  background: dot,
                  opacity: 0.8,
                }}
              />
              {name}
            </div>
          ))}
        </div>

        {/* Main content — logo mark + wordmark + tagline */}
        <div
          style={{
            display: "flex",
            flexDirection: "column",
            alignItems: "center",
            gap: 0,
          }}
        >
          {/* Logo mark in a dark-green container card */}
          <div
            style={{
              width: 96,
              height: 96,
              borderRadius: 24,
              background: DARK_GREEN,
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
              marginBottom: 28,
              boxShadow: `0 0 60px rgba(207,225,185,0.18), 0 0 120px rgba(52,78,65,0.5)`,
            }}
          >
            {/*
              Inline SVG of the Sage logo mark (transparent variant).
              Path data from ZuraLog-Sage.svg — the blocky interlocking mark.
              Scaled to fit the 96×96 card with 18px padding on each side.
            */}
            <svg
              viewBox="0 0 2048 2048"
              width="60"
              height="60"
              style={{ display: "block" }}
            >
              <path
                fill={SAGE}
                d="m1377.8 420.9v189.9h670.2v473.8h-1377.8v230.8h707.6v501.3h-707.6v-379.8h-670.2v-473.8h1377.8v-230.8h-707.6v-501.3h707.6z"
              />
            </svg>
          </div>

          {/* Wordmark */}
          <div
            style={{
              fontSize: 80,
              fontWeight: 800,
              letterSpacing: "-3px",
              display: "flex",
              alignItems: "baseline",
              lineHeight: 1,
              marginBottom: 20,
            }}
          >
            <span style={{ color: "#ffffff" }}>Zura</span>
            <span style={{ color: SAGE }}>Log</span>
          </div>

          {/* Two-line tagline */}
          <div
            style={{
              display: "flex",
              flexDirection: "column",
              alignItems: "center",
              gap: 2,
              marginBottom: 24,
            }}
          >
            <div
              style={{
                fontSize: 28,
                fontWeight: 700,
                color: "rgba(255,255,255,0.90)",
                letterSpacing: "-0.5px",
              }}
            >
              Unified Health.
            </div>
            <div
              style={{
                fontSize: 28,
                fontWeight: 700,
                color: SAGE,
                letterSpacing: "-0.5px",
              }}
            >
              Made Smart.
            </div>
          </div>

          {/* Subtitle */}
          <div
            style={{
              fontSize: 18,
              color: "rgba(207,225,185,0.50)",
              textAlign: "center",
              maxWidth: 520,
              lineHeight: 1.6,
              letterSpacing: "0.01em",
            }}
          >
            The AI that connects your fitness apps and actually thinks.
          </div>
        </div>

        {/* Bottom row — CTA pill + domain */}
        <div
          style={{
            position: "absolute",
            bottom: 44,
            display: "flex",
            alignItems: "center",
            gap: 20,
          }}
        >
          <div
            style={{
              background: SAGE,
              borderRadius: 9999,
              padding: "11px 30px",
              fontSize: 16,
              fontWeight: 700,
              color: "#0D1F17",
              letterSpacing: "0.01em",
            }}
          >
            Join the Waitlist
          </div>
          <div
            style={{
              fontSize: 15,
              color: SAGE_DIM,
              fontWeight: 500,
              letterSpacing: "0.04em",
            }}
          >
            zuralog.com
          </div>
        </div>

        {/* Subtle dot-grid texture */}
        <div
          style={{
            position: "absolute",
            inset: 0,
            backgroundImage: `radial-gradient(rgba(207,225,185,0.07) 1px, transparent 1px)`,
            backgroundSize: "28px 28px",
          }}
        />

        {/* Inset border frame */}
        <div
          style={{
            position: "absolute",
            inset: 16,
            border: "1px solid rgba(207,225,185,0.08)",
            borderRadius: 28,
          }}
        />

        {/* Bottom vignette to ground the content */}
        <div
          style={{
            position: "absolute",
            bottom: 0,
            left: 0,
            right: 0,
            height: 200,
            background: `linear-gradient(to top, rgba(0,0,0,0.7) 0%, transparent 100%)`,
          }}
        />
      </div>
    ),
    { ...size }
  );
}
