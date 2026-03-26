"use client";

/**
 * AuroraBackground — CSS-only ambient glow behind the brand bible.
 * Three radial-gradient blobs rotate slowly at very low opacity,
 * creating a subtle living backdrop without any JavaScript cost.
 */
export function AuroraBackground() {
  return (
    <div
      className="fixed inset-0 -z-10 overflow-hidden pointer-events-none"
      aria-hidden="true"
    >
      {/* Sage blob — top-left */}
      <div
        className="ds-aurora-blob absolute w-[600px] h-[600px] rounded-full opacity-[0.04]"
        style={{
          background: "radial-gradient(circle, #CFE1B9, transparent 70%)",
          top: "10%",
          left: "20%",
          filter: "blur(80px)",
          animation: "dsAuroraFloat1 60s linear infinite",
        }}
      />
      {/* Vitals blue blob — mid-right */}
      <div
        className="ds-aurora-blob absolute w-[500px] h-[500px] rounded-full opacity-[0.03]"
        style={{
          background: "radial-gradient(circle, #6AC4DC, transparent 70%)",
          top: "40%",
          right: "10%",
          filter: "blur(80px)",
          animation: "dsAuroraFloat2 45s linear infinite",
        }}
      />
      {/* Wellness purple blob — bottom-left */}
      <div
        className="ds-aurora-blob absolute w-[400px] h-[400px] rounded-full opacity-[0.03]"
        style={{
          background: "radial-gradient(circle, #BF5AF2, transparent 70%)",
          bottom: "20%",
          left: "30%",
          filter: "blur(80px)",
          animation: "dsAuroraFloat3 55s linear infinite",
        }}
      />
    </div>
  );
}
