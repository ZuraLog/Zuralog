"use client";

// Single fixed full-viewport background layer.
// The redesign uses one cream color throughout (#F0EEE9) — no scroll-driven
// color transitions. The old section-specific journey was removed when
// MobileSection, BentoSection, HowItWorksSection, and PhoneMockupSection
// were replaced with the new feature sections.

export function PageBackground() {
  return (
    <div
      aria-hidden="true"
      className="fixed inset-0 -z-10 pointer-events-none"
      style={{ backgroundColor: "var(--color-ds-warm-white)" }}
    />
  );
}
