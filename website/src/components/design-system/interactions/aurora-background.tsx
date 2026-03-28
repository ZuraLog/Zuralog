"use client";

import { useBrandBibleThemeOptional } from "./brand-bible-theme";

/**
 * AuroraBackground — CSS-only ambient glow behind the brand bible.
 * Three radial-gradient blobs rotate slowly, creating a living backdrop.
 * In light mode the blobs shift to warm forest tones instead of glowing sage.
 */
export function AuroraBackground() {
  const themeCtx = useBrandBibleThemeOptional();
  const isLight = themeCtx?.isLight ?? false;

  return (
    <div
      className="fixed inset-0 z-[1] overflow-hidden pointer-events-none"
      aria-hidden="true"
    >
      {/* Sage / Forest blob — top-left */}
      <div
        className="ds-aurora-blob absolute w-[900px] h-[900px] rounded-full"
        style={{
          background: isLight
            ? "radial-gradient(circle, rgba(52,78,65,0.07), transparent 70%)"
            : "radial-gradient(circle, rgba(207,225,185,0.18), transparent 70%)",
          top: "0%",
          left: "5%",
          filter: "blur(100px)",
          animation: "dsAuroraFloat1 60s linear infinite",
        }}
      />
      {/* Vitals blue blob — mid-right */}
      <div
        className="ds-aurora-blob absolute w-[800px] h-[800px] rounded-full"
        style={{
          background: isLight
            ? "radial-gradient(circle, rgba(106,196,220,0.06), transparent 70%)"
            : "radial-gradient(circle, rgba(106,196,220,0.12), transparent 70%)",
          top: "30%",
          right: "0%",
          filter: "blur(100px)",
          animation: "dsAuroraFloat2 45s linear infinite",
        }}
      />
      {/* Wellness purple blob — bottom-left */}
      <div
        className="ds-aurora-blob absolute w-[700px] h-[700px] rounded-full"
        style={{
          background: isLight
            ? "radial-gradient(circle, rgba(191,90,242,0.04), transparent 70%)"
            : "radial-gradient(circle, rgba(191,90,242,0.10), transparent 70%)",
          bottom: "10%",
          left: "15%",
          filter: "blur(100px)",
          animation: "dsAuroraFloat3 55s linear infinite",
        }}
      />
    </div>
  );
}
