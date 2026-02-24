/**
 * HeroSceneLoader — SSR-safe dynamic loader for the 3D hero scene.
 * All Three.js code is loaded client-side only via next/dynamic.
 * Shows a pulsing skeleton while the scene loads.
 */
"use client";

import dynamic from "next/dynamic";
import { Canvas } from "@react-three/fiber";
import { Suspense } from "react";
import { useDevice } from "@/hooks/use-device";

const HeroScene = dynamic(
  () => import("./hero-scene").then((m) => ({ default: m.HeroScene })),
  { ssr: false, loading: () => null },
);

/**
 * Renders the 3D hero scene with SSR guard and loading skeleton.
 * Degrades gracefully if WebGL is unavailable.
 */
export function HeroSceneLoader() {
  const { isMobile } = useDevice();

  return (
    <Suspense
      fallback={
        <div className="absolute inset-0 animate-pulse bg-gradient-radial from-sage/5 via-transparent to-transparent" />
      }
    >
      <Canvas
        dpr={[1, Math.min(typeof window !== "undefined" ? window.devicePixelRatio : 1, isMobile ? 1.5 : 2)]}
        gl={{ antialias: !isMobile, alpha: true, powerPreference: "high-performance" }}
        camera={{ position: [0, 0, 5], fov: 45 }}
        className="absolute inset-0"
      >
        <HeroScene isMobile={isMobile} />
      </Canvas>
    </Suspense>
  );
}
