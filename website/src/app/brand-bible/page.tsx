/**
 * Zuralog Brand Bible — Visual Design System Reference
 *
 * A living visual representation of every design token, component, and pattern
 * defined in docs/design.md. This page IS the proof that the design system works.
 */
import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Brand Bible",
  description: "Zuralog Design System — Visual Reference",
  robots: { index: false, follow: false },
};

/* ── Design Tokens ──────────────────────────────────────────────────────────── */

const t = {
  canvas: "#161618",
  surface: "#1E1E20",
  surfaceRaised: "#272729",
  surfaceOverlay: "#313133",
  sage: "#CFE1B9",
  warmWhite: "#F0EEE9",
  textPrimary: "#F0EEE9",
  textSecondary: "#9B9894",
  textOnSage: "#1A2E22",
  textOnWarmWhite: "#161618",
  success: "#34C759",
  warning: "#FF9500",
  error: "#FF3B30",
  syncing: "#007AFF",
  categoryActivity: "#30D158",
  categorySleep: "#5E5CE6",
  categoryHeart: "#FF375F",
  categoryNutrition: "#FF9F0A",
  categoryBody: "#64D2FF",
  categoryVitals: "#6AC4DC",
  categoryWellness: "#BF5AF2",
  categoryCycle: "#FF6482",
  categoryMobility: "#FFD60A",
  categoryEnvironment: "#63E6BE",
};

/* ── Pattern helpers ────────────────────────────────────────────────────────── */

/** Sage-colored surface pattern — visible contour lines with color-burn */
function sagePattern(opacity = 0.28): React.CSSProperties {
  return {
    position: "absolute" as const,
    inset: 0,
    backgroundImage: "url('/patterns/sage.png')",
    backgroundSize: "cover",
    backgroundPosition: "center",
    opacity,
    mixBlendMode: "color-burn" as const,
  };
}

/** Crimson pattern for destructive/error surfaces */
function crimsonPattern(opacity = 0.25): React.CSSProperties {
  return {
    position: "absolute" as const,
    inset: 0,
    backgroundImage: "url('/patterns/crimson.png')",
    backgroundSize: "cover",
    backgroundPosition: "center",
    opacity,
    mixBlendMode: "color-burn" as const,
  };
}

/** Dark surface pattern — screen blend for cards, avatars, etc. */
function darkPattern(opacity = 0.18, file = "sage.png"): React.CSSProperties {
  return {
    position: "absolute" as const,
    inset: 0,
    backgroundImage: `url('/patterns/${file}')`,
    backgroundSize: "cover",
    backgroundPosition: "center",
    opacity,
    mixBlendMode: "screen" as const,
  };
}

/* ── Inline SVG Icons ───────────────────────────────────────────────────────── */

const iconProps = {
  width: 20,
  height: 20,
  viewBox: "0 0 24 24",
  fill: "none",
  stroke: "currentColor",
  strokeWidth: 2,
  strokeLinecap: "round" as const,
  strokeLinejoin: "round" as const,
};

function IconBell() {
  return (
    <svg {...iconProps}>
      <path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9" />
      <path d="M13.73 21a2 2 0 0 1-3.46 0" />
    </svg>
  );
}

function IconPalette() {
  return (
    <svg {...iconProps}>
      <circle cx="13.5" cy="6.5" r="1.5" />
      <circle cx="17.5" cy="10.5" r="1.5" />
      <circle cx="8.5" cy="7.5" r="1.5" />
      <circle cx="6.5" cy="12" r="1.5" />
      <path d="M12 2C6.5 2 2 6.5 2 12s4.5 10 10 10c.926 0 1.648-.746 1.648-1.688 0-.437-.18-.835-.437-1.125-.29-.289-.438-.652-.438-1.125a1.64 1.64 0 0 1 1.668-1.668h1.996c3.051 0 5.555-2.503 5.555-5.554C21.965 6.012 17.461 2 12 2z" />
    </svg>
  );
}

function IconLock() {
  return (
    <svg {...iconProps}>
      <rect x="3" y="11" width="18" height="11" rx="2" ry="2" />
      <path d="M7 11V7a5 5 0 0 1 10 0v4" />
    </svg>
  );
}

function IconLeaf() {
  return (
    <svg {...iconProps} width={36} height={36}>
      <path d="M11 20A7 7 0 0 1 9.8 6.9C15.5 4.9 20 4 20 4s-1 4.5-3 10.1A7 7 0 0 1 11 20z" />
      <path d="M2 21c0-3 1.85-5.36 5.08-6C9.5 14.52 12 13 12 13" />
    </svg>
  );
}

function IconDroplet() {
  return (
    <svg {...iconProps}>
      <path d="M12 2.69l5.66 5.66a8 8 0 1 1-11.31 0z" />
    </svg>
  );
}

function IconSmile() {
  return (
    <svg {...iconProps}>
      <circle cx="12" cy="12" r="10" />
      <path d="M8 14s1.5 2 4 2 4-2 4-2" />
      <line x1="9" y1="9" x2="9.01" y2="9" />
      <line x1="15" y1="9" x2="15.01" y2="9" />
    </svg>
  );
}

function IconZap() {
  return (
    <svg {...iconProps}>
      <polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2" />
    </svg>
  );
}

function IconSearch() {
  return (
    <svg {...iconProps}>
      <circle cx="11" cy="11" r="8" />
      <line x1="21" y1="21" x2="16.65" y2="16.65" />
    </svg>
  );
}

/* ── Helpers ─────────────────────────────────────────────────────────────────── */

function SectionTitle({ children }: { children: React.ReactNode }) {
  return (
    <h2
      style={{
        color: t.sage,
        fontSize: 28,
        fontWeight: 600,
        marginTop: 64,
        marginBottom: 8,
        letterSpacing: -0.5,
      }}
    >
      {children}
    </h2>
  );
}

function SectionSubtitle({ children }: { children: React.ReactNode }) {
  return (
    <p style={{ color: t.textSecondary, fontSize: 14, marginBottom: 32, lineHeight: 1.5 }}>
      {children}
    </p>
  );
}

function Label({ children }: { children: React.ReactNode }) {
  return (
    <div
      style={{
        color: t.textSecondary,
        fontSize: 10,
        textTransform: "uppercase" as const,
        letterSpacing: 1,
        marginBottom: 10,
        marginTop: 24,
      }}
    >
      {children}
    </div>
  );
}

/* ── Page ─────────────────────────────────────────────────────────────────── */

