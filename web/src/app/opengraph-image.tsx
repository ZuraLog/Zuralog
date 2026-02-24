/**
 * opengraph-image.tsx — dynamically generated Open Graph image.
 *
 * Uses Next.js ImageResponse to render a 1200x630 OG image at build time.
 * Dark background with Zuralog wordmark and tagline.
 *
 * Automatically served at /opengraph-image (picked up by Next.js metadata).
 */
import { ImageResponse } from 'next/og';

export const runtime = 'edge';
export const alt = 'Zuralog — The AI That Connects Your Fitness Apps';
export const size = { width: 1200, height: 630 };
export const contentType = 'image/png';

/**
 * Generates the OG image for the Zuralog website.
 *
 * @returns ImageResponse — a 1200x630 PNG.
 */
export default async function Image() {
  return new ImageResponse(
    (
      <div
        style={{
          background: '#0A0A0A',
          width: '100%',
          height: '100%',
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          justifyContent: 'center',
          fontFamily: 'sans-serif',
          gap: 24,
        }}
      >
        {/* Sage Green accent circle */}
        <div
          style={{
            position: 'absolute',
            width: 400,
            height: 400,
            borderRadius: '50%',
            background: 'radial-gradient(circle, rgba(207,225,185,0.15) 0%, transparent 70%)',
            top: '50%',
            left: '50%',
            transform: 'translate(-50%, -50%)',
          }}
        />

        {/* Logo / Wordmark */}
        <div
          style={{
            fontSize: 80,
            fontWeight: 700,
            color: '#CFE1B9',
            letterSpacing: '-2px',
          }}
        >
          Zuralog
        </div>

        {/* Tagline */}
        <div
          style={{
            fontSize: 28,
            color: 'rgba(255,255,255,0.6)',
            textAlign: 'center',
            maxWidth: 700,
          }}
        >
          The AI that connects your fitness apps and actually thinks.
        </div>

        {/* CTA badge */}
        <div
          style={{
            marginTop: 8,
            background: 'rgba(207,225,185,0.12)',
            border: '1px solid rgba(207,225,185,0.3)',
            borderRadius: 9999,
            padding: '8px 24px',
            fontSize: 20,
            color: '#CFE1B9',
          }}
        >
          Join the Waitlist
        </div>
      </div>
    ),
    { ...size },
  );
}
