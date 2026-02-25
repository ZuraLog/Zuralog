/**
 * opengraph-image.tsx — dynamically generated Open Graph image.
 *
 * Uses Next.js ImageResponse to render a 1200x630 OG image.
 * Cream/peach palette matching the marketing site design.
 * Automatically served at /opengraph-image by Next.js metadata routing.
 */
import { ImageResponse } from "next/og";

export const runtime = "edge";
export const alt = "ZuraLog — Unified Health. Made Smart.";
export const size = { width: 1200, height: 630 };
export const contentType = "image/png";

export default async function Image() {
  return new ImageResponse(
    (
      <div
        style={{
          background: "#FAFAF5",
          width: "100%",
          height: "100%",
          display: "flex",
          flexDirection: "column",
          alignItems: "center",
          justifyContent: "center",
          fontFamily: "sans-serif",
          position: "relative",
          overflow: "hidden",
        }}
      >
        {/* Background peach glow */}
        <div
          style={{
            position: "absolute",
            width: 700,
            height: 700,
            borderRadius: "50%",
            background:
              "radial-gradient(circle, rgba(255,171,118,0.15) 0%, transparent 65%)",
            top: "50%",
            left: "50%",
            transform: "translate(-50%, -50%)",
          }}
        />

        {/* Top bar — integration badges */}
        <div
          style={{
            position: "absolute",
            top: 40,
            display: "flex",
            alignItems: "center",
            gap: 12,
          }}
        >
          {["Strava", "Apple Health", "Oura", "Garmin", "Health Connect"].map(
            (name) => (
              <div
                key={name}
                style={{
                  display: "flex",
                  alignItems: "center",
                  gap: 6,
                  background: "rgba(45,45,45,0.06)",
                  border: "1px solid rgba(45,45,45,0.10)",
                  borderRadius: 9999,
                  padding: "6px 14px",
                  fontSize: 13,
                  color: "rgba(45,45,45,0.5)",
                }}
              >
                <div
                  style={{
                    width: 6,
                    height: 6,
                    borderRadius: "50%",
                    background:
                      name === "Strava"
                        ? "#FC4C02"
                        : name === "Apple Health"
                          ? "#FF3B30"
                          : name === "Oura"
                            ? "#9B8EFF"
                            : name === "Garmin"
                              ? "#007CC3"
                              : "#4285F4",
                  }}
                />
                {name}
              </div>
            )
          )}
        </div>

        {/* Main content */}
        <div
          style={{
            display: "flex",
            flexDirection: "column",
            alignItems: "center",
            gap: 20,
          }}
        >
          {/* Logo wordmark */}
          <div
            style={{
              fontSize: 88,
              fontWeight: 800,
              letterSpacing: "-3px",
              display: "flex",
              alignItems: "baseline",
            }}
          >
            <span style={{ color: "#2D2D2D" }}>Zura</span>
            <span style={{ color: "#FFAB76" }}>Log</span>
          </div>

          {/* Tagline */}
          <div
            style={{
              display: "flex",
              flexDirection: "column",
              alignItems: "center",
              gap: 4,
            }}
          >
            <div style={{ fontSize: 32, fontWeight: 700, color: "#2D2D2D" }}>
              Unified Health.
            </div>
            <div style={{ fontSize: 32, fontWeight: 700, color: "#FFAB76" }}>
              Made Smart.
            </div>
          </div>

          {/* Subtitle */}
          <div
            style={{
              fontSize: 20,
              color: "rgba(45,45,45,0.45)",
              textAlign: "center",
              maxWidth: 550,
              lineHeight: 1.5,
            }}
          >
            The AI fitness hub that connects all your apps into one intelligent
            action layer.
          </div>
        </div>

        {/* CTA badge at bottom */}
        <div
          style={{
            position: "absolute",
            bottom: 40,
            display: "flex",
            alignItems: "center",
            gap: 20,
          }}
        >
          <div
            style={{
              background: "#FFAB76",
              borderRadius: 9999,
              padding: "12px 32px",
              fontSize: 18,
              fontWeight: 700,
              color: "#2D2D2D",
            }}
          >
            Join the Waitlist
          </div>
          <div style={{ fontSize: 16, color: "rgba(45,45,45,0.35)" }}>
            zuralog.com
          </div>
        </div>

        {/* Subtle grid */}
        <div
          style={{
            position: "absolute",
            inset: 0,
            backgroundImage:
              "linear-gradient(rgba(45,45,45,0.04) 1px, transparent 1px), linear-gradient(90deg, rgba(45,45,45,0.04) 1px, transparent 1px)",
            backgroundSize: "60px 60px",
          }}
        />

        {/* Border frame */}
        <div
          style={{
            position: "absolute",
            inset: 16,
            border: "1px solid rgba(45,45,45,0.08)",
            borderRadius: 24,
          }}
        />
      </div>
    ),
    { ...size }
  );
}
