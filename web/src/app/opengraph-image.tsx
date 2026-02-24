/**
 * opengraph-image.tsx — dynamically generated Open Graph image.
 *
 * Uses Next.js ImageResponse to render a 1200x630 OG image at build time.
 * Premium dark design with sage branding, integration icons, and tagline.
 *
 * Automatically served at /opengraph-image (picked up by Next.js metadata).
 */
import { ImageResponse } from 'next/og';

export const runtime = 'edge';
export const alt = 'ZuraLog — Unified Health. Made Smart.';
export const size = { width: 1200, height: 630 };
export const contentType = 'image/png';

/**
 * Generates the OG image for the ZuraLog website.
 *
 * @returns ImageResponse — a 1200x630 PNG.
 */
export default async function Image() {
  return new ImageResponse(
    (
      <div
        style={{
          background: '#050505',
          width: '100%',
          height: '100%',
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          justifyContent: 'center',
          fontFamily: 'sans-serif',
          position: 'relative',
          overflow: 'hidden',
        }}
      >
        {/* Background glow effects */}
        <div
          style={{
            position: 'absolute',
            width: 600,
            height: 600,
            borderRadius: '50%',
            background: 'radial-gradient(circle, rgba(207,225,185,0.12) 0%, transparent 65%)',
            top: '50%',
            left: '50%',
            transform: 'translate(-50%, -50%)',
          }}
        />
        <div
          style={{
            position: 'absolute',
            width: 300,
            height: 300,
            borderRadius: '50%',
            background: 'radial-gradient(circle, rgba(207,225,185,0.08) 0%, transparent 70%)',
            top: -60,
            right: 100,
          }}
        />
        <div
          style={{
            position: 'absolute',
            width: 200,
            height: 200,
            borderRadius: '50%',
            background: 'radial-gradient(circle, rgba(207,225,185,0.06) 0%, transparent 70%)',
            bottom: -40,
            left: 120,
          }}
        />

        {/* Top bar — integration badges */}
        <div
          style={{
            position: 'absolute',
            top: 40,
            display: 'flex',
            alignItems: 'center',
            gap: 16,
          }}
        >
          {['Strava', 'Apple Health', 'Oura', 'Garmin', 'Health Connect'].map(
            (name) => (
              <div
                key={name}
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: 6,
                  background: 'rgba(255,255,255,0.04)',
                  border: '1px solid rgba(255,255,255,0.08)',
                  borderRadius: 9999,
                  padding: '6px 16px',
                  fontSize: 14,
                  color: 'rgba(255,255,255,0.45)',
                }}
              >
                <div
                  style={{
                    width: 6,
                    height: 6,
                    borderRadius: '50%',
                    background:
                      name === 'Strava'
                        ? '#FC4C02'
                        : name === 'Apple Health'
                          ? '#FF3B30'
                          : name === 'Oura'
                            ? '#9B8EFF'
                            : name === 'Garmin'
                              ? '#007CC3'
                              : '#4285F4',
                  }}
                />
                {name}
              </div>
            ),
          )}
        </div>

        {/* Main content */}
        <div
          style={{
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'center',
            gap: 20,
          }}
        >
          {/* Logo wordmark */}
          <div
            style={{
              fontSize: 88,
              fontWeight: 800,
              letterSpacing: '-3px',
              display: 'flex',
              alignItems: 'baseline',
            }}
          >
            <span style={{ color: '#ffffff' }}>Zura</span>
            <span style={{ color: '#CFE1B9' }}>Log</span>
          </div>

          {/* Tagline */}
          <div
            style={{
              display: 'flex',
              flexDirection: 'column',
              alignItems: 'center',
              gap: 4,
            }}
          >
            <div style={{ fontSize: 32, fontWeight: 700, color: '#ffffff' }}>
              Unified Health.
            </div>
            <div style={{ fontSize: 32, fontWeight: 700, color: '#CFE1B9' }}>
              Made Smart.
            </div>
          </div>

          {/* Subtitle */}
          <div
            style={{
              fontSize: 20,
              color: 'rgba(255,255,255,0.4)',
              textAlign: 'center',
              maxWidth: 550,
              lineHeight: 1.5,
            }}
          >
            The AI fitness hub that connects all your apps into one intelligent action layer.
          </div>
        </div>

        {/* CTA badge at bottom */}
        <div
          style={{
            position: 'absolute',
            bottom: 40,
            display: 'flex',
            alignItems: 'center',
            gap: 20,
          }}
        >
          <div
            style={{
              background: '#CFE1B9',
              borderRadius: 9999,
              padding: '12px 32px',
              fontSize: 18,
              fontWeight: 700,
              color: '#0a0a0a',
            }}
          >
            Join the Waitlist
          </div>
          <div
            style={{
              fontSize: 16,
              color: 'rgba(255,255,255,0.3)',
            }}
          >
            zuralog.com
          </div>
        </div>

        {/* Subtle grid lines */}
        <div
          style={{
            position: 'absolute',
            inset: 0,
            backgroundImage:
              'linear-gradient(rgba(207,225,185,0.03) 1px, transparent 1px), linear-gradient(90deg, rgba(207,225,185,0.03) 1px, transparent 1px)',
            backgroundSize: '60px 60px',
          }}
        />

        {/* Border frame */}
        <div
          style={{
            position: 'absolute',
            inset: 16,
            border: '1px solid rgba(255,255,255,0.06)',
            borderRadius: 24,
          }}
        />
      </div>
    ),
    { ...size },
  );
}