export default function BrandBiblePage() {
  return (
    <div
      style={{
        background: t.canvas,
        minHeight: "100vh",
        fontFamily: "'Plus Jakarta Sans', system-ui, sans-serif",
        color: t.textPrimary,
      }}
    >
      {/* Header */}
      <div style={{ maxWidth: 960, margin: "0 auto", padding: "48px 24px 96px" }}>
        <div style={{ marginBottom: 48 }}>
          <h1
            style={{
              fontSize: 48,
              fontWeight: 700,
              color: t.sage,
              marginBottom: 8,
              letterSpacing: -1,
            }}
          >
            Zuralog Design System
          </h1>
          <p style={{ color: t.textSecondary, fontSize: 16, lineHeight: 1.6, maxWidth: 600 }}>
            Dark mode is the primary experience. Premium wellness. Calm confidence. Nature meets
            technology. The topographic contour-line pattern is the brand&apos;s visual signature.
          </p>
        </div>

        {/* ═══════════════════════════════════════════════════════════════════════
            1. CANVAS & ELEVATION
            ═══════════════════════════════════════════════════════════════════════ */}
        <SectionTitle>Canvas &amp; Elevation</SectionTitle>
        <SectionSubtitle>
          Surfaces are distinguished by brightness alone. Each elevation step is exactly +8 brighter
          across all RGB channels. No borders, no shadows.
        </SectionSubtitle>

        <div style={{ display: "flex", gap: 0, borderRadius: 20, overflow: "hidden", marginBottom: 32 }}>
          {[
            { label: "Canvas", hex: t.canvas, sub: "Screen background" },
            { label: "Surface", hex: t.surface, sub: "Cards, containers" },
            { label: "Surface Raised", hex: t.surfaceRaised, sub: "Popovers, dropdowns" },
            { label: "Surface Overlay", hex: t.surfaceOverlay, sub: "Modals, sheets" },
          ].map((level) => (
            <div
              key={level.label}
              style={{
                flex: 1,
                background: level.hex,
                padding: 24,
                minHeight: 120,
                display: "flex",
                flexDirection: "column",
                justifyContent: "flex-end",
              }}
            >
              <div style={{ color: t.textPrimary, fontSize: 14, fontWeight: 600 }}>
                {level.label}
              </div>
              <div style={{ color: t.textSecondary, fontSize: 11, marginTop: 2 }}>{level.sub}</div>
              <div
                style={{ color: t.textSecondary, fontSize: 11, fontFamily: "monospace", marginTop: 4 }}
              >
                {level.hex}
              </div>
            </div>
          ))}
        </div>

        {/* ═══════════════════════════════════════════════════════════════════════
            2. TYPOGRAPHY
            ═══════════════════════════════════════════════════════════════════════ */}
        <SectionTitle>Typography</SectionTitle>
        <SectionSubtitle>
          Plus Jakarta Sans on all platforms. Geometric, modern, and refined. Numbers render
          beautifully at every size.
        </SectionSubtitle>

        <div
          style={{
            background: t.surface,
            borderRadius: 20,
            padding: 32,
            display: "flex",
            flexDirection: "column",
            gap: 20,
          }}
        >
          {[
            { style: "Display Large", size: 34, weight: 700, sample: "78" },
            { style: "Display Medium", size: 28, weight: 600, sample: "Good morning, Alex" },
            { style: "Display Small", size: 24, weight: 600, sample: "Health Score" },
            { style: "Title Large", size: 20, weight: 500, sample: "Sleep Duration" },
            { style: "Title Medium", size: 17, weight: 500, sample: "Morning Briefing" },
            { style: "Body Large", size: 16, weight: 400, sample: "Your HRV is 18% higher after 7+ hours of sleep." },
            { style: "Body Medium", size: 14, weight: 400, sample: "On nights with deep sleep above 90 minutes, recovery improves." },
            { style: "Body Small", size: 12, weight: 400, sample: "Last updated 2 hours ago" },
            { style: "Label Large", size: 15, weight: 600, sample: "Log Activity" },
            { style: "Label Medium", size: 13, weight: 500, sample: "All  Sleep  Activity  Heart" },
            { style: "Label Small", size: 11, weight: 500, sample: "BPM  STEPS  KCAL" },
          ].map((item) => (
            <div
              key={item.style}
              style={{
                display: "flex",
                alignItems: "baseline",
                gap: 24,
                borderBottom: `1px solid rgba(240,238,233,0.04)`,
                paddingBottom: 16,
              }}
            >
              <div
                style={{
                  width: 140,
                  flexShrink: 0,
                  color: t.textSecondary,
                  fontSize: 11,
                  fontFamily: "monospace",
                }}
              >
                {item.style}
                <br />
                {item.size}pt / {item.weight}
              </div>
              <div
                style={{
                  color: t.textPrimary,
                  fontSize: item.size,
                  fontWeight: item.weight,
                }}
              >
                {item.sample}
              </div>
            </div>
          ))}
        </div>

        {/* ═══════════════════════════════════════════════════════════════════════
            3. COLOR — ACCENTS
            ═══════════════════════════════════════════════════════════════════════ */}
        <SectionTitle>Accent Colors</SectionTitle>
        <SectionSubtitle>
          Two accent roles. Sage = brand actions (&quot;tap this&quot;). Warm White = navigation
          (&quot;go here&quot;).
        </SectionSubtitle>

        <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 16, marginBottom: 32 }}>
          <div style={{ background: t.sage, borderRadius: 20, padding: 32 }}>
            <div style={{ color: t.textOnSage, fontSize: 24, fontWeight: 700 }}>Sage</div>
            <div style={{ color: t.textOnSage, fontSize: 13, opacity: 0.7, marginTop: 4 }}>
              #CFE1B9 — Primary actions, buttons, toggles, links
            </div>
          </div>
          <div style={{ background: t.warmWhite, borderRadius: 20, padding: 32 }}>
            <div style={{ color: t.textOnWarmWhite, fontSize: 24, fontWeight: 700 }}>Warm White</div>
            <div style={{ color: t.textOnWarmWhite, fontSize: 13, opacity: 0.6, marginTop: 4 }}>
              #F0EEE9 — Navigation, tabs, segmented controls
            </div>
          </div>
        </div>

        {/* ── Text Colors ── */}
        <Label>Text Colors</Label>
        <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr 1fr 1fr", gap: 12, marginBottom: 32 }}>
          {[
            { label: "Text Primary", hex: t.textPrimary, bg: t.canvas },
            { label: "Text Secondary", hex: t.textSecondary, bg: t.canvas },
            { label: "Text On Sage", hex: t.textOnSage, bg: t.sage },
            { label: "Text On Warm White", hex: t.textOnWarmWhite, bg: t.warmWhite },
          ].map((item) => (
            <div
              key={item.label}
              style={{
                background: item.bg,
                borderRadius: 16,
                padding: 20,
                border: item.bg === t.canvas ? `1px solid ${t.surfaceRaised}` : "none",
              }}
            >
              <div style={{ color: item.hex, fontSize: 20, fontWeight: 600 }}>Aa</div>
              <div style={{ color: item.hex, fontSize: 11, marginTop: 8, opacity: 0.8 }}>
                {item.label}
              </div>
              <div style={{ color: item.hex, fontSize: 10, fontFamily: "monospace", opacity: 0.6 }}>
                {item.hex}
              </div>
            </div>
          ))}
        </div>

        {/* ═══════════════════════════════════════════════════════════════════════
            4. HEALTH CATEGORIES
            ═══════════════════════════════════════════════════════════════════════ */}
        <SectionTitle>Health Category Colors</SectionTitle>
        <SectionSubtitle>Fixed across light and dark mode. Each category has its own color identity.</SectionSubtitle>

        <div style={{ display: "grid", gridTemplateColumns: "repeat(5, 1fr)", gap: 12 }}>
          {[
            { name: "Activity", color: t.categoryActivity },
            { name: "Sleep", color: t.categorySleep },
            { name: "Heart", color: t.categoryHeart },
            { name: "Nutrition", color: t.categoryNutrition },
            { name: "Body", color: t.categoryBody },
            { name: "Vitals", color: t.categoryVitals },
            { name: "Wellness", color: t.categoryWellness },
            { name: "Cycle", color: t.categoryCycle },
            { name: "Mobility", color: t.categoryMobility },
            { name: "Environment", color: t.categoryEnvironment },
          ].map((cat) => (
            <div
              key={cat.name}
              style={{
                background: t.surface,
                borderRadius: 16,
                padding: 16,
                textAlign: "center",
              }}
            >
              <div
                style={{
                  width: 32,
                  height: 32,
                  borderRadius: "50%",
                  background: cat.color,
                  margin: "0 auto 8px",
                }}
              />
              <div style={{ color: t.textPrimary, fontSize: 12, fontWeight: 500 }}>{cat.name}</div>
              <div style={{ color: t.textSecondary, fontSize: 10, fontFamily: "monospace" }}>
                {cat.color}
              </div>
            </div>
          ))}
        </div>

        {/* ═══════════════════════════════════════════════════════════════════════
            4b. HEALTH CATEGORY CARDS (with pattern variants)
            ═══════════════════════════════════════════════════════════════════════ */}
        <Label>Category Feature Cards</Label>
        <SectionSubtitle>
          Each health category has a matching pattern variant. The left accent bar uses the category
          color and the card background shows the matching topographic pattern.
        </SectionSubtitle>

        <div style={{ display: "grid", gridTemplateColumns: "repeat(3, 1fr)", gap: 12, marginBottom: 32 }}>
          {[
            { name: "Activity", color: t.categoryActivity, pattern: "green.png", metric: "8,432 steps", sub: "Daily goal: 10,000" },
            { name: "Sleep", color: t.categorySleep, pattern: "periwinkle.png", metric: "7h 24m", sub: "Deep: 1h 45m" },
            { name: "Heart", color: t.categoryHeart, pattern: "rose.png", metric: "68 bpm", sub: "Resting heart rate" },
            { name: "Nutrition", color: t.categoryNutrition, pattern: "amber.png", metric: "1,850 kcal", sub: "Target: 2,200" },
            { name: "Body", color: t.categoryBody, pattern: "sky-blue.png", metric: "72.4 kg", sub: "BMI: 23.1" },
            { name: "Wellness", color: t.categoryWellness, pattern: "purple.png", metric: "78 / 100", sub: "Health score" },
          ].map((cat) => (
            <div
              key={cat.name}
              style={{
                display: "flex",
                borderRadius: 16,
                overflow: "hidden",
                background: t.surface,
              }}
            >
              {/* Left accent bar */}
              <div style={{ width: 4, background: cat.color, flexShrink: 0 }} />
              {/* Card body with pattern */}
              <div
                style={{
                  flex: 1,
                  padding: 16,
                  position: "relative" as const,
                  overflow: "hidden",
                }}
              >
                <div
                  style={{
                    position: "absolute" as const,
                    inset: 0,
                    backgroundImage: `url('/patterns/${cat.pattern}')`,
                    backgroundSize: "cover",
                    backgroundPosition: "center",
                    opacity: 0.15,
                    mixBlendMode: "screen" as const,
                  }}
                />
                <div style={{ position: "relative" as const }}>
                  <div style={{ color: cat.color, fontSize: 10, fontWeight: 600, textTransform: "uppercase" as const, letterSpacing: 0.5, marginBottom: 4 }}>
                    {cat.name}
                  </div>
                  <div style={{ color: t.textPrimary, fontSize: 20, fontWeight: 700 }}>
                    {cat.metric}
                  </div>
                  <div style={{ color: t.textSecondary, fontSize: 11, marginTop: 2 }}>
                    {cat.sub}
                  </div>
                </div>
              </div>
            </div>
          ))}
        </div>

        {/* ═══════════════════════════════════════════════════════════════════════
            5. SEMANTIC / STATUS COLORS
            ═══════════════════════════════════════════════════════════════════════ */}
        <Label>Semantic / Status</Label>
        <div style={{ display: "grid", gridTemplateColumns: "repeat(4, 1fr)", gap: 12, marginBottom: 32 }}>
          {[
            { name: "Success", color: t.success },
            { name: "Warning", color: t.warning },
            { name: "Error", color: t.error },
            { name: "Syncing", color: t.syncing },
          ].map((s) => (
            <div key={s.name} style={{ display: "flex", alignItems: "center", gap: 10 }}>
              <div style={{ width: 24, height: 24, borderRadius: "50%", background: s.color, flexShrink: 0 }} />
              <div>
                <div style={{ color: t.textPrimary, fontSize: 13 }}>{s.name}</div>
                <div style={{ color: t.textSecondary, fontSize: 10, fontFamily: "monospace" }}>{s.color}</div>
              </div>
            </div>
          ))}
        </div>

        {/* ═══════════════════════════════════════════════════════════════════════
            6. SPACING
            ═══════════════════════════════════════════════════════════════════════ */}
        <SectionTitle>Spacing</SectionTitle>
        <SectionSubtitle>Based on a 4px grid with a 2px fine-tuning step.</SectionSubtitle>

        <div style={{ display: "flex", alignItems: "flex-end", gap: 16, marginBottom: 32 }}>
          {[
            { token: "XXS", value: 2 },
            { token: "XS", value: 4 },
            { token: "SM", value: 8 },
            { token: "MD", value: 16 },
            { token: "MD+", value: 20 },
            { token: "LG", value: 24 },
            { token: "XL", value: 32 },
            { token: "XXL", value: 48 },
          ].map((s) => (
            <div key={s.token} style={{ textAlign: "center" }}>
              <div
                style={{
                  width: 48,
                  height: s.value * 2,
                  background: t.sage,
                  borderRadius: 4,
                  opacity: 0.6,
                  marginBottom: 8,
                }}
              />
              <div style={{ color: t.textPrimary, fontSize: 12, fontWeight: 600 }}>{s.token}</div>
              <div style={{ color: t.textSecondary, fontSize: 10 }}>{s.value}px</div>
            </div>
          ))}
        </div>

        {/* ═══════════════════════════════════════════════════════════════════════
            7. SHAPE (BORDER RADIUS)
            ═══════════════════════════════════════════════════════════════════════ */}
        <SectionTitle>Shape</SectionTitle>
        <SectionSubtitle>Border radius tokens from tight to pill.</SectionSubtitle>

        <div style={{ display: "flex", gap: 16, marginBottom: 32 }}>
          {[
            { token: "XS", value: 8, size: 48 },
            { token: "SM", value: 12, size: 56 },
            { token: "MD", value: 16, size: 64 },
            { token: "LG", value: 20, size: 72 },
            { token: "XL", value: 28, size: 80 },
            { token: "Pill", value: 100, size: 48 },
          ].map((s) => (
            <div key={s.token} style={{ textAlign: "center" }}>
              <div
                style={{
                  width: s.token === "Pill" ? 96 : s.size,
                  height: s.size,
                  background: t.surface,
                  borderRadius: s.value,
                  marginBottom: 8,
                }}
              />
              <div style={{ color: t.textPrimary, fontSize: 12, fontWeight: 600 }}>{s.token}</div>
              <div style={{ color: t.textSecondary, fontSize: 10 }}>{s.value}px</div>
            </div>
          ))}
        </div>

        {/* ═══════════════════════════════════════════════════════════════════════
            8. BUTTONS
            ═══════════════════════════════════════════════════════════════════════ */}
        <SectionTitle>Buttons</SectionTitle>
        <SectionSubtitle>
          Pill radius at all sizes. Filled buttons get the topographic pattern. Visual hierarchy:
          Pattern + fill &gt; Outline &gt; Text.
        </SectionSubtitle>

        <div style={{ background: t.surface, borderRadius: 20, padding: 32, marginBottom: 16 }}>
          <Label>Button Types</Label>
          <div style={{ display: "flex", gap: 16, alignItems: "center", flexWrap: "wrap", marginBottom: 24 }}>
            {/* Primary */}
            <div
              style={{
                background: t.sage,
                borderRadius: 100,
                padding: "14px 28px",
                position: "relative" as const,
                overflow: "hidden",
              }}
            >
              <div style={sagePattern(0.28)} />
              <span
                style={{
                  position: "relative" as const,
                  color: t.textOnSage,
                  fontWeight: 600,
                  fontSize: 15,
                }}
              >
                Primary
              </span>
            </div>
            {/* Destructive */}
            <div
              style={{
                background: t.error,
                borderRadius: 100,
                padding: "14px 28px",
                position: "relative" as const,
                overflow: "hidden",
              }}
            >
              <div style={crimsonPattern(0.25)} />
              <span style={{ position: "relative" as const, color: "#FFFFFF", fontWeight: 600, fontSize: 15 }}>
                Destructive
              </span>
            </div>
            {/* Secondary */}
            <div
              style={{
                border: `1.5px solid rgba(240,238,233,0.2)`,
                borderRadius: 100,
                padding: "14px 28px",
              }}
            >
              <span style={{ color: t.warmWhite, fontWeight: 600, fontSize: 15 }}>Secondary</span>
            </div>
            {/* Text */}
            <div style={{ padding: "14px 28px" }}>
              <span style={{ color: t.sage, fontWeight: 600, fontSize: 15 }}>Text Button &rarr;</span>
            </div>
          </div>

          <Label>Button Sizes</Label>
          <div style={{ display: "flex", gap: 12, alignItems: "center" }}>
            {/* Large */}
            <div
              style={{
                background: t.sage,
                borderRadius: 100,
                padding: "0 28px",
                height: 52,
                display: "flex",
                alignItems: "center",
                position: "relative" as const,
                overflow: "hidden",
              }}
            >
              <div style={sagePattern(0.28)} />
              <span style={{ position: "relative" as const, color: t.textOnSage, fontWeight: 600, fontSize: 15 }}>
                Large (52px)
              </span>
            </div>
            {/* Medium */}
            <div
              style={{
                background: t.sage,
                borderRadius: 100,
                padding: "0 24px",
                height: 44,
                display: "flex",
                alignItems: "center",
                position: "relative" as const,
                overflow: "hidden",
              }}
            >
              <div style={sagePattern(0.28)} />
              <span style={{ position: "relative" as const, color: t.textOnSage, fontWeight: 600, fontSize: 15 }}>
                Medium (44px)
              </span>
            </div>
            {/* Small */}
            <div
              style={{
                background: t.sage,
                borderRadius: 100,
                padding: "0 18px",
                height: 32,
                display: "flex",
                alignItems: "center",
                position: "relative" as const,
                overflow: "hidden",
              }}
            >
              <div style={sagePattern(0.25)} />
              <span style={{ position: "relative" as const, color: t.textOnSage, fontWeight: 500, fontSize: 13 }}>
                Small (32px)
              </span>
            </div>
          </div>

          <Label>Button States</Label>
          <div style={{ display: "flex", gap: 12, alignItems: "center" }}>
            <div style={{ textAlign: "center" }}>
              <div
                style={{
                  background: t.sage,
                  borderRadius: 100,
                  padding: "10px 24px",
                  position: "relative" as const,
                  overflow: "hidden",
                }}
              >
                <div style={sagePattern(0.28)} />
                <span style={{ position: "relative" as const, color: t.textOnSage, fontWeight: 600, fontSize: 14 }}>
                  Default
                </span>
              </div>
            </div>
            <div style={{ textAlign: "center" }}>
              <div
                style={{
                  background: t.sage,
                  borderRadius: 100,
                  padding: "10px 24px",
                  opacity: 0.85,
                  transform: "scale(0.97)",
                  position: "relative" as const,
                  overflow: "hidden",
                }}
              >
                <div style={sagePattern(0.28)} />
                <span style={{ position: "relative" as const, color: t.textOnSage, fontWeight: 600, fontSize: 14 }}>
                  Pressed
                </span>
              </div>
            </div>
            <div style={{ textAlign: "center" }}>
              <div
                style={{
                  background: t.sage,
                  borderRadius: 100,
                  padding: "10px 24px",
                  opacity: 0.4,
                }}
              >
                <span style={{ color: t.textOnSage, fontWeight: 600, fontSize: 14 }}>Disabled</span>
              </div>
            </div>
          </div>
        </div>

        {/* ═══════════════════════════════════════════════════════════════════════
            9. CARDS
            ═══════════════════════════════════════════════════════════════════════ */}
        <SectionTitle>Cards</SectionTitle>
        <SectionSubtitle>
          Soft, rounded corners with generous padding. Hero and feature cards get the pattern. Data
          cards stay clean.
        </SectionSubtitle>

        <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr 1fr", gap: 16, marginBottom: 32 }}>
          {/* Hero Card */}
          <div>
            <Label>Hero Card (18%)</Label>
            <div
              style={{
                background: t.surface,
                borderRadius: 20,
                padding: 20,
                position: "relative" as const,
                overflow: "hidden",
              }}
            >
              <div style={darkPattern(0.18, "sage.png")} />
              <div style={{ position: "relative" as const }}>
                <div style={{ color: t.textSecondary, fontSize: 11, textTransform: "uppercase" as const, letterSpacing: 0.5 }}>
                  Health Score
                </div>
                <div style={{ color: t.sage, fontSize: 40, fontWeight: 700, marginTop: 4 }}>78</div>
                <div style={{ color: t.textSecondary, fontSize: 12, marginTop: 4 }}>
                  Your best week this month
                </div>
              </div>
            </div>
          </div>

          {/* Feature Card */}
          <div>
            <Label>Feature Card (15%)</Label>
            <div
              style={{
                background: t.surface,
                borderRadius: 20,
                padding: 20,
                position: "relative" as const,
                overflow: "hidden",
              }}
            >
              <div style={darkPattern(0.15, "sage.png")} />
              <div style={{ position: "relative" as const }}>
                <div style={{ color: t.textPrimary, fontSize: 15, fontWeight: 600, marginBottom: 6 }}>
                  Sleep linked to HRV
                </div>
                <div style={{ color: t.textSecondary, fontSize: 13, lineHeight: 1.5 }}>
                  Your HRV is 18% higher after 7+ hours of sleep.
                </div>
              </div>
            </div>
          </div>

          {/* Data Card */}
          <div>
            <Label>Data Card (no pattern)</Label>
            <div style={{ background: t.surface, borderRadius: 16, padding: 16 }}>
              <div style={{ color: t.textSecondary, fontSize: 10, textTransform: "uppercase" as const }}>Steps</div>
              <div style={{ color: t.textPrimary, fontSize: 22, fontWeight: 600, marginTop: 6 }}>
                8,432
              </div>
              <div style={{ color: t.categoryActivity, fontSize: 10, marginTop: 4 }}>&uarr; 12%</div>
            </div>
          </div>
        </div>

        {/* ═══════════════════════════════════════════════════════════════════════
            10. INPUTS & SELECTION
            ═══════════════════════════════════════════════════════════════════════ */}
        <SectionTitle>Inputs &amp; Selection</SectionTitle>
        <SectionSubtitle>
          Filled style — Surface fill with no border. Any Sage-filled interactive surface gets the
          topographic pattern.
        </SectionSubtitle>

        <div style={{ background: t.surface, borderRadius: 20, padding: 32, marginBottom: 32 }}>
          <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 32 }}>
            {/* Left column */}
            <div>
              <Label>Text Field</Label>
              <div style={{ background: t.canvas, borderRadius: 12, padding: "14px 16px" }}>
                <div style={{ color: t.textSecondary, fontSize: 11, fontWeight: 500, marginBottom: 4 }}>
                  Display Name
                </div>
                <div style={{ color: t.textPrimary, fontSize: 16 }}>Alex Johnson</div>
              </div>

              <Label>Toggle Switch</Label>
              <div style={{ display: "flex", flexDirection: "column" as const, gap: 12 }}>
                <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
                  <span style={{ color: t.textPrimary, fontSize: 14 }}>Morning Briefing</span>
                  <div
                    style={{
                      width: 44,
                      height: 26,
                      background: t.sage,
                      borderRadius: 13,
                      position: "relative" as const,
                      overflow: "hidden",
                    }}
                  >
                    <div style={sagePattern(0.28)} />
                    <div
                      style={{
                        width: 22,
                        height: 22,
                        background: "white",
                        borderRadius: "50%",
                        position: "absolute" as const,
                        right: 2,
                        top: 2,
                      }}
                    />
                  </div>
                </div>
                <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
                  <span style={{ color: t.textPrimary, fontSize: 14 }}>Smart Reminders</span>
                  <div
                    style={{
                      width: 44,
                      height: 26,
                      background: t.surfaceRaised,
                      borderRadius: 13,
                      position: "relative" as const,
                    }}
                  >
                    <div
                      style={{
                        width: 22,
                        height: 22,
                        background: t.textSecondary,
                        borderRadius: "50%",
                        position: "absolute" as const,
                        left: 2,
                        top: 2,
                      }}
                    />
                  </div>
                </div>
              </div>

              <Label>Checkbox &amp; Radio</Label>
              <div style={{ display: "flex", flexDirection: "column" as const, gap: 12 }}>
                <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
                  <div
                    style={{
                      width: 20,
                      height: 20,
                      background: t.sage,
                      borderRadius: 4,
                      display: "flex",
                      alignItems: "center",
                      justifyContent: "center",
                      position: "relative" as const,
                      overflow: "hidden",
                    }}
                  >
                    <div style={sagePattern(0.28)} />
                    <span style={{ position: "relative" as const, color: t.textOnSage, fontSize: 12, fontWeight: 700 }}>
                      &#10003;
                    </span>
                  </div>
                  <span style={{ color: t.textPrimary, fontSize: 14 }}>Checked</span>
                </div>
                <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
                  <div
                    style={{
                      width: 20,
                      height: 20,
                      border: `2px solid ${t.textSecondary}`,
                      borderRadius: 4,
                    }}
                  />
                  <span style={{ color: t.textPrimary, fontSize: 14 }}>Unchecked</span>
                </div>
                <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
                  <div
                    style={{
                      width: 20,
                      height: 20,
                      border: `2px solid ${t.sage}`,
                      borderRadius: "50%",
                      display: "flex",
                      alignItems: "center",
                      justifyContent: "center",
                    }}
                  >
                    <div style={{ width: 10, height: 10, background: t.sage, borderRadius: "50%" }} />
                  </div>
                  <span style={{ color: t.textPrimary, fontSize: 14 }}>Selected Radio</span>
                </div>
              </div>
            </div>

            {/* Right column */}
            <div>
              <Label>Slider</Label>
              <div>
                <div style={{ display: "flex", justifyContent: "space-between", marginBottom: 8 }}>
                  <span style={{ color: t.textPrimary, fontSize: 13 }}>Water intake</span>
                  <span style={{ color: t.sage, fontSize: 13, fontWeight: 600 }}>1,800 ml</span>
                </div>
                <div
                  style={{
                    height: 6,
                    background: t.surfaceRaised,
                    borderRadius: 3,
                    position: "relative" as const,
                  }}
                >
                  {/* Filled track */}
                  <div
                    style={{
                      height: 6,
                      background: t.sage,
                      borderRadius: 3,
                      width: "65%",
                      position: "relative" as const,
                      overflow: "hidden",
                    }}
                  >
                    <div style={sagePattern(0.25)} />
                  </div>
                  {/* Thumb */}
                  <div
                    style={{
                      width: 18,
                      height: 18,
                      background: t.sage,
                      borderRadius: "50%",
                      position: "absolute" as const,
                      left: "calc(65% - 9px)",
                      top: -6,
                      overflow: "hidden",
                    }}
                  >
                    <div style={sagePattern(0.28)} />
                  </div>
                </div>
              </div>

              <Label>Segmented Control</Label>
              <div
                style={{
                  display: "flex",
                  background: t.canvas,
                  borderRadius: 12,
                  padding: 4,
                  position: "relative" as const,
                  overflow: "hidden",
                }}
              >
                <div style={darkPattern(0.06, "sage.png")} />
                <div
                  style={{
                    position: "relative" as const,
                    flex: 1,
                    background: t.warmWhite,
                    color: t.textOnWarmWhite,
                    textAlign: "center" as const,
                    padding: 8,
                    borderRadius: 9,
                    fontSize: 12,
                    fontWeight: 600,
                  }}
                >
                  Today
                </div>
                <div
                  style={{
                    position: "relative" as const,
                    flex: 1,
                    textAlign: "center" as const,
                    padding: 8,
                    color: t.textSecondary,
                    fontSize: 12,
                  }}
                >
                  Week
                </div>
                <div
                  style={{
                    position: "relative" as const,
                    flex: 1,
                    textAlign: "center" as const,
                    padding: 8,
                    color: t.textSecondary,
                    fontSize: 12,
                  }}
                >
                  Month
                </div>
              </div>

              <Label>Chips</Label>
              <div style={{ display: "flex", gap: 8, flexWrap: "wrap" as const }}>
                {/* Active chip */}
                <div
                  style={{
                    background: "rgba(207,225,185,0.15)",
                    borderRadius: 100,
                    padding: "8px 16px",
                    position: "relative" as const,
                    overflow: "hidden",
                  }}
                >
                  <div style={darkPattern(0.15, "original.png")} />
                  <span style={{ position: "relative" as const, color: t.sage, fontSize: 12, fontWeight: 600 }}>
                    All
                  </span>
                </div>
                {["Sleep", "Activity", "Heart"].map((chip) => (
                  <div
                    key={chip}
                    style={{ background: t.canvas, borderRadius: 100, padding: "8px 16px" }}
                  >
                    <span style={{ color: t.textSecondary, fontSize: 12 }}>{chip}</span>
                  </div>
                ))}
              </div>

              <Label>Dropdown</Label>
              <div
                style={{
                  background: t.canvas,
                  borderRadius: 12,
                  padding: "14px 16px",
                  display: "flex",
                  justifyContent: "space-between",
                  alignItems: "center",
                }}
              >
                <div>
                  <div style={{ color: t.textSecondary, fontSize: 11, fontWeight: 500, marginBottom: 2 }}>
                    Coach Persona
                  </div>
                  <div style={{ color: t.textPrimary, fontSize: 16 }}>Balanced</div>
                </div>
                <span style={{ color: t.textSecondary }}>&darr;</span>
              </div>
            </div>
          </div>
        </div>

        {/* ═══════════════════════════════════════════════════════════════════════
            11. FEEDBACK
            ═══════════════════════════════════════════════════════════════════════ */}
        <SectionTitle>Feedback &amp; Communication</SectionTitle>
        <SectionSubtitle>
          How the app talks back. Higher urgency = higher elevation level.
        </SectionSubtitle>

        <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 16, marginBottom: 32 }}>
          {/* Toasts */}
          <div style={{ background: t.surface, borderRadius: 20, padding: 24 }}>
            <Label>Toast / Snackbar</Label>
            <div style={{ display: "flex", flexDirection: "column" as const, gap: 10 }}>
              <div
                style={{
                  background: t.surfaceRaised,
                  borderRadius: 100,
                  padding: "10px 20px",
                  display: "flex",
                  alignItems: "center",
                  gap: 10,
                }}
              >
                <div style={{ width: 8, height: 8, borderRadius: "50%", background: t.success }} />
                <span style={{ color: t.textPrimary, fontSize: 13 }}>Weight logged successfully</span>
              </div>
              <div
                style={{
                  background: t.surfaceRaised,
                  borderRadius: 100,
                  padding: "10px 20px",
                  display: "flex",
                  alignItems: "center",
                  justifyContent: "space-between",
                }}
              >
                <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
                  <div style={{ width: 8, height: 8, borderRadius: "50%", background: t.error }} />
                  <span style={{ color: t.textPrimary, fontSize: 13 }}>Connection failed</span>
                </div>
                <span style={{ color: t.sage, fontSize: 13, fontWeight: 600 }}>Retry</span>
              </div>
            </div>
          </div>

          {/* Dialog */}
          <div style={{ background: t.surface, borderRadius: 20, padding: 24 }}>
            <Label>Alert Dialog</Label>
            <div style={{ background: t.surfaceOverlay, borderRadius: 28, padding: 24 }}>
              <div style={{ color: t.textPrimary, fontSize: 17, fontWeight: 500, marginBottom: 8 }}>
                Disconnect Strava?
              </div>
              <div style={{ color: t.textSecondary, fontSize: 13, lineHeight: 1.5, marginBottom: 20 }}>
                Your data stays, but new workouts won&apos;t sync.
              </div>
              <div style={{ display: "flex", gap: 10 }}>
                <div
                  style={{
                    flex: 1,
                    border: `1.5px solid rgba(240,238,233,0.2)`,
                    borderRadius: 100,
                    padding: 10,
                    textAlign: "center" as const,
                  }}
                >
                  <span style={{ color: t.warmWhite, fontWeight: 600, fontSize: 13 }}>Cancel</span>
                </div>
                <div
                  style={{
                    flex: 1,
                    background: t.error,
                    borderRadius: 100,
                    padding: 10,
                    textAlign: "center" as const,
                    position: "relative" as const,
                    overflow: "hidden",
                  }}
                >
                  <div style={crimsonPattern(0.25)} />
                  <span style={{ position: "relative" as const, color: "#FFF", fontWeight: 600, fontSize: 13 }}>
                    Disconnect
                  </span>
                </div>
              </div>
            </div>
          </div>

          {/* Loading states */}
          <div style={{ background: t.surface, borderRadius: 20, padding: 24 }}>
            <Label>Skeleton Loader</Label>
            <div style={{ background: t.canvas, borderRadius: 16, padding: 16 }}>
              <div
                style={{
                  background: t.surfaceRaised,
                  borderRadius: 6,
                  height: 10,
                  width: "40%",
                  marginBottom: 10,
                }}
              />
              <div
                style={{
                  background: t.surfaceRaised,
                  borderRadius: 6,
                  height: 24,
                  width: "60%",
                  marginBottom: 8,
                }}
              />
              <div style={{ background: t.surfaceRaised, borderRadius: 6, height: 10, width: "30%" }} />
            </div>

            <Label>Progress Bar</Label>
            <div>
              <div style={{ display: "flex", justifyContent: "space-between", marginBottom: 4 }}>
                <span style={{ color: t.textSecondary, fontSize: 11 }}>Syncing Fitbit...</span>
                <span style={{ color: t.sage, fontSize: 11 }}>65%</span>
              </div>
              <div style={{ height: 4, background: t.surfaceRaised, borderRadius: 2 }}>
                <div
                  style={{
                    height: 4,
                    background: t.sage,
                    borderRadius: 2,
                    width: "65%",
                    position: "relative" as const,
                    overflow: "hidden",
                  }}
                >
                  <div style={sagePattern(0.25)} />
                </div>
              </div>
            </div>
          </div>

          {/* Badge & Tooltip */}
          <div style={{ background: t.surface, borderRadius: 20, padding: 24 }}>
            <Label>Badge &amp; Tooltip</Label>
            <div style={{ display: "flex", alignItems: "center", gap: 32, marginTop: 8 }}>
              {/* Badge with bell SVG icon */}
              <div style={{ position: "relative" as const }}>
                <div
                  style={{
                    width: 32,
                    height: 32,
                    background: t.surfaceRaised,
                    borderRadius: 8,
                    display: "flex",
                    alignItems: "center",
                    justifyContent: "center",
                    color: t.textSecondary,
                  }}
                >
                  <IconBell />
                </div>
                <div
                  style={{
                    position: "absolute" as const,
                    top: -4,
                    right: -4,
                    width: 16,
                    height: 16,
                    background: t.error,
                    borderRadius: "50%",
                    display: "flex",
                    alignItems: "center",
                    justifyContent: "center",
                    border: `2px solid ${t.canvas}`,
                  }}
                >
                  <span style={{ color: "white", fontSize: 8, fontWeight: 700 }}>3</span>
                </div>
              </div>
              {/* Tooltip — pointer triangle connected to body */}
              <div style={{ position: "relative" as const, display: "inline-block" }}>
                <div
                  style={{
                    background: t.surfaceRaised,
                    borderRadius: 8,
                    padding: "8px 12px",
                    position: "relative" as const,
                    zIndex: 1,
                  }}
                >
                  <span style={{ color: t.textPrimary, fontSize: 12 }}>Tap to expand</span>
                </div>
                <div
                  style={{
                    width: 0,
                    height: 0,
                    borderLeft: "6px solid transparent",
                    borderRight: "6px solid transparent",
                    borderTop: `6px solid ${t.surfaceRaised}`,
                    position: "absolute" as const,
                    bottom: -6,
                    left: 20,
                  }}
                />
              </div>
            </div>
          </div>
        </div>

        {/* ═══════════════════════════════════════════════════════════════════════
            12. DISPLAY COMPONENTS
            ═══════════════════════════════════════════════════════════════════════ */}
        <SectionTitle>Display Components</SectionTitle>
        <SectionSubtitle>List items, avatars, dividers, accordions — information building blocks.</SectionSubtitle>

        <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 16, marginBottom: 32 }}>
          {/* List Items */}
          <div>
            <Label>List Items</Label>
            <div style={{ background: t.surface, borderRadius: 16, overflow: "hidden" }}>
              {[
                { icon: "bell" as const, title: "Notifications", sub: "Morning briefing, reminders" },
                { icon: "palette" as const, title: "Appearance", sub: "Theme, haptics" },
                { icon: "lock" as const, title: "Privacy & Data", sub: "AI memory, export" },
              ].map((item, i, arr) => (
                <div
                  key={item.title}
                  style={{
                    padding: "12px 16px",
                    display: "flex",
                    justifyContent: "space-between",
                    alignItems: "center",
                    borderBottom: i < arr.length - 1 ? "1px solid rgba(240,238,233,0.04)" : "none",
                  }}
                >
                  <div style={{ display: "flex", alignItems: "center", gap: 12 }}>
                    <div
                      style={{
                        width: 32,
                        height: 32,
                        background: t.surfaceRaised,
                        borderRadius: 8,
                        display: "flex",
                        alignItems: "center",
                        justifyContent: "center",
                        position: "relative" as const,
                        overflow: "hidden",
                        color: t.textSecondary,
                      }}
                    >
                      <div style={darkPattern(0.18, "original.png")} />
                      <span style={{ position: "relative" as const }}>
                        {item.icon === "bell" && <IconBell />}
                        {item.icon === "palette" && <IconPalette />}
                        {item.icon === "lock" && <IconLock />}
                      </span>
                    </div>
                    <div>
                      <div style={{ color: t.textPrimary, fontSize: 14, fontWeight: 500 }}>
                        {item.title}
                      </div>
                      <div style={{ color: t.textSecondary, fontSize: 11 }}>{item.sub}</div>
                    </div>
                  </div>
                  <span style={{ color: t.textSecondary }}>&rarr;</span>
                </div>
              ))}
            </div>
          </div>

          {/* Avatars & Dividers */}
          <div>
            <Label>Avatars (with pattern on default)</Label>
            <div style={{ display: "flex", gap: 16, alignItems: "center", marginBottom: 24 }}>
              {[48, 36, 24].map((size) => (
                <div
                  key={size}
                  style={{
                    width: size,
                    height: size,
                    borderRadius: "50%",
                    background: t.surfaceRaised,
                    display: "flex",
                    alignItems: "center",
                    justifyContent: "center",
                    position: "relative" as const,
                    overflow: "hidden",
                  }}
                >
                  <div style={darkPattern(0.2, "original.png")} />
                  <span
                    style={{
                      position: "relative" as const,
                      color: t.sage,
                      fontSize: size * 0.38,
                      fontWeight: 600,
                    }}
                  >
                    AJ
                  </span>
                </div>
              ))}
              <span style={{ color: t.textSecondary, fontSize: 11 }}>48 / 36 / 24px</span>
            </div>

            <Label>Divider</Label>
            <div style={{ padding: "8px 0" }}>
              <div style={{ height: 1, background: "rgba(240,238,233,0.06)" }} />
              <div style={{ color: t.textSecondary, fontSize: 11, marginTop: 8 }}>
                1px - Warm White at 6% opacity
              </div>
            </div>

            <Label>Accordion</Label>
            <div style={{ background: t.surface, borderRadius: 16, overflow: "hidden" }}>
              <div
                style={{
                  padding: "12px 16px",
                  display: "flex",
                  justifyContent: "space-between",
                  alignItems: "center",
                }}
              >
                <span style={{ color: t.textPrimary, fontSize: 14, fontWeight: 500 }}>
                  Sleep Details
                </span>
                <span style={{ color: t.sage, fontSize: 12 }}>&darr;</span>
              </div>
              <div
                style={{
                  padding: "0 16px 12px",
                  borderTop: "1px solid rgba(240,238,233,0.04)",
                }}
              >
                <div
                  style={{
                    display: "flex",
                    justifyContent: "space-between",
                    paddingTop: 12,
                  }}
                >
                  <span style={{ color: t.textSecondary, fontSize: 12 }}>Deep Sleep</span>
                  <span style={{ color: t.textPrimary, fontSize: 12 }}>1h 45m</span>
                </div>
                <div style={{ display: "flex", justifyContent: "space-between", marginTop: 8 }}>
                  <span style={{ color: t.textSecondary, fontSize: 12 }}>REM Sleep</span>
                  <span style={{ color: t.textPrimary, fontSize: 12 }}>2h 10m</span>
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* ═══════════════════════════════════════════════════════════════════════
            13. SPECIAL SURFACES
            ═══════════════════════════════════════════════════════════════════════ */}
        <SectionTitle>Special Surfaces</SectionTitle>
        <SectionSubtitle>Empty states, onboarding, and the FAB.</SectionSubtitle>

        <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr 1fr", gap: 16, marginBottom: 32 }}>
          {/* Empty State */}
          <div
            style={{
              background: t.surface,
              borderRadius: 20,
              padding: 32,
              textAlign: "center" as const,
              position: "relative" as const,
              overflow: "hidden",
            }}
          >
            <div style={darkPattern(0.15, "sage.png")} />
            <div style={{ position: "relative" as const }}>
              <div style={{ marginBottom: 12, color: t.sage, display: "flex", justifyContent: "center" }}>
                <IconLeaf />
              </div>
              <div style={{ color: t.textPrimary, fontSize: 17, fontWeight: 600, marginBottom: 6 }}>
                No data yet
              </div>
              <div style={{ color: t.textSecondary, fontSize: 13, lineHeight: 1.5, marginBottom: 16 }}>
                Connect an app or log your first entry.
              </div>
              <div
                style={{
                  display: "inline-block",
                  background: t.sage,
                  borderRadius: 100,
                  padding: "10px 24px",
                  position: "relative" as const,
                  overflow: "hidden",
                }}
              >
                <div style={sagePattern(0.28)} />
                <span
                  style={{
                    position: "relative" as const,
                    color: t.textOnSage,
                    fontWeight: 600,
                    fontSize: 14,
                  }}
                >
                  Get Started
                </span>
              </div>
            </div>
          </div>

          {/* Onboarding */}
          <div
            style={{
              background: t.surface,
              borderRadius: 20,
              padding: 32,
              textAlign: "center" as const,
              position: "relative" as const,
              overflow: "hidden",
            }}
          >
            <div style={darkPattern(0.18, "sage.png")} />
            <div style={{ position: "relative" as const }}>
              <div style={{ color: t.sage, fontSize: 28, fontWeight: 700, marginBottom: 8 }}>
                Welcome to Zuralog
              </div>
              <div style={{ color: t.textSecondary, fontSize: 14, lineHeight: 1.5 }}>
                Your AI health assistant.
                <br />
                Let&apos;s set up your profile.
              </div>
            </div>
          </div>

          {/* FAB */}
          <div
            style={{
              display: "flex",
              flexDirection: "column" as const,
              alignItems: "center",
              justifyContent: "center",
              gap: 16,
            }}
          >
            <div
              style={{
                width: 56,
                height: 56,
                borderRadius: "50%",
                background: t.sage,
                display: "flex",
                alignItems: "center",
                justifyContent: "center",
                position: "relative" as const,
                overflow: "hidden",
                boxShadow: "0 4px 12px rgba(0,0,0,0.3)",
              }}
            >
              <div style={sagePattern(0.28)} />
              <span
                style={{
                  position: "relative" as const,
                  color: t.textOnSage,
                  fontSize: 28,
                  fontWeight: 300,
                }}
              >
                +
              </span>
            </div>
            <div style={{ color: t.textSecondary, fontSize: 11, textAlign: "center" as const }}>
              FAB — 56px
              <br />
              Sage + pattern (28%)
            </div>
          </div>
        </div>

        {/* ═══════════════════════════════════════════════════════════════════════
            14. NAVIGATION
            ═══════════════════════════════════════════════════════════════════════ */}
        <SectionTitle>Navigation</SectionTitle>
        <SectionSubtitle>Floating pill bottom bar. Transparent top bar. Sage active tab.</SectionSubtitle>

        <div style={{ background: t.surface, borderRadius: 20, padding: 24, marginBottom: 32 }}>
          {/* Top bar mock */}
          <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 24 }}>
            <div style={{ color: t.textPrimary, fontSize: 28, fontWeight: 600 }}>Today</div>
            <div
              style={{
                width: 36,
                height: 36,
                borderRadius: "50%",
                background: t.surfaceRaised,
                display: "flex",
                alignItems: "center",
                justifyContent: "center",
                position: "relative" as const,
                overflow: "hidden",
              }}
            >
              <div style={darkPattern(0.2, "original.png")} />
              <span style={{ position: "relative" as const, color: t.sage, fontSize: 14, fontWeight: 600 }}>
                AJ
              </span>
            </div>
          </div>

          {/* Bottom nav mock */}
          <div
            style={{
              background: t.canvas,
              borderRadius: 100,
              padding: "10px 8px",
              display: "flex",
              justifyContent: "space-around",
              alignItems: "center",
            }}
          >
            {[
              { label: "Today", active: true },
              { label: "Data", active: false },
              { label: "Coach", active: false },
              { label: "Progress", active: false },
              { label: "Trends", active: false },
            ].map((tab) => (
              <div
                key={tab.label}
                style={{
                  padding: "6px 16px",
                  borderRadius: 100,
                  background: tab.active ? "rgba(207,225,185,0.12)" : "transparent",
                }}
              >
                <span
                  style={{
                    color: tab.active ? t.sage : t.textSecondary,
                    fontSize: 12,
                    fontWeight: tab.active ? 600 : 400,
                  }}
                >
                  {tab.label}
                </span>
              </div>
            ))}
          </div>
        </div>

        {/* ═══════════════════════════════════════════════════════════════════════
            15. PATTERN REFERENCE
            ═══════════════════════════════════════════════════════════════════════ */}
        <SectionTitle>Topographic Pattern Reference</SectionTitle>
        <SectionSubtitle>
          Every surface that gets the brand pattern. Light surfaces use color-burn blend. Dark surfaces
          use screen blend. Web uses higher opacity than mobile for visibility.
        </SectionSubtitle>

        <div style={{ background: t.surface, borderRadius: 20, overflow: "hidden" }}>
          <table
            style={{
              width: "100%",
              borderCollapse: "collapse" as const,
              fontSize: 13,
            }}
          >
            <thead>
              <tr style={{ borderBottom: `1px solid rgba(240,238,233,0.08)` }}>
                {["Component", "Opacity", "Blend", "Notes"].map((h) => (
                  <th
                    key={h}
                    style={{
                      textAlign: "left" as const,
                      padding: "12px 16px",
                      color: t.textSecondary,
                      fontSize: 11,
                      textTransform: "uppercase" as const,
                      letterSpacing: 0.5,
                      fontWeight: 500,
                    }}
                  >
                    {h}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {[
                { comp: "Primary button", opacity: "25-28%", blend: "Color-burn", note: "sage.png — cover" },
                { comp: "Destructive button", opacity: "25%", blend: "Color-burn", note: "crimson.png — cover" },
                { comp: "FAB", opacity: "28%", blend: "Color-burn", note: "sage.png — cover" },
                { comp: "Hero card", opacity: "18%", blend: "Screen", note: "sage.png — cover" },
                { comp: "Feature card", opacity: "15%", blend: "Screen", note: "sage.png — cover" },
                { comp: "Empty state", opacity: "15%", blend: "Screen", note: "sage.png — cover" },
                { comp: "Onboarding", opacity: "18%", blend: "Screen", note: "sage.png — cover" },
                { comp: "Toggle track (on)", opacity: "28%", blend: "Color-burn", note: "sage.png — cover" },
                { comp: "Slider thumb + track", opacity: "28% / 25%", blend: "Color-burn", note: "sage.png — cover" },
                { comp: "Checkbox (checked)", opacity: "28%", blend: "Color-burn", note: "sage.png — cover" },
                { comp: "Progress bar", opacity: "25%", blend: "Color-burn", note: "sage.png — cover" },
                { comp: "Active chip", opacity: "15%", blend: "Screen", note: "original.png — cover" },
                { comp: "Default avatar", opacity: "20%", blend: "Screen", note: "original.png — cover" },
                { comp: "List icon squares", opacity: "18%", blend: "Screen", note: "original.png — cover" },
                { comp: "Search bar", opacity: "8%", blend: "Screen", note: "original.png — cover" },
                { comp: "Tab track", opacity: "6%", blend: "Screen", note: "sage.png — cover" },
                { comp: "Category cards", opacity: "15%", blend: "Screen", note: "[color].png — cover" },
              ].map((row, i) => (
                <tr
                  key={row.comp}
                  style={{
                    borderBottom:
                      i < 16 ? "1px solid rgba(240,238,233,0.04)" : "none",
                  }}
                >
                  <td style={{ padding: "10px 16px", color: t.textPrimary }}>{row.comp}</td>
                  <td style={{ padding: "10px 16px", color: t.sage, fontFamily: "monospace" }}>
                    {row.opacity}
                  </td>
                  <td style={{ padding: "10px 16px", color: t.textSecondary }}>{row.blend}</td>
                  <td style={{ padding: "10px 16px", color: t.textSecondary, fontSize: 12 }}>
                    {row.note}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        {/* Footer */}
        <div
          style={{
            marginTop: 64,
            paddingTop: 24,
            borderTop: "1px solid rgba(240,238,233,0.06)",
            color: t.textSecondary,
            fontSize: 12,
            textAlign: "center" as const,
          }}
        >
          Zuralog Design System — Dark Mode — {new Date().getFullYear()}
        </div>
      </div>
    </div>
  );
}
