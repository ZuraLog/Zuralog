/**
 * HeroSceneLoader — SSR-safe dynamic loader for the 3D hero scene.
 *
 * Key rendering decisions:
 *   - alpha: true  → WebGL canvas is transparent so the CSS background shows through
 *   - scene.background = null  → enforced inside HeroScene via useThree
 *   - Canvas sits at z-index 0 (not -z-10) inside an absolute inset container
 *     that is itself positioned correctly within the hero section stack
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
 * Renders the transparent 3D hero Canvas with SSR guard.
 */
export function HeroSceneLoader() {
  const { isMobile } = useDevice();

  return (
    <Suspense fallback={null}>
      <Canvas
        dpr={[1, isMobile ? 1.5 : 2]}
        gl={{
          antialias: !isMobile,
          alpha: true,              // transparent WebGL canvas
          powerPreference: "high-performance",
        }}
        camera={{ position: [0, 0, 6], fov: 50 }}
        style={{
          position: "absolute",
          inset: 0,
          width: "100%",
          height: "100%",
        }}
      >
        <HeroScene isMobile={isMobile} />
      </Canvas>
    </Suspense>
  );
}
